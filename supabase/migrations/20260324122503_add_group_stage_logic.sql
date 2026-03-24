-- 1. Add group_label to matches
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS group_label TEXT;

-- 2. Create the Standings View
CREATE OR REPLACE VIEW public.group_standings 
WITH (security_invoker = true)
AS
WITH team_stats AS (
    -- Get stats for Team 1 in every match
    SELECT 
        tournament_id,
        group_label,
        (participants->0->>'name') as team_name,
        CASE WHEN (current_score->'final_sets'->0)::int > (current_score->'final_sets'->1)::int THEN 1 ELSE 0 END as is_win,
        (current_score->'final_sets'->0)::int as sets_won,
        (current_score->'final_sets'->1)::int as sets_lost,
        -- Sum of all points in all sets
        (SELECT SUM((s->>'team1')::int) FROM jsonb_array_elements(current_score->'sets') AS s) as points_for,
        (SELECT SUM((s->>'team2')::int) FROM jsonb_array_elements(current_score->'sets') AS s) as points_against
    FROM public.matches
    WHERE status = 'completed' AND group_label IS NOT NULL
    
    UNION ALL

    -- Get stats for Team 2 in every match
    SELECT 
        tournament_id,
        group_label,
        (participants->1->>'name') as team_name,
        CASE WHEN (current_score->'final_sets'->1)::int > (current_score->'final_sets'->0)::int THEN 1 ELSE 0 END as is_win,
        (current_score->'final_sets'->1)::int as sets_won,
        (current_score->'final_sets'->0)::int as sets_lost,
        (SELECT SUM((s->>'team2')::int) FROM jsonb_array_elements(current_score->'sets') AS s) as points_for,
        (SELECT SUM((s->>'team1')::int) FROM jsonb_array_elements(current_score->'sets') AS s) as points_against
    FROM public.matches
    WHERE status = 'completed' AND group_label IS NOT NULL
)
SELECT 
    tournament_id,
    group_label,
    team_name,
    COUNT(*) as played,
    SUM(is_win) as wins,
    (COUNT(*) - SUM(is_win)) as losses,
    SUM(sets_won) as total_sets_won,
    SUM(sets_lost) as total_sets_lost,
    SUM(points_for) - SUM(points_against) as point_diff
FROM team_stats
GROUP BY tournament_id, group_label, team_name
ORDER BY wins DESC, (SUM(sets_won) - SUM(sets_lost)) DESC, (SUM(points_for) - SUM(points_against)) DESC;