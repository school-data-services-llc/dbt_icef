-- Fails when a student with an SBAC score appears more than once for the same year.
-- Ghost roster rows (studentidentifier IS NULL) are excluded.
SELECT
  year,
  studentidentifier,
  COUNT(*) AS row_count
FROM {{ ref('sbac_state_testing_tabular') }}
WHERE studentidentifier IS NOT NULL
GROUP BY year, studentidentifier
HAVING COUNT(*) > 1
