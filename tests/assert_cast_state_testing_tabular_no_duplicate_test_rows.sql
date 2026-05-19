-- Fails when a student with a CAST score appears more than once for the same year + assessment.
-- Ghost roster rows (studentidentifier IS NULL) are excluded.
SELECT
  year,
  studentidentifier,
  assessmentname,
  COUNT(*) AS row_count
FROM {{ ref('cast_state_testing_tabular') }}
WHERE studentidentifier IS NOT NULL
GROUP BY year, studentidentifier, assessmentname
HAVING COUNT(*) > 1
