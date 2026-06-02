{{ config(materialized='view', schema='views') }}

-- CAST summative: current from state_testing_continuous (24-25) and state_testing_continuous_25_26 (25-26).
-- No prev_year_* columns: CAST is only administered in grades 5, 8, and HS (12), so students don't take it
-- in consecutive years and there is no meaningful prior-year value to surface.
-- Domain scores (cast__*): STRING reporting bands / category text on both continuous extracts.

WITH cast_continuous_2425 AS (
  SELECT DISTINCT
    studentidentifier,
    student_number,
    assessmentname,
    scalescoreachievementlevel,
    proficiency,
    dfs_cast AS cast_dfs,
    scalescore,
    lexilemeasure,
    -- Reporting-category performance (STRING); do not cast to FLOAT64 or bands become NULL.
    CAST(`cast__life_sciences` AS STRING) AS `cast__life_sciences`,
    CAST(`cast__physical_sciences` AS STRING) AS `cast__physical_sciences`,
    CAST(`cast__earth_and_space_sciences` AS STRING) AS `cast__earth_and_space_sciences`
  FROM {{ source('state_testing', 'state_testing_continuous') }}
  WHERE assessmentname IN ('CAST Summative Grade 5', 'CAST Summative Grade 8', 'CAST Summative Grade HS')
),

cast_continuous_2526 AS (
  SELECT
    a.StudentIdentifier AS studentidentifier,
    a.student_number,
    a.AssessmentName AS assessmentname,
    a.ScaleScoreAchievementLevel AS scalescoreachievementlevel,
    a.proficiency,
    a.dfs_cast AS cast_dfs,
    a.ScaleScore AS scalescore,
    a.LexileMeasure AS lexilemeasure,
    CAST(a.`CAST: Life Sciences` AS STRING) AS `cast__life_sciences`,
    CAST(a.`CAST: Physical Sciences` AS STRING) AS `cast__physical_sciences`,
    CAST(a.`CAST: Earth and Space Sciences` AS STRING) AS `cast__earth_and_space_sciences`
  FROM {{ source('state_testing', 'state_testing_continuous_25_26') }} a
  WHERE a.AssessmentName IN ('CAST Summative Grade 5', 'CAST Summative Grade 8', 'CAST Summative Grade HS')
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY a.student_number, a.AssessmentName
    ORDER BY {{ state_testing_25_26_latest_row_order() }}
  ) = 1
),

student_to_teacher_2425 AS (
  SELECT
    student_number,
    lastfirst,
    grade_level,
    elastatus,
    race,
    school_name,
    sped_identifier,
    absenteeism_status,
    hit_tutoring,
    science_teacher,
    math_teacher,
    CASE
      WHEN grade_level = 5 THEN math_teacher
      WHEN grade_level IN (8, 12) THEN science_teacher
      ELSE NULL
    END AS teacher
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year = '24-25'
),

student_to_teacher_2526 AS (
  SELECT
    student_number,
    lastfirst,
    grade_level,
    elastatus,
    race,
    school_name,
    sped_identifier,
    absenteeism_status,
    hit_tutoring,
    science_teacher,
    math_teacher,
    CASE
      WHEN grade_level = 5 THEN math_teacher
      WHEN grade_level IN (8, 12) THEN science_teacher
      ELSE NULL
    END AS teacher
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year = '25-26'
),

current_year_2425 AS (
  SELECT
    cc.studentidentifier,
    cc.student_number,
    cc.assessmentname,
    cc.scalescoreachievementlevel,
    cc.proficiency,
    cc.cast_dfs,
    cc.scalescore,
    CAST(cc.lexilemeasure AS FLOAT64) AS lexilemeasure,
    cc.`cast__life_sciences`,
    cc.`cast__physical_sciences`,
    cc.`cast__earth_and_space_sciences`,
    st.lastfirst,
    st.grade_level,
    st.elastatus,
    st.race,
    st.school_name,
    st.sped_identifier,
    st.absenteeism_status,
    st.hit_tutoring,
    st.teacher,
    '24-25' AS year
  FROM cast_continuous_2425 cc
  RIGHT JOIN student_to_teacher_2425 st
    ON cc.student_number = st.student_number
  WHERE st.grade_level IN (5, 8, 12)
),

current_year_2526 AS (
  SELECT
    cc.studentidentifier,
    COALESCE(cc.student_number, st.student_number) AS student_number,
    cc.assessmentname,
    cc.scalescoreachievementlevel,
    cc.proficiency,
    cc.cast_dfs,
    cc.scalescore,
    CAST(cc.lexilemeasure AS FLOAT64) AS lexilemeasure,
    cc.`cast__life_sciences`,
    cc.`cast__physical_sciences`,
    cc.`cast__earth_and_space_sciences`,
    st.lastfirst,
    st.grade_level,
    st.elastatus,
    st.race,
    st.school_name,
    st.sped_identifier,
    st.absenteeism_status,
    st.hit_tutoring,
    st.teacher,
    '25-26' AS year
  FROM cast_continuous_2526 cc
  RIGHT JOIN student_to_teacher_2526 st
    ON cc.student_number = st.student_number
  WHERE st.grade_level IN (5, 8, 12)
),

historical AS (
  SELECT
    studentidentifier,
    student_number,
    assessmentname,
    scalescoreachievementlevel,
    proficiency,
    cast_dfs,
    scalescore,
    CAST(lexilemeasure AS FLOAT64) AS lexilemeasure,
    CAST(`cast__life_sciences` AS STRING) AS `cast__life_sciences`,
    CAST(`cast__physical_sciences` AS STRING) AS `cast__physical_sciences`,
    CAST(`cast__earth_and_space_sciences` AS STRING) AS `cast__earth_and_space_sciences`,
    lastfirst,
    grade_level,
    elastatus,
    race,
    school_name,
    sped_identifier,
    absenteeism_status,
    CAST(NULL AS STRING) AS hit_tutoring,
    teacher,
    '24-25' AS year
  FROM `icef-437920.dbt_historical.cast_state_testing_tabular_24-25`
),

-- current_year_2425 (live source) is authoritative for 24-25; the snapshot has NULLs for the
-- cast__* domain bands which prevents SELECT DISTINCT from collapsing duplicate rows.
-- Keep snapshot rows only for students NOT in the live branch (e.g., students no longer on the roster).
historical_24_25_only AS (
  SELECT h.*
  FROM historical h
  LEFT JOIN current_year_2425 c
    ON h.studentidentifier = c.studentidentifier
    OR h.student_number    = c.student_number
  WHERE c.studentidentifier IS NULL
    AND c.student_number    IS NULL
)

SELECT DISTINCT *
FROM (
  SELECT * FROM current_year_2425
  UNION ALL
  SELECT * FROM current_year_2526
  UNION ALL
  SELECT * FROM historical_24_25_only
)


-- have jenny spot check dfs_cast values look correct. 
-- reference `icef-437920.logging.data_pipeline_audit` table.