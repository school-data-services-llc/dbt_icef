{{ config(materialized='view', schema='views') }}

-- One row per 25-26 Summative ELPAC or Summative Alternate ELPAC result.
-- Prior-year 24-25 same-track results joined on student_number + elpac_track.
-- Roster/demographics from student_to_teacher (25-26). ELPI metrics per CA ELPI rules.

WITH elpac_current_2526 AS (
  SELECT
    a.StudentIdentifier AS studentidentifier,
    a.student_number,
    a.Subject AS subject,
    a.AssessmentName AS assessmentname,
    a.ScaleScoreAchievementLevel AS scalescoreachievementlevel,
    SAFE_CAST(a.ScaleScore AS FLOAT64) AS scalescore,
    a.GradeLevelWhenAssessed AS gradelevelwhenassessed,
    CASE
      WHEN LOWER(TRIM(CAST(a.Subject AS STRING))) LIKE '%alternate%' THEN 'alternate'
      ELSE 'elpac'
    END AS elpac_track,
    CAST(a.`ELPAC: Oral Language Level` AS STRING) AS elpac__oral_language_level,
    CAST(a.`ELPAC: Written Language Level` AS STRING) AS elpac__written_language_level,
    CAST(a.`ELPAC: Listening` AS STRING) AS elpac__listening,
    CAST(a.`ELPAC: Speaking` AS STRING) AS elpac__speaking,
    CAST(a.`ELPAC: Reading` AS STRING) AS elpac__reading,
    CAST(a.`ELPAC: Writing` AS STRING) AS elpac__writing
  FROM {{ source('state_testing', 'state_testing_continuous_25_26') }} AS a
  WHERE LOWER(TRIM(CAST(a.Subject AS STRING))) LIKE '%elpac%'
    AND LOWER(TRIM(CAST(a.AssessmentType AS STRING))) = 'summative'
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY a.student_number, a.AssessmentName
    ORDER BY {{ state_testing_25_26_latest_row_order() }}
  ) = 1
),

elpac_prior_2425 AS (
  SELECT DISTINCT
    p.studentidentifier,
    p.student_number,
    p.subject,
    p.assessmentname,
    p.scalescoreachievementlevel,
    SAFE_CAST(p.scalescore AS FLOAT64) AS scalescore,
    p.gradelevelwhenassessed,
    CASE
      WHEN LOWER(TRIM(CAST(p.subject AS STRING))) LIKE '%alternate%' THEN 'alternate'
      ELSE 'elpac'
    END AS elpac_track
  FROM {{ source('state_testing', 'state_testing_continuous') }} AS p
  WHERE LOWER(TRIM(CAST(p.subject AS STRING))) LIKE '%elpac%'
    AND LOWER(TRIM(CAST(p.assessmenttype AS STRING))) = 'summative'
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
    year
  FROM {{ source('views', 'student_to_teacher') }}
  WHERE year = '25-26'
),

joined AS (
  SELECT
    curr.studentidentifier,
    COALESCE(st.student_number, curr.student_number) AS student_number,
    st.lastfirst,
    st.grade_level,
    st.elastatus,
    st.race,
    st.school_name,
    st.sped_identifier,
    st.absenteeism_status,
    st.hit_tutoring,
    st.english_teacher,
    st.year,
    curr.subject,
    curr.assessmentname,
    curr.scalescoreachievementlevel,
    curr.scalescore,
    curr.gradelevelwhenassessed,
    curr.elpac_track,
    curr.elpac__oral_language_level,
    curr.elpac__written_language_level,
    curr.elpac__listening,
    curr.elpac__speaking,
    curr.elpac__reading,
    curr.elpac__writing,
    prev.subject AS prev_year_subject,
    prev.scalescoreachievementlevel AS prev_year_scalescoreachievementlevel,
    prev.scalescore AS prev_year_scalescore,
    prev.gradelevelwhenassessed AS prev_year_gradelevelwhenassessed,
    prev.elpac_track AS prev_year_elpac_track,
    CASE
      WHEN prev.student_number IS NOT NULL THEN 1
      ELSE 0
    END AS elpi_eligible
  FROM elpac_current_2526 AS curr
  LEFT JOIN elpac_prior_2425 AS prev
    ON curr.student_number = prev.student_number
    AND curr.elpac_track = prev.elpac_track
    -- One-off guard: this student has placeholder student_number=0 in source; do not
    -- infer prior-year linkage from that key.
    AND NOT (curr.studentidentifier = 9409030211 AND curr.student_number = 0)
  LEFT JOIN student_to_teacher_2526 AS st
    ON st.student_number = curr.student_number
),

elpi_cuts AS (
  SELECT
    grade_band,
    level_code,
    min_score,
    max_score
  FROM {{ ref('elpi_cut_scores') }}
),

joined_with_bands AS (
  SELECT
    j.*,
    {{ normalize_elpi_grade_band('j.grade_level') }} AS current_elpi_grade_band,
    {{ normalize_elpi_grade_band('j.prev_year_gradelevelwhenassessed') }} AS prev_elpi_grade_band
  FROM joined AS j
),

with_elpi AS (
  SELECT
    jb.*,
    {{ calculate_elpi_level(
      'jb.scalescoreachievementlevel',
      'jb.elpac_track',
      'curr_cut.level_code'
    ) }} AS elpi_level,
    {{ calculate_elpi_level(
      'jb.prev_year_scalescoreachievementlevel',
      'jb.elpac_track',
      'prev_cut.level_code'
    ) }} AS prev_year_elpi_level
  FROM joined_with_bands AS jb
  LEFT JOIN elpi_cuts AS curr_cut
    ON jb.elpac_track = 'elpac'
    AND jb.current_elpi_grade_band = curr_cut.grade_band
    AND jb.scalescore BETWEEN curr_cut.min_score AND curr_cut.max_score
    AND TRIM(CAST(jb.scalescoreachievementlevel AS STRING)) IN ('Level 2', 'Level 3')
  LEFT JOIN elpi_cuts AS prev_cut
    ON jb.elpac_track = 'elpac'
    AND jb.prev_elpi_grade_band = prev_cut.grade_band
    AND jb.prev_year_scalescore BETWEEN prev_cut.min_score AND prev_cut.max_score
    AND TRIM(CAST(jb.prev_year_scalescoreachievementlevel AS STRING)) IN ('Level 2', 'Level 3')
)

SELECT
  studentidentifier,
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
  year,
  subject,
  prev_year_subject,
  scalescoreachievementlevel,
  scalescore,
  prev_year_scalescoreachievementlevel,
  prev_year_scalescore,
  elpac__oral_language_level,
  elpac__written_language_level,
  elpac__listening,
  elpac__speaking,
  elpac__reading,
  elpac__writing,
  elpac_track,
  elpi_level,
  prev_year_elpi_level,
  elpi_eligible,
  {{ elpi_level_rank('elpi_level') }} AS elpi_level_rank,
  {{ elpi_level_rank('prev_year_elpi_level') }} AS prev_year_elpi_level_rank,
  CASE
    WHEN elpi_eligible = 0 THEN 0
    WHEN elpac_track = 'alternate' OR prev_year_elpac_track = 'alternate' THEN
      CASE
        WHEN {{ elpi_level_rank('elpi_level') }} > {{ elpi_level_rank('prev_year_elpi_level') }} THEN 1
        WHEN elpi_level = '3' AND prev_year_elpi_level = '3' THEN 1
        WHEN scalescore - prev_year_scalescore >= 10 THEN 1
        ELSE 0
      END
    ELSE
      CASE
        WHEN {{ elpi_level_rank('elpi_level') }} > {{ elpi_level_rank('prev_year_elpi_level') }} THEN 1
        WHEN elpi_level = '4' AND prev_year_elpi_level = '4' THEN 1
        ELSE 0
      END
  END AS advanced_elpi
FROM with_elpi
