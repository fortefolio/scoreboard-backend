-- Migration: Enhance Umpire Invitation Flow
-- Adds umpire_invite_status to matches and updates the notification trigger with rich data.

BEGIN;

-- 1. Create the umpire status enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'umpire_status') THEN
        CREATE TYPE umpire_status AS ENUM ('pending', 'accepted', 'refused');
    END IF;
END $$;

-- 2. Add the status column to matches
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS umpire_invite_status umpire_status DEFAULT 'pending' NOT NULL;

-- 3. Update the notification trigger function
CREATE OR REPLACE FUNCTION public.handle_umpire_invitation()
RETURNS TRIGGER AS $$
DECLARE
    v_team1_name TEXT;
    v_team2_name TEXT;
    v_tournament_name TEXT := 'Standalone Match';
BEGIN
    -- Only notify if umpire_id is newly assigned or changed
    IF (TG_OP = 'INSERT' AND NEW.umpire_id IS NOT NULL) OR 
       (TG_OP = 'UPDATE' AND NEW.umpire_id IS NOT NULL AND (OLD.umpire_id IS NULL OR OLD.umpire_id <> NEW.umpire_id)) THEN
        
        -- Parse team names from participants JSONB
        -- Structure: [{"name": "Team A", ...}, {"name": "Team B", ...}]
        v_team1_name := COALESCE(NEW.participants->0->>'name', 'Team 1');
        v_team2_name := COALESCE(NEW.participants->1->>'name', 'Team 2');

        -- Fetch tournament name if applicable
        IF NEW.tournament_id IS NOT NULL THEN
            SELECT name INTO v_tournament_name 
            FROM public.tournaments 
            WHERE id = NEW.tournament_id;
        END IF;

        -- Reset status to pending on new invitation
        NEW.umpire_invite_status := 'pending';

        -- Insert rich notification
        INSERT INTO public.notifications (user_id, title, body, data)
        VALUES (
            NEW.umpire_id,
            'New Umpire Invitation',
            'You have been invited to score: ' || v_team1_name || ' vs ' || v_team2_name,
            jsonb_build_object(
                'type', 'umpire_invitation',
                'match_id', NEW.id,
                'link', '/match/' || NEW.id,
                'match_details', jsonb_build_object(
                    'teams', v_team1_name || ' vs ' || v_team2_name,
                    'tournament', v_tournament_name,
                    'scheduled_at', NEW.scheduled_at
                )
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMIT;
