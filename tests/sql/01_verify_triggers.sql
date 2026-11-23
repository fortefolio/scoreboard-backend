-- Verifies critical DB triggers & RPC contracts:
--   1. handle_umpire_invitation skips self-assigned organizer on INSERT
--   2. handle_match_score_update_notification ignores clock-only updates
--   3. handle_match_score_update_notification creates milestone rows vs live-collapse rows

DO $$
DECLARE
    v_org_id UUID := gen_random_uuid();
    v_follower_id UUID := gen_random_uuid();
    v_fb_match_id UUID := gen_random_uuid();
    v_bb_match_id UUID := gen_random_uuid();
    v_self_invite_count INT;
    v_clock_notif_count INT;
    v_goal_notif_count INT;
    v_bb_notif_count INT;
    v_bb_collapse_key TEXT;
BEGIN
    INSERT INTO auth.users (id, email) VALUES
        (v_org_id, 'org@test.local'),
        (v_follower_id, 'follower@test.local');

    INSERT INTO public.users (id, email, username, subscription_tier) VALUES
        (v_org_id, 'org@test.local', 'org_ci', 'pro'),
        (v_follower_id, 'follower@test.local', 'follower_ci', 'free')
    ON CONFLICT (id) DO NOTHING;

    -- 1. Creating a match with umpire_id = organizer_id must NOT notify organizer
    INSERT INTO public.matches (id, organizer_id, umpire_id, sport_type, status, participants, scores)
    VALUES (
        v_fb_match_id,
        v_org_id,
        v_org_id,
        'Football',
        'ongoing',
        '[{"name":"AAC"},{"name":"AAV"}]'::jsonb,
        '{"current":{"home":0,"away":0},"football":{"goals":{"home":0,"away":0},"is_clock_running":false,"elapsed_seconds":0}}'::jsonb
    );

    SELECT COUNT(*) INTO v_self_invite_count
    FROM public.notifications
    WHERE user_id = v_org_id AND (data->>'type') = 'umpire_invitation';

    IF v_self_invite_count <> 0 THEN
        RAISE EXCEPTION 'Expected 0 self-invite notifications, got %', v_self_invite_count;
    END IF;

    -- Follower follows the football match
    INSERT INTO public.follows (user_id, entity_type, entity_id)
    VALUES (v_follower_id, 'match', v_fb_match_id);

    -- 2. Clock-only update must NOT create a notification
    UPDATE public.matches
    SET scores = '{"current":{"home":0,"away":0},"football":{"goals":{"home":0,"away":0},"is_clock_running":true,"elapsed_seconds":12}}'::jsonb
    WHERE id = v_fb_match_id;

    SELECT COUNT(*) INTO v_clock_notif_count
    FROM public.notifications
    WHERE user_id = v_follower_id AND (data->>'match_id') = v_fb_match_id::text;

    IF v_clock_notif_count <> 0 THEN
        RAISE EXCEPTION 'Expected 0 clock-toggle notifications, got %', v_clock_notif_count;
    END IF;

    -- 3. Football goal creates a milestone notification
    UPDATE public.matches
    SET scores = '{"current":{"home":1,"away":0},"football":{"goals":{"home":1,"away":0},"is_clock_running":true,"elapsed_seconds":65}}'::jsonb
    WHERE id = v_fb_match_id;

    SELECT COUNT(*) INTO v_goal_notif_count
    FROM public.notifications
    WHERE user_id = v_follower_id AND (data->>'match_id') = v_fb_match_id::text;

    IF v_goal_notif_count <> 1 THEN
        RAISE EXCEPTION 'Expected 1 goal notification, got %', v_goal_notif_count;
    END IF;

    -- 4. Basketball live updates collapse into 1 row with collapse_key
    INSERT INTO public.matches (id, organizer_id, umpire_id, sport_type, status, participants, scores)
    VALUES (
        v_bb_match_id,
        v_org_id,
        v_org_id,
        'Basketball',
        'ongoing',
        '[{"name":"Lakers"},{"name":"Warriors"}]'::jsonb,
        '{"current":{"home":0,"away":0},"basketball":{"period":"Q1"}}'::jsonb
    );

    INSERT INTO public.follows (user_id, entity_type, entity_id)
    VALUES (v_follower_id, 'match', v_bb_match_id);

    UPDATE public.matches
    SET scores = '{"current":{"home":2,"away":0},"basketball":{"period":"Q1"}}'::jsonb
    WHERE id = v_bb_match_id;

    UPDATE public.matches
    SET scores = '{"current":{"home":5,"away":0},"basketball":{"period":"Q1"}}'::jsonb
    WHERE id = v_bb_match_id;

    SELECT COUNT(*), MAX(data->>'collapse_key')
    INTO v_bb_notif_count, v_bb_collapse_key
    FROM public.notifications
    WHERE user_id = v_follower_id AND (data->>'match_id') = v_bb_match_id::text;

    IF v_bb_notif_count <> 1 THEN
        RAISE EXCEPTION 'Expected 1 collapsed basketball notification, got %', v_bb_notif_count;
    END IF;

    IF v_bb_collapse_key IS DISTINCT FROM ('match_' || v_bb_match_id::text || '_live') THEN
        RAISE EXCEPTION 'Unexpected collapse_key: %', v_bb_collapse_key;
    END IF;
END $$;
