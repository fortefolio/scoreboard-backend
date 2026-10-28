-- Migration: Complete Tennis Mechanics, Group Standings & Automatic Bracket Advancement
-- Fixes tiebreak server rotation, max_sets/match_format support, round rule overrides,
-- group_standings view compatibility for Tennis/Volleyball, and automatic bracket advancement on match completion.

BEGIN;

-- ============================================================================
-- 1. Complete Tennis Scoring Specialist
-- ============================================================================
CREATE OR REPLACE FUNCTION public.calculate_tennis_score(
    p_scores JSONB,
    v_winner_idx INT,
    v_rules JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_tennis JSONB;
    v_points INT[];
    v_games INT[];
    v_sets JSONB;
    v_current_set_idx INT;
    v_is_tiebreak BOOLEAN;
    v_is_match_tiebreak BOOLEAN;
    v_opp_idx INT := 1 - v_winner_idx;

    -- Rule flags
    v_no_ad BOOLEAN := COALESCE((v_rules->>'no_ad')::BOOLEAN, FALSE);
    v_set_type TEXT := COALESCE(v_rules->>'set_type', 'tiebreak');
    v_max_sets INT := COALESCE(
        (v_rules->>'max_sets')::INT,
        CASE
            WHEN v_rules->>'match_format' = 'best_of_5' THEN 5
            WHEN v_rules->>'match_format' = 'best_of_1' THEN 1
            ELSE 3
        END
    );
    v_sets_to_win INT;
    v_use_match_tb BOOLEAN := COALESCE((v_rules->>'match_tiebreak')::BOOLEAN, FALSE);
    v_final_set_tb_points INT := COALESCE((v_rules->>'final_set_tiebreak_points')::INT, 7);

    -- Logic helpers
    v_game_won BOOLEAN := FALSE;
    v_set_won BOOLEAN := FALSE;
    v_match_won BOOLEAN := FALSE;
    v_tb_points_to_win INT := 7;
    v_total_tb_points INT;
    v_total_games_in_set INT;
    v_serving_idx INT;
    v_tb_init_server INT;
    v_tb_score JSONB := NULL;
    v_sets_p1 INT := 0;
    v_sets_p2 INT := 0;
    v_s JSONB;
    v_current_set_games JSONB;
    v_current_game_points JSONB;
    v_game_server INT;
    v_was_tiebreak_game BOOLEAN := FALSE;
    v_point_label TEXT;
    v_pt_names TEXT[] := ARRAY['0', '15', '30', '40'];
BEGIN
    -- Guard: if match is already won, ignore subsequent points
    IF COALESCE((p_scores->>'match_won')::BOOLEAN, FALSE) THEN
        RETURN p_scores;
    END IF;

    v_sets_to_win := CEIL(v_max_sets / 2.0)::INT;

    v_tennis := COALESCE(p_scores->'tennis', '{"points": [0,0], "games": [0,0], "sets": [], "current_set": 1, "is_tiebreak": false}'::jsonb);
    v_points := ARRAY[COALESCE((v_tennis->'points'->0)::INT, 0), COALESCE((v_tennis->'points'->1)::INT, 0)];
    v_games := ARRAY[COALESCE((v_tennis->'games'->0)::INT, 0), COALESCE((v_tennis->'games'->1)::INT, 0)];
    v_sets := COALESCE(v_tennis->'sets', '[]'::jsonb);
    v_current_set_idx := COALESCE((v_tennis->>'current_set')::INT, 1);
    v_is_tiebreak := COALESCE((v_tennis->>'is_tiebreak')::BOOLEAN, FALSE);
    v_serving_idx := COALESCE((p_scores->>'serving_index')::INT, 0);
    v_tb_init_server := (v_tennis->>'tiebreak_initial_server')::INT;
    v_current_set_games := COALESCE(v_tennis->'current_set_games', '[]'::jsonb);
    v_current_game_points := COALESCE(v_tennis->'current_game_points', '[]'::jsonb);

    -- Check if this is a deciding-set Match Tiebreak (played instead of a full deciding set)
    v_is_match_tiebreak := v_use_match_tb AND v_current_set_idx = v_max_sets AND v_max_sets > 1;

    IF (v_is_tiebreak OR v_is_match_tiebreak) AND v_tb_init_server IS NULL THEN
        v_tb_init_server := v_serving_idx;
    END IF;

    v_was_tiebreak_game := (v_is_tiebreak OR v_is_match_tiebreak);
    v_game_server := CASE WHEN v_was_tiebreak_game THEN COALESCE(v_tb_init_server, v_serving_idx) ELSE v_serving_idx END;

    -- A. Update Points
    v_points[v_winner_idx + 1] := v_points[v_winner_idx + 1] + 1;

    -- B. Check for Game Win
    IF v_was_tiebreak_game THEN
        IF v_is_match_tiebreak THEN
            v_tb_points_to_win := 10;
        ELSIF v_current_set_idx = v_max_sets THEN
            v_tb_points_to_win := v_final_set_tb_points;
        ELSE
            v_tb_points_to_win := 7;
        END IF;

        v_point_label := v_points[1]::TEXT || '-' || v_points[2]::TEXT;
        v_current_game_points := v_current_game_points || to_jsonb(v_point_label);

        IF v_points[v_winner_idx + 1] >= v_tb_points_to_win AND (v_points[v_winner_idx + 1] - v_points[v_opp_idx + 1]) >= 2 THEN
            v_game_won := TRUE;
            v_tb_score := jsonb_build_object('home', v_points[1], 'away', v_points[2]);
        ELSE
            -- Tiebreak Serving Rotation (rotates after point 1, 3, 5, 7...)
            v_total_tb_points := v_points[1] + v_points[2];
            IF v_total_tb_points % 2 = 1 THEN
                v_serving_idx := 1 - v_serving_idx;
            END IF;
        END IF;
    ELSE
        IF v_no_ad THEN
            IF v_points[v_winner_idx + 1] >= 4 THEN
                v_game_won := TRUE;
            END IF;
        ELSE
            IF v_points[v_winner_idx + 1] >= 4 AND (v_points[v_winner_idx + 1] - v_points[v_opp_idx + 1]) >= 2 THEN
                v_game_won := TRUE;
            ELSIF v_points[v_winner_idx + 1] = 4 AND v_points[v_opp_idx + 1] = 4 THEN
                -- Back to Deuce (3-3)
                v_points[1] := 3;
                v_points[2] := 3;
            END IF;
        END IF;

        IF v_game_won THEN
            v_current_game_points := v_current_game_points || to_jsonb('Game'::TEXT);
        ELSE
            IF v_points[1] >= 3 AND v_points[2] >= 3 THEN
                IF v_points[1] = v_points[2] THEN
                    v_point_label := '40-40';
                ELSIF v_points[1] > v_points[2] THEN
                    v_point_label := 'AD-40';
                ELSE
                    v_point_label := '40-AD';
                END IF;
            ELSE
                v_point_label := v_pt_names[v_points[1] + 1] || '-' || v_pt_names[v_points[2] + 1];
            END IF;
            v_current_game_points := v_current_game_points || to_jsonb(v_point_label);
        END IF;
    END IF;

    -- C. Handle Game Won
    IF v_game_won THEN
        v_games[v_winner_idx + 1] := v_games[v_winner_idx + 1] + 1;
        v_points := ARRAY[0, 0];

        v_current_set_games := v_current_set_games || jsonb_build_object(
            'game_number', jsonb_array_length(v_current_set_games) + 1,
            'server', v_game_server,
            'winner', v_winner_idx,
            'is_break', (NOT v_was_tiebreak_game AND v_winner_idx != v_game_server),
            'is_tiebreak', v_was_tiebreak_game,
            'games_after', jsonb_build_object('home', v_games[1], 'away', v_games[2]),
            'points_progression', v_current_game_points
        );
        v_current_game_points := '[]'::jsonb;

        IF v_was_tiebreak_game THEN
            -- Official Tennis Rule: The player who served first in the tiebreak receives in Game 1 of the next set
            v_serving_idx := 1 - COALESCE(v_tb_init_server, v_serving_idx);
            v_is_tiebreak := FALSE;
            v_tb_init_server := NULL;
            v_set_won := TRUE;
        ELSE
            v_serving_idx := 1 - v_serving_idx;

            IF v_games[v_winner_idx + 1] >= 6 THEN
                IF (v_games[v_winner_idx + 1] - v_games[v_opp_idx + 1]) >= 2 THEN
                    v_set_won := TRUE;
                ELSIF v_games[1] = 6 AND v_games[2] = 6 AND v_set_type = 'tiebreak' THEN
                    v_is_tiebreak := TRUE;
                    v_tb_init_server := v_serving_idx;
                END IF;
            END IF;
        END IF;
    END IF;

    -- D. Handle Set Won
    IF v_set_won THEN
        IF v_tb_score IS NOT NULL THEN
            v_sets := v_sets || jsonb_build_object(
                'home', v_games[1],
                'away', v_games[2],
                'team1', v_games[1],
                'team2', v_games[2],
                'tiebreak', v_tb_score,
                'games_history', v_current_set_games
            );
        ELSE
            v_sets := v_sets || jsonb_build_object(
                'home', v_games[1],
                'away', v_games[2],
                'team1', v_games[1],
                'team2', v_games[2],
                'games_history', v_current_set_games
            );
        END IF;
        v_games := ARRAY[0, 0];
        v_current_set_games := '[]'::jsonb;
        v_current_set_idx := v_current_set_idx + 1;
    END IF;

    -- Count sets won across all completed sets
    FOR v_s IN SELECT * FROM jsonb_array_elements(v_sets) LOOP
        IF COALESCE((v_s->>'home')::INT, (v_s->>'team1')::INT, 0) > COALESCE((v_s->>'away')::INT, (v_s->>'team2')::INT, 0) THEN
            v_sets_p1 := v_sets_p1 + 1;
        ELSE
            v_sets_p2 := v_sets_p2 + 1;
        END IF;
    END LOOP;

    IF v_sets_p1 >= v_sets_to_win OR v_sets_p2 >= v_sets_to_win THEN
        v_match_won := TRUE;
    ELSIF v_set_won AND v_use_match_tb AND v_current_set_idx = v_max_sets AND v_max_sets > 1 THEN
        v_tb_init_server := v_serving_idx;
    END IF;

    -- E. Compile Result
    v_total_games_in_set := v_games[1] + v_games[2];
    RETURN jsonb_build_object(
        'current', jsonb_build_object('home', v_games[1], 'away', v_games[2]),
        'sets', v_sets,
        'final_sets', jsonb_build_array(v_sets_p1, v_sets_p2),
        'final_history', v_sets,
        'serving_index', v_serving_idx,
        'match_won', v_match_won,
        'tennis', jsonb_build_object(
            'points', v_points,
            'games', v_games,
            'sets', v_sets,
            'current_set', v_current_set_idx,
            'is_tiebreak', v_is_tiebreak,
            'tiebreak_initial_server', v_tb_init_server,
            'current_set_games', v_current_set_games,
            'current_game_points', v_current_game_points,
            'server_side', CASE WHEN (v_points[1] + v_points[2]) % 2 = 0 THEN 'deuce' ELSE 'ad' END,
            'change_ends', (
                ((v_points[1] = 0 AND v_points[2] = 0) AND (v_total_games_in_set % 2 = 1 OR v_set_won))
                OR ((v_is_tiebreak OR v_is_match_tiebreak) AND (v_points[1] + v_points[2]) > 0 AND (v_points[1] + v_points[2]) % 6 = 0)
            )
        )
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ============================================================================
-- 2. Automatic Bracket Advancement Helper
-- ============================================================================
CREATE OR REPLACE FUNCTION public.advance_tournament_match(p_match_id UUID)
RETURNS VOID AS $$
DECLARE
    v_match RECORD;
    v_tournament RECORD;
    v_tournament_type TEXT;
    v_sets JSONB;
    v_s JSONB;
    v_p1_sets INT := 0;
    v_p2_sets INT := 0;
    v_winner_idx INT;
    v_loser_idx INT;
    v_winner JSONB;
    v_loser JSONB;
    v_next_round INT;
    v_next_order INT;
    v_slot_idx INT;
    v_next_match RECORD;
    v_losers_round INT;
    v_losers_order INT;
    v_losers_match RECORD;
    v_grand_final RECORD;
    v_updated_participants JSONB;
    v_is_dropping_in BOOLEAN;
BEGIN
    SELECT * INTO v_match FROM public.matches WHERE id = p_match_id;
    IF NOT FOUND OR v_match.tournament_id IS NULL OR v_match.group_label IS NOT NULL THEN
        RETURN;
    END IF;

    SELECT * INTO v_tournament FROM public.tournaments WHERE id = v_match.tournament_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Determine winner from sets or current score
    v_sets := COALESCE(v_match.scores->'tennis'->'sets', v_match.scores->'sets', v_match.scores->'set_scores', '[]'::jsonb);
    IF jsonb_typeof(v_sets) = 'array' AND jsonb_array_length(v_sets) > 0 THEN
        FOR v_s IN SELECT * FROM jsonb_array_elements(v_sets) LOOP
            IF COALESCE((v_s->>'home')::INT, (v_s->>'team1')::INT, 0) > COALESCE((v_s->>'away')::INT, (v_s->>'team2')::INT, 0) THEN
                v_p1_sets := v_p1_sets + 1;
            ELSE
                v_p2_sets := v_p2_sets + 1;
            END IF;
        END LOOP;
    ELSE
        v_p1_sets := COALESCE((v_match.scores->'current'->>'home')::INT, 0);
        v_p2_sets := COALESCE((v_match.scores->'current'->>'away')::INT, 0);
    END IF;

    IF v_p1_sets = v_p2_sets THEN
        RETURN;
    END IF;

    v_winner_idx := CASE WHEN v_p1_sets > v_p2_sets THEN 0 ELSE 1 END;
    v_loser_idx := 1 - v_winner_idx;
    v_winner := v_match.participants->v_winner_idx;
    v_loser := v_match.participants->v_loser_idx;

    IF v_winner IS NULL THEN
        RETURN;
    END IF;

    v_tournament_type := COALESCE(v_tournament.settings->'stage_1'->>'type', 'bracket');

    -- Helper logic for placing a participant into slot 0 or slot 1 of a target match
    -- CASE A: DOUBLE ELIMINATION WINNERS BRACKET
    IF v_match.bracket_type = 'main' AND v_tournament_type = 'double_elimination' THEN
        v_next_round := v_match.round_number + 1;
        v_next_order := CEIL(v_match.match_order / 2.0)::INT;
        v_slot_idx := CASE WHEN v_match.match_order % 2 = 1 THEN 0 ELSE 1 END;

        SELECT * INTO v_next_match
        FROM public.matches
        WHERE tournament_id = v_match.tournament_id
          AND bracket_type = 'main'
          AND round_number = v_next_round
          AND match_order = v_next_order
        LIMIT 1;

        IF FOUND THEN
            v_updated_participants := COALESCE(v_next_match.participants, '[]'::jsonb);
            IF v_slot_idx = 0 THEN
                v_updated_participants := jsonb_build_array(v_winner, COALESCE(v_updated_participants->1, 'null'::jsonb)) - 'null';
                IF v_next_match.participants->1 IS NOT NULL THEN
                    v_updated_participants := jsonb_build_array(v_winner, v_next_match.participants->1);
                ELSE
                    v_updated_participants := jsonb_build_array(v_winner);
                END IF;
            ELSE
                IF v_next_match.participants->0 IS NOT NULL THEN
                    v_updated_participants := jsonb_build_array(v_next_match.participants->0, v_winner);
                ELSE
                    v_updated_participants := jsonb_build_array(null, v_winner);
                END IF;
            END IF;
            UPDATE public.matches SET participants = v_updated_participants WHERE id = v_next_match.id;
        ELSE
            -- Advance to Grand Final slot 0
            SELECT * INTO v_grand_final
            FROM public.matches
            WHERE tournament_id = v_match.tournament_id
              AND bracket_type = 'grand_final'
            LIMIT 1;
            IF FOUND THEN
                IF v_grand_final.participants->1 IS NOT NULL THEN
                    v_updated_participants := jsonb_build_array(v_winner, v_grand_final.participants->1);
                ELSE
                    v_updated_participants := jsonb_build_array(v_winner);
                END IF;
                UPDATE public.matches SET participants = v_updated_participants WHERE id = v_grand_final.id;
            END IF;
        END IF;

        -- Drop loser to Losers Bracket
        IF v_match.round_number = 1 THEN
            v_losers_round := 1;
            v_losers_order := CEIL(v_match.match_order / 2.0)::INT;
        ELSE
            v_losers_round := (v_match.round_number * 2) - 2;
            v_losers_order := v_match.match_order;
        END IF;

        SELECT * INTO v_losers_match
        FROM public.matches
        WHERE tournament_id = v_match.tournament_id
          AND bracket_type = 'losers'
          AND round_number = v_losers_round
          AND match_order = v_losers_order
        LIMIT 1;

        IF FOUND AND v_loser IS NOT NULL THEN
            IF v_losers_match.participants->0 IS NOT NULL AND v_losers_match.participants->0 != 'null'::jsonb THEN
                v_updated_participants := jsonb_build_array(v_losers_match.participants->0, v_loser);
            ELSE
                v_updated_participants := jsonb_build_array(v_loser);
            END IF;
            UPDATE public.matches SET participants = v_updated_participants WHERE id = v_losers_match.id;
        END IF;

    -- CASE B: DOUBLE ELIMINATION LOSERS BRACKET
    ELSIF v_match.bracket_type = 'losers' AND v_tournament_type = 'double_elimination' THEN
        v_next_round := v_match.round_number + 1;
        v_is_dropping_in := (v_match.round_number % 2 = 1);
        v_next_order := CASE WHEN v_is_dropping_in THEN v_match.match_order ELSE CEIL(v_match.match_order / 2.0)::INT END;
        v_slot_idx := CASE WHEN v_is_dropping_in THEN 1 ELSE (CASE WHEN v_match.match_order % 2 = 1 THEN 0 ELSE 1 END) END;

        SELECT * INTO v_next_match
        FROM public.matches
        WHERE tournament_id = v_match.tournament_id
          AND bracket_type = 'losers'
          AND round_number = v_next_round
          AND match_order = v_next_order
        LIMIT 1;

        IF FOUND THEN
            IF v_slot_idx = 0 THEN
                IF v_next_match.participants->1 IS NOT NULL THEN
                    v_updated_participants := jsonb_build_array(v_winner, v_next_match.participants->1);
                ELSE
                    v_updated_participants := jsonb_build_array(v_winner);
                END IF;
            ELSE
                IF v_next_match.participants->0 IS NOT NULL THEN
                    v_updated_participants := jsonb_build_array(v_next_match.participants->0, v_winner);
                ELSE
                    v_updated_participants := jsonb_build_array(null, v_winner);
                END IF;
            END IF;
            UPDATE public.matches SET participants = v_updated_participants WHERE id = v_next_match.id;
        ELSE
            -- Advance to Grand Final slot 1
            SELECT * INTO v_grand_final
            FROM public.matches
            WHERE tournament_id = v_match.tournament_id
              AND bracket_type = 'grand_final'
            LIMIT 1;
            IF FOUND THEN
                IF v_grand_final.participants->0 IS NOT NULL THEN
                    v_updated_participants := jsonb_build_array(v_grand_final.participants->0, v_winner);
                ELSE
                    v_updated_participants := jsonb_build_array(null, v_winner);
                END IF;
                UPDATE public.matches SET participants = v_updated_participants WHERE id = v_grand_final.id;
            END IF;
        END IF;

    -- CASE C: GRAND FINAL OR SINGLE ELIMINATION
    ELSIF v_match.bracket_type = 'grand_final' THEN
        UPDATE public.tournaments SET status = 'completed' WHERE id = v_match.tournament_id;
    ELSE
        v_next_round := v_match.round_number + 1;
        v_next_order := CEIL(v_match.match_order / 2.0)::INT;
        v_slot_idx := CASE WHEN v_match.match_order % 2 = 1 THEN 0 ELSE 1 END;

        SELECT * INTO v_next_match
        FROM public.matches
        WHERE tournament_id = v_match.tournament_id
          AND bracket_type = v_match.bracket_type
          AND round_number = v_next_round
          AND match_order = v_next_order
        LIMIT 1;

        IF FOUND THEN
            IF v_slot_idx = 0 THEN
                IF v_next_match.participants->1 IS NOT NULL THEN
                    v_updated_participants := jsonb_build_array(v_winner, v_next_match.participants->1);
                ELSE
                    v_updated_participants := jsonb_build_array(v_winner);
                END IF;
            ELSE
                IF v_next_match.participants->0 IS NOT NULL THEN
                    v_updated_participants := jsonb_build_array(v_next_match.participants->0, v_winner);
                ELSE
                    v_updated_participants := jsonb_build_array(null, v_winner);
                END IF;
            END IF;
            UPDATE public.matches SET participants = v_updated_participants WHERE id = v_next_match.id;
        ELSE
            -- No next match exists -> This was the Championship Final!
            UPDATE public.tournaments SET status = 'completed' WHERE id = v_match.tournament_id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ============================================================================
-- 3. Update Dispatcher Trigger to Merge Round Overrides & Advance Bracket
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_match_score()
RETURNS TRIGGER AS $$
DECLARE
    v_match RECORD;
    v_rules JSONB;
    v_scores JSONB;
    v_result JSONB;
    v_side TEXT;
    v_match_won BOOLEAN := FALSE;
    v_football JSONB;
    v_event_type TEXT;
BEGIN
    SELECT m.*, t.settings AS tournament_settings
    INTO v_match
    FROM public.matches m
    LEFT JOIN public.tournaments t ON m.tournament_id = t.id
    WHERE m.id = NEW.match_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    v_scores := COALESCE(v_match.scores, '{"current": {"home": 0, "away": 0}, "serving_index": 0}'::jsonb);
    -- Merge tournament default settings, round-specific overrides, and match-specific settings
    v_rules := COALESCE(v_match.tournament_settings->'default', '{}'::jsonb)
        || COALESCE(v_match.tournament_settings->'overrides'->(COALESCE(v_match.round_number, 1)::text), '{}'::jsonb)
        || COALESCE(v_match.settings, '{}'::jsonb);
    v_event_type := NEW.event_data->>'type';

    -- Handle Meta-Events
    IF v_event_type = 'start_scoreboard' THEN
        IF NEW.event_data ? 'initial_server_index' THEN
            v_scores := jsonb_set(v_scores, '{serving_index}', (NEW.event_data->'initial_server_index'));
            UPDATE public.matches SET status = 'ongoing', scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        ELSE
            UPDATE public.matches SET status = 'ongoing', updated_at = NOW() WHERE id = NEW.match_id;
        END IF;
        RETURN NEW;
    END IF;

    IF v_event_type = 'toss_coin' THEN
        v_scores := jsonb_set(v_scores, '{serving_index}', (NEW.event_data->'winner_index'));
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    -- Handle Football clock and period events
    IF v_event_type = 'clock_toggle' THEN
        v_football := COALESCE(v_scores->'football', '{"period": 1, "is_running": false, "timer_started_at": null, "elapsed_At_pause": 0}'::jsonb);
        v_football := v_football || jsonb_build_object(
            'is_running', COALESCE((NEW.event_data->>'is_running')::boolean, false),
            'timer_started_at', NEW.event_data->'timer_started_at',
            'elapsed_At_pause', COALESCE((NEW.event_data->>'elapsed_at_pause')::int, (v_football->>'elapsed_At_pause')::int, 0)
        );
        v_scores := jsonb_set(v_scores, '{football}', v_football);
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    IF v_event_type = 'period_change' THEN
        v_football := COALESCE(v_scores->'football', '{"period": 1, "is_running": false, "timer_started_at": null, "elapsed_At_pause": 0}'::jsonb);
        v_football := v_football || jsonb_build_object(
            'period', COALESCE((NEW.event_data->>'new_period')::int, 1),
            'is_running', false,
            'timer_started_at', null,
            'elapsed_At_pause', COALESCE((NEW.event_data->>'elapsed_at_pause')::int, 0)
        );
        v_scores := jsonb_set(v_scores, '{football}', v_football);
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    -- Dispatch scoring events
    IF v_event_type IN ('point_won', 'score', 'goal', 'point_scored') THEN
        v_side := NEW.event_data->>'side';
        IF v_side IS NULL THEN RETURN NEW; END IF;

        CASE lower(COALESCE(v_match.sport_type, 'generic'))
            WHEN 'tennis' THEN
                IF NOT (v_scores ? 'tennis') THEN
                    v_scores := jsonb_set(v_scores, '{tennis}', '{"points": [0,0], "games": [0,0], "sets": [], "current_set": 1, "is_tiebreak": false}'::jsonb);
                END IF;
                v_result := public.calculate_tennis_score(v_scores, (CASE WHEN v_side = 'home' THEN 0 ELSE 1 END), v_rules);
                v_match_won := COALESCE((v_result->>'match_won')::BOOLEAN, FALSE);
                v_scores := v_scores || v_result;

            WHEN 'volleyball', 'beach_volleyball' THEN
                v_result := public.calculate_volleyball_score(v_scores, v_side, v_rules);
                v_match_won := COALESCE((v_result->>'match_won')::BOOLEAN, FALSE);
                v_scores := v_scores || v_result;

            WHEN 'basketball' THEN
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side],
                    ((COALESCE((v_scores->'current'->>v_side)::INT, 0) + COALESCE((NEW.event_data->>'points')::INT, 1))::TEXT)::jsonb);

            ELSE
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side],
                    ((COALESCE((v_scores->'current'->>v_side)::INT, 0) + 1)::TEXT)::jsonb);
        END CASE;
    END IF;

    IF v_match_won AND v_match.status != 'completed' THEN
        UPDATE public.matches SET status = 'completed', scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        PERFORM public.advance_tournament_match(NEW.match_id);
    ELSE
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ============================================================================
-- 4. Update group_standings View to Support Tennis & Volleyball Set Formats
-- ============================================================================
DROP VIEW IF EXISTS public.group_standings;
CREATE OR REPLACE VIEW public.group_standings
WITH (security_invoker = true)
AS
WITH match_set_totals AS (
    SELECT
        m.id AS match_id,
        m.tournament_id,
        m.group_label,
        m.participants->0->>'name' AS team1_name,
        m.participants->1->>'name' AS team2_name,
        COALESCE(
            (m.scores->'final_sets'->0)::int,
            (
                SELECT COUNT(*)::int
                FROM jsonb_array_elements(COALESCE(m.scores->'tennis'->'sets', m.scores->'sets', '[]'::jsonb)) AS s
                WHERE COALESCE((s->>'home')::int, (s->>'team1')::int, 0) > COALESCE((s->>'away')::int, (s->>'team2')::int, 0)
            ),
            0
        ) AS team1_sets,
        COALESCE(
            (m.scores->'final_sets'->1)::int,
            (
                SELECT COUNT(*)::int
                FROM jsonb_array_elements(COALESCE(m.scores->'tennis'->'sets', m.scores->'sets', '[]'::jsonb)) AS s
                WHERE COALESCE((s->>'away')::int, (s->>'team2')::int, 0) > COALESCE((s->>'home')::int, (s->>'team1')::int, 0)
            ),
            0
        ) AS team2_sets,
        COALESCE(
            (
                SELECT SUM(COALESCE((s->>'team1')::int, (s->>'home')::int, 0))::int
                FROM jsonb_array_elements(COALESCE(m.scores->'final_history', m.scores->'tennis'->'sets', m.scores->'sets', '[]'::jsonb)) AS s
            ),
            (m.scores->'current'->>'home')::int,
            0
        ) AS team1_points,
        COALESCE(
            (
                SELECT SUM(COALESCE((s->>'team2')::int, (s->>'away')::int, 0))::int
                FROM jsonb_array_elements(COALESCE(m.scores->'final_history', m.scores->'tennis'->'sets', m.scores->'sets', '[]'::jsonb)) AS s
            ),
            (m.scores->'current'->>'away')::int,
            0
        ) AS team2_points
    FROM public.matches m
    WHERE m.status = 'completed' AND m.group_label IS NOT NULL
),
team_stats AS (
    SELECT
        tournament_id,
        group_label,
        team1_name AS team_name,
        CASE WHEN team1_sets > team2_sets THEN 1 ELSE 0 END AS is_win,
        team1_sets AS sets_won,
        team2_sets AS sets_lost,
        team1_points AS points_for,
        team2_points AS points_against
    FROM match_set_totals
    UNION ALL
    SELECT
        tournament_id,
        group_label,
        team2_name AS team_name,
        CASE WHEN team2_sets > team1_sets THEN 1 ELSE 0 END AS is_win,
        team2_sets AS sets_won,
        team1_sets AS sets_lost,
        team2_points AS points_for,
        team1_points AS points_against
    FROM match_set_totals
)
SELECT
    tournament_id,
    group_label,
    team_name,
    COUNT(*) AS played,
    SUM(is_win) AS wins,
    (COUNT(*) - SUM(is_win)) AS losses,
    SUM(sets_won) AS total_sets_won,
    SUM(sets_lost) AS total_sets_lost,
    SUM(points_for) - SUM(points_against) AS point_diff
FROM team_stats
GROUP BY tournament_id, group_label, team_name
ORDER BY wins DESC, (SUM(sets_won) - SUM(sets_lost)) DESC, (SUM(points_for) - SUM(points_against)) DESC;

GRANT SELECT ON public.group_standings TO anon, authenticated;

COMMIT;
