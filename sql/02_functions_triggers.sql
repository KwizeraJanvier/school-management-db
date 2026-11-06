-- =============================================================
-- Functions and business-rule triggers
-- =============================================================
SET search_path TO school;

-- -------------------------------------------------------------
-- Score -> letter grade
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION letter_grade(score NUMERIC)
RETURNS CHAR(1)
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE
        WHEN score IS NULL THEN NULL
        WHEN score >= 80   THEN 'A'
        WHEN score >= 70   THEN 'B'
        WHEN score >= 60   THEN 'C'
        WHEN score >= 50   THEN 'D'
        ELSE                    'F'
    END;
$$;

-- -------------------------------------------------------------
-- Score -> grade points on a 4.0 scale (used for GPA)
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION grade_points(score NUMERIC)
RETURNS NUMERIC(2,1)
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE letter_grade(score)
        WHEN 'A' THEN 4.0
        WHEN 'B' THEN 3.0
        WHEN 'C' THEN 2.0
        WHEN 'D' THEN 1.0
        WHEN 'F' THEN 0.0
    END;
$$;

-- -------------------------------------------------------------
-- Rule: an offering cannot take more students than its capacity
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_offering_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_capacity  SMALLINT;
    v_enrolled  INT;
BEGIN
    -- Lock the offering row so concurrent enrollments are counted correctly
    SELECT capacity INTO v_capacity
    FROM course_offerings
    WHERE offering_id = NEW.offering_id
    FOR UPDATE;

    SELECT COUNT(*) INTO v_enrolled
    FROM enrollments
    WHERE offering_id = NEW.offering_id;

    IF v_enrolled >= v_capacity THEN
        RAISE EXCEPTION 'Offering % is full (capacity %)', NEW.offering_id, v_capacity
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enrollments_capacity
BEFORE INSERT ON enrollments
FOR EACH ROW EXECUTE FUNCTION check_offering_capacity();

-- -------------------------------------------------------------
-- Rule: a teacher cannot teach two offerings at overlapping times
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_teacher_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_clash TEXT;
BEGIN
    SELECT c.code INTO v_clash
    FROM course_offerings o
    JOIN courses c USING (course_id)
    WHERE o.teacher_id  = NEW.teacher_id
      AND o.term_id     = NEW.term_id
      AND o.day_of_week = NEW.day_of_week
      AND o.offering_id <> COALESCE(NEW.offering_id, -1)
      AND (o.start_time, o.end_time) OVERLAPS (NEW.start_time, NEW.end_time)
    LIMIT 1;

    IF v_clash IS NOT NULL THEN
        RAISE EXCEPTION 'Teacher % is already teaching % at that time', NEW.teacher_id, v_clash
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_offerings_teacher_schedule
BEFORE INSERT OR UPDATE ON course_offerings
FOR EACH ROW EXECUTE FUNCTION check_teacher_schedule();
