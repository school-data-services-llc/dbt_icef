{{ config(materialized='view', schema='views') }}

-- Full student_to_teacher roster (one row per student per year) left-joined to
-- the best LINQ meal eligibility record for that same academic year. Use as a
-- running record of who has coverage/submission vs who still needs an
-- application. Direct certification and categorical eligibility take precedence
-- over a family meal application when ranking LINQ rows.
--
-- Year mapping:
--   roster year 'YY-YY'  -> academic_year '20YY-20YY'
--   LINQ may send '2025-2026' or '2026/2027'; both normalize to hyphen form.
-- Roster years before 25-26 are excluded (meal tracking starts there).

WITH roster AS (
  SELECT
    CAST(student_number AS INT64) AS student_number,
    year AS roster_year,
    CONCAT(
      '20', SPLIT(year, '-')[OFFSET(0)],
      '-',
      '20', SPLIT(year, '-')[OFFSET(1)]
    ) AS academic_year,
    school_name,
    grade_level,
    lastfirst,
    ROW_NUMBER() OVER (
      PARTITION BY CAST(student_number AS INT64), year
      ORDER BY school_name
    ) AS rn
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year >= '25-26'
    AND student_number IS NOT NULL
),

categorized AS (
  SELECT
    * EXCEPT (student_id, academic_year),
    CAST(student_id AS INT64) AS student_id,
    REPLACE(academic_year, '/', '-') AS academic_year,
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

best_meal AS (
  SELECT *
  FROM ranked
  WHERE rn = 1
)

SELECT
  st.student_number AS student_id,
  m.personid AS person_id,
  m.familymealapplicationid AS family_meal_application_id,
  m.mealapplicationid AS meal_application_id,
  st.school_name AS school,
  st.grade_level AS grade,
  m.application_status,
  m.application_status = 'Processed' AS is_finalized,
  m.eligibility_type,
  m.eligibility_benefit_type,
  m.eligibility_category,
  m.application_date_parsed AS application_date,
  st.academic_year,
  COALESCE(
    m.firstname,
    NULLIF(TRIM(SPLIT(st.lastfirst, ',')[SAFE_OFFSET(1)]), '')
  ) AS first_name,
  COALESCE(
    m.lastname,
    NULLIF(TRIM(SPLIT(st.lastfirst, ',')[SAFE_OFFSET(0)]), '')
  ) AS last_name,
  m.student_id IS NULL AS needs_application
FROM roster st
LEFT JOIN best_meal m
  ON st.student_number = m.student_id
 AND st.academic_year = m.academic_year
WHERE st.rn = 1
