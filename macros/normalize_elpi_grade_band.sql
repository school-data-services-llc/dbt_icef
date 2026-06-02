{% macro normalize_elpi_grade_band(grade_column) %}
(
  CASE
    WHEN {{ grade_column }} IS NULL THEN NULL
    WHEN UPPER(TRIM(CAST({{ grade_column }} AS STRING))) IN ('K', 'KG', 'KINDERGARTEN', '0', 'G0') THEN 'K'
    WHEN UPPER(TRIM(CAST({{ grade_column }} AS STRING))) IN ('9', '10', 'G9', 'G10', '9-10') THEN '9-10'
    WHEN UPPER(TRIM(CAST({{ grade_column }} AS STRING))) IN ('11', '12', 'G11', 'G12', '11-12') THEN '11-12'
    WHEN SAFE_CAST({{ grade_column }} AS INT64) = 0 THEN 'K'
    WHEN SAFE_CAST({{ grade_column }} AS INT64) IN (9, 10) THEN '9-10'
    WHEN SAFE_CAST({{ grade_column }} AS INT64) IN (11, 12) THEN '11-12'
    WHEN SAFE_CAST({{ grade_column }} AS INT64) BETWEEN 1 AND 8
      THEN CAST(SAFE_CAST({{ grade_column }} AS INT64) AS STRING)
    WHEN REGEXP_CONTAINS(UPPER(TRIM(CAST({{ grade_column }} AS STRING))), r'^G?\d+$') THEN (
      CASE
        WHEN SAFE_CAST(REGEXP_REPLACE(UPPER(TRIM(CAST({{ grade_column }} AS STRING))), r'^G', '') AS INT64) = 0 THEN 'K'
        WHEN SAFE_CAST(REGEXP_REPLACE(UPPER(TRIM(CAST({{ grade_column }} AS STRING))), r'^G', '') AS INT64) IN (9, 10) THEN '9-10'
        WHEN SAFE_CAST(REGEXP_REPLACE(UPPER(TRIM(CAST({{ grade_column }} AS STRING))), r'^G', '') AS INT64) IN (11, 12) THEN '11-12'
        WHEN SAFE_CAST(REGEXP_REPLACE(UPPER(TRIM(CAST({{ grade_column }} AS STRING))), r'^G', '') AS INT64) BETWEEN 1 AND 8
          THEN CAST(SAFE_CAST(REGEXP_REPLACE(UPPER(TRIM(CAST({{ grade_column }} AS STRING))), r'^G', '') AS INT64) AS STRING)
        ELSE NULL
      END
    )
    ELSE NULL
  END
)
{% endmacro %}
