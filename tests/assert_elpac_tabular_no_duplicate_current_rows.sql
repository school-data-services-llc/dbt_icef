-- Fails when a student has more than one row for the same ELPAC track in elpac_tabular.
SELECT
  student_number,
  elpac_track,
  COUNT(*) AS row_count
FROM {{ ref('elpac_tabular') }}
WHERE student_number IS NOT NULL
GROUP BY student_number, elpac_track
HAVING COUNT(*) > 1
