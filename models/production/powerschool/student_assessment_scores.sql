{{ config(materialized='view', schema='views') }}

-- pq_student_assessment_scores (latest daily snapshot) enriched with:
--   week_number from powerschool.school_calendar (matched on grade_entered_date
--   Monday + school year), and all student_to_teacher roster columns.
-- school_year on scores is 'YYYY-YYYY'; calendar/roster use 'YY-YY'.

WITH latest_snapshot AS (
  SELECT MAX(partitiontime) AS max_partitiontime
  FROM {{ source('powerschool', 'pq_student_assessment_scores') }}
),

scores AS (
  SELECT
    a.*,
    CONCAT(
      SUBSTR(a.school_year, 3, 2),
      '-',
      SUBSTR(a.school_year, 8, 2)
    ) AS school_year_short,
    DATE_TRUNC(
      SAFE.PARSE_DATE('%Y-%m-%d', a.grade_entered_date),
      WEEK(MONDAY)
    ) AS grade_week_monday
  FROM {{ source('powerschool', 'pq_student_assessment_scores') }} a
  INNER JOIN latest_snapshot ls
    ON a.partitiontime = ls.max_partitiontime
),

calendar AS (
  SELECT
    school_year,
    week_number,
    SAFE.PARSE_DATE('%Y-%m-%d', monday_date) AS monday_date
  FROM {{ source('powerschool', 'school_calendar') }}
)

SELECT
  s.* EXCEPT (school_year_short, grade_week_monday),
  c.week_number,
  st.year,
  st.ssid,
  st.lastfirst,
  st.grade_level,
  st.teacherid,
  st.elem_teacher,
  st.homeroom_teacher,
  st.english_teacher,
  st.math_teacher,
  st.history_teacher,
  st.science_teacher,
  st.spanish_teacher,
  st.school_name,
  st.race,
  st.elastatus,
  st.frlstatus,
  st.sped_identifier,
  st.ishomeless,
  st.isfoster,
  st.hit_tutoring,
  st.current_ada,
  st.chronically_absent,
  st.absenteeism_status,
  st.`where`,
  st.is_count_active,
  st.new_or_current
FROM scores s
LEFT JOIN calendar c
  ON c.school_year = s.school_year_short
 AND c.monday_date = s.grade_week_monday
LEFT JOIN {{ source('views', 'student_to_teacher') }} st
  ON SAFE_CAST(s.student_number AS INT64) = st.student_number
 AND s.school_year_short = st.year
