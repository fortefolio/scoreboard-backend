-- Function to set umpire_id to organizer_id if not provided
CREATE OR REPLACE FUNCTION public.handle_match_umpire_default()
RETURNS trigger AS $$
BEGIN
  -- Only set default umpire for standalone matches (not part of a tournament)
  IF NEW.tournament_id IS NULL AND NEW.umpire_id IS NULL THEN
    NEW.umpire_id := NEW.organizer_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function before insert
CREATE TRIGGER on_match_inserted_set_umpire
  BEFORE INSERT ON public.matches
  FOR EACH ROW EXECUTE PROCEDURE public.handle_match_umpire_default();
