-- One row per student: ELA + Math summative. Prior-year ELA/Math scale + DFS + ELA/Math proficiency:
--   year = '24-25' → from state_testing_2324 (23-24). year = '25-26' → from state_testing_continuous (24-25).
-- 25-26 upstream may have Summative CAST/ELPAC only (no ELA/Math summative yet); current-year scores stay null until ELA/Math summative rows exist. student_number / StudentIdentifier on 25-26 rows still filled from roster + continuous lookup when possible.
-- prev_year_math_proficiency is NULL on historical rows (dbt_historical.sbac_state_testing_tabular_24-25 only persisted ELA prior-year proficiency).
{{ config(materialized='view', schema='views') }}


WITH ela_continuous AS (
  SELECT DISTINCT
    studentidentifier,
    student_number,
    assessmentname AS ela_assessmentname,
    scalescoreachievementlevel AS ela_scalescoreachievementlevel,
    proficiency AS ela_proficiency,
    dfs_ela AS ela_dfs,
    scalescore AS ela_scalescore,
    lexilemeasure AS ela_lexilemeasure,
    SAFE_CAST(`ela__reading` AS FLOAT64) AS `ela__reading`,
    SAFE_CAST(`ela__writing` AS FLOAT64) AS `ela__writing`,
    SAFE_CAST(`ela__listening` AS FLOAT64) AS `ela__listening`,
    SAFE_CAST(`ela__research_and_inquiry` AS FLOAT64) AS `ela__research_and_inquiry`
  FROM {{ source('state_testing', 'state_testing_continuous') }}
  WHERE assessmenttype = 'Summative' AND subject = 'ELA'
),

math_continuous AS (
  SELECT DISTINCT
    studentidentifier,
    student_number,
    assessmentname AS math_assessmentname,
    scalescoreachievementlevel AS math_scalescoreachievementlevel,
    proficiency AS math_proficiency,
    dfs_math AS math_dfs,
    scalescore AS math_scalescore,
    lexilemeasure AS math_lexilemeasure,
    SAFE_CAST(`math__concepts_and_procedures` AS FLOAT64) AS `math__concepts_and_procedures`,
    SAFE_CAST(`math__problem_solving_and_modeling___data_analysis` AS FLOAT64) AS `math__problem_solving_and_modeling___data_analysis`,
    SAFE_CAST(`math__communicating_reasoning` AS FLOAT64) AS `math__communicating_reasoning`
  FROM {{ source('state_testing', 'state_testing_continuous') }}
  WHERE assessmenttype = 'Summative' AND subject = 'Math'
),

joined_continuous AS (
  SELECT
    COALESCE(e.studentidentifier, m.studentidentifier) AS studentidentifier,
    COALESCE(e.student_number, m.student_number) AS student_number,
    e.ela_assessmentname,
    e.ela_scalescoreachievementlevel,
    e.ela_proficiency,
    e.ela_dfs,
    e.ela_scalescore,
    e.ela_lexilemeasure,
    e.`ela__reading`,
    e.`ela__writing`,
    e.`ela__listening`,
    e.`ela__research_and_inquiry`,
    m.math_assessmentname,
    m.math_scalescoreachievementlevel,
    m.math_proficiency,
    m.math_dfs,
    m.math_scalescore,
    m.math_lexilemeasure,
    m.`math__concepts_and_procedures`,
    m.`math__problem_solving_and_modeling___data_analysis`,
    m.`math__communicating_reasoning`
  FROM ela_continuous e
  FULL OUTER JOIN math_continuous m
    ON e.studentidentifier = m.studentidentifier
),

ela_2324 AS (
  SELECT DISTINCT
    studentidentifier,
    student_number,
    scalescoreachievementlevel AS ela_scalescoreachievementlevel,
    dfs_ela AS ela_dfs,
    proficiency
  FROM {{ source('state_testing', 'state_testing_2324') }}
  WHERE assessmenttype = 'Summative' AND subject = 'ELA'
),

math_2324 AS (
  SELECT DISTINCT
    studentidentifier,
    student_number,
    scalescoreachievementlevel AS math_scalescoreachievementlevel,
    dfs_math AS math_dfs,
    proficiency
  FROM {{ source('state_testing', 'state_testing_2324') }}
  WHERE assessmenttype = 'Summative' AND subject = 'Math'
),

prior_2324_metrics AS (
  SELECT
    COALESCE(e.studentidentifier, m.studentidentifier) AS studentidentifier,
    e.ela_scalescoreachievementlevel AS prev_year_ela_scalescoreachievementlevel,
    e.ela_dfs AS prev_year_ela_dfs,
    m.math_scalescoreachievementlevel AS prev_year_math_scalescoreachievementlevel,
    m.math_dfs AS prev_year_math_dfs,
    e.proficiency AS prev_year_ela_proficiency,
    m.proficiency AS prev_year_math_proficiency
  FROM ela_2324 e
  FULL OUTER JOIN math_2324 m
    ON e.studentidentifier = m.studentidentifier
),

prior_2425_metrics AS (
  SELECT
    jc.studentidentifier,
    jc.student_number,
    jc.ela_scalescoreachievementlevel AS prev_year_ela_scalescoreachievementlevel,
    jc.ela_dfs AS prev_year_ela_dfs,
    jc.math_scalescoreachievementlevel AS prev_year_math_scalescoreachievementlevel,
    jc.math_dfs AS prev_year_math_dfs,
    jc.ela_proficiency AS prev_year_ela_proficiency,
    jc.math_proficiency AS prev_year_math_proficiency
  FROM joined_continuous jc
),

-- Roster-keyed lookup so 25-26 rows pick up prior-year metrics even when the student
-- has no 25-26 ELA/Math Summative row (i.e., stacked_2526 is empty for them).
prior_2425_metrics_by_student_number AS (
  SELECT
    student_number,
    MAX(prev_year_ela_scalescoreachievementlevel) AS prev_year_ela_scalescoreachievementlevel,
    MAX(prev_year_ela_dfs) AS prev_year_ela_dfs,
    MAX(prev_year_math_scalescoreachievementlevel) AS prev_year_math_scalescoreachievementlevel,
    MAX(prev_year_math_dfs) AS prev_year_math_dfs,
    MAX(prev_year_ela_proficiency) AS prev_year_ela_proficiency,
    MAX(prev_year_math_proficiency) AS prev_year_math_proficiency
  FROM prior_2425_metrics
  WHERE student_number IS NOT NULL
  GROUP BY student_number
),

ela_continuous_2526 AS (
  SELECT DISTINCT
    StudentIdentifier AS studentidentifier,
    student_number,
    AssessmentName AS ela_assessmentname,
    ScaleScoreAchievementLevel AS ela_scalescoreachievementlevel,
    proficiency AS ela_proficiency,
    dfs_ela AS ela_dfs,
    ScaleScore AS ela_scalescore,
    LexileMeasure AS ela_lexilemeasure,
    SAFE_CAST(`ELA: Reading` AS FLOAT64) AS `ela__reading`,
    SAFE_CAST(`ELA: Writing` AS FLOAT64) AS `ela__writing`,
    SAFE_CAST(`ELA: Listening` AS FLOAT64) AS `ela__listening`,
    SAFE_CAST(`ELA: Research and Inquiry` AS FLOAT64) AS `ela__research_and_inquiry`
  FROM {{ source('state_testing', 'state_testing_continuous_25_26') }}
  WHERE LOWER(TRIM(CAST(AssessmentType AS STRING))) = 'summative'
    AND LOWER(TRIM(CAST(Subject AS STRING))) = 'ela'
),

math_continuous_2526 AS (
  SELECT DISTINCT
    StudentIdentifier AS studentidentifier,
    student_number,
    AssessmentName AS math_assessmentname,
    ScaleScoreAchievementLevel AS math_scalescoreachievementlevel,
    proficiency AS math_proficiency,
    dfs_math AS math_dfs,
    ScaleScore AS math_scalescore,
    LexileMeasure AS math_lexilemeasure,
    SAFE_CAST(`Math: Concepts and Procedures` AS FLOAT64) AS `math__concepts_and_procedures`,
    SAFE_CAST(`Math: Problem Solving and Modeling & Data Analysis` AS FLOAT64) AS `math__problem_solving_and_modeling___data_analysis`,
    SAFE_CAST(`Math: Communicating Reasoning` AS FLOAT64) AS `math__communicating_reasoning`
  FROM {{ source('state_testing', 'state_testing_continuous_25_26') }}
  WHERE LOWER(TRIM(CAST(AssessmentType AS STRING))) = 'summative'
    AND LOWER(TRIM(CAST(Subject AS STRING))) = 'math'
),

joined_continuous_2526 AS (
  SELECT
    COALESCE(e.studentidentifier, m.studentidentifier) AS studentidentifier,
    COALESCE(e.student_number, m.student_number) AS student_number,
    e.ela_assessmentname,
    e.ela_scalescoreachievementlevel,
    e.ela_proficiency,
    e.ela_dfs,
    e.ela_scalescore,
    e.ela_lexilemeasure,
    e.`ela__reading`,
    e.`ela__writing`,
    e.`ela__listening`,
    e.`ela__research_and_inquiry`,
    m.math_assessmentname,
    m.math_scalescoreachievementlevel,
    m.math_proficiency,
    m.math_dfs,
    m.math_scalescore,
    m.math_lexilemeasure,
    m.`math__concepts_and_procedures`,
    m.`math__problem_solving_and_modeling___data_analysis`,
    m.`math__communicating_reasoning`
  FROM ela_continuous_2526 e
  FULL OUTER JOIN math_continuous_2526 m
    ON e.studentidentifier = m.studentidentifier
),

stacked_2425 AS (
  SELECT
    jc.*,
    p2324.prev_year_ela_scalescoreachievementlevel,
    p2324.prev_year_ela_dfs,
    p2324.prev_year_math_scalescoreachievementlevel,
    p2324.prev_year_math_dfs,
    p2324.prev_year_ela_proficiency,
    p2324.prev_year_math_proficiency
  FROM joined_continuous jc
  LEFT JOIN prior_2324_metrics p2324
    ON jc.studentidentifier = p2324.studentidentifier
),

-- prev_year_* columns are joined later in current_year_2526 via student_number on the roster,
-- so this CTE is just a thin pass-through of the 25-26 current-year scores.
stacked_2526 AS (
  SELECT jc.*
  FROM joined_continuous_2526 jc
),

student_to_teacher_2425 AS (
  SELECT
    student_number,
    lastfirst,
    grade_level,
    elastatus,
    race,
    school_name,
    sped_identifier,
    absenteeism_status,
    hit_tutoring,
    english_teacher,
    math_teacher
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year = '24-25'
),

student_to_teacher_2526 AS (
  SELECT
    student_number,
    lastfirst,
    grade_level,
    elastatus,
    race,
    school_name,
    sped_identifier,
    absenteeism_status,
    hit_tutoring,
    english_teacher,
    math_teacher
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year = '25-26'
),

-- 25-26 continuous often has Summative CAST/ELPAC but not ELA/Math yet; stacked_2526 can be empty.
-- Map roster student_number → any StudentIdentifier on the 25-26 extract for display when sst is null.
studentidentifier_lookup_2526 AS (
  SELECT
    student_number,
    MAX(StudentIdentifier) AS studentidentifier
  FROM {{ source('state_testing', 'state_testing_continuous_25_26') }}
  WHERE student_number IS NOT NULL
  GROUP BY student_number
),

intervention_11 AS (
  SELECT
    student_number,
    intervention
  FROM {{ source('powerschool', 'knight_time_intervention_grade_11_2025') }}
),

current_year_2425 AS (
  SELECT
    sst.studentidentifier,
    sst.student_number,
    -- ELA (current year + prior year)
    sst.ela_assessmentname,
    sst.ela_scalescoreachievementlevel,
    sst.ela_proficiency,
    sst.ela_dfs,
    sst.ela_scalescore,
    sst.ela_lexilemeasure,
    sst.`ela__reading`,
    sst.`ela__writing`,
    sst.`ela__listening`,
    sst.`ela__research_and_inquiry`,
    sst.prev_year_ela_scalescoreachievementlevel,
    sst.prev_year_ela_dfs,
    sst.prev_year_ela_proficiency,
    -- Math (current year + prior year)
    sst.math_assessmentname,
    sst.math_scalescoreachievementlevel,
    sst.math_proficiency,
    sst.math_dfs,
    sst.math_scalescore,
    CAST(sst.math_lexilemeasure AS FLOAT64) AS math_lexilemeasure,
    sst.`math__concepts_and_procedures`,
    sst.`math__problem_solving_and_modeling___data_analysis`,
    sst.`math__communicating_reasoning`,
    sst.prev_year_math_scalescoreachievementlevel,
    sst.prev_year_math_dfs,
    sst.prev_year_math_proficiency,
    -- Roster / metadata
    st.lastfirst,
    st.grade_level,
    st.elastatus,
    st.race,
    st.school_name,
    st.sped_identifier,
    st.absenteeism_status,
    st.hit_tutoring,
    st.english_teacher,
    st.math_teacher,
    CAST('24-25' AS STRING) AS year,
    i11.intervention
  FROM stacked_2425 sst
  RIGHT JOIN student_to_teacher_2425 st
    ON sst.student_number = st.student_number
  LEFT JOIN intervention_11 i11
    ON st.student_number = i11.student_number
  WHERE st.grade_level IN (3, 4, 5, 6, 7, 8, 11)
),

current_year_2526 AS (
  -- prev_year_* values come from prior_2425_metrics_by_student_number (roster-keyed),
  -- so they're populated even when the student has no 25-26 ELA/Math Summative row yet.
  SELECT
    COALESCE(sst.studentidentifier, sil.studentidentifier) AS studentidentifier,
    COALESCE(sst.student_number, st.student_number) AS student_number,
    -- ELA (current year + prior year)
    sst.ela_assessmentname,
    sst.ela_scalescoreachievementlevel,
    sst.ela_proficiency,
    sst.ela_dfs,
    sst.ela_scalescore,
    sst.ela_lexilemeasure,
    sst.`ela__reading`,
    sst.`ela__writing`,
    sst.`ela__listening`,
    sst.`ela__research_and_inquiry`,
    p2425.prev_year_ela_scalescoreachievementlevel,
    p2425.prev_year_ela_dfs,
    p2425.prev_year_ela_proficiency,
    -- Math (current year + prior year)
    sst.math_assessmentname,
    sst.math_scalescoreachievementlevel,
    sst.math_proficiency,
    sst.math_dfs,
    sst.math_scalescore,
    CAST(sst.math_lexilemeasure AS FLOAT64) AS math_lexilemeasure,
    sst.`math__concepts_and_procedures`,
    sst.`math__problem_solving_and_modeling___data_analysis`,
    sst.`math__communicating_reasoning`,
    p2425.prev_year_math_scalescoreachievementlevel,
    p2425.prev_year_math_dfs,
    p2425.prev_year_math_proficiency,
    -- Roster / metadata
    st.lastfirst,
    st.grade_level,
    st.elastatus,
    st.race,
    st.school_name,
    st.sped_identifier,
    st.absenteeism_status,
    st.hit_tutoring,
    st.english_teacher,
    st.math_teacher,
    CAST('25-26' AS STRING) AS year,
    CAST(NULL AS STRING) AS intervention
  FROM stacked_2526 sst
  RIGHT JOIN student_to_teacher_2526 st
    ON sst.student_number = st.student_number
  LEFT JOIN studentidentifier_lookup_2526 sil
    ON sil.student_number = st.student_number
  LEFT JOIN prior_2425_metrics_by_student_number p2425
    ON p2425.student_number = st.student_number
  WHERE st.grade_level IN (3, 4, 5, 6, 7, 8, 11)
),

historical AS (
  SELECT
    studentidentifier,
    student_number,
    -- ELA (current year + prior year)
    ela_assessmentname,
    ela_scalescoreachievementlevel,
    ela_proficiency,
    ela_dfs,
    ela_scalescore,
    ela_lexilemeasure,
    `ela__reading`,
    `ela__writing`,
    `ela__listening`,
    `ela__research_and_inquiry`,
    `24_ela_scalescoreachievementlevel` AS prev_year_ela_scalescoreachievementlevel,
    `24_ela_dfs` AS prev_year_ela_dfs,
    `24_proficiency` AS prev_year_ela_proficiency,
    -- Math (current year + prior year); snapshot didn't persist prev_year_math_proficiency.
    math_assessmentname,
    math_scalescoreachievementlevel,
    math_proficiency,
    math_dfs,
    math_scalescore,
    CAST(math_lexilemeasure AS FLOAT64) AS math_lexilemeasure,
    `math__concepts_and_procedures`,
    `math__problem_solving_and_modeling___data_analysis`,
    `math__communicating_reasoning`,
    `24_math_scalescoreachievementlevel` AS prev_year_math_scalescoreachievementlevel,
    `24_math_dfs` AS prev_year_math_dfs,
    CAST(NULL AS FLOAT64) AS prev_year_math_proficiency,
    -- Roster / metadata
    lastfirst,
    grade_level,
    elastatus,
    race,
    school_name,
    sped_identifier,
    absenteeism_status,
    CAST(NULL AS STRING) AS hit_tutoring,
    english_teacher,
    math_teacher,
    CAST('24-25' AS STRING) AS year,
    intervention
  FROM `icef-437920.dbt_historical.sbac_state_testing_tabular_24-25`
),

-- current_year_2425 (live source) is authoritative for 24-25; the snapshot's roster fields
-- (and prev_year_math_proficiency, which the snapshot doesn't carry) drift from the live branch
-- and prevent SELECT DISTINCT from collapsing duplicate rows.
-- Keep snapshot rows only for students NOT in the live branch (e.g., students no longer on the roster).
historical_24_25_only AS (
  SELECT h.*
  FROM historical h
  LEFT JOIN current_year_2425 c
    ON h.studentidentifier = c.studentidentifier
    OR h.student_number    = c.student_number
  WHERE c.studentidentifier IS NULL
    AND c.student_number    IS NULL
)

SELECT DISTINCT *
FROM (
  SELECT * FROM current_year_2425
  UNION ALL
  SELECT * FROM current_year_2526
  UNION ALL
  SELECT * FROM historical_24_25_only
)
