-- THIS IS DUMMY FUNCTION
CREATE OR REPLACE FUNCTION app_crm.add_opportunity(
)
RETURNS void AS $$
BEGIN
    INSERT INTO app_crm.opportunities (
        description,
        contact_id,
        estimated_value,
        close_date,
        status
    ) VALUES (
        'test',
        1,
        1,
        '2024-07-11',
        'test'
    );
END;
$$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION copy_task(task_id INT) RETURNS VOID AS $$
-- DECLARE
--     v_description TEXT;
--     v_due_date DATE;
--     v_status VARCHAR(50);
--     v_assigned_to VARCHAR(255);
--     v_priority VARCHAR(50);
--     new_task_id INT;
-- BEGIN
--     -- Select the row with the given task_id
--     SELECT description, due_date, status, assigned_to, priority
--     INTO v_description, v_due_date, v_status, v_assigned_to, v_priority
--     FROM app_crm.tasks
--     WHERE task_id = task_id;

--     -- Insert the selected row as a new row
--     INSERT INTO app_crm.tasks (description, due_date, status, assigned_to, priority)
--     VALUES (v_description, v_due_date, v_status, v_assigned_to, v_priority);

    
-- END;
-- $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION app_crm.copy_contact(contact_id INT) RETURNS VOID AS $$
DECLARE
    _contact_id ALIAS FOR $1;
BEGIN
    -- Insert a copy of the row with the given contact_id
    INSERT INTO app_crm.contacts (first_name, last_name, email, phone, company_id, address, position)
    SELECT first_name, last_name, email, phone, company_id, address, position
    FROM app_crm.contacts
    WHERE app_crm.contacts.contact_id = _contact_id;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION app_crm.add_opportunity(), app_crm.copy_contact(INT) TO "user";

NOTIFY pgrst, 'reload schema';