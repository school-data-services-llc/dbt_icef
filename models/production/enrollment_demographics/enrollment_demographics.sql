{{ config(materialized='view', schema='views') }}

-- Enrollment demographics + budget vs actual seats, by school / grade / year.
-- Capacity:
--   25-26 <- enrollment.budgeted_enrollment_capacity_hardcode_8_18_25
--   26-27 <- enrollment.budgeted_enrollment_capacity (year column)
-- Roster / subgroups from student_to_teacher for the same years.

WITH capacity AS (
  SELECT
    school_name,
    CAST(grade_level AS STRING) AS grade_level,
    '25-26' AS year,
    CAST(budgeted_enrollment AS INT64) AS budgeted_enrollment
  FROM {{ source('enrollment', 'budgeted_enrollment_capacity_hardcode_8_18_25') }}

  UNION ALL

  SELECT
    school_name,
    CAST(grade_level AS STRING) AS grade_level,
    year,
    CAST(budgeted_enrollment AS INT64) AS budgeted_enrollment
  FROM {{ source('enrollment', 'budgeted_enrollment_capacity') }}
  WHERE year = '26-27'
),

total_students_cte AS (
  SELECT
    school_name,
    year,
    CAST(grade_level AS STRING) AS grade_level,
    COUNT(*) AS total_students
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year IN ('25-26', '26-27')
  GROUP BY school_name, grade_level, year
),

actual_vs_budget AS (
  SELECT
    c.school_name,
    c.year,
    c.grade_level,
    '' AS subgroup,
    '' AS demographic,
    ts.total_students AS student_count,
    c.budgeted_enrollment,
    c.budgeted_enrollment - SAFE_CAST(ts.total_students AS INT64) AS seats_remaining,
    ROUND(
      SAFE_DIVIDE(ts.total_students, CAST(c.budgeted_enrollment AS FLOAT64)),
      3
    ) AS percent_of_seats_filled
  FROM capacity c
  LEFT JOIN total_students_cte ts
    ON c.school_name = ts.school_name
   AND c.grade_level = ts.grade_level
   AND c.year = ts.year
),

school_totals AS (
  SELECT
    school_name,
    year,
    'total' AS grade_level,
    '' AS subgroup,
    '' AS demographic,
    SUM(student_count) AS student_count,
    SUM(budgeted_enrollment) AS budgeted_enrollment,
    SUM(seats_remaining) AS seats_remaining,
    ROUND(
      SAFE_DIVIDE(SUM(student_count), SUM(budgeted_enrollment)),
      3
    ) AS percent_of_seats_filled
  FROM actual_vs_budget
  GROUP BY school_name, year
),

subgroup_counts AS (
  SELECT
    school_name,
    year,
    CAST(grade_level AS STRING) AS grade_level,
    'race' AS subgroup,
    race AS demographic,
    COUNT(*) AS student_count,
    CAST(NULL AS INT64) AS budgeted_enrollment,
    CAST(NULL AS INT64) AS seats_remaining,
    CAST(NULL AS FLOAT64) AS percent_of_seats_filled
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year IN ('25-26', '26-27')
  GROUP BY school_name, year, grade_level, race

  UNION ALL

  SELECT
    school_name,
    year,
    CAST(grade_level AS STRING) AS grade_level,
    'elastatus' AS subgroup,
    elastatus AS demographic,
    COUNT(*) AS student_count,
    CAST(NULL AS INT64) AS budgeted_enrollment,
    CAST(NULL AS INT64) AS seats_remaining,
    CAST(NULL AS FLOAT64) AS percent_of_seats_filled
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year IN ('25-26', '26-27')
  GROUP BY school_name, year, grade_level, elastatus

  UNION ALL

  SELECT
    school_name,
    year,
    CAST(grade_level AS STRING) AS grade_level,
    'sped_identifier' AS subgroup,
    sped_identifier AS demographic,
    COUNT(*) AS student_count,
    CAST(NULL AS INT64) AS budgeted_enrollment,
    CAST(NULL AS INT64) AS seats_remaining,
    CAST(NULL AS FLOAT64) AS percent_of_seats_filled
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year IN ('25-26', '26-27')
  GROUP BY school_name, year, grade_level, sped_identifier

  UNION ALL

  SELECT
    school_name,
    year,
    CAST(grade_level AS STRING) AS grade_level,
    'absenteeism_status' AS subgroup,
    absenteeism_status AS demographic,
    COUNT(*) AS student_count,
    CAST(NULL AS INT64) AS budgeted_enrollment,
    CAST(NULL AS INT64) AS seats_remaining,
    CAST(NULL AS FLOAT64) AS percent_of_seats_filled
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year IN ('25-26', '26-27')
  GROUP BY school_name, year, grade_level, absenteeism_status

  UNION ALL

  SELECT
    school_name,
    year,
    CAST(grade_level AS STRING) AS grade_level,
    'frlstatus' AS subgroup,
    frlstatus AS demographic,
    COUNT(*) AS student_count,
    CAST(NULL AS INT64) AS budgeted_enrollment,
    CAST(NULL AS INT64) AS seats_remaining,
    CAST(NULL AS FLOAT64) AS percent_of_seats_filled
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year IN ('25-26', '26-27')
  GROUP BY school_name, year, grade_level, frlstatus
)

SELECT * FROM actual_vs_budget
UNION ALL
SELECT * FROM school_totals
UNION ALL
SELECT * FROM subgroup_counts
ORDER BY year, school_name, grade_level, subgroup, demographic
