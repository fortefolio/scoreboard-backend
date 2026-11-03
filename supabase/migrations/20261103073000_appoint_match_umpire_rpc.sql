-- Migration: 20261103073000_appoint_match_umpire_rpc.sql
-- Description: Adds secure RPC to appoint, change, or unassign match umpires/referees.

CREATE OR REPLACE FUNCTION public.appoint_match_umpire(
  p_match_id UUID,
  p_new_umpire_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_caller_id UUID;
  v_match RECORD;
  v_is_organizer BOOLEAN;
  v_is_current_umpire BOOLEAN;
  v_umpire_user RECORD;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to appoint referee.';
  END IF;

  SELECT m.id, m.organizer_id, m.umpire_id, m.tournament_id, t.organizer_id AS tourney_org_id, m.status
  INTO v_match
  FROM public.matches m
  LEFT JOIN public.tournaments t ON t.id = m.tournament_id
  WHERE m.id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found.';
  END IF;

  v_is_organizer := (v_caller_id = v_match.organizer_id OR (v_match.tourney_org_id IS NOT NULL AND v_caller_id = v_match.tourney_org_id));
  v_is_current_umpire := (v_caller_id = v_match.umpire_id);

  -- Only organizers can appoint someone else. An umpire can only step down (p_new_umpire_id IS NULL).
  IF NOT v_is_organizer THEN
    IF v_is_current_umpire AND p_new_umpire_id IS NULL THEN
      -- Allowed: umpire stepping down
      NULL;
    ELSE
      RAISE EXCEPTION 'Only the match or tournament organizer can change the referee.';
    END IF;
  END IF;

  -- Verify new umpire user exists if provided
  IF p_new_umpire_id IS NOT NULL THEN
    SELECT id, username, email INTO v_umpire_user
    FROM public.users
    WHERE id = p_new_umpire_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Selected user does not exist.';
    END IF;
  END IF;

  -- Update the match
  UPDATE public.matches
  SET umpire_id = p_new_umpire_id,
      umpire_invite_status = CASE 
        WHEN p_new_umpire_id IS NULL THEN 'pending'::umpire_status
        WHEN p_new_umpire_id = v_caller_id THEN 'accepted'::umpire_status
        ELSE 'pending'::umpire_status
      END,
      updated_at = NOW()
  WHERE id = p_match_id;

  RETURN jsonb_build_object(
    'success', true,
    'match_id', p_match_id,
    'umpire_id', p_new_umpire_id,
    'umpire_username', v_umpire_user.username
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.appoint_match_umpire(UUID, UUID) TO authenticated;
