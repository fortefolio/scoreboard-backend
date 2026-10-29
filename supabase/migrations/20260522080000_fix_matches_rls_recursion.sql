-- Migration: Fix infinite recursion detected in policy for relation "matches"
-- The previous policy "Accepted umpires can update matches" contained a subquery:
--   organizer_id = (SELECT m.organizer_id FROM public.matches m WHERE m.id = matches.id)
-- within WITH CHECK, which caused cyclic RLS evaluation during any UPDATE on matches.
-- We fix this by removing the subquery from the RLS policy and instead enforcing organizer_id immutability
-- via a BEFORE UPDATE trigger.

DROP POLICY IF EXISTS "Accepted umpires can update matches" ON public.matches;

CREATE POLICY "Accepted umpires can update matches"
ON public.matches FOR UPDATE
USING (
  umpire_id = (SELECT auth.uid()) 
  AND umpire_invite_status = 'accepted'
)
WITH CHECK (
  umpire_id = (SELECT auth.uid()) 
  AND umpire_invite_status = 'accepted'
);

-- Trigger to protect organizer_id from being altered by non-organizers
CREATE OR REPLACE FUNCTION public.check_match_organizer_immutable()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.organizer_id IS DISTINCT FROM OLD.organizer_id THEN
    IF auth.uid() IS NULL OR auth.uid() != OLD.organizer_id THEN
      RAISE EXCEPTION 'Only the match organizer can change the organizer_id';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_check_match_organizer_immutable ON public.matches;
CREATE TRIGGER tr_check_match_organizer_immutable
BEFORE UPDATE OF organizer_id ON public.matches
FOR EACH ROW
EXECUTE FUNCTION public.check_match_organizer_immutable();
