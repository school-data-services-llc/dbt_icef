{{ config(materialized='view', schema='views') }}

-- One row per student per academic year. When LINQ returns multiple applications,
-- keep the best status (closest to a final decision), then the most recent
-- application_date. Rows without a SIS student_id are excluded.

WITH ranked AS (
  SELECT
  * EXCEPT (student_id),
  CAST(student_id AS INT64) AS student_id,
  DATE(SAFE.PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S%Ez', application_date)) AS application_date_parsed,
  ROW_NUMBER() OVER (
    PARTITION BY CAST(student_id AS INT64), academic_year
    ORDER BY
      CASE application_status
        WHEN 'Processed'               THEN 1
        WHEN 'Reviewed'                THEN 2
        WHEN 'Second Review'           THEN 3
        WHEN 'Verification'            THEN 4
        WHEN 'Submitted'               THEN 5
        WHEN 'On Hold'                 THEN 6
        WHEN 'In Progress (Incomplete)' THEN 7
        WHEN 'In Progress (Draft)'     THEN 8
        WHEN 'Invalid'                 THEN 9
        WHEN 'Duplicate'               THEN 10
        ELSE 50
      END,
      SAFE.PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S%Ez', application_date) DESC
  ) AS rn
  FROM {{ source('linq', 'linq_meal_applications') }}
  WHERE student_id IS NOT NULL
)

SELECT
  student_id,
  personid AS person_id,
  familymealapplicationid AS family_meal_application_id,
  mealapplicationid AS meal_application_id,
  school,
  grade,
  application_status,
  application_status = 'Processed' AS is_finalized,
  eligibility_type,
  eligibility_benefit_type,
  application_date_parsed AS application_date,
  academic_year,
  firstname AS first_name,
  lastname AS last_name
FROM ranked
WHERE rn = 1
