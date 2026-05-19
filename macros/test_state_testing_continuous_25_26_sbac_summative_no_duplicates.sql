{% test state_testing_continuous_25_26_sbac_summative_no_duplicates(model) %}
-- Fails when the 25-26 source has more than one SBAC Summative row per student + assessment.
-- Catches loader append/MERGE regressions before they reach sbac_state_testing_tabular.
SELECT
  student_number,
  AssessmentName,
  COUNT(*) AS row_count
FROM {{ model }}
WHERE LOWER(TRIM(CAST(AssessmentType AS STRING))) = 'summative'
  AND LOWER(TRIM(CAST(Subject AS STRING))) IN ('ela', 'math')
GROUP BY student_number, AssessmentName
HAVING COUNT(*) > 1
{% endtest %}
