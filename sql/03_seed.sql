-- =============================================================
-- Sample data
-- Random values use a fixed seed, so every run produces the same data.
-- Data is a snapshot as of 2026-11-06 (the current term is in progress).
-- =============================================================
SET search_path TO school;

SELECT setseed(0.42);

-- -------------------------------------------------------------
-- Departments
-- -------------------------------------------------------------
INSERT INTO departments (code, name) VALUES
    ('MATH', 'Mathematics'),
    ('SCI',  'Natural Sciences'),
    ('LANG', 'Languages'),
    ('HUM',  'Humanities'),
    ('ICT',  'Computing');

-- -------------------------------------------------------------
-- Teachers
-- -------------------------------------------------------------
INSERT INTO teachers (first_name, last_name, email, department_id, hire_date)
SELECT t.first_name, t.last_name,
       lower(t.first_name || '.' || t.last_name) || '@school.example',
       (SELECT department_id FROM departments WHERE code = t.dept_code), t.hire_date
FROM (VALUES
    ('Jean',     'Habimana',   'MATH', DATE '2015-01-05'),
    ('Grace',    'Uwase',      'SCI',  DATE '2018-09-03'),
    ('Eric',     'Mugisha',    'SCI',  DATE '2012-01-09'),
    ('Amina',    'Hassan',     'LANG', DATE '2019-01-07'),
    ('Baraka',   'Otieno',     'LANG', DATE '2016-09-05'),
    ('Claudine', 'Mukamana',   'HUM',  DATE '2020-01-06'),
    ('David',    'Nkurunziza', 'ICT',  DATE '2021-09-06'),
    ('Sarah',    'Ingabire',   'MATH', DATE '2026-09-01')   -- new hire, no classes yet
) AS t (first_name, last_name, dept_code, hire_date);

-- -------------------------------------------------------------
-- Courses
-- -------------------------------------------------------------
INSERT INTO courses (code, title, department_id, credits, pass_mark)
SELECT c.code, c.title,
       (SELECT department_id FROM departments WHERE code = c.dept_code), c.credits, c.pass_mark
FROM (VALUES
    ('MATH101', 'Mathematics',              'MATH', 4, 50),
    ('MATH201', 'Statistics',               'MATH', 3, 50),
    ('PHYS101', 'Physics',                  'SCI',  4, 50),
    ('CHEM101', 'Chemistry',                'SCI',  4, 50),
    ('BIO101',  'Biology',                  'SCI',  3, 50),
    ('ENG101',  'English',                  'LANG', 3, 60),
    ('KSW101',  'Kiswahili',                'LANG', 2, 60),
    ('FRE101',  'French',                   'LANG', 2, 60),
    ('HIS101',  'History',                  'HUM',  2, 50),
    ('CS101',   'Introduction to Programming', 'ICT', 3, 50)
) AS c (code, title, dept_code, credits, pass_mark);

-- -------------------------------------------------------------
-- Terms
-- -------------------------------------------------------------
INSERT INTO terms (name, start_date, end_date) VALUES
    ('2025 Term 1', '2025-01-13', '2025-04-04'),
    ('2025 Term 2', '2025-04-28', '2025-07-18'),
    ('2025 Term 3', '2025-09-08', '2025-11-28'),
    ('2026 Term 1', '2026-01-12', '2026-04-03'),
    ('2026 Term 2', '2026-04-27', '2026-07-17'),
    ('2026 Term 3', '2026-09-07', '2026-11-27');   -- in progress

-- -------------------------------------------------------------
-- Course offerings: every course runs every term on a fixed timetable
-- -------------------------------------------------------------
INSERT INTO course_offerings
    (course_id, term_id, teacher_id, room, day_of_week, start_time, end_time, capacity)
SELECT c.course_id, tm.term_id, t.teacher_id, s.room, s.day_of_week, s.start_time, s.end_time, s.capacity
FROM (VALUES
    ('MATH101', 'jean.habimana@school.example',    'A1',      1, TIME '08:00', TIME '10:00', 35),
    ('MATH201', 'jean.habimana@school.example',    'A1',      3, TIME '08:00', TIME '10:00', 25),
    ('PHYS101', 'grace.uwase@school.example',      'Lab 1',   2, TIME '08:00', TIME '10:00', 30),
    ('CHEM101', 'eric.mugisha@school.example',     'Lab 2',   2, TIME '10:30', TIME '12:30', 30),
    ('BIO101',  'eric.mugisha@school.example',     'Lab 2',   4, TIME '08:00', TIME '10:00', 30),
    ('ENG101',  'amina.hassan@school.example',     'B2',      1, TIME '10:30', TIME '12:30', 40),
    ('KSW101',  'baraka.otieno@school.example',    'B2',      3, TIME '10:30', TIME '12:30', 40),
    ('FRE101',  'baraka.otieno@school.example',    'B3',      5, TIME '08:00', TIME '10:00', 25),
    ('HIS101',  'claudine.mukamana@school.example','B3',      4, TIME '10:30', TIME '12:30', 35),
    ('CS101',   'david.nkurunziza@school.example', 'ICT Lab', 5, TIME '10:30', TIME '12:30', 20)
) AS s (course_code, teacher_email, room, day_of_week, start_time, end_time, capacity)
JOIN courses  c ON c.code  = s.course_code
JOIN teachers t ON t.email = s.teacher_email
CROSS JOIN terms tm
ORDER BY tm.term_id, c.course_id;

-- -------------------------------------------------------------
-- Students: 48 students, 16 per admission year
-- -------------------------------------------------------------
INSERT INTO students
    (student_number, first_name, last_name, email, date_of_birth, gender, admission_year, status)
SELECT
    'S' || yr || lpad(((n - 1) % 16 + 1)::TEXT, 3, '0'),
    f.first_name,
    l.last_name,
    lower(f.first_name || '.' || l.last_name) || '@students.school.example',
    make_date(yr - 15, 1, 1) + (random() * 364)::INT,
    f.gender,
    yr,
    CASE
        WHEN yr = 2024 AND (n - 1) % 16 < 4 THEN 'graduated'
        WHEN n IN (20, 37)                  THEN 'withdrawn'
        ELSE 'active'
    END
FROM unnest(ARRAY[
        'Aline','Brian','Cynthia','Daniel','Esther','Felix','Gloria','Hakim',
        'Irene','Joseph','Keza','Liam','Mariam','Noah','Olive','Patrick',
        'Queen','Robert','Sandrine','Thierry','Umutoni','Victor','Wendy','Xavier',
        'Yvonne','Zawadi','Alice','Benjamin','Chantal','Didier','Eliane','Fabrice',
        'Gisele','Hope','Isaac','Janet','Kevin','Lydia','Moses','Nadia',
        'Olivier','Pacifique','Rachel','Samuel','Teta','Ulrich','Vanessa','Yves'
     ], ARRAY[
        'F','M','F','M','F','M','F','M',
        'F','M','F','M','F','M','F','M',
        'F','M','F','M','F','M','F','M',
        'F','F','F','M','F','M','F','M',
        'F','F','M','F','M','F','M','F',
        'M','M','F','M','F','M','F','M'
     ]) WITH ORDINALITY AS f (first_name, gender, n)
CROSS JOIN LATERAL (
    SELECT (ARRAY[
        'Uwimana','Niyonzima','Mutesi','Kamanzi','Ishimwe','Mwangi','Achieng','Bizimana',
        'Iradukunda','Okello','Nshuti','Kariuki','Umuhoza','Ndayisaba','Wanjiru','Hakizimana',
        'Mbabazi','Tuyisenge','Akinyi','Gatete','Ndikumana','Muthoni','Rukundo','Nyiraneza'
    ])[(n::INT * 7) % 24 + 1] AS last_name,
    2024 + ((n::INT - 1) / 16) AS yr
) l
ORDER BY n;

-- -------------------------------------------------------------
-- Enrollments
-- Each eligible student picks 5 courses per term; offerings never exceed capacity.
-- -------------------------------------------------------------
CREATE TEMP TABLE student_ability AS
SELECT student_id, 50 + random() * 42 AS ability          -- 50..92
FROM students;

CREATE TEMP TABLE course_difficulty (code, offset_pts) AS VALUES
    ('MATH201', -8), ('PHYS101', -6), ('CHEM101', -4), ('MATH101', -3), ('CS101', -2),
    ('FRE101', -1),  ('BIO101', 0),   ('HIS101', 2),   ('ENG101', 3),   ('KSW101', 5);

INSERT INTO enrollments (student_id, offering_id, enrolled_on, final_score)
WITH eligible AS (
    SELECT s.student_id, tm.term_id, tm.start_date, tm.name AS term_name
    FROM students s
    JOIN terms tm ON extract(YEAR FROM tm.start_date) >= s.admission_year
    WHERE s.status = 'active'
       OR (s.status = 'graduated' AND tm.start_date < DATE '2026-01-01')
       OR (s.status = 'withdrawn' AND tm.term_id = (
              SELECT min(t2.term_id) FROM terms t2
              WHERE extract(YEAR FROM t2.start_date) >= s.admission_year))
),
candidates AS (
    SELECT e.student_id, o.offering_id, o.capacity, e.start_date, e.term_name, c.code,
           row_number() OVER (PARTITION BY e.student_id, e.term_id ORDER BY random()) AS pick
    FROM eligible e
    JOIN course_offerings o ON o.term_id = e.term_id
    JOIN courses c          ON c.course_id = o.course_id
),
chosen AS (
    SELECT *, row_number() OVER (PARTITION BY offering_id ORDER BY pick, student_id) AS seat
    FROM candidates
    WHERE pick <= 5
)
SELECT ch.student_id, ch.offering_id, ch.start_date - 7,
       CASE WHEN ch.term_name = '2026 Term 3' THEN NULL       -- not graded yet
            ELSE round(greatest(0, least(100,
                     sa.ability + cd.offset_pts + (random() - 0.5) * 30))::NUMERIC, 1)
       END
FROM chosen ch
JOIN student_ability   sa ON sa.student_id = ch.student_id
JOIN course_difficulty cd ON cd.code = ch.code
WHERE ch.seat <= ch.capacity
ORDER BY ch.offering_id, ch.student_id;

-- -------------------------------------------------------------
-- Attendance: one record per weekly class meeting up to the snapshot date.
-- Weaker students miss more classes.
-- -------------------------------------------------------------
INSERT INTO attendance (enrollment_id, class_date, status)
SELECT enrollment_id, class_date,
       CASE
           WHEN r < 0.01 + (92 - ability) / 450      THEN 'absent'
           WHEN r < 0.06 + (92 - ability) / 450      THEN 'late'
           ELSE 'present'
       END
FROM (
    -- random() is drawn here, once per class meeting; the class-date subquery
    -- must not produce it, or the planner may cache and reuse its values
    SELECT en.enrollment_id, d.class_date, sa.ability, random() AS r
    FROM enrollments en
    JOIN course_offerings o  ON o.offering_id = en.offering_id
    JOIN terms tm            ON tm.term_id = o.term_id
    JOIN student_ability sa  ON sa.student_id = en.student_id
    CROSS JOIN LATERAL (
        SELECT g::DATE AS class_date
        FROM generate_series(tm.start_date, least(tm.end_date, DATE '2026-11-06'), INTERVAL '1 day') g
        WHERE extract(ISODOW FROM g) = o.day_of_week
    ) d
    ORDER BY en.enrollment_id, d.class_date
    OFFSET 0
) meetings;

DROP TABLE student_ability, course_difficulty;
