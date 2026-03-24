-- 1. Add the umpire_id column to the matches table
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS umpire_id UUID REFERENCES auth.users(id);

-- 2. Ensure RLS is enabled
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

-- 3. Drop existing policies to avoid "already exists" errors during migration
DROP POLICY IF EXISTS "Public can view matches" ON public.matches;
DROP POLICY IF EXISTS "Admins and Umpires can update matches" ON public.matches;

-- 4. Create the 'View' Policy (Read-only for everyone)
CREATE POLICY "Public can view matches" 
ON public.matches FOR SELECT 
USING (true);

-- 5. Create the 'Update' Policy (Write access for Organizer OR Umpire)
-- This policy checks the ID of the logged-in user against the table columns
CREATE POLICY "Admins and Umpires can update matches" 
ON public.matches FOR UPDATE 
TO authenticated
USING (
  auth.uid() = organizer_id OR 
  auth.uid() = umpire_id
)
WITH CHECK (
  auth.uid() = organizer_id OR 
  auth.uid() = umpire_id
);