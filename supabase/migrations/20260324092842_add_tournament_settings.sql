ALTER TABLE public.tournaments 
ADD COLUMN settings JSONB DEFAULT '{}'::jsonb;