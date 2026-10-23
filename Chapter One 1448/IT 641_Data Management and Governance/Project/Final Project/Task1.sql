
CREATE TABLE Departments (
    department_id INT GENERATED ALWAYS AS IDENTITY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    building_location VARCHAR(100),
    CONSTRAINT pk_departments PRIMARY KEY (department_id)
);

CREATE TABLE Programs (
    program_id INT GENERATED ALWAYS AS IDENTITY,
    program_name VARCHAR(100) NOT NULL,
    degree_level VARCHAR(20) NOT NULL CHECK (degree_level IN ('BSc', 'MSc', 'PhD')),
    department_id INT NOT NULL,
    CONSTRAINT pk_programs PRIMARY KEY (program_id),
    CONSTRAINT fk_programs_departments FOREIGN KEY (department_id)
        REFERENCES Departments(department_id) ON DELETE CASCADE
);

CREATE TABLE Faculty (
    faculty_id INT GENERATED ALWAYS AS IDENTITY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    rank VARCHAR(30) CHECK (rank IN ('Lecturer', 'Assistant Professor', 'Associate Professor', 'Professor')),
    department_id INT NOT NULL,
    mentor_faculty_id INT NULL, 
    CONSTRAINT pk_faculty PRIMARY KEY (faculty_id),
    CONSTRAINT fk_faculty_departments FOREIGN KEY (department_id)
        REFERENCES Departments(department_id),
    CONSTRAINT fk_faculty_mentor FOREIGN KEY (mentor_faculty_id)
        REFERENCES Faculty(faculty_id) ON DELETE SET NULL,
    CONSTRAINT chk_self_mentoring CHECK (mentor_faculty_id <> faculty_id)
);


CREATE TABLE Students (
    student_id INT GENERATED ALWAYS AS IDENTITY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    enrollment_year INT NOT NULL CHECK (enrollment_year >= 2000),
    academic_status VARCHAR(20) DEFAULT 'Active' CHECK (academic_status IN ('Active', 'Graduated', 'Suspended', 'Withdrawn')),
    program_id INT NOT NULL,
    supervisor_faculty_id INT NULL,
    supervision_role VARCHAR(50) DEFAULT 'Primary Supervisor',
    supervision_start_date DATE DEFAULT CURRENT_DATE, 
    CONSTRAINT pk_students PRIMARY KEY (student_id),
    CONSTRAINT fk_students_programs FOREIGN KEY (program_id)
        REFERENCES Programs(program_id),
    CONSTRAINT fk_students_supervisor FOREIGN KEY (supervisor_faculty_id)
        REFERENCES Faculty(faculty_id) ON DELETE SET NULL
);


CREATE TABLE ResearchProjects (
    project_id INT GENERATED ALWAYS AS IDENTITY,
    title VARCHAR(200) NOT NULL,
    abstract TEXT,
    start_date DATE NOT NULL,
    end_date DATE,
    budget DECIMAL(12, 2) NOT NULL CHECK (budget >= 0),
    principal_investigator_id INT NOT NULL,
    CONSTRAINT pk_research_projects PRIMARY KEY (project_id),
    CONSTRAINT fk_projects_pi FOREIGN KEY (principal_investigator_id)
        REFERENCES Faculty(faculty_id),
    CONSTRAINT chk_project_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE FundingSources (
    funding_source_id INT GENERATED ALWAYS AS IDENTITY,
    source_name VARCHAR(100) NOT NULL UNIQUE,
    source_type VARCHAR(50) CHECK (source_type IN ('Government', 'Industry', 'Internal', 'Non-Profit')),
    CONSTRAINT pk_funding_sources PRIMARY KEY (funding_source_id)
);

CREATE TABLE ProjectFunding (
    project_id INT NOT NULL,
    funding_source_id INT NOT NULL,
    funding_amount DECIMAL(12, 2) NOT NULL CHECK (funding_amount > 0), 
    funding_date DATE NOT NULL DEFAULT CURRENT_DATE,                    
    grant_reference_number VARCHAR(100),
    CONSTRAINT pk_project_funding PRIMARY KEY (project_id, funding_source_id),
    CONSTRAINT fk_pf_project FOREIGN KEY (project_id)
        REFERENCES ResearchProjects(project_id) ON DELETE CASCADE,
    CONSTRAINT fk_pf_funding_source FOREIGN KEY (funding_source_id)
        REFERENCES FundingSources(funding_source_id) ON DELETE CASCADE
);


CREATE TABLE StudentProjectAssignments (
    student_id INT NOT NULL,
    project_id INT NOT NULL,
    student_project_role VARCHAR(50) NOT NULL,                 
    contribution_percentage DECIMAL(5, 2) NOT NULL CHECK (contribution_percentage > 0 AND contribution_percentage <= 100),
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_student_project PRIMARY KEY (student_id, project_id),
    CONSTRAINT fk_spa_student FOREIGN KEY (student_id)
        REFERENCES Students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_spa_project FOREIGN KEY (project_id)
        REFERENCES ResearchProjects(project_id) ON DELETE CASCADE
);


CREATE TABLE Equipment (
    equipment_id INT GENERATED ALWAYS AS IDENTITY,
    equipment_name VARCHAR(100) NOT NULL,
    model_number VARCHAR(50),
    lab_location VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'Operational' CHECK (status IN ('Operational', 'Under Maintenance', 'Decommissioned')),
    CONSTRAINT pk_equipment PRIMARY KEY (equipment_id)
);

CREATE TABLE EquipmentUsage (
    usage_id INT GENERATED ALWAYS AS IDENTITY,
    equipment_id INT NOT NULL,
    project_id INT NOT NULL,
    usage_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, 
    purpose TEXT NOT NULL,                                  
    hours_used DECIMAL(5, 2) CHECK (hours_used > 0),
    CONSTRAINT pk_equipment_usage PRIMARY KEY (usage_id),
    CONSTRAINT fk_eu_equipment FOREIGN KEY (equipment_id)
        REFERENCES Equipment(equipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_eu_project FOREIGN KEY (project_id)
        REFERENCES ResearchProjects(project_id) ON DELETE CASCADE
);



CREATE TABLE Publications (
    publication_id INT GENERATED ALWAYS AS IDENTITY,
    title VARCHAR(250) NOT NULL,
    publication_type VARCHAR(30) CHECK (publication_type IN ('Journal Article', 'Conference Paper', 'Book Chapter', 'Workshop')),
    publication_date DATE,
    doi VARCHAR(100) UNIQUE,
    project_id INT NULL,
    CONSTRAINT pk_publications PRIMARY KEY (publication_id),
    CONSTRAINT fk_publications_project FOREIGN KEY (project_id)
        REFERENCES ResearchProjects(project_id) ON DELETE SET NULL
);

CREATE TABLE PublicationAuthors (
    publication_id INT NOT NULL,
    faculty_id INT NOT NULL,
    author_order INT NOT NULL CHECK (author_order > 0),                   
    is_corresponding_author BOOLEAN NOT NULL DEFAULT FALSE,              
    CONSTRAINT pk_publication_authors PRIMARY KEY (publication_id, faculty_id),
    CONSTRAINT fk_pa_publication FOREIGN KEY (publication_id)
        REFERENCES Publications(publication_id) ON DELETE CASCADE,
    CONSTRAINT fk_pa_faculty FOREIGN KEY (faculty_id)
        REFERENCES Faculty(faculty_id) ON DELETE CASCADE,
    CONSTRAINT uq_publication_author_order UNIQUE (publication_id, author_order)
);


CREATE TABLE Conferences (
    conference_id INT GENERATED ALWAYS AS IDENTITY,
    conference_name VARCHAR(150) NOT NULL,
    acronym VARCHAR(20) NOT NULL,
    submission_deadline DATE NOT NULL,
    location VARCHAR(100),
    CONSTRAINT pk_conferences PRIMARY KEY (conference_id)
);

CREATE TABLE ConferenceSubmissions (
    submission_id INT GENERATED ALWAYS AS IDENTITY,
    publication_id INT NOT NULL,
    conference_id INT NOT NULL,
    submission_date DATE NOT NULL DEFAULT CURRENT_DATE,
    submission_status VARCHAR(30) DEFAULT 'Submitted' 
        CHECK (submission_status IN ('Submitted', 'Under Review', 'Accepted', 'Rejected', 'Revision Requested')),
    manuscript_file_path VARCHAR(255),
    CONSTRAINT pk_submissions PRIMARY KEY (submission_id),
    CONSTRAINT fk_sub_publication FOREIGN KEY (publication_id)
        REFERENCES Publications(publication_id) ON DELETE CASCADE,
    CONSTRAINT fk_sub_conference FOREIGN KEY (conference_id)
        REFERENCES Conferences(conference_id) ON DELETE CASCADE
);

CREATE TABLE PeerReviews (
    review_id INT GENERATED ALWAYS AS IDENTITY,
    submission_id INT NOT NULL,
    reviewer_faculty_id INT NOT NULL,
    review_score INT CHECK (review_score BETWEEN 1 AND 10), 
    comments TEXT,                                        
    review_date DATE DEFAULT CURRENT_DATE,
    CONSTRAINT pk_peer_reviews PRIMARY KEY (review_id),
    CONSTRAINT fk_pr_submission FOREIGN KEY (submission_id)
        REFERENCES ConferenceSubmissions(submission_id) ON DELETE CASCADE,
    CONSTRAINT fk_pr_reviewer FOREIGN KEY (reviewer_faculty_id)
        REFERENCES Faculty(faculty_id)
);

CREATE TABLE SubmissionRevisions (
    revision_id INT GENERATED ALWAYS AS IDENTITY,
    submission_id INT NOT NULL,
    revision_number INT NOT NULL CHECK (revision_number > 0), 
    revision_date DATE NOT NULL DEFAULT CURRENT_DATE,        
    response_to_reviewers TEXT,                               
    revised_file_path VARCHAR(255),
    CONSTRAINT pk_revisions PRIMARY KEY (revision_id),
    CONSTRAINT fk_rev_submission FOREIGN KEY (submission_id)
        REFERENCES ConferenceSubmissions(submission_id) ON DELETE CASCADE,
    CONSTRAINT uq_submission_revision UNIQUE (submission_id, revision_number)
);
