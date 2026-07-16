{{ config(materialized='view', schema='views') }}

-- One row per student per academic year. Direct certification and categorical
-- eligibility take precedence over a family meal application. This preserves
-- the authoritative eligibility pathway when a covered family also applies.
-- Students not on student_to_teacher for the matching school year are excluded
-- (e.g. graduates / leavers with LINQ eligibility but no current roster row).

WITH categorized AS (
  SELECT
    * EXCEPT (student_id),
    CAST(student_id AS INT64) AS student_id,
    DATE(
      SAFE.PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S%Ez', application_date)
    ) AS application_date_parsed,
    CASE
      WHEN LOWER(TRIM(eligibility_benefit_type)) IN (
        'calfresh (snap)',
        'calworks',
        'medicaid',
        'medicaid reduced'
      ) THEN 'Direct Certification'
      WHEN LOWER(TRIM(eligibility_benefit_type)) = 'homeless' THEN 'Homeless'
      WHEN LOWER(TRIM(eligibility_benefit_type)) = 'migrant' THEN 'Migrant'
      WHEN LOWER(TRIM(eligibility_benefit_type)) = 'foster' THEN 'Foster'
      ELSE 'Meal Application'
    END AS eligibility_category
  FROM {{ source('linq', 'linq_meal_applications') }}
  WHERE student_id IS NOT NULL
),

ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY student_id, academic_year
      ORDER BY
        CASE eligibility_category
          WHEN 'Direct Certification' THEN 1
          WHEN 'Homeless' THEN 2
          WHEN 'Migrant' THEN 3
          WHEN 'Foster' THEN 4
          WHEN 'Meal Application' THEN 5
          ELSE 50
        END,
        CASE application_status
          WHEN 'Processed' THEN 1
          WHEN 'Reviewed' THEN 2
          WHEN 'Second Review' THEN 3
          WHEN 'Verification' THEN 4
          WHEN 'Submitted' THEN 5
          WHEN 'On Hold' THEN 6
          WHEN 'In Progress (Incomplete)' THEN 7
          WHEN 'In Progress (Draft)' THEN 8
          WHEN 'Invalid' THEN 9
          WHEN 'Duplicate' THEN 10
          ELSE 50
        END,
        SAFE.PARSE_TIMESTAMP(
          '%Y-%m-%dT%H:%M:%E*S%Ez',
          application_date
        ) DESC,
        mealapplicationid DESC
    ) AS rn
  FROM categorized
),

roster AS (
  SELECT DISTINCT
    CAST(student_number AS INT64) AS student_number,
    year
  FROM {{ source('views', 'student_to_teacher') }}
)

SELECT
  r.student_id,
  r.personid AS person_id,
  r.familymealapplicationid AS family_meal_application_id,
  r.mealapplicationid AS meal_application_id,
  r.school,
  r.grade,
  r.application_status,
  r.application_status = 'Processed' AS is_finalized,
  r.eligibility_type,
  r.eligibility_benefit_type,
  r.eligibility_category,
  r.application_date_parsed AS application_date,
  r.academic_year,
  r.firstname AS first_name,
  r.lastname AS last_name
FROM ranked r
INNER JOIN roster st
  ON r.student_id = st.student_number
  -- LINQ academic_year is '2025-2026'; roster year is '25-26'
 AND st.year = CONCAT(
   SUBSTR(r.academic_year, 3, 2),
   '-',
   SUBSTR(r.academic_year, 8, 2)
 )
WHERE r.rn = 1
