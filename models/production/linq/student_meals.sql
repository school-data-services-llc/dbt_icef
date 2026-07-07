{{ config(materialized='view', schema='linq', enabled=false) }}

-- One row per meal served (participation record), enriched with the student's
-- best application for that academic year. Prefers Processed applications over
-- Duplicate/other statuses, then the most recent by application_date.
-- student_id is FLOAT64 in the source tables, so it is cast to INT64 both to
-- allow PARTITION BY and to keep the join/grain clean.

WITH latest_applications AS (
  SELECT
    * EXCEPT (student_id),
    CAST(student_id AS INT64) AS student_id,
    ROW_NUMBER() OVER (
      PARTITION BY CAST(student_id AS INT64), academic_year
      ORDER BY
        CASE WHEN application_status = 'Processed' THEN 0 ELSE 1 END,
        application_date DESC
    ) AS rn
  FROM {{ source('linq', 'linq_meal_applications') }}
  WHERE student_id IS NOT NULL
),

participation AS (
  SELECT
    *,
    CAST(student_id AS INT64) AS student_id_int,
    -- Academic years run July-June: meals served July-December belong to the
    -- year that started that July; January-June meals belong to the prior one.
    CASE
      WHEN EXTRACT(MONTH FROM PARSE_DATE('%Y-%m-%d', participation_date)) >= 7
        THEN FORMAT(
          '%d-%d',
          EXTRACT(YEAR FROM PARSE_DATE('%Y-%m-%d', participation_date)),
          EXTRACT(YEAR FROM PARSE_DATE('%Y-%m-%d', participation_date)) + 1
        )
      ELSE FORMAT(
        '%d-%d',
        EXTRACT(YEAR FROM PARSE_DATE('%Y-%m-%d', participation_date)) - 1,
        EXTRACT(YEAR FROM PARSE_DATE('%Y-%m-%d', participation_date))
      )
    END AS academic_year
  FROM {{ source('linq', 'linq_meal_participation') }}
)

SELECT
  p.student_id_int AS student_id,
  p.participation_date,
  p.meal_type,
  p.school,
  p.grade,
  p.eligibility_at_meal,
  a.application_status,
  a.eligibility_type AS application_eligibility_type,
  a.application_date,
  p.academic_year,
  p.personid AS person_id,
  p.customerdocumentid AS customer_document_id
FROM participation p
LEFT JOIN latest_applications a
  ON p.student_id_int = a.student_id
  AND p.academic_year = a.academic_year
  AND a.rn = 1
