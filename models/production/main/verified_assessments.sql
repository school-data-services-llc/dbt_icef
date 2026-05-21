{{ config(
    materialized='view',
    schema='views'
) }}

-- Verified assessments (iReady & DIBELS): student_to_teacher + main + diagnostic_results_tabular.
-- main is long-format (one row per standard_code/skill) — expect many rows per student.
-- diagnostic is deduped to one row per local_student_id (pick row with richest EOY fields) to avoid
-- cartesian dupes when diagnostic had multiple rows per student.

WITH diagnostic_dedup AS (
  SELECT * EXCEPT (rn)
  FROM (
    SELECT
      d.*,
      ROW_NUMBER() OVER (
        PARTITION BY CAST(d.local_student_id AS STRING)
        ORDER BY
          (CASE WHEN d.eoy_composite_dibels IS NOT NULL THEN 1 ELSE 0 END
            + CASE WHEN d.eoy_ela_overall_relative_placement IS NOT NULL THEN 1 ELSE 0 END
            + CASE WHEN d.eoy_math_overall_relative_placement IS NOT NULL THEN 1 ELSE 0 END) DESC,
          (CASE WHEN d.moy_composite_dibels IS NOT NULL THEN 1 ELSE 0 END
            + CASE WHEN d.moy_ela_overall_relative_placement IS NOT NULL THEN 1 ELSE 0 END
            + CASE WHEN d.moy_math_overall_relative_placement IS NOT NULL THEN 1 ELSE 0 END) DESC,
          (CASE WHEN d.boy_composite_dibels IS NOT NULL THEN 1 ELSE 0 END
            + CASE WHEN d.boy_ela_overall_relative_placement IS NOT NULL THEN 1 ELSE 0 END
            + CASE WHEN d.boy_math_overall_relative_placement IS NOT NULL THEN 1 ELSE 0 END) DESC
      ) AS rn
    FROM {{ source('views', 'diagnostic_results_tabular') }} d
  )
  WHERE rn = 1
)

SELECT
  CAST(st.year AS STRING) AS year,
  CAST(st.elastatus AS STRING) AS elastatus,
  CAST(st.english_teacher AS STRING) AS english_teacher,
  CAST(st.math_teacher AS STRING) AS math_teacher,
  CAST(st.lastfirst AS STRING) AS lastfirst,
  CAST(st.school_name AS STRING) AS school_name,
  CAST(st.sped_identifier AS STRING) AS sped_identifier,
  CAST(st.absenteeism_status AS STRING) AS absenteeism_status,
  CAST(st.hit_tutoring AS STRING) AS hit_tutoring,
  CAST(st.grade_level AS INT64) AS grade_level,
  CAST(st.student_number AS INT64) AS student_number,
  CAST(d.boy_composite_dibels AS STRING) AS boy_composite_dibels,
  CAST(d.boy_ela_overall_relative_placement AS STRING) AS boy_ela_overall_relative_placement,
  CAST(d.boy_math_overall_relative_placement AS STRING) AS boy_math_overall_relative_placement,
  CAST(m.data_source AS STRING) AS data_source,
  CAST(m.curriculum AS STRING) AS curriculum,
  CAST(m.unit AS STRING) AS unit,
  CAST(d.eoy_composite_dibels AS STRING) AS eoy_composite_dibels,
  CAST(d.eoy_ela_overall_relative_placement AS STRING) AS eoy_ela_overall_relative_placement,
  CAST(d.eoy_math_overall_relative_placement AS STRING) AS eoy_math_overall_relative_placement,
  CAST(d.moy_composite_dibels AS STRING) AS moy_composite_dibels,
  CAST(d.moy_ela_overall_relative_placement AS STRING) AS moy_ela_overall_relative_placement,
  CAST(d.moy_math_overall_relative_placement AS STRING) AS moy_math_overall_relative_placement,
  -- Numeric-only score; non-numeric m.score (e.g. band labels) surfaces via proficiency below.
  SAFE_CAST(TRIM(CAST(m.score AS STRING)) AS FLOAT64) AS score,
  CAST(
    CASE
      WHEN SAFE_CAST(TRIM(CAST(m.score AS STRING)) AS FLOAT64) IS NOT NULL
        THEN m.proficiency
      ELSE COALESCE(
        NULLIF(TRIM(CAST(m.proficiency AS STRING)), ''),
        NULLIF(TRIM(CAST(m.score AS STRING)), '')
      )
    END AS STRING
  ) AS proficiency,
  CAST(m.standard_code AS STRING) AS standard_code
FROM {{ source('views', 'student_to_teacher') }} st
LEFT JOIN {{ ref('main') }} m
  ON CAST(st.student_number AS STRING) = m.local_student_id
  AND st.year = m.year
  AND LOWER(TRIM(m.data_source)) IN ('iready', 'dibels')
LEFT JOIN diagnostic_dedup d
  ON CAST(st.student_number AS STRING) = CAST(d.local_student_id AS STRING)
WHERE st.grade_level BETWEEN 0 AND 12
  AND LOWER(TRIM(m.data_source)) IN ('iready', 'dibels')
