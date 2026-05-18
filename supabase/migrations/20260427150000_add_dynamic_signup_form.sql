-- Migration: Add dynamic signup form support
-- Allows organizers to define custom fields and participants to provide responses.

BEGIN;

-- 1. Add columns for dynamic form configuration and responses
ALTER TABLE public.tournaments 
ADD COLUMN IF NOT EXISTS signup_form_config JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.tournament_participants 
ADD COLUMN IF NOT EXISTS form_responses JSONB DEFAULT '{}'::jsonb;

-- 2. Create validation function for dynamic form responses
CREATE OR REPLACE FUNCTION public.validate_participant_form_responses()
RETURNS TRIGGER AS $$
DECLARE
    v_config JSONB;
    v_field JSONB;
    v_field_id TEXT;
    v_required BOOLEAN;
BEGIN
    -- Get the form configuration from the associated tournament
    SELECT signup_form_config INTO v_config 
    FROM public.tournaments 
    WHERE id = NEW.tournament_id;

    -- If no config or empty array, skip validation
    IF v_config IS NULL OR jsonb_array_length(v_config) = 0 THEN
        RETURN NEW;
    END IF;

    -- Iterate through defined fields in the configuration
    FOR v_field IN SELECT * FROM jsonb_array_elements(v_config)
    LOOP
        v_field_id := v_field->>'id';
        v_required := (v_field->>'required')::BOOLEAN;

        -- Check if the field is required but missing or null in the responses
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

-- 3. Create trigger to enforce validation before insertion
CREATE TRIGGER tr_validate_participant_signup_form
BEFORE INSERT OR UPDATE ON public.tournament_participants
FOR EACH ROW
EXECUTE FUNCTION public.validate_participant_form_responses();

COMMIT;
