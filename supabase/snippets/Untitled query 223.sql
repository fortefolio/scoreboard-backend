SELECT 
    trigger_name, 
    event_manipulation AS triggers_on, 
    event_object_table AS table_name
FROM information_schema.triggers

SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';

SELECT tablename, policyname, cmd AS command_type
FROM pg_policies 
WHERE schemaname = 'public';

SELECT viewname 
FROM pg_views 
WHERE schemaname = 'public';

UPDATE tournaments 
SET status = 'scheduled' 
WHERE id = '97e1fd48-226a-47ac-a3f9-0711225aee33';

SELECT enumlabel 
FROM pg_enum 
JOIN pg_type ON pg_enum.enumtypid = pg_type.oid 
WHERE pg_type.typname = 'tournament_status';

UPDATE tournaments 
SET status = 'ongoing' 
WHERE id = '97e1fd48-226a-47ac-a3f9-0711225aee33';

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'matches';