{{ config(
    materialized='view',
    schema='state_testing'
) }}

-- FIAB/IAB subset of state_testing.state_testing_continuous_25-26, shaped for main.
-- Filters to assessmenttype LIKE '%IAB%'; joins the 26-27 roster on StudentIdentifier = ssid.

WITH iab AS (
  SELECT
    a.StudentIdentifier,
    a.student_number,
    a.AssessmentName AS assessmentname,
    a.Subject AS subject,
    a.SubmitDateTime AS submitdatetime,
    a.ScaleScore AS scalescore,
    a.`Reporting Category` AS reporting_category
  FROM {{ source('state_testing', 'state_testing_continuous_25_26') }} a
  WHERE LOWER(TRIM(CAST(a.AssessmentType AS STRING))) LIKE '%iab%'
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY a.student_number, a.AssessmentName
    ORDER BY {{ state_testing_25_26_latest_row_order() }}
  ) = 1
),

student_to_teacher AS (
  SELECT
    student_number,
    ssid,
    grade_level
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year = '26-27'
)

SELECT
  CAST('CERS' AS STRING) AS data_source,
  CAST(NULL AS STRING) AS assessment_id,
  CAST('26-27' AS STRING) AS year,
  CAST(i.submitdatetime AS STRING) AS date_taken,
  CAST(st.grade_level AS STRING) AS grade,
  CAST(st.student_number AS STRING) AS local_student_id,
  CAST('assessment' AS STRING) AS test_type,
  CAST(i.subject AS STRING) AS curriculum,
  CAST(
    IF(
      STRPOS(CAST(i.assessmentname AS STRING), ' - ') > 0,
      TRIM(SUBSTR(CAST(i.assessmentname AS STRING), STRPOS(CAST(i.assessmentname AS STRING), ' - ') + 3)),
      CAST(i.assessmentname AS STRING)
    ) AS STRING
  ) AS unit,
  CAST(NULL AS STRING) AS unit_labels,
  CAST(i.assessmentname AS STRING) AS title,
  CAST('percent' AS STRING) AS standard_code,
  CAST(i.scalescore AS STRING) AS score,
  CAST(NULL AS STRING) AS performance_band_level,
  CAST(NULL AS STRING) AS performance_band_label,
  CAST(i.reporting_category AS STRING) AS proficiency
FROM iab i
INNER JOIN student_to_teacher st
  ON CAST(i.StudentIdentifier AS STRING) = CAST(st.ssid AS STRING)
