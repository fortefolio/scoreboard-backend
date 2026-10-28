-- 1. Add the umpire_id column to the matches table
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS umpire_id UUID REFERENCES auth.users(id);

-- 2. Ensure RLS is enabled
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;