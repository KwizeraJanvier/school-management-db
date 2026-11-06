#!/usr/bin/env bash
# Builds the school_db database from scratch and loads sample data.
# Connection settings come from the standard PG* variables, e.g.:
#   PGPORT=5433 ./setup.sh
set -euo pipefail

DB_NAME="${DB_NAME:-school_db}"
cd "$(dirname "$0")"

if ! psql -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
    echo "Creating database $DB_NAME"
    createdb "$DB_NAME"
fi

for f in sql/01_schema.sql sql/02_functions_triggers.sql sql/03_seed.sql sql/04_views.sql; do
    echo "Running $f"
    psql -d "$DB_NAME" -v ON_ERROR_STOP=1 -q -f "$f" > /dev/null
done

psql -d "$DB_NAME" -c "
    SET search_path TO school;
    SELECT 'students' AS table_name, COUNT(*) AS rows FROM students
    UNION ALL SELECT 'teachers',         COUNT(*) FROM teachers
    UNION ALL SELECT 'courses',          COUNT(*) FROM courses
    UNION ALL SELECT 'course_offerings', COUNT(*) FROM course_offerings
    UNION ALL SELECT 'enrollments',      COUNT(*) FROM enrollments
    UNION ALL SELECT 'attendance',       COUNT(*) FROM attendance;"

echo "Done. Try: psql -d $DB_NAME -f sql/05_queries.sql"
