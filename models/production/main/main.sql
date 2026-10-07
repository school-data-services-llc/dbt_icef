{{ config(
    materialized='view',
    schema='views'
) }}


WITH illuminate AS (
  SELECT
    CAST(data_source AS STRING) AS data_source,
    CAST(assessment_id AS STRING) AS assessment_id,
    CAST(year AS STRING) AS year,  -- Year as STRING
    CAST(date_taken AS STRING) AS date_taken,
    CAST(grade AS STRING) AS grade,
    CAST(local_student_id AS STRING) AS local_student_id,
    CAST(test_type AS STRING) AS test_type,
    CAST(curriculum AS STRING) AS curriculum,
    CAST(unit AS STRING) AS unit,
    CAST(unit_labels AS STRING) AS unit_labels,
    CAST(title AS STRING) AS title,
    CAST(standard_code AS STRING) AS standard_code,
    CAST(score AS STRING) AS score,  -- Score as STRING
    CAST(performance_band_level AS STRING) AS performance_band_level,
    CAST(performance_band_label AS STRING) AS performance_band_label,
    CAST(proficiency AS STRING) AS proficiency
  FROM {{ source('illuminate', 'illuminate_assessment_results') }}
), 

iready AS (
  SELECT
    CAST(data_source AS STRING),
    CAST(assessment_id AS STRING),
    CAST(year AS STRING),  -- Year as STRING
    CAST(date_taken AS STRING),
    CAST(grade AS STRING),
    CAST(local_student_id AS STRING),
    CAST(test_type AS STRING),
    CAST(curriculum AS STRING),
    CAST(unit AS STRING),
    CAST(unit_labels AS STRING),
    CAST(title AS STRING),
    CAST(standard_code AS STRING),
    CAST(score AS STRING),  -- Score as STRING
    CAST(performance_band_level AS STRING),
    CAST(performance_band_label AS STRING),
    CAST(proficiency AS STRING)
  FROM {{ source('iready', 'iready_assessment_results') }}
), 

star AS (
  SELECT
    CAST(data_source AS STRING),
    CAST(assessment_id AS STRING),
    CAST(year AS STRING),  -- Year as STRING
    CAST(date_taken AS STRING),
    CAST(grade AS STRING),
    CAST(local_student_id AS STRING),
    CAST(test_type AS STRING),
    CAST(curriculum AS STRING),
    CAST(unit AS STRING),
    CAST(unit_labels AS STRING),
    CAST(title AS STRING),
    CAST(standard_code AS STRING),
    CAST(score AS STRING),  -- Score as STRING
    CAST(performance_band_level AS STRING),
    CAST(performance_band_label AS STRING),
    CAST(proficiency AS STRING)
  FROM {{ source('star', 'star_assessment_results') }}
), 

dibels AS (
  SELECT
    CAST(data_source AS STRING),
    CAST(assessment_id AS STRING),
    CAST(year AS STRING),  -- Year as STRING
    CAST(date_taken AS STRING),
    CAST(grade AS STRING),
    CAST(local_student_id AS STRING),
    CAST(test_type AS STRING),
    CAST(curriculum AS STRING),
    CAST(unit AS STRING),
    CAST(unit_labels AS STRING),
    CAST(title AS STRING),
    CAST(standard_code AS STRING),
    CAST(score AS STRING),  -- Score as STRING
    CAST(performance_band_level AS STRING),
    CAST(performance_band_label AS STRING),
    CAST(proficiency AS STRING)
  FROM {{ source('dibels', 'dibels_assessment_results') }}
),

sbac AS (
  SELECT
    CAST(data_source AS STRING),
    CAST(NULL AS STRING) AS assessment_id,  -- Explicitly cast NULL as STRING
    CAST(year AS STRING),  
    CAST(NULL AS STRING) AS date_taken,  
    CAST(grade AS STRING),
    CAST(local_student_id AS STRING),
    CAST(test_type AS STRING),
    CAST(curriculum AS STRING),
    CAST(unit AS STRING),
    CAST(NULL AS STRING) AS unit_labels, 
    CAST(title AS STRING),
    CAST(standard_code AS STRING),
    CAST(score AS STRING),  
    CAST(NULL AS STRING) AS performance_band_level, 
    CAST(NULL AS STRING) AS performance_band_label, 
    CAST(NULL AS STRING) AS proficiency 
  FROM {{ source('state_testing', 'sbac_2024') }}
),

IA2 AS (
  SELECT
    CAST(data_source AS STRING),
    CAST(assessment_id AS STRING),
    CAST(year AS STRING),  -- Year as STRING
    CAST(date_taken AS STRING),
    CAST(grade AS STRING),
    CAST(local_student_id AS STRING),
    CAST(test_type AS STRING),
    CAST(curriculum AS STRING),
    CAST(unit AS STRING),
    CAST(unit_labels AS STRING),
    CAST(title AS STRING),
    CAST(standard_code AS STRING),
    CAST(score AS STRING),  -- Score as STRING
    CAST(performance_band_level AS STRING),
    CAST(performance_band_label AS STRING),
    CAST(proficiency AS STRING)
  FROM {{ source('state_testing', 'IA2_assessment_results_view') }}
),

IA3 AS (
  SELECT
    CAST(data_source AS STRING),
    CAST(assessment_id AS STRING),
    CAST(year AS STRING),  -- Year as STRING
    CAST(date_taken AS STRING),
    CAST(grade AS STRING),
    CAST(local_student_id AS STRING),
    CAST(test_type AS STRING),
    CAST(curriculum AS STRING),
    CAST(unit AS STRING),
    CAST(unit_labels AS STRING),
    CAST(title AS STRING),
    CAST(standard_code AS STRING),
    CAST(score AS STRING),  -- Score as STRING
    CAST(performance_band_level AS STRING),
    CAST(performance_band_label AS STRING),
    CAST(proficiency AS STRING)
  FROM {{ source('state_testing', 'IA3_assessment_results_view') }}
),
pear_assignment_responses_view AS (
  SELECT
    CAST(data_source AS STRING),
    CAST(assessment_id AS STRING),
    CAST(year AS STRING),  -- Year as STRING
    CAST(date_taken AS STRING),
    CAST(grade AS STRING),
    CAST(local_student_id AS STRING),
    CAST(test_type AS STRING),
    CAST(curriculum AS STRING),
    CAST(unit AS STRING),
    CAST(NULL AS STRING) AS unit_labels, --missing here
    CAST(title AS STRING),
    CAST(standard_code AS STRING),
    CAST(score AS STRING),  -- Score as STRING
    CAST(performance_band_level AS STRING),
    CAST(performance_band_label AS STRING),
    CAST(proficiency AS STRING)
  FROM {{ source('pear', 'pear_assignment_responses_view') }}
  WHERE score IS NOT NULL
),
pear_assignment_summaries_view AS (
  SELECT
    CAST(data_source AS STRING),
    CAST(assessment_id AS STRING),
    CAST(year AS STRING),  -- Year as STRING
    CAST(date_taken AS STRING),
    CAST(grade AS STRING),
    CAST(local_student_id AS STRING),
    CAST(test_type AS STRING),
    CAST(curriculum AS STRING),
    CAST(unit AS STRING),
    CAST(NULL AS STRING) AS unit_labels, --missing here
    CAST(title AS STRING),
    CAST(standard_code AS STRING),
    CAST(score AS STRING),  -- Score as STRING
    CAST(performance_band_level AS STRING),
    CAST(performance_band_label AS STRING),
    CAST(proficiency AS STRING)
  FROM {{ source('pear', 'pear_assignment_summaries_view') }}
  WHERE score IS NOT NULL
),

state_testing_continuous_ica AS (
  SELECT
    CAST(data_source AS STRING),
    CAST(assessment_id AS STRING),
    CAST(year AS STRING),
    CAST(date_taken AS STRING),
    CAST(grade AS STRING),
    CAST(local_student_id AS STRING),
    CAST(test_type AS STRING),
    CAST(curriculum AS STRING),
    CAST(unit AS STRING),
    CAST(unit_labels AS STRING),
    CAST(title AS STRING),
    CAST(standard_code AS STRING),
    CAST(score AS STRING),
    CAST(performance_band_level AS STRING),
    CAST(performance_band_label AS STRING),
    CAST(proficiency AS STRING)
  FROM {{ ref('state_testing_continuous_ica') }}
),

state_testing_continuous_iab AS (
  SELECT
    CAST(data_source AS STRING),
    CAST(assessment_id AS STRING),
    CAST(year AS STRING),
    CAST(date_taken AS STRING),
    CAST(grade AS STRING),
    CAST(local_student_id AS STRING),
    CAST(test_type AS STRING),
    CAST(curriculum AS STRING),
    CAST(unit AS STRING),
    CAST(unit_labels AS STRING),
    CAST(title AS STRING),
    CAST(standard_code AS STRING),
    CAST(score AS STRING),
    CAST(performance_band_level AS STRING),
    CAST(performance_band_label AS STRING),
    CAST(proficiency AS STRING)
  FROM {{ ref('state_testing_continuous_iab') }}
)




SELECT * FROM illuminate
UNION ALL
SELECT * FROM iready
UNION ALL
SELECT * FROM star
UNION ALL
SELECT * FROM dibels
UNION ALL
SELECT * FROM sbac
UNION ALL
SELECT * FROM IA2
UNION ALL
SELECT * FROM IA3
UNION ALL
SELECT * FROM pear_assignment_responses_view
UNION ALL
SELECT * FROM pear_assignment_summaries_view
UNION ALL
SELECT * FROM state_testing_continuous_ica
UNION ALL
SELECT * FROM state_testing_continuous_iab
