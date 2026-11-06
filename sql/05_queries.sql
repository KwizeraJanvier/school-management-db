-- =============================================================
-- Reporting queries: questions a school administrator would ask
-- =============================================================
SET search_path TO school;


-- -------------------------------------------------------------
-- Q1. How full is each class this term?
-- -------------------------------------------------------------
SELECT day, time_slot, course_code, teacher, room, enrolled, capacity,
       round(100.0 * enrolled / capacity) AS fill_pct
FROM v_current_timetable;


-- -------------------------------------------------------------
-- Q2. Pass rate, average score and grade distribution per course
--     (all graded terms)
-- -------------------------------------------------------------
SELECT
    course_code,
    course_title,
    COUNT(*)                                                    AS graded,
    round(AVG(final_score), 1)                                  AS avg_score,
    round(100.0 * COUNT(*) FILTER (WHERE result = 'passed') / COUNT(*), 1) AS pass_rate_pct,
    COUNT(*) FILTER (WHERE grade = 'A')                         AS a,
    COUNT(*) FILTER (WHERE grade = 'B')                         AS b,
    COUNT(*) FILTER (WHERE grade = 'C')                         AS c,
    COUNT(*) FILTER (WHERE grade = 'D')                         AS d,
    COUNT(*) FILTER (WHERE grade = 'F')                         AS f
FROM v_transcript
WHERE final_score IS NOT NULL
GROUP BY course_code, course_title
ORDER BY pass_rate_pct;


-- -------------------------------------------------------------
-- Q3. Top 3 students in each course in the last completed term
--     (ties share a rank)
-- -------------------------------------------------------------
WITH last_graded_term AS (
    SELECT MAX(term_id) AS term_id
    FROM v_transcript
    WHERE final_score IS NOT NULL
),
ranked AS (
    SELECT t.term, t.course_code, t.student_name, t.final_score,
           DENSE_RANK() OVER (PARTITION BY t.course_code ORDER BY t.final_score DESC) AS rnk
    FROM v_transcript t
    JOIN last_graded_term l USING (term_id)
)
SELECT term, course_code, rnk, student_name, final_score
FROM ranked
WHERE rnk <= 3
ORDER BY course_code, rnk, student_name;


-- -------------------------------------------------------------
-- Q4. Honour roll: active students with a cumulative GPA of 3.0+
-- -------------------------------------------------------------
SELECT RANK() OVER (ORDER BY g.gpa DESC) AS rank,
       g.student_number, g.student_name, g.gpa, g.courses_graded, g.credits_earned
FROM v_student_gpa g
JOIN students s USING (student_id)
WHERE s.status = 'active'
  AND g.gpa >= 3.0
ORDER BY rank, g.student_name;


-- -------------------------------------------------------------
-- Q5. Is each student improving? Term GPA vs. their previous term
-- -------------------------------------------------------------
WITH term_gpa AS (
    SELECT student_id, student_name, term_id, term,
           round(SUM(grade_points * credits) / SUM(credits), 2) AS term_gpa
    FROM v_transcript
    WHERE final_score IS NOT NULL
    GROUP BY student_id, student_name, term_id, term
)
SELECT student_name, term, term_gpa,
       LAG(term_gpa) OVER w                AS previous_gpa,
       term_gpa - LAG(term_gpa) OVER w     AS change
FROM term_gpa
WINDOW w AS (PARTITION BY student_id ORDER BY term_id)
ORDER BY student_name, term_id;


-- -------------------------------------------------------------
-- Q6. Does attendance affect results?
--     Average score by attendance band (graded courses)
-- -------------------------------------------------------------
SELECT
    CASE
        WHEN ar.attendance_pct = 100 THEN '1. 100%'
        WHEN ar.attendance_pct >= 90 THEN '2. 90-99%'
        WHEN ar.attendance_pct >= 80 THEN '3. 80-89%'
        ELSE                              '4. below 80%'
    END                                                         AS attendance_band,
    COUNT(*)                                                    AS enrollments,
    round(AVG(e.final_score), 1)                                AS avg_score,
    round(100.0 * COUNT(*) FILTER (WHERE e.final_score < c.pass_mark) / COUNT(*), 1) AS fail_rate_pct
FROM enrollments e
JOIN v_attendance_rate ar USING (enrollment_id)
JOIN course_offerings o   USING (offering_id)
JOIN courses c            USING (course_id)
WHERE e.final_score IS NOT NULL
GROUP BY attendance_band
ORDER BY attendance_band;


-- -------------------------------------------------------------
-- Q7. Early warning: students at risk in the current term
--     (attendance below 80% in any course, or cumulative GPA below 1.5)
-- -------------------------------------------------------------
WITH current_term AS (
    SELECT term_id FROM terms ORDER BY start_date DESC LIMIT 1
),
current_attendance AS (
    SELECT e.student_id,
           round(AVG(ar.attendance_pct), 1)                           AS avg_attendance_pct,
           string_agg(c.code, ', ' ORDER BY c.code)
               FILTER (WHERE ar.attendance_pct < 80)                  AS low_attendance_in
    FROM enrollments e
    JOIN course_offerings o   ON o.offering_id    = e.offering_id
    JOIN current_term ct      ON ct.term_id       = o.term_id
    JOIN courses c            ON c.course_id      = o.course_id
    JOIN v_attendance_rate ar ON ar.enrollment_id = e.enrollment_id
    GROUP BY e.student_id
)
SELECT s.student_number,
       s.first_name || ' ' || s.last_name   AS student_name,
       ca.avg_attendance_pct,
       ca.low_attendance_in,
       g.gpa                                AS cumulative_gpa,
       concat_ws(', ',
           CASE WHEN ca.low_attendance_in IS NOT NULL THEN 'low attendance' END,
           CASE WHEN g.gpa < 1.5                      THEN 'low GPA' END) AS reasons
FROM current_attendance ca
JOIN students s           ON s.student_id = ca.student_id
LEFT JOIN v_student_gpa g ON g.student_id = ca.student_id    -- new students have no GPA yet
WHERE ca.low_attendance_in IS NOT NULL OR g.gpa < 1.5
ORDER BY g.gpa NULLS LAST, ca.avg_attendance_pct;


-- -------------------------------------------------------------
-- Q8. Teacher workload this term (includes teachers with no classes)
-- -------------------------------------------------------------
WITH current_term AS (
    SELECT term_id FROM terms ORDER BY start_date DESC LIMIT 1
),
teaching_load AS (
    SELECT o.teacher_id,
           COUNT(*)                                                    AS classes,
           SUM(EXTRACT(EPOCH FROM o.end_time - o.start_time) / 3600)::NUMERIC(4,1) AS hours_per_week,
           SUM((SELECT COUNT(*) FROM enrollments e
                WHERE e.offering_id = o.offering_id))                  AS students
    FROM course_offerings o
    JOIN current_term USING (term_id)
    GROUP BY o.teacher_id
)
SELECT t.first_name || ' ' || t.last_name   AS teacher,
       d.name                               AS department,
       COALESCE(l.classes, 0)               AS classes,
       COALESCE(l.students, 0)              AS students,
       COALESCE(l.hours_per_week, 0)        AS hours_per_week
FROM teachers t
JOIN departments d          ON d.department_id = t.department_id
LEFT JOIN teaching_load l   ON l.teacher_id    = t.teacher_id
ORDER BY students DESC, teacher;


-- -------------------------------------------------------------
-- Q9. Department performance by school year
-- -------------------------------------------------------------
SELECT d.name                                   AS department,
       extract(YEAR FROM tm.start_date)::INT    AS year,
       COUNT(*)                                 AS graded,
       round(AVG(e.final_score), 1)             AS avg_score
FROM enrollments e
JOIN course_offerings o ON o.offering_id   = e.offering_id
JOIN courses c          ON c.course_id     = o.course_id
JOIN departments d      ON d.department_id = c.department_id
JOIN terms tm           ON tm.term_id      = o.term_id
WHERE e.final_score IS NOT NULL
GROUP BY department, year
ORDER BY department, year;


-- -------------------------------------------------------------
-- Q10. Outstanding failures: courses a student failed and has not
--      passed since
-- -------------------------------------------------------------
SELECT f.student_name, f.course_code, f.term AS failed_in, f.final_score
FROM v_transcript f
JOIN students s USING (student_id)
WHERE f.result = 'failed'
  AND s.status = 'active'
  AND NOT EXISTS (
        SELECT 1
        FROM v_transcript p
        WHERE p.student_id  = f.student_id
          AND p.course_code = f.course_code
          AND p.term_id     > f.term_id
          AND p.result      = 'passed')
ORDER BY f.student_name, f.term_id;


-- -------------------------------------------------------------
-- Q11. Active students not enrolled in anything this term
-- -------------------------------------------------------------
SELECT s.student_number, s.first_name || ' ' || s.last_name AS student_name, s.admission_year
FROM students s
WHERE s.status = 'active'
  AND NOT EXISTS (
        SELECT 1
        FROM enrollments e
        JOIN course_offerings o ON o.offering_id = e.offering_id
        WHERE e.student_id = s.student_id
          AND o.term_id = (SELECT term_id FROM terms ORDER BY start_date DESC LIMIT 1));


-- -------------------------------------------------------------
-- Q12. Data check: rooms double-booked in the same term
--      (should return no rows)
-- -------------------------------------------------------------
SELECT tm.name AS term, a.room,
       ca.code AS course_a, cb.code AS course_b,
       a.day_of_week, a.start_time, a.end_time
FROM course_offerings a
JOIN course_offerings b
  ON  b.term_id      = a.term_id
  AND b.room         = a.room
  AND b.day_of_week  = a.day_of_week
  AND b.offering_id  > a.offering_id                 -- each pair once
  AND (a.start_time, a.end_time) OVERLAPS (b.start_time, b.end_time)
JOIN courses ca ON ca.course_id = a.course_id
JOIN courses cb ON cb.course_id = b.course_id
JOIN terms tm   ON tm.term_id   = a.term_id;
