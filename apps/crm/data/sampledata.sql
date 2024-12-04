-- Insert data into Companies
INSERT INTO app_crm.companies (name, industry, size, address, operation_dates)
VALUES 
('Tech Innovations', 'Technology', 100, '123 Tech Lane', daterange('2020-01-01', '2022-12-31', '[]')),
('Green Solutions', 'Environmental', 50, '456 Green Blvd', daterange('2020-06-01', '2023-06-30', '[]')),
('Health Plus', 'Healthcare', 200, '789 Health St', daterange('2020-01-01', '2024-12-31', '[]')),
('EduFuture', 'Education', 150, '321 Education Rd', daterange('2021-01-01', '2025-06-30', '[]')),
('FinanceFirst', 'Finance', 120, '654 Finance Ave', daterange('2020-01-01', '2023-12-31', '[]')),
('RetailWorks', 'Retail', 80, '987 Retail Cir', daterange('2020-06-01', '2024-06-30', '[]')),
('FoodLovers', 'Food & Beverage', 60, '246 Food Way', daterange('2021-01-01', '2024-12-31', '[]')),
('TravelTime', 'Travel', 70, '135 Travel Route', daterange('2020-01-01', '2025-06-30', '[]')),
('MediaMagic', 'Media', 90, '864 Media Dr', daterange('2020-01-01', '2022-12-31', '[]')),
('AutoAdvance', 'Automotive', 110, '975 Auto Ln', daterange('2020-06-01', '2024-12-31', '[]'));

-- Insert data into Contacts
WITH inserted_companies AS (
  SELECT company_id FROM app_crm.companies
)
INSERT INTO app_crm.contacts (first_name, last_name, email, phone, company_id, address, position)
SELECT
  'FirstName' || gen, 'LastName' || gen, 'email' || gen || '@example.com', '123-456-789' || gen,
  (SELECT company_id FROM inserted_companies OFFSET floor(random()*10) LIMIT 1),
  'Address ' || gen, 'Position ' || gen
FROM generate_series(1,30) gen;

-- Insert data into Leads
WITH inserted_contacts AS (
  SELECT contact_id FROM app_crm.contacts
)
INSERT INTO app_crm.leads (contact_id, status, source, interest)
SELECT
  (SELECT contact_id FROM inserted_contacts OFFSET floor(random()*30) LIMIT 1),
  CASE WHEN random() > 0.5 THEN 'Open' ELSE 'Closed' END,
  CASE WHEN random() > 0.5 THEN 'Web' ELSE 'Referral' END,
  'Interest ' || gen
FROM generate_series(1,20) gen;

-- Insert data into Sales
WITH inserted_leads AS (
  SELECT lead_id FROM app_crm.leads
)
INSERT INTO app_crm.sales (lead_id, amount, sale_date, product_service)
SELECT
  (SELECT lead_id FROM inserted_leads OFFSET floor(random()*20) LIMIT 1),
  round(random()*10000 + 1000, 2),
  CURRENT_DATE - (gen || ' days')::interval,
  'Product/Service ' || gen
FROM generate_series(1,15) gen;

-- Insert data into Opportunities
WITH inserted_contacts AS (
  SELECT contact_id FROM app_crm.contacts
)
INSERT INTO app_crm.opportunities (description, contact_id, estimated_value, close_date, status)
SELECT
  'Opportunity ' || gen, 
  (SELECT contact_id FROM inserted_contacts OFFSET floor(random()*30) LIMIT 1),
  round(random()*20000 + 2000, 2),
  CURRENT_DATE + (gen || ' days')::interval,
  CASE WHEN random() > 0.5 THEN 'Open' ELSE 'Closed' END
FROM generate_series(1,10) gen;

-- Insert data into Tasks
INSERT INTO app_crm.tasks (description, due_date, status, assigned_to, priority)
SELECT
  'Task ' || gen, 
  CURRENT_DATE + (gen || ' days')::interval,
  CASE WHEN random() > 0.5 THEN 'Pending' ELSE 'Completed' END,
  'AssignedTo ' || gen,
  CASE WHEN random() > 0.5 THEN 'High' ELSE 'Low' END
FROM generate_series(1,25) gen;

-- Insert data into Activities
WITH inserted_contacts AS (
  SELECT contact_id FROM app_crm.contacts
)
INSERT INTO app_crm.activities (type, contact_id, date, notes)
SELECT
  CASE WHEN random() > 0.5 THEN 'Call' ELSE 'Meeting' END,
  (SELECT contact_id FROM inserted_contacts OFFSET floor(random()*30) LIMIT 1),
  CURRENT_DATE - (gen || ' days')::interval,
  'Notes for activity ' || gen
FROM generate_series(1,20) gen;


-- bucket data sync -- 
SELECT app_crm.insert_random_files_for_all_tasks();

----------------------------------------------
