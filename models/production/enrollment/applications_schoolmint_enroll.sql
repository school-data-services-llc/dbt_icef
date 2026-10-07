{{ config(
    materialized='view',
    schema='enrollment'
) }}

-- Stacked union of historical Applications tables from dbt_historical → enrollment.applications_schoolmint_enroll.
-- `year` tags which school-year snapshot each row came from ('26-27' vs '27-28').

SELECT
  s.*,
  '26-27' AS year
FROM {{ source('dbt_historical', 'Applications_2026') }} s

UNION ALL

SELECT
  s.*,
  '27-28' AS year
FROM {{ source('dbt_historical', 'Applications_2027') }} s
