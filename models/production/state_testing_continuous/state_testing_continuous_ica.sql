{{ config(
    materialized='view',
    schema='state_testing'
) }}

-- ICA subset of state_testing.state_testing_continuous_25-26, shaped for main.
-- Filters to assessmenttype LIKE 'ICA'; joins student_to_teacher for grade; grade 11 math → curriculum 'Algebra II'.

WITH ica AS (
  SELECT
    a.Student_number,
    a.AssessmentName AS Assessmentname,
    a.Subject,
    a.ScaleScoreAchievementLevel AS Scalescoreachievementlevel,
    a.ScaleScore AS Scalescore
  FROM {{ source('state_testing', 'state_testing_continuous_25_26') }} a
  WHERE LOWER(TRIM(CAST(a.AssessmentType AS STRING))) LIKE '%ica%'
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY a.student_number, a.AssessmentName
    ORDER BY {{ state_testing_25_26_latest_row_order() }}
  ) = 1
),

student_to_teacher AS (
  SELECT
    student_number,
    grade_level
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year = '25-26'
)

SELECT
  CAST('CERS' AS STRING) AS data_source,
  CAST(NULL AS STRING) AS assessment_id,
  CAST('25-26' AS STRING) AS year,
  CAST(NULL AS STRING) AS date_taken,
  CAST(st.grade_level AS STRING) AS grade,
  CAST(i.Student_number AS STRING) AS local_student_id,
  CAST('assessment' AS STRING) AS test_type,
  CAST(
    CASE
      WHEN LOWER(TRIM(CAST(i.Subject AS STRING))) = 'math'
        AND CAST(i.Assessmentname AS STRING) = 'Grade 11 MATH - Interim Comprehensive Assessment (ICA)'
      THEN 'Algebra II'
      ELSE CAST(i.Subject AS STRING)
    END AS STRING
  ) AS curriculum,
  CAST('ICA' AS STRING) AS unit,
  CAST(NULL AS STRING) AS unit_labels,
  CAST(i.Assessmentname AS STRING) AS title,
  CAST('percent' AS STRING) AS standard_code,
  CAST(i.Scalescore AS STRING) AS score,
  CAST(NULL AS STRING) AS performance_band_level,
  CAST(NULL AS STRING) AS performance_band_label,
  CAST(i.Scalescoreachievementlevel AS STRING) AS proficiency
FROM ica i
INNER JOIN student_to_teacher st
  ON i.Student_number = st.student_number
