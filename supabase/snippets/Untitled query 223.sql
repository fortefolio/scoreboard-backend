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