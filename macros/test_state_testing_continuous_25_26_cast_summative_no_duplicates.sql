{% test state_testing_continuous_25_26_cast_summative_no_duplicates(model) %}
-- Fails when the 25-26 source has more than one CAST Summative row per student + assessment.
-- Catches loader append/MERGE regressions before they reach cast_state_testing_tabular.
SELECT
  student_number,
  AssessmentName,
  COUNT(*) AS row_count
FROM {{ model }}
WHERE AssessmentName IN (
    'CAST Summative Grade 5',
    'CAST Summative Grade 8',
    'CAST Summative Grade HS'
  )
GROUP BY student_number, AssessmentName
HAVING COUNT(*) > 1
{% endtest %}
