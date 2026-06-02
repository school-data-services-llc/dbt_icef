{% macro elpi_level_rank(elpi_level_column) %}
(
  CASE TRIM(CAST({{ elpi_level_column }} AS STRING))
    WHEN '1' THEN 1
    WHEN '2L' THEN 2
    WHEN '2H' THEN 3
    WHEN '3L' THEN 4
    WHEN '3H' THEN 5
    WHEN '4' THEN 6
    WHEN '2' THEN 2
    WHEN '3' THEN 3
    ELSE NULL
  END
)
{% endmacro %}
