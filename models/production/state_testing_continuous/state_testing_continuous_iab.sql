{{ config(
    materialized='view',
    schema='state_testing'
) }}

-- FIAB/IAB subset of state_testing continuous extracts, shaped for main.
-- year follows SchoolYear (2025-26 → 25-26, 2026-27 → 26-27).
-- Joins student_to_teacher on StudentIdentifier = ssid for that same year.

WITH iab_raw AS (
  SELECT
    a.StudentIdentifier,
    a.student_number,
    a.AssessmentName AS assessmentname,
    a.Subject AS subject,
    a.SubmitDateTime AS submitdatetime,
    a.ScaleScore AS scalescore,
    a.`Reporting Category` AS reporting_category,
    a.SchoolYear AS schoolyear,
    a.file_name
  FROM {{ source('state_testing', 'state_testing_continuous_25_26') }} a
  WHERE LOWER(TRIM(CAST(a.AssessmentType AS STRING))) LIKE '%iab%'

  UNION ALL

  SELECT
    a.StudentIdentifier,
    a.student_number,
    a.AssessmentName AS assessmentname,
    a.Subject AS subject,
    a.SubmitDateTime AS submitdatetime,
    a.ScaleScore AS scalescore,
    a.`Reporting Category` AS reporting_category,
    a.SchoolYear AS schoolyear,
    a.file_name
  FROM {{ source('state_testing', 'state_testing_continuous_26_27') }} a
  WHERE LOWER(TRIM(CAST(a.AssessmentType AS STRING))) LIKE '%iab%'
),

iab AS (
  SELECT
    *,
    CASE
      WHEN CAST(schoolyear AS STRING) IN ('2025-26', '25-26') THEN '25-26'
      WHEN CAST(schoolyear AS STRING) IN ('2026-27', '26-27') THEN '26-27'
      ELSE CONCAT(
        SUBSTR(CAST(schoolyear AS STRING), 3, 2),
        '-',
        SUBSTR(CAST(schoolyear AS STRING), 8, 2)
      )
    END AS year
  FROM iab_raw
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
      CASE
        WHEN CAST(schoolyear AS STRING) IN ('2025-26', '25-26') THEN '25-26'
        WHEN CAST(schoolyear AS STRING) IN ('2026-27', '26-27') THEN '26-27'
        ELSE CONCAT(
          SUBSTR(CAST(schoolyear AS STRING), 3, 2),
          '-',
          SUBSTR(CAST(schoolyear AS STRING), 8, 2)
        )
      END,
      student_number,
      assessmentname
    ORDER BY {{ state_testing_25_26_submit_datetime('submitdatetime') }} DESC NULLS LAST, file_name DESC
  ) = 1
),

student_to_teacher AS (
  SELECT
    student_number,
    ssid,
    grade_level,
    year
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year IN ('25-26', '26-27')
)

SELECT
  CAST('CERS' AS STRING) AS data_source,
  CAST(NULL AS STRING) AS assessment_id,
  CAST(i.year AS STRING) AS year,
  CAST(i.submitdatetime AS STRING) AS date_taken,
  CAST(st.grade_level AS STRING) AS grade,
  CAST(st.student_number AS STRING) AS local_student_id,
  CAST('FIAB' AS STRING) AS test_type,
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
 AND i.year = st.year
