-- =============================================================
-- School Management Database — Schema
-- PostgreSQL 16
-- =============================================================

SET client_min_messages = warning;   -- hide "drop cascades to ..." notices on rebuild

DROP SCHEMA IF EXISTS school CASCADE;
CREATE SCHEMA school;
SET search_path TO school;

-- -------------------------------------------------------------
-- Departments
-- -------------------------------------------------------------
CREATE TABLE departments (
    department_id   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            VARCHAR(10)  NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL UNIQUE
);

-- -------------------------------------------------------------
-- Teachers
-- -------------------------------------------------------------
CREATE TABLE teachers (
    teacher_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name      VARCHAR(50)  NOT NULL,
    last_name       VARCHAR(50)  NOT NULL,
    email           VARCHAR(255) NOT NULL UNIQUE,
    department_id   SMALLINT     NOT NULL REFERENCES departments (department_id),
    hire_date       DATE         NOT NULL,
    CONSTRAINT teachers_email_format CHECK (email LIKE '%_@_%._%')
);

-- -------------------------------------------------------------
-- Students
-- -------------------------------------------------------------
CREATE TABLE students (
    student_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_number  CHAR(8)      NOT NULL UNIQUE,          -- e.g. S2024001
    first_name      VARCHAR(50)  NOT NULL,
    last_name       VARCHAR(50)  NOT NULL,
    email           VARCHAR(255) NOT NULL UNIQUE,
    date_of_birth   DATE         NOT NULL,
    gender          CHAR(1)      CHECK (gender IN ('F', 'M')),
    admission_year  SMALLINT     NOT NULL CHECK (admission_year BETWEEN 2000 AND 2100),
    status          VARCHAR(10)  NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'graduated', 'withdrawn')),
    CONSTRAINT students_email_format CHECK (email LIKE '%_@_%._%')
);

-- -------------------------------------------------------------
-- Courses (the catalogue)
-- -------------------------------------------------------------
CREATE TABLE courses (
    course_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            VARCHAR(10)  NOT NULL UNIQUE,              -- e.g. MATH101
    title           VARCHAR(100) NOT NULL,
    department_id   SMALLINT     NOT NULL REFERENCES departments (department_id),
    credits         SMALLINT     NOT NULL CHECK (credits BETWEEN 1 AND 10),
    pass_mark       NUMERIC(5,2) NOT NULL DEFAULT 50 CHECK (pass_mark BETWEEN 0 AND 100)
);

-- -------------------------------------------------------------
-- Academic terms
-- -------------------------------------------------------------
CREATE TABLE terms (
    term_id         SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(30) NOT NULL UNIQUE,               -- e.g. 2024 Term 1
    start_date      DATE        NOT NULL,
    end_date        DATE        NOT NULL,
    CONSTRAINT terms_valid_range CHECK (end_date > start_date)
);

-- -------------------------------------------------------------
-- Course offerings: a course taught in a term, by a teacher, at a time
-- -------------------------------------------------------------
CREATE TABLE course_offerings (
    offering_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    course_id       INT      NOT NULL REFERENCES courses (course_id),
    term_id         SMALLINT NOT NULL REFERENCES terms (term_id),
    teacher_id      INT      NOT NULL REFERENCES teachers (teacher_id),
    room            VARCHAR(20) NOT NULL,
    day_of_week     SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 5),  -- 1 = Monday
    start_time      TIME     NOT NULL,
    end_time        TIME     NOT NULL,
    capacity        SMALLINT NOT NULL CHECK (capacity > 0),
    CONSTRAINT offerings_valid_time CHECK (end_time > start_time),
    CONSTRAINT offerings_one_per_term UNIQUE (course_id, term_id)
);

-- -------------------------------------------------------------
-- Enrollments: a student taking an offering, with the final score
-- -------------------------------------------------------------
CREATE TABLE enrollments (
    enrollment_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id      INT  NOT NULL REFERENCES students (student_id) ON DELETE CASCADE,
    offering_id     INT  NOT NULL REFERENCES course_offerings (offering_id) ON DELETE CASCADE,
    enrolled_on     DATE NOT NULL DEFAULT CURRENT_DATE,
    final_score     NUMERIC(5,2) CHECK (final_score BETWEEN 0 AND 100),  -- NULL until graded
    CONSTRAINT enrollments_unique UNIQUE (student_id, offering_id)
);

-- -------------------------------------------------------------
-- Attendance: one row per enrollment per class meeting
-- -------------------------------------------------------------
CREATE TABLE attendance (
    enrollment_id   INT  NOT NULL REFERENCES enrollments (enrollment_id) ON DELETE CASCADE,
    class_date      DATE NOT NULL,
    status          VARCHAR(7) NOT NULL CHECK (status IN ('present', 'late', 'absent')),
    PRIMARY KEY (enrollment_id, class_date)
);

-- -------------------------------------------------------------
-- Indexes on foreign keys used in joins
-- -------------------------------------------------------------
CREATE INDEX idx_teachers_department    ON teachers (department_id);
CREATE INDEX idx_courses_department     ON courses (department_id);
CREATE INDEX idx_offerings_term         ON course_offerings (term_id);
CREATE INDEX idx_offerings_teacher      ON course_offerings (teacher_id);
CREATE INDEX idx_enrollments_offering   ON enrollments (offering_id);
