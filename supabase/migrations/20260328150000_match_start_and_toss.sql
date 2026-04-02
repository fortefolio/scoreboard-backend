-- Add serving_index for sports with service rotation (like Tennis, Volleyball)
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS serving_index INTEGER;

-- RPC to start a match scoreboard
CREATE OR REPLACE FUNCTION public.start_match_scoreboard(
  m_id UUID, 
  initial_server_index INTEGER DEFAULT NULL
)
RETURNS void AS $$
DECLARE
    v_scores JSONB;
BEGIN
  SELECT scores INTO v_scores FROM public.matches WHERE id = m_id;
  
  IF initial_server_index IS NOT NULL THEN
    v_scores := jsonb_set(v_scores, '{serving_index}', initial_server_index::TEXT::jsonb);
  END IF;

  UPDATE public.matches
  SET 
    status = 'ongoing',
    scores = v_scores,
    updated_at = NOW()
  WHERE id = m_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the main trigger function to handle status and server metadata
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

    -- Handle meta-events (status changes, toss)
    IF NEW.event_data->>'type' = 'start_scoreboard' THEN
        UPDATE public.matches SET status = 'ongoing' WHERE id = NEW.match_id;
    END IF;

    IF NEW.event_data->>'type' = 'toss_coin' THEN
        UPDATE public.matches 
        SET serving_index = (NEW.event_data->>'winner_index')::INT 
        WHERE id = NEW.match_id;
    END IF;
    
    -- Handle scoring logic based on sport type
    CASE lower(v_sport_type)
        WHEN 'football', 'soccer' THEN
            IF NEW.event_data->>'type' = 'goal' THEN
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
            IF NEW.event_data->>'type' = 'point_won' THEN
                v_current_score := NEW.event_data->'current_match_score';
                -- Auto-rotate server if the event data indicates a game was won
                IF (NEW.event_data->>'game_won')::BOOLEAN = true THEN
                    UPDATE public.matches 
                    SET serving_index = (1 - serving_index)
                    WHERE id = NEW.match_id;
                END IF;
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
