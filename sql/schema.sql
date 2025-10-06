-- sql/schema.sql
-- Azure SQL schema for Dementia app

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dementia_app')
    EXEC('CREATE SCHEMA dementia_app');
GO

IF OBJECT_ID('dementia_app.families', 'U') IS NOT NULL DROP TABLE dementia_app.families;
CREATE TABLE dementia_app.families (
    family_id       INT IDENTITY(1,1) PRIMARY KEY,
    family_name     NVARCHAR(200) NOT NULL,
    notes           NVARCHAR(1000) NULL,
    created_at      DATETIME2(3) NOT NULL CONSTRAINT DF_families_created_at DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2(3) NOT NULL CONSTRAINT DF_families_updated_at DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('dementia_app.patients', 'U') IS NOT NULL DROP TABLE dementia_app.patients;
CREATE TABLE dementia_app.patients (
    patient_id      INT IDENTITY(1,1) PRIMARY KEY,
    family_id       INT NOT NULL FOREIGN KEY REFERENCES dementia_app.families(family_id),
    first_name      NVARCHAR(100) NOT NULL,
    last_name       NVARCHAR(100) NOT NULL,
    date_of_birth   DATE NULL,
    notes           NVARCHAR(1000) NULL,
    created_at      DATETIME2(3) NOT NULL CONSTRAINT DF_patients_created_at DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2(3) NOT NULL CONSTRAINT DF_patients_updated_at DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('dementia_app.contacts', 'U') IS NOT NULL DROP TABLE dementia_app.contacts;
CREATE TABLE dementia_app.contacts (
    contact_id      INT IDENTITY(1,1) PRIMARY KEY,
    family_id       INT NOT NULL FOREIGN KEY REFERENCES dementia_app.families(family_id),
    patient_id      INT NULL FOREIGN KEY REFERENCES dementia_app.patients(patient_id),
    relationship    NVARCHAR(50) NULL,
    display_name    NVARCHAR(200) NOT NULL,
    email           NVARCHAR(256) NULL,
    phone           NVARCHAR(50) NULL,
    created_at      DATETIME2(3) NOT NULL CONSTRAINT DF_contacts_created_at DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2(3) NOT NULL CONSTRAINT DF_contacts_updated_at DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('dementia_app.memories', 'U') IS NOT NULL DROP TABLE dementia_app.memories;
CREATE TABLE dementia_app.memories (
    memory_id       INT IDENTITY(1,1) PRIMARY KEY,
    patient_id      INT NOT NULL FOREIGN KEY REFERENCES dementia_app.patients(patient_id),
    memory_type     VARCHAR(20) NOT NULL CHECK (memory_type IN ('text','image','audio','video')),
    title           NVARCHAR(200) NULL,
    content_text    NVARCHAR(MAX) NULL,
    media_url       NVARCHAR(1000) NULL,
    tags            NVARCHAR(300) NULL,
    created_at      DATETIME2(3) NOT NULL CONSTRAINT DF_memories_created_at DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2(3) NOT NULL CONSTRAINT DF_memories_updated_at DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('dementia_app.agenda', 'U') IS NOT NULL DROP TABLE dementia_app.agenda;
CREATE TABLE dementia_app.agenda (
    agenda_id       INT IDENTITY(1,1) PRIMARY KEY,
    patient_id      INT NOT NULL FOREIGN KEY REFERENCES dementia_app.patients(patient_id),
    title           NVARCHAR(200) NOT NULL,
    details         NVARCHAR(1000) NULL,
    start_time_utc  DATETIME2(0) NOT NULL,
    end_time_utc    DATETIME2(0) NULL,
    created_at      DATETIME2(3) NOT NULL CONSTRAINT DF_agenda_created_at DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2(3) NOT NULL CONSTRAINT DF_agenda_updated_at DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('dementia_app.reminders', 'U') IS NOT NULL DROP TABLE dementia_app.reminders;
CREATE TABLE dementia_app.reminders (
    reminder_id     INT IDENTITY(1,1) PRIMARY KEY,
    patient_id      INT NOT NULL FOREIGN KEY REFERENCES dementia_app.patients(patient_id),
    title           NVARCHAR(200) NOT NULL,
    message         NVARCHAR(1000) NULL,
    remind_at_utc   DATETIME2(0) NOT NULL,
    created_at      DATETIME2(3) NOT NULL CONSTRAINT DF_reminders_created_at DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2(3) NOT NULL CONSTRAINT DF_reminders_updated_at DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_patients_family ON dementia_app.patients(family_id);
CREATE INDEX IX_contacts_family ON dementia_app.contacts(family_id);
CREATE INDEX IX_contacts_patient ON dementia_app.contacts(patient_id);
CREATE INDEX IX_memories_patient ON dementia_app.memories(patient_id);
CREATE INDEX IX_agenda_patient ON dementia_app.agenda(patient_id);
CREATE INDEX IX_reminders_patient ON dementia_app.reminders(patient_id);
GO
