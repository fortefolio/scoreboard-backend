-- Function to update match score based on event
CREATE OR REPLACE FUNCTION public.update_match_score()
RETURNS TRIGGER AS $$
DECLARE
    v_sport_type TEXT;
    v_current_score JSONB;
    v_team_id UUID;
    v_points INT;
BEGIN
    -- Get the sport type and current score from the matches table
    SELECT sport_type, current_score 
    INTO v_sport_type, v_current_score
    FROM public.matches
    WHERE id = NEW.match_id;

    -- Initialize current_score if empty
    IF v_current_score = '{}'::jsonb THEN
        v_current_score := '{"home": 0, "away": 0}'::jsonb;
    END IF;

    -- Extract common data from event_data
    v_team_id := (NEW.event_data->>'team_id')::UUID;
    
    -- Handle scoring logic based on sport type
    CASE lower(v_sport_type)
        WHEN 'football', 'soccer' THEN
            IF NEW.event_data->>'type' = 'goal' THEN
                -- Assume event_data contains 'side' ('home' or 'away')
                IF NEW.event_data->>'side' = 'home' THEN
                    v_current_score := jsonb_set(v_current_score, '{home}', 
                        ((v_current_score->>'home')::INT + 1)::TEXT::jsonb);
                ELSIF NEW.event_data->>'side' = 'away' THEN
                    v_current_score := jsonb_set(v_current_score, '{away}', 
                        ((v_current_score->>'away')::INT + 1)::TEXT::jsonb);
                END IF;
            END IF;

        WHEN 'basketball' THEN
            IF NEW.event_data->>'type' = 'score' THEN
                v_points := (NEW.event_data->>'points')::INT;
                IF NEW.event_data->>'side' = 'home' THEN
                    v_current_score := jsonb_set(v_current_score, '{home}', 
                        ((v_current_score->>'home')::INT + v_points)::TEXT::jsonb);
                ELSIF NEW.event_data->>'side' = 'away' THEN
                    v_current_score := jsonb_set(v_current_score, '{away}', 
                        ((v_current_score->>'away')::INT + v_points)::TEXT::jsonb);
                END IF;
            END IF;

        WHEN 'tennis' THEN
            -- Tennis scoring is complex (Sets, Games, Points). 
            -- For this prototype, we store the full context provided in event_data
            IF NEW.event_data->>'type' = 'point_won' THEN
                v_current_score := NEW.event_data->'current_match_score';
            END IF;

        WHEN 'volleyball', 'beach_volleyball' THEN
            IF NEW.event_data->>'type' = 'point_scored' THEN
                IF NEW.event_data->>'side' = 'home' THEN
                    v_current_score := jsonb_set(v_current_score, '{home}', 
                        ((v_current_score->>'home')::INT + 1)::TEXT::jsonb);
                ELSIF NEW.event_data->>'side' = 'away' THEN
                    v_current_score := jsonb_set(v_current_score, '{away}', 
                        ((v_current_score->>'away')::INT + 1)::TEXT::jsonb);
                END IF;
            END IF;
            
        ELSE
            -- Generic handler for simple increment if not specified
            IF NEW.event_data->>'type' = 'increment_score' THEN
                IF NEW.event_data->>'side' = 'home' THEN
                    v_current_score := jsonb_set(v_current_score, '{home}', 
                        ((v_current_score->>'home')::INT + 1)::TEXT::jsonb);
                ELSIF NEW.event_data->>'side' = 'away' THEN
                    v_current_score := jsonb_set(v_current_score, '{away}', 
                        ((v_current_score->>'away')::INT + 1)::TEXT::jsonb);
                END IF;
            END IF;
    END CASE;

    -- Update the match with the new score
    UPDATE public.matches
    SET current_score = v_current_score,
        updated_at = NOW()
    WHERE id = NEW.match_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to execute after a new event is inserted
CREATE TRIGGER tr_update_match_score
AFTER INSERT ON public.match_events
FOR EACH ROW
EXECUTE FUNCTION public.update_match_score();
