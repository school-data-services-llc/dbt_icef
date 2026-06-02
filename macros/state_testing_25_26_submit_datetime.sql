{# Parse SubmitDateTime from state_testing_continuous_25-26 (e.g. "May 29, 2026"). #}
{% macro state_testing_25_26_submit_datetime(column_name) %}
SAFE.PARSE_DATETIME('%b %e, %Y', TRIM(CAST({{ column_name }} AS STRING)))
{% endmacro %}

{% macro state_testing_25_26_latest_row_order() %}
{{ state_testing_25_26_submit_datetime('SubmitDateTime') }} DESC NULLS LAST, file_name DESC
{% endmacro %}
