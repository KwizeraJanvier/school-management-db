-- =============================================================
-- Reporting views
-- =============================================================
SET search_path TO school;

-- -------------------------------------------------------------
-- One row per student per course taken: the academic transcript
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW v_transcript AS
SELECT
    s.student_id,
    s.student_number,
    s.first_name || ' ' || s.last_name   AS student_name,
    tm.term_id,
    tm.name                              AS term,
    c.code                               AS course_code,
    c.title                              AS course_title,
    c.credits,
    e.final_score,
    letter_grade(e.final_score)          AS grade,
    grade_points(e.final_score)          AS grade_points,
    CASE
        WHEN e.final_score IS NULL        THEN 'in progress'
        WHEN e.final_score >= c.pass_mark THEN 'passed'
        ELSE 'failed'
    END                                  AS result
FROM enrollments e
JOIN students s          ON s.student_id  = e.student_id
JOIN course_offerings o  ON o.offering_id = e.offering_id
JOIN courses c           ON c.course_id   = o.course_id
JOIN terms tm            ON tm.term_id    = o.term_id;

-- -------------------------------------------------------------
-- Credit-weighted cumulative GPA per student (graded courses only)
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW v_student_gpa AS
SELECT
    student_id,
    student_number,
    student_name,
    COUNT(*)                                              AS courses_graded,
    SUM(credits) FILTER (WHERE result = 'passed')         AS credits_earned,
    round(SUM(grade_points * credits) / SUM(credits), 2)  AS gpa
FROM v_transcript
WHERE final_score IS NOT NULL
GROUP BY student_id, student_number, student_name;

-- -------------------------------------------------------------
-- Attendance rate per enrollment ('late' counts as attended)
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW v_attendance_rate AS
SELECT
    a.enrollment_id,
    COUNT(*)                                              AS classes_held,
    COUNT(*) FILTER (WHERE a.status <> 'absent')          AS classes_attended,
    round(100.0 * COUNT(*) FILTER (WHERE a.status <> 'absent') / COUNT(*), 1) AS attendance_pct
FROM attendance a
GROUP BY a.enrollment_id;

-- -------------------------------------------------------------
-- Weekly timetable for the current term
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW v_current_timetable AS
SELECT
    (ARRAY['Mon','Tue','Wed','Thu','Fri'])[o.day_of_week] AS day,
    to_char(o.start_time, 'HH24:MI') || '-' || to_char(o.end_time, 'HH24:MI') AS time_slot,
    c.code                               AS course_code,
    c.title                              AS course_title,
    t.first_name || ' ' || t.last_name   AS teacher,
    o.room,
    (SELECT COUNT(*) FROM enrollments e WHERE e.offering_id = o.offering_id) AS enrolled,
    o.capacity
FROM course_offerings o
JOIN courses  c ON c.course_id  = o.course_id
JOIN teachers t ON t.teacher_id = o.teacher_id
WHERE o.term_id = (SELECT term_id FROM terms ORDER BY start_date DESC LIMIT 1)
ORDER BY o.day_of_week, o.start_time;
