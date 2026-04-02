-- Add name and contact_email columns to tournament_participants for signups
-- Remove team_id as we are using 'name' for identifying participants/teams in this prototype
ALTER TABLE public.tournament_participants 
ADD COLUMN IF NOT EXISTS name TEXT,
ADD COLUMN IF NOT EXISTS contact_email TEXT,
DROP COLUMN IF EXISTS team_id;
