{#-
  Summative ELPAC: Level 1/4 from achievement band; Level 2/3 subdivided via cut_level_code
  from a prior JOIN to elpi_cut_scores (BigQuery does not allow correlated seed subqueries).
  Alternate ELPAC: extract level number from achievement level.
-#}
{% macro calculate_elpi_level(achievement_level_column, elpac_track_column, cut_level_code_column) %}
(
  CASE
    WHEN {{ elpac_track_column }} = 'alternate' THEN
      REGEXP_EXTRACT(TRIM(CAST({{ achievement_level_column }} AS STRING)), r'(\d+)')
    WHEN TRIM(CAST({{ achievement_level_column }} AS STRING)) = 'Level 1' THEN '1'
    WHEN TRIM(CAST({{ achievement_level_column }} AS STRING)) = 'Level 4' THEN '4'
    WHEN TRIM(CAST({{ achievement_level_column }} AS STRING)) IN ('Level 2', 'Level 3')
      THEN {{ cut_level_code_column }}
    ELSE NULL
  END
)
{% endmacro %}
