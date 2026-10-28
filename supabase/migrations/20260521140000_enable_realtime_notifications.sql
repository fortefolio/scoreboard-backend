-- Migration: Enable Real-time for Notifications
-- This allows the frontend to listen for new notifications and update live.

BEGIN;

-- 1. Ensure the supabase_realtime publication exists (redundant but safe)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

-- 2. Add the notifications table to the publication
-- This triggers broadcast events whenever a new notification is inserted
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

COMMIT;
