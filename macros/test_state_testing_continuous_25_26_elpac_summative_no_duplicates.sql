{% test state_testing_continuous_25_26_elpac_summative_no_duplicates(model) %}
-- Fails when the 25-26 source has more than one identical ELPAC Summative row
-- (same student, subject track, and SubmitDateTime). Reloads on new dates are allowed;
-- elpac_tabular keeps the latest SubmitDateTime per student + AssessmentName.
SELECT
  student_number,
  Subject,
  SubmitDateTime,
  COUNT(*) AS row_count
FROM {{ model }}
WHERE LOWER(TRIM(CAST(Subject AS STRING))) LIKE '%elpac%'
  AND LOWER(TRIM(CAST(AssessmentType AS STRING))) = 'summative'
GROUP BY student_number, Subject, SubmitDateTime
HAVING COUNT(*) > 1
{% endtest %}
