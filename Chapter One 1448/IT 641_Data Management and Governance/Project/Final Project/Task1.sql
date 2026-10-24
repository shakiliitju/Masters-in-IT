-- =========================================================
-- Research Management System - DDL (MySQL 8.0.16+)
-- Fixes applied:
--   1. DATE DEFAULT (CURRENT_DATE)
--   2. CHECK constraints at table level (named)
--   3. Self-mentor rule -> triggers (error 3823)
--   4. Reviewer-present rule -> triggers (error 3823)
--   5. BIGINT AUTO_INCREMENT instead of BIGSERIAL
--   6. ENGINE=InnoDB everywhere
--   7. Circular FK Department<->Faculty via ALTER TABLE
-- =========================================================
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS AuditLog;
DROP TABLE IF EXISTS EquipmentUsage;
DROP TABLE IF EXISTS Equipment;
DROP TABLE IF EXISTS Revision;
DROP TABLE IF EXISTS Review;
DROP TABLE IF EXISTS Submission;
DROP TABLE IF EXISTS Conference;
DROP TABLE IF EXISTS PublicationAuthor;
DROP TABLE IF EXISTS Publication;
DROP TABLE IF EXISTS Funding;
DROP TABLE IF EXISTS FundingSource;
DROP TABLE IF EXISTS StudentProject;
DROP TABLE IF EXISTS FacultyProject;
DROP TABLE IF EXISTS ResearchProject;
DROP TABLE IF EXISTS Student;
DROP TABLE IF EXISTS Faculty;
DROP TABLE IF EXISTS Program;
DROP TABLE IF EXISTS Department;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================================================
-- DEPARTMENT
-- =========================================================
CREATE TABLE Department (
    department_id     INT            PRIMARY KEY,
    department_name   VARCHAR(100)   NOT NULL UNIQUE,
    building          VARCHAR(100),
    phone             VARCHAR(20),
    head_faculty_id   INT            NULL
) ENGINE=InnoDB;

-- =========================================================
-- PROGRAM
-- =========================================================
CREATE TABLE Program (
    program_id        INT            PRIMARY KEY,
    program_name      VARCHAR(100)   NOT NULL,
    degree_level      VARCHAR(20)    NOT NULL,
    department_id     INT            NOT NULL,
    CONSTRAINT chk_program_degree
        CHECK (degree_level IN ('Bachelor','Master','PhD','Diploma')),
    CONSTRAINT fk_program_dept
        FOREIGN KEY (department_id) REFERENCES Department(department_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- FACULTY (recursive mentoring)
-- =========================================================
CREATE TABLE Faculty (
    faculty_id        INT            PRIMARY KEY,
    first_name        VARCHAR(50)    NOT NULL,
    last_name         VARCHAR(50)    NOT NULL,
    email             VARCHAR(120)   NOT NULL UNIQUE,
    phone             VARCHAR(20),
    hire_date         DATE           NOT NULL DEFAULT (CURRENT_DATE),
    title             VARCHAR(50),
    salary            DECIMAL(12,2),
    department_id     INT            NOT NULL,
    mentor_id         INT            NULL,
    CONSTRAINT chk_faculty_email
        CHECK (email LIKE '%@%'),
    CONSTRAINT chk_faculty_title
        CHECK (title IS NULL OR title IN ('Professor','Associate Professor',
                                          'Assistant Professor','Lecturer','Researcher')),
    CONSTRAINT chk_faculty_salary
        CHECK (salary IS NULL OR salary >= 0),
    CONSTRAINT fk_faculty_dept
        FOREIGN KEY (department_id) REFERENCES Department(department_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_faculty_mentor
        FOREIGN KEY (mentor_id) REFERENCES Faculty(faculty_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

ALTER TABLE Department
    ADD CONSTRAINT fk_dept_head
    FOREIGN KEY (head_faculty_id) REFERENCES Faculty(faculty_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

DELIMITER $$

CREATE TRIGGER trg_faculty_no_self_mentor_insert
BEFORE INSERT ON Faculty
FOR EACH ROW
BEGIN
    IF NEW.mentor_id IS NOT NULL AND NEW.mentor_id = NEW.faculty_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A faculty member cannot be their own mentor.';
    END IF;
END$$

CREATE TRIGGER trg_faculty_no_self_mentor_update
BEFORE UPDATE ON Faculty
FOR EACH ROW
BEGIN
    IF NEW.mentor_id IS NOT NULL AND NEW.mentor_id = NEW.faculty_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A faculty member cannot be their own mentor.';
    END IF;
END$$

DELIMITER ;

-- =========================================================
-- STUDENT
-- =========================================================
CREATE TABLE Student (
    student_id        INT            PRIMARY KEY,
    first_name        VARCHAR(50)    NOT NULL,
    last_name         VARCHAR(50)    NOT NULL,
    email             VARCHAR(120)   NOT NULL UNIQUE,
    phone             VARCHAR(20),
    date_of_birth     DATE,
    enrollment_date   DATE           NOT NULL DEFAULT (CURRENT_DATE),
    academic_status   VARCHAR(20)    NOT NULL DEFAULT 'Active',
    program_id        INT            NOT NULL,
    supervisor_id     INT            NULL,
    CONSTRAINT chk_student_email
        CHECK (email LIKE '%@%'),
    CONSTRAINT chk_student_status
        CHECK (academic_status IN ('Active','Suspended','Graduated','Withdrawn')),
    CONSTRAINT fk_student_program
        FOREIGN KEY (program_id) REFERENCES Program(program_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_student_supervisor
        FOREIGN KEY (supervisor_id) REFERENCES Faculty(faculty_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- RESEARCH PROJECT
-- =========================================================
CREATE TABLE ResearchProject (
    project_id        INT            PRIMARY KEY,
    project_title     VARCHAR(200)   NOT NULL,
    start_date        DATE           NOT NULL DEFAULT (CURRENT_DATE),
    end_date          DATE,
    status            VARCHAR(20)    NOT NULL DEFAULT 'Active',
    department_id     INT            NOT NULL,
    lead_faculty_id   INT            NULL,
    CONSTRAINT chk_project_status
        CHECK (status IN ('Proposed','Active','Completed','Cancelled')),
    CONSTRAINT chk_project_dates
        CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT fk_project_dept
        FOREIGN KEY (department_id) REFERENCES Department(department_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_project_lead
        FOREIGN KEY (lead_faculty_id) REFERENCES Faculty(faculty_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- FACULTY–PROJECT SUPERVISION (M:N)
-- =========================================================
CREATE TABLE FacultyProject (
    faculty_id        INT            NOT NULL,
    project_id        INT            NOT NULL,
    supervision_role  VARCHAR(50)    NOT NULL DEFAULT 'Co-Investigator',
    start_date        DATE           NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (faculty_id, project_id),
    CONSTRAINT chk_fp_role
        CHECK (supervision_role IN ('Principal Investigator','Co-Investigator',
                                    'Supervisor','Advisor','Consultant')),
    CONSTRAINT fk_fp_faculty
        FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_fp_project
        FOREIGN KEY (project_id) REFERENCES ResearchProject(project_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- STUDENT–PROJECT PARTICIPATION (M:N)
-- =========================================================
CREATE TABLE StudentProject (
    student_id               INT            NOT NULL,
    project_id               INT            NOT NULL,
    project_role             VARCHAR(50)    NOT NULL DEFAULT 'Researcher',
    contribution_percentage  DECIMAL(5,2)   NOT NULL DEFAULT 0,
    join_date                DATE           NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (student_id, project_id),
    CONSTRAINT chk_sp_role
        CHECK (project_role IN ('Researcher','Assistant','Lead Student','Intern','Volunteer')),
    CONSTRAINT chk_sp_contrib
        CHECK (contribution_percentage BETWEEN 0 AND 100),
    CONSTRAINT fk_sp_student
        FOREIGN KEY (student_id) REFERENCES Student(student_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sp_project
        FOREIGN KEY (project_id) REFERENCES ResearchProject(project_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- FUNDING SOURCE & FUNDING
-- =========================================================
CREATE TABLE FundingSource (
    source_id         INT            PRIMARY KEY,
    source_name       VARCHAR(150)   NOT NULL UNIQUE,
    source_type       VARCHAR(50),
    contact_email     VARCHAR(120),
    country           VARCHAR(60),
    CONSTRAINT chk_source_type
        CHECK (source_type IS NULL OR source_type IN
               ('Government','Industry','University','Non-Profit','International'))
) ENGINE=InnoDB;

CREATE TABLE Funding (
    funding_id        INT            PRIMARY KEY,
    project_id        INT            NOT NULL,
    source_id         INT            NOT NULL,
    funding_amount    DECIMAL(14,2)  NOT NULL,
    funding_date      DATE           NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT chk_funding_amount
        CHECK (funding_amount >= 0),
    CONSTRAINT fk_funding_project
        FOREIGN KEY (project_id) REFERENCES ResearchProject(project_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_funding_source
        FOREIGN KEY (source_id) REFERENCES FundingSource(source_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- PUBLICATION / CONFERENCE / SUBMISSION
-- =========================================================
CREATE TABLE Publication (
    publication_id    INT            PRIMARY KEY,
    title             VARCHAR(300)   NOT NULL,
    publication_type  VARCHAR(30)    NOT NULL,
    publication_year  INT            NOT NULL,
    doi               VARCHAR(100)   UNIQUE,
    journal_name      VARCHAR(150),
    CONSTRAINT chk_pub_type
        CHECK (publication_type IN ('Journal','Conference','Book Chapter','Workshop')),
    CONSTRAINT chk_pub_year
        CHECK (publication_year BETWEEN 1900 AND 2100)
) ENGINE=InnoDB;

CREATE TABLE PublicationAuthor (
    publication_id    INT            NOT NULL,
    faculty_id        INT            NOT NULL,
    author_order      INT            NOT NULL,
    is_corresponding  BOOLEAN        NOT NULL DEFAULT FALSE,
    PRIMARY KEY (publication_id, faculty_id),
    CONSTRAINT uq_pub_author_order UNIQUE (publication_id, author_order),
    CONSTRAINT chk_author_order CHECK (author_order > 0),
    CONSTRAINT fk_pa_publication
        FOREIGN KEY (publication_id) REFERENCES Publication(publication_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pa_faculty
        FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Conference (
    conference_id       INT            PRIMARY KEY,
    conference_name     VARCHAR(200)   NOT NULL,
    location            VARCHAR(150),
    conference_date     DATE           NOT NULL,
    submission_deadline DATE,
    CONSTRAINT chk_conf_dates
        CHECK (submission_deadline IS NULL OR submission_deadline <= conference_date)
) ENGINE=InnoDB;

CREATE TABLE Submission (
    submission_id     INT            PRIMARY KEY,
    publication_id    INT            NOT NULL,
    conference_id     INT            NOT NULL,
    submission_date   DATE           NOT NULL DEFAULT (CURRENT_DATE),
    decision          VARCHAR(20)    NOT NULL DEFAULT 'Pending',
    decision_date     DATE,
    CONSTRAINT chk_sub_decision
        CHECK (decision IN ('Pending','Accepted','Rejected','Revision')),
    CONSTRAINT uq_sub_pub_conf UNIQUE (publication_id, conference_id),
    CONSTRAINT fk_sub_publication
        FOREIGN KEY (publication_id) REFERENCES Publication(publication_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sub_conference
        FOREIGN KEY (conference_id) REFERENCES Conference(conference_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- REVIEW (reviewer-present rule enforced by triggers)
-- =========================================================
CREATE TABLE Review (
    review_id           INT            PRIMARY KEY,
    submission_id       INT            NOT NULL,
    reviewer_faculty_id INT            NULL,
    reviewer_name       VARCHAR(120),
    review_score        DECIMAL(4,2)   NOT NULL,
    review_comments     TEXT,
    review_date         DATE           NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT chk_review_score CHECK (review_score BETWEEN 0 AND 10),
    CONSTRAINT fk_review_submission
        FOREIGN KEY (submission_id) REFERENCES Submission(submission_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_review_faculty
        FOREIGN KEY (reviewer_faculty_id) REFERENCES Faculty(faculty_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

DELIMITER $$

CREATE TRIGGER trg_review_reviewer_present_insert
BEFORE INSERT ON Review
FOR EACH ROW
BEGIN
    IF NEW.reviewer_faculty_id IS NULL AND NEW.reviewer_name IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A review must have either a reviewer_faculty_id or a reviewer_name.';
    END IF;
END$$

CREATE TRIGGER trg_review_reviewer_present_update
BEFORE UPDATE ON Review
FOR EACH ROW
BEGIN
    IF NEW.reviewer_faculty_id IS NULL AND NEW.reviewer_name IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A review must have either a reviewer_faculty_id or a reviewer_name.';
    END IF;
END$$

DELIMITER ;

-- =========================================================
-- REVISION
-- =========================================================
CREATE TABLE Revision (
    revision_id       INT            PRIMARY KEY,
    submission_id     INT            NOT NULL,
    revision_number   INT            NOT NULL,
    revision_date     DATE           NOT NULL DEFAULT (CURRENT_DATE),
    revision_notes    TEXT,
    CONSTRAINT chk_revision_number CHECK (revision_number > 0),
    CONSTRAINT uq_revision_number UNIQUE (submission_id, revision_number),
    CONSTRAINT fk_revision_submission
        FOREIGN KEY (submission_id) REFERENCES Submission(submission_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- EQUIPMENT & USAGE
-- =========================================================
CREATE TABLE Equipment (
    equipment_id      INT            PRIMARY KEY,
    equipment_name    VARCHAR(150)   NOT NULL,
    serial_number     VARCHAR(80)    UNIQUE,
    purchase_date     DATE,
    condition_status  VARCHAR(20)    NOT NULL DEFAULT 'Good',
    department_id     INT            NOT NULL,
    CONSTRAINT chk_equip_condition
        CHECK (condition_status IN ('Good','Fair','Poor','Out of Service')),
    CONSTRAINT fk_equipment_dept
        FOREIGN KEY (department_id) REFERENCES Department(department_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE EquipmentUsage (
    equipment_id      INT            NOT NULL,
    project_id        INT            NOT NULL,
    usage_date        DATE           NOT NULL,
    usage_purpose     VARCHAR(200),
    PRIMARY KEY (equipment_id, project_id, usage_date),
    CONSTRAINT fk_eu_equipment
        FOREIGN KEY (equipment_id) REFERENCES Equipment(equipment_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_eu_project
        FOREIGN KEY (project_id) REFERENCES ResearchProject(project_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- AUDIT LOG
-- =========================================================
CREATE TABLE AuditLog (
    audit_id          BIGINT         NOT NULL AUTO_INCREMENT,
    db_user           VARCHAR(100)   NOT NULL DEFAULT (CURRENT_USER()),
    operation         VARCHAR(10)    NOT NULL,
    table_name        VARCHAR(60)    NOT NULL,
    record_pk         VARCHAR(100)   NOT NULL,
    old_value         TEXT,
    new_value         TEXT,
    change_time       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (audit_id),
    CONSTRAINT chk_audit_op
        CHECK (operation IN ('INSERT','UPDATE','DELETE'))
) ENGINE=InnoDB;

-- =========================================================
SELECT 'Schema created successfully' AS status;