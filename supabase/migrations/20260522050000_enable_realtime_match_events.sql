-- Enable realtime publication and replica identity for match_events
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'match_events'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.match_events;
    END IF;
END $$;

ALTER TABLE public.match_events REPLICA IDENTITY FULL;
