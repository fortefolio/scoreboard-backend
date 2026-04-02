-- Function to check if the max_teams limit has been reached
CREATE OR REPLACE FUNCTION public.check_tournament_participant_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_max_teams INT;
    v_current_teams INT;
BEGIN
    -- Get the max_teams setting for the tournament
    SELECT (settings->'stage_1'->>'max_teams')::int 
    INTO v_max_teams
    FROM public.tournaments
    WHERE id = NEW.tournament_id;

    -- If max_teams is NULL, there's no limit
    IF v_max_teams IS NULL THEN
        RETURN NEW;
    END IF;

    -- Count existing participants for this tournament
    SELECT COUNT(*) 
    INTO v_current_teams
    FROM public.tournament_participants
    WHERE tournament_id = NEW.tournament_id;

    -- If limit reached, raise an error
    IF v_current_teams >= v_max_teams THEN
        RAISE EXCEPTION 'This tournament has reached the maximum number of participants (%)', v_max_teams;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce the limit before insertion
CREATE TRIGGER tr_check_max_teams
BEFORE INSERT ON public.tournament_participants
FOR EACH ROW
EXECUTE FUNCTION public.check_tournament_participant_limit();
