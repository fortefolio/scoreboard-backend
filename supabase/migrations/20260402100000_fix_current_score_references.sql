-- 1. Fix the notification trigger to use the new unified 'scores' column
CREATE OR REPLACE FUNCTION public.handle_match_completion_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Only notify when status changes to 'completed'
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status <> 'completed') THEN
        
        -- Insert notifications for all followers of participants or the competition
        INSERT INTO public.notifications (user_id, title, body, data)
        SELECT 
            f.user_id,
            'Match Completed!',
            NEW.sport_type || ' match finished.', -- Simplified to avoid dependency on exact score structure
            jsonb_build_object(
                'match_id', NEW.id,
                'tournament_id', NEW.tournament_id,
                'type', 'match_completed',
                'link', '/matches/' || NEW.id,
                'final_sets', NEW.scores->'final_sets' -- Include the final set scores if they exist
            )
        FROM public.follows f
        WHERE 
            -- Following a participant (team/player) in the match
            (f.entity_type IN ('team', 'player') AND NEW.participants @> jsonb_build_array(jsonb_build_object('id', f.entity_id)))
            OR
            -- Following the competition (tournament)
            (f.entity_type = 'competition' AND NEW.tournament_id = f.entity_id);
            
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Fix the user_feed view to use the new 'scores' column
CREATE OR REPLACE VIEW public.user_feed AS
-- 1. Completed Matches for followed teams, players, or tournaments
SELECT 
    f.user_id,
    m.id AS activity_id,
    'match' AS activity_type,
    m.sport_type,
    m.status::TEXT,
    m.scores AS activity_data, -- Changed from current_score to scores
    m.updated_at AS activity_timestamp
FROM public.follows f
JOIN public.matches m ON (
    -- If following a team/player involved in the match
    (f.entity_type IN ('team', 'player') AND m.participants @> jsonb_build_array(jsonb_build_object('id', f.entity_id)))
    OR
    -- If following a competition (tournament) that this match belongs to
    (f.entity_type = 'competition' AND m.tournament_id = f.entity_id) -- Simplified the join
)
WHERE m.status = 'completed'

UNION ALL

-- 2. New/Pending Tournaments for followed competitions
SELECT 
    f.user_id,
    t.id AS activity_id,
    'tournament' AS activity_type,
    t.sport_type,
    t.status::TEXT,
    jsonb_build_object('name', t.name) AS activity_data,
    t.created_at AS activity_timestamp
FROM public.follows f
JOIN public.tournaments t ON (
    (f.entity_type = 'competition' AND t.id = f.entity_id)
)
WHERE t.status = 'pending';
