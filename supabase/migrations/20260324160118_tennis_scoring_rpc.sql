-- Migration: 20260324_tennis_scoring_rpc.sql

CREATE OR REPLACE FUNCTION update_tennis_score(m_id UUID, winner_idx INT)
RETURNS void AS $$
DECLARE
    curr_p INT[];
    curr_g INT[];
    opp_idx INT;
BEGIN
    -- 1. Get current state
    SELECT tennis_points, tennis_games INTO curr_p, curr_g 
    FROM matches WHERE id = m_id;
    
    opp_idx := CASE WHEN winner_idx = 0 THEN 1 ELSE 0 END;

    -- 2. Check for Game Win
    -- Standard: 4th point (index 3) and opponent has < 3 points
    -- Deuce: Winner has 3+ points and leads by 2
    IF (curr_p[winner_idx + 1] >= 3 AND curr_p[winner_idx + 1] > curr_p[opp_idx + 1]) THEN
        -- Win the Game
        UPDATE matches 
        SET tennis_points = '{0,0}', 
            tennis_games[winner_idx + 1] = tennis_games[winner_idx + 1] + 1
        WHERE id = m_id;
    ELSE
        -- Just increment the Point
        UPDATE matches 
        SET tennis_points[winner_idx + 1] = tennis_points[winner_idx + 1] + 1
        WHERE id = m_id;
    END IF;
END;
$$ LANGUAGE plpgsql;