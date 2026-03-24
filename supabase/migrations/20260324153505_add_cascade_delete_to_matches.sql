-- Remove the old restricted foreign key
ALTER TABLE public.matches 
DROP CONSTRAINT IF EXISTS matches_tournament_id_fkey;

-- Add the new cascading foreign key
ALTER TABLE public.matches 
ADD CONSTRAINT matches_tournament_id_fkey 
  FOREIGN KEY (tournament_id) 
  REFERENCES public.tournaments(id) 
  ON DELETE CASCADE;