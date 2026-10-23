erDiagram
departments ||--o{ users : "department_id"
departments ||--o{ subjects : "department_id"
users ||--o{ system_configs : "updated_by"
users ||--o{ system_logs : "user_id"
users ||--o{ subjects : "created_by"
subjects ||--o{ chapters : "subject_id"
subjects ||--o{ subject_access : "subject_id"
users ||--o{ subject_access : "lecturer_id"
users ||--o{ subject_access : "approved_by"
subjects ||--o{ classes : "subject_id"
users ||--o{ classes : "lecturer_id"
classes ||--o{ class_enrollments : "class_id"
users ||--o{ class_enrollments : "student_id"
subjects ||--o{ questions : "subject_id"
chapters ||--o{ questions : "chapter_id"
users ||--o{ questions : "created_by"
questions ||--o{ question_options : "question_id"
subjects ||--o{ exams : "subject_id"
classes ||--o{ exams : "class_id"
users ||--o{ exams : "created_by"
exams ||--o{ exam_chapter_rules : "exam_id"
chapters ||--o{ exam_chapter_rules : "chapter_id"
exams ||--o{ exam_questions : "exam_id"
questions ||--o{ exam_questions : "question_id"
exams ||--o{ exam_eligibility : "exam_id"
users ||--o{ exam_eligibility : "student_id"
exams ||--o{ exam_attempts : "exam_id"
users ||--o{ exam_attempts : "student_id"
exam_attempts ||--o{ student_answers : "attempt_id"
questions ||--o{ student_answers : "question_id"
question_options ||--o{ student_answers : "selected_option_id"
exam_attempts ||--o{ violation_logs : "attempt_id"

    departments {
        PK_ department_id "SERIAL"
        UK_ department_code "VARCHAR(20)"
        _ department_name "VARCHAR(100)"
    }

    users {
        PK_ user_id "SERIAL"
        UK_ user_code "VARCHAR(20)"
        UK_ email "VARCHAR(100)"
        _ password_hash "VARCHAR(255)"
        _ full_name "VARCHAR(100)"
        _ role "VARCHAR(20)"
        FK_ department_id "INT"
        _ status "VARCHAR(20)"
        _ created_at "TIMESTAMP"
    }

    system_configs {
        PK_ config_key "VARCHAR(50)"
        _ config_value "VARCHAR(255)"
        _ description "TEXT"
        FK_ updated_by "INT"
        _ updated_at "TIMESTAMP"
    }

    system_logs {
        PK_ log_id "SERIAL"
        FK_ user_id "INT"
        _ action "VARCHAR(255)"
        _ created_at "TIMESTAMP"
    }

    subjects {
        PK_ subject_id "SERIAL"
        UK_ subject_code "VARCHAR(20)"
        _ subject_name "VARCHAR(150)"
        _ description "TEXT"
        _ allow_auto_grading "BOOLEAN"
        FK_ department_id "INT"
        FK_ created_by "INT"
    }

    chapters {
        PK_ chapter_id "SERIAL"
        FK_ subject_id "INT"
        _ chapter_number "NUMERIC(4,2)"
        _ chapter_title "VARCHAR(200)"
    }

    subject_access {
        PK_ access_id "SERIAL"
        FK_ subject_id "INT"
        FK_ lecturer_id "INT"
        _ grant_type "VARCHAR(30)"
        _ status "VARCHAR(20)"
        FK_ approved_by "INT"
        _ updated_at "TIMESTAMP"
    }

    classes {
        PK_ class_id "SERIAL"
        UK_ class_code "VARCHAR(30)"
        FK_ subject_id "INT"
        FK_ lecturer_id "INT"
        _ semester "VARCHAR(20)"
    }

    class_enrollments {
        PK_ enrollment_id "SERIAL"
        FK_ class_id "INT"
        FK_ student_id "INT"
    }

    questions {
        PK_ question_id "SERIAL"
        FK_ subject_id "INT"
        FK_ chapter_id "INT"
        FK_ created_by "INT"
        _ question_type "VARCHAR(20)"
        _ content "TEXT"
        _ description "TEXT"
        _ learning_outcome "VARCHAR(50)"
        _ default_score "NUMERIC(5,2)"
        _ is_public "BOOLEAN"
        _ created_at "TIMESTAMP"
    }

    question_options {
        PK_ option_id "SERIAL"
        FK_ question_id "INT"
        _ option_content "TEXT"
        _ matching_answer "TEXT"
        _ is_correct "BOOLEAN"
        _ hint "TEXT"
    }

    exams {
        PK_ exam_id "SERIAL"
        FK_ subject_id "INT"
        FK_ class_id "INT"
        FK_ created_by "INT"
        _ exam_title "VARCHAR(200)"
        _ description "TEXT"
        _ importance_level "INT"
        _ start_time "TIMESTAMP"
        _ end_time "TIMESTAMP"
        _ duration_minutes "INT"
        _ mcq_grading_method "VARCHAR(50)"
        _ min_pass_percentage "NUMERIC(5,2)"
        _ question_source_mode "VARCHAR(30)"
        _ mcq_weight_percent "NUMERIC(5,2)"
        _ essay_weight_percent "NUMERIC(5,2)"
        _ status "VARCHAR(20)"
        _ created_at "TIMESTAMP"
    }

    exam_chapter_rules {
        PK_ rule_id "SERIAL"
        FK_ exam_id "INT"
        FK_ chapter_id "INT"
        _ question_type "VARCHAR(20)"
        _ question_count "INT"
    }

    exam_questions {
        PK_ exam_question_id "SERIAL"
        FK_ exam_id "INT"
        FK_ question_id "INT"
    }

    exam_eligibility {
        PK_ eligibility_id "SERIAL"
        FK_ exam_id "INT"
        FK_ student_id "INT"
        _ is_banned "BOOLEAN"
    }

    exam_attempts {
        PK_ attempt_id "SERIAL"
        FK_ exam_id "INT"
        FK_ student_id "INT"
        _ started_at "TIMESTAMP"
        _ submitted_at "TIMESTAMP"
        _ total_score "NUMERIC(5,2)"
        _ is_passed "BOOLEAN"
        _ status "VARCHAR(20)"
    }

    student_answers {
        PK_ answer_id "SERIAL"
        FK_ attempt_id "INT"
        FK_ question_id "INT"
        FK_ selected_option_id "INT"
        _ answer_text "TEXT"
        _ score_awarded "NUMERIC(5,2)"
    }

    violation_logs {
        PK_ violation_id "SERIAL"
        FK_ attempt_id "INT"
        _ violation_type "VARCHAR(50)"
        _ violation_details "VARCHAR(255)"
        _ detected_at "TIMESTAMP"
    }
