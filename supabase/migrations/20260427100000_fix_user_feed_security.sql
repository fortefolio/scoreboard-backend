-- 1. Add RLS policies for the follows table
-- This is required so the SECURITY INVOKER view can access follow data on behalf of the user.
CREATE POLICY "Users can view their own follows"
ON public.follows FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own follows"
ON public.follows FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 2. Recreate the user_feed view with security_invoker = true
-- This ensures the view respects the RLS policies of the tables it references.
DROP VIEW IF EXISTS public.user_feed;

CREATE VIEW public.user_feed 
WITH (security_invoker = true)
AS
-- 1. Completed Matches for followed teams, players, or tournaments
SELECT 
    f.user_id,
    m.id AS activity_id,
    'match' AS activity_type,
    m.sport_type,
    m.status::TEXT,
    m.scores AS activity_data,
    m.updated_at AS activity_timestamp
FROM public.follows f
JOIN public.matches m ON (
    -- If following a team/player involved in the match
    (f.entity_type IN ('team', 'player') AND m.participants @> jsonb_build_array(jsonb_build_object('id', f.entity_id)))
    OR
    -- If following a competition (tournament) that this match belongs to
    (f.entity_type = 'competition' AND m.tournament_id = f.entity_id)
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

-- 3. Restore documentation comment
COMMENT ON VIEW public.user_feed IS 'Stitches together completed matches and new tournaments for a user''s social feed based on follows.';
