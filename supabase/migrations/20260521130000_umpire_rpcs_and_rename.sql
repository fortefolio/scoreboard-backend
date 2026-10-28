-- Migration: Rename signup column and add Umpire RPCs
-- Renames signup_form_config to signup_schema for frontend compatibility.
-- Adds atomic RPCs for accepting/refusing umpire invitations.

BEGIN;

-- 1. Rename column for frontend compatibility
ALTER TABLE public.tournaments 
RENAME COLUMN signup_form_config TO signup_schema;

-- 2. Update the validation trigger to use the new name
CREATE OR REPLACE FUNCTION public.validate_participant_form_responses()
RETURNS TRIGGER AS $$
DECLARE
    v_config JSONB;
    v_field JSONB;
    v_field_id TEXT;
    v_required BOOLEAN;
BEGIN
    -- Get the form configuration (now named signup_schema)
    SELECT signup_schema INTO v_config 
    FROM public.tournaments 
    WHERE id = NEW.tournament_id;

    IF v_config IS NULL OR jsonb_array_length(v_config) = 0 THEN
        RETURN NEW;
    END IF;

    FOR v_field IN SELECT * FROM jsonb_array_elements(v_config)
    LOOP
        v_field_id := v_field->>'id';
        v_required := (v_field->>'required')::BOOLEAN;

        IF v_required AND (
            NEW.form_responses IS NULL OR 
            NOT (NEW.form_responses ? v_field_id) OR 
            NEW.form_responses->>v_field_id IS NULL OR 
            trim(NEW.form_responses->>v_field_id) = ''
        ) THEN
            RAISE EXCEPTION 'Missing required field: %', (v_field->>'label');
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- 3. Atomic RPC: Accept Umpire Invitation
CREATE OR REPLACE FUNCTION public.accept_umpire_invitation(p_match_id UUID, p_notification_id UUID)
RETURNS void AS $$
BEGIN
    -- Update Match Status
    UPDATE public.matches 
    SET umpire_invite_status = 'accepted'
    WHERE id = p_match_id AND umpire_id = (SELECT auth.uid());

    -- Mark Notification as Read
    UPDATE public.notifications
    SET read_at = NOW()
    WHERE id = p_notification_id AND user_id = (SELECT auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Atomic RPC: Refuse Umpire Invitation
CREATE OR REPLACE FUNCTION public.refuse_umpire_invitation(p_match_id UUID, p_notification_id UUID)
RETURNS void AS $$
BEGIN
    -- Update Match: Remove Umpire and set status
    UPDATE public.matches 
    SET umpire_invite_status = 'refused',
        umpire_id = NULL
    WHERE id = p_match_id AND umpire_id = (SELECT auth.uid());

    -- Mark Notification as Read
    UPDATE public.notifications
    SET read_at = NOW()
    WHERE id = p_notification_id AND user_id = (SELECT auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 5. Grant permissions for RPCs
GRANT EXECUTE ON FUNCTION public.accept_umpire_invitation(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refuse_umpire_invitation(UUID, UUID) TO authenticated;

COMMIT;
