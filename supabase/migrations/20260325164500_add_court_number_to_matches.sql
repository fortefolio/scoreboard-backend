-- Add court_number to matches for tournament court assignment
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS court_number INT;
