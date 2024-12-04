DROP SCHEMA IF EXISTS app_crm CASCADE;
CREATE SCHEMA app_crm;

NOTIFY pgrst, 'reload config';
NOTIFY pgrst, 'reload schema';

-- Tags Table
CREATE TABLE app_crm.tags (
    tag_id SERIAL PRIMARY KEY,
    label TEXT NOT NULL, 
    color TEXT 
);
COMMENT ON COLUMN app_crm.tags.label IS 'REQ_ON_CREATE DISPLAY_FIELD';

-- Companies Table
CREATE TABLE app_crm.companies (
    company_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    industry VARCHAR(255),
    size INT,
    address TEXT,
    operation_dates DATERANGE,
    tags INT[]
);
COMMENT ON COLUMN app_crm.companies.name IS 'REQ_ON_CREATE DISPLAY_FIELD';
COMMENT ON COLUMN app_crm.companies.industry IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.companies.size IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.companies.address IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.companies.tags IS 'TAG=tags.tag_id';

-- Contacts Table
CREATE TABLE app_crm.contacts (
    contact_id SERIAL PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    company_id INT,
    address TEXT,
    position VARCHAR(255),
    FOREIGN KEY (company_id) REFERENCES app_crm.companies(company_id)
);
COMMENT ON COLUMN app_crm.contacts.first_name IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.contacts.last_name IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.contacts.email IS 'REQ_ON_CREATE DISPLAY_FIELD';
COMMENT ON COLUMN app_crm.contacts.phone IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.contacts.company_id IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.contacts.position IS 'REQ_ON_CREATE';


-- Leads Table
CREATE TABLE app_crm.leads (
    lead_id SERIAL PRIMARY KEY,
    contact_id INT,
    status VARCHAR(50),
    source VARCHAR(255),
    interest VARCHAR(255),
    FOREIGN KEY (contact_id) REFERENCES app_crm.contacts(contact_id)
);
COMMENT ON COLUMN app_crm.leads.contact_id IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.leads.status IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.leads.source IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.leads.interest IS 'REQ_ON_CREATE DISPLAY_FIELD';


-- Sales Table
CREATE TABLE app_crm.sales (
    sale_id SERIAL PRIMARY KEY,
    lead_id INT,
    amount MONEY,
    sale_date DATE,
    product_service VARCHAR(255),
    contracts UUID DEFAULT uuid_generate_v4(), 
    FOREIGN KEY (lead_id) REFERENCES app_crm.leads(lead_id)
);
COMMENT ON COLUMN app_crm.sales.lead_id IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.sales.amount IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.sales.sale_date IS 'REQ_ON_CREATE DISPLAY_FIELD';
COMMENT ON COLUMN app_crm.sales.product_service IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.sales.contracts IS 'MANAGED_FILES';


-- Opportunities Table
CREATE TABLE app_crm.opportunities (
    opportunity_id SERIAL PRIMARY KEY,
    description TEXT,
    contact_id INT,
    estimated_value MONEY,
    close_date DATE,
    status VARCHAR(50),
    FOREIGN KEY (contact_id) REFERENCES app_crm.contacts(contact_id)
);
COMMENT ON COLUMN app_crm.opportunities.description IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.opportunities.contact_id IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.opportunities.estimated_value IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.opportunities.close_date IS 'REQ_ON_CREATE DISPLAY_FIELD';
COMMENT ON COLUMN app_crm.opportunities.status IS 'REQ_ON_CREATE';


-- Tasks Table
CREATE TABLE app_crm.tasks (
    task_id SERIAL PRIMARY KEY,
    description TEXT,
    due_date DATE,
    status VARCHAR(50),
    assigned_to VARCHAR(255),
    priority VARCHAR(50),
    email_attachment UUID DEFAULT uuid_generate_v4(),
    scanned_quote_paper UUID DEFAULT uuid_generate_v4()
    -- Optional: If tasks are related to contacts or leads, you can add a foreign key here.
);
COMMENT ON COLUMN app_crm.tasks.description IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.tasks.due_date IS 'REQ_ON_CREATE DISPLAY_FIELD';
COMMENT ON COLUMN app_crm.tasks.status IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.tasks.assigned_to IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.tasks.priority IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.tasks.email_attachment IS 'MANAGED_FILES';
COMMENT ON COLUMN app_crm.tasks.scanned_quote_paper IS 'MANAGED_FILES';


CREATE OR REPLACE FUNCTION app_crm.email_attachment_files(app_crm.tasks)
    RETURNS SETOF filemanager.files AS
$$
BEGIN
    RETURN QUERY
        SELECT *
        FROM meta.groupfiles($1.email_attachment);
END;
$$ LANGUAGE plpgsql STABLE;


CREATE OR REPLACE FUNCTION app_crm.scanned_quote_paper_files(app_crm.tasks)
    RETURNS SETOF filemanager.files AS
$$
BEGIN
    RETURN QUERY
        SELECT *
        FROM meta.groupfiles($1.scanned_quote_paper);
END;
$$ LANGUAGE plpgsql STABLE;


-- Activities Table
CREATE TABLE app_crm.activities (
    activity_id SERIAL PRIMARY KEY,
    type VARCHAR(50),
    contact_id INT,
    date DATE,
    notes TEXT,
    FOREIGN KEY (contact_id) REFERENCES app_crm.contacts(contact_id)
    -- Optional: If activities are related to leads or opportunities, you can add a foreign key here.
);
COMMENT ON COLUMN app_crm.activities.type IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.activities.contact_id IS 'REQ_ON_CREATE';
COMMENT ON COLUMN app_crm.activities.date IS 'REQ_ON_CREATE DISPLAY_FIELD';
COMMENT ON COLUMN app_crm.activities.notes IS 'REQ_ON_CREATE';

CREATE TABLE IF NOT EXISTS app_crm.tasks_comments (
    comment_id SERIAL PRIMARY KEY,
    task_id INT,
    body TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    username TEXT,
    FOREIGN KEY (task_id) REFERENCES app_crm.tasks(task_id) ON DELETE CASCADE,
    FOREIGN KEY (username) REFERENCES authentication.users(email) ON DELETE CASCADE
);

COMMENT ON TABLE app_crm.tasks_comments IS 'COMMENTS_TABLE';

-----------------------------------------
-------- RANDOM DATA GENERATION ---------
-----------------------------------------

CREATE OR REPLACE FUNCTION app_crm.insert_random_files_for_all_tasks()
RETURNS VOID AS $$
DECLARE
    task RECORD;
    v_email_attachment_uuid UUID;
    v_scanned_quote_paper_uuid UUID;
    v_email_group_id INT;
    v_quote_group_id INT;
    v_bucket_id INT;
    v_type_id_email INT;
    v_type_id_quote INT;
    v_num_files_email INT;
    v_num_files_quote INT;
BEGIN
    -- Ensure the bucket exists
    SELECT filemanager.buckets.id INTO v_bucket_id 
    FROM filemanager.buckets 
    WHERE filemanager.buckets.schema_name = 'app_crm';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bucket for schema "app_crm" not found';
    END IF;

    -- Ensure the type exists for email_attachment
    SELECT filemanager.types.id INTO v_type_id_email 
    FROM filemanager.types 
    WHERE filemanager.types.bucket_id = v_bucket_id 
      AND filemanager.types.table_name = 'tasks' 
      AND filemanager.types.column_name = 'email_attachment';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Type for email_attachment not found';
    END IF;

    -- Ensure the type exists for scanned_quote_paper
    SELECT filemanager.types.id INTO v_type_id_quote 
    FROM filemanager.types 
    WHERE filemanager.types.bucket_id = v_bucket_id 
      AND filemanager.types.table_name = 'tasks' 
      AND filemanager.types.column_name = 'scanned_quote_paper';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Type for scanned_quote_paper not found';
    END IF;

    -- Loop through all tasks in the app_crm.tasks table
    FOR task IN SELECT task_id, email_attachment, scanned_quote_paper FROM app_crm.tasks LOOP
        v_email_attachment_uuid := task.email_attachment;
        v_scanned_quote_paper_uuid := task.scanned_quote_paper;

        -- Ensure the group exists for email_attachment, create if not
        SELECT filemanager.groups.id INTO v_email_group_id 
        FROM filemanager.groups 
        WHERE filemanager.groups.type_id = v_type_id_email 
          AND filemanager.groups.group_uuid = v_email_attachment_uuid;
        
        IF NOT FOUND THEN
            INSERT INTO filemanager.groups (type_id, group_uuid)
            VALUES (v_type_id_email, v_email_attachment_uuid)
            RETURNING id INTO v_email_group_id;
        END IF;

        -- Ensure the group exists for scanned_quote_paper, create if not
        SELECT filemanager.groups.id INTO v_quote_group_id 
        FROM filemanager.groups 
        WHERE filemanager.groups.type_id = v_type_id_quote 
          AND filemanager.groups.group_uuid = v_scanned_quote_paper_uuid;
        
        IF NOT FOUND THEN
            INSERT INTO filemanager.groups (type_id, group_uuid)
            VALUES (v_type_id_quote, v_scanned_quote_paper_uuid)
            RETURNING id INTO v_quote_group_id;
        END IF;

        -- Randomize the number of files to insert (between 0 and 5)
        v_num_files_email := floor(random() * 6);
        v_num_files_quote := floor(random() * 6);

        -- Insert random files for email_attachment
        FOR i IN 1..v_num_files_email LOOP
            INSERT INTO filemanager.files (filename, file_type, file_size, minio_url, group_id)
            VALUES (
                'email_file_' || i || '.pdf',
                'pdf',
                floor(random() * 10000 + 1000), -- Random file size between 1000 and 11000
                'https://minio.example.com/app_crm/email_file_' || i || '.pdf',
                v_email_group_id
            );
        END LOOP;

        -- Insert random files for scanned_quote_paper
        FOR i IN 1..v_num_files_quote LOOP
            INSERT INTO filemanager.files (filename, file_type, file_size, minio_url, group_id)
            VALUES (
                'quote_file_' || i || '.pdf',
                'pdf',
                floor(random() * 10000 + 1000), -- Random file size between 1000 and 11000
                'https://minio.example.com/app_crm/quote_file_' || i || '.pdf',
                v_quote_group_id
            );
        END LOOP;

    END LOOP;

END;
$$ LANGUAGE plpgsql;


-----------------------------------------
------------- PERMISSIONS ---------------
-----------------------------------------
GRANT USAGE ON SCHEMA app_crm TO "user";
GRANT ALL ON 
    app_crm.companies, 
    app_crm.contacts, 
    app_crm.leads, 
    app_crm.sales, 
    app_crm.opportunities, 
    app_crm.tasks, 
    app_crm.activities,
    app_crm.tags,
    app_crm.tasks_comments
TO "user";


GRANT EXECUTE ON FUNCTION 
    app_crm.insert_random_files_for_all_tasks(),
    app_crm.email_attachment_files(tasks),
    app_crm.scanned_quote_paper_files(tasks)
TO "user";

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app_crm TO "user";

NOTIFY pgrst, 'reload config';
NOTIFY pgrst, 'reload schema';

