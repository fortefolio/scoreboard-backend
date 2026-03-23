-- View for the social feed: stitches together completed matches and new tournaments
-- based on what entities (teams, players, competitions) a user follows.

CREATE OR REPLACE VIEW public.user_feed AS
-- 1. Completed Matches for followed teams, players, or tournaments
SELECT 
    f.user_id,
    m.id AS activity_id,
    'match' AS activity_type,
    m.sport_type,
    m.status::TEXT, -- Cast to TEXT for UNION compatibility
    m.current_score AS activity_data,
    m.updated_at AS activity_timestamp
FROM public.follows f
JOIN public.matches m ON (
    -- If following a team/player involved in the match
    (f.entity_type IN ('team', 'player') AND m.participants @> jsonb_build_array(jsonb_build_object('id', f.entity_id)))
    OR
    -- If following a competition (tournament) that this match belongs to
    (f.entity_type = 'competition' AND EXISTS (
        SELECT 1 FROM public.bracket_matches bm 
        WHERE bm.match_id = m.id AND bm.tournament_id = f.entity_id
    ))
)
WHERE m.status = 'completed'

UNION ALL

-- 2. New/Pending Tournaments for followed competitions
SELECT 
    f.user_id,
    t.id AS activity_id,
    'tournament' AS activity_type,
    t.sport_type,
    t.status::TEXT, -- Cast to TEXT for UNION compatibility
    jsonb_build_object('name', t.name) AS activity_data,
    t.created_at AS activity_timestamp
FROM public.follows f
JOIN public.tournaments t ON (
    (f.entity_type = 'competition' AND t.id = f.entity_id)
)
WHERE t.status = 'pending';

-- Comments for documentation
COMMENT ON VIEW public.user_feed IS 'Stitches together completed matches and new tournaments for a user''s social feed based on follows.';
