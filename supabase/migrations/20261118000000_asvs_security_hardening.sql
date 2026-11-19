-- ============================================================================
-- Migration: OWASP ASVS 5.0 L2 Security Hardening
-- File: supabase/migrations/20261118000000_asvs_security_hardening.sql
-- ============================================================================

-- 1. [V8.2.2] Fix private tournament signup IDOR & error oracle
DROP POLICY IF EXISTS "Allow public signups" ON public.tournament_participants;
CREATE POLICY "Allow public signups"
ON public.tournament_participants FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
          AND t.status = 'pending'
          AND (
            t.visibility IN ('public', 'unlisted')
            OR t.organizer_id = (SELECT auth.uid())
          )
    )
);

CREATE OR REPLACE FUNCTION public.check_tournament_participant_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_max_teams INT;
    v_current_teams INT;
    v_visibility TEXT;
    v_organizer_id UUID;
    v_status TEXT;
BEGIN
    SELECT
        COALESCE(
            (settings->>'max_teams')::int,
            (settings->'stage_1'->>'max_teams')::int
        ),
        visibility,
        organizer_id,
        status
    INTO v_max_teams, v_visibility, v_organizer_id, v_status
    FROM public.tournaments
    WHERE id = NEW.tournament_id
    FOR UPDATE;

    -- Do not leak private tournament existence, names, or capacity via BEFORE INSERT trigger
    IF NOT FOUND OR (
        v_visibility NOT IN ('public', 'unlisted')
        AND v_organizer_id IS DISTINCT FROM (SELECT auth.uid())
        AND current_setting('role', true) != 'service_role'
    ) THEN
        RAISE EXCEPTION 'Tournament registration is not available.';
    END IF;

    IF v_status != 'pending' THEN
        RAISE EXCEPTION 'Signups are closed for this tournament.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.tournament_participants
        WHERE tournament_id = NEW.tournament_id
          AND lower(trim(name)) = lower(trim(NEW.name))
    ) THEN
        RAISE EXCEPTION 'A team or player named "%" is already registered for this tournament', trim(NEW.name);
    END IF;

    IF v_max_teams IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*)
    INTO v_current_teams
    FROM public.tournament_participants
    WHERE tournament_id = NEW.tournament_id;

    IF v_current_teams >= v_max_teams THEN
        RAISE EXCEPTION 'This tournament has reached the maximum number of participants (%)', v_max_teams;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 2. [Option A] Public tournament signup confirmation & Edge Function rate-limit table
ALTER TABLE public.tournament_participants
  ADD COLUMN IF NOT EXISTS confirmation_status TEXT NOT NULL DEFAULT 'confirmed',
  ADD COLUMN IF NOT EXISTS confirmation_token_hash TEXT,
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ DEFAULT now();

CREATE TABLE IF NOT EXISTS public.signup_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rate_key TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_signup_rate_limits_key_created
ON public.signup_rate_limits (rate_key, created_at DESC);

ALTER TABLE public.signup_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.signup_rate_limits FROM anon, authenticated;

-- 3. [V1.2.4] Restore SET search_path = '' on handle_new_user()
ALTER FUNCTION public.handle_new_user() SET search_path = '';

-- 4. [V13.3.1] Deactivate hardcoded QA/review voucher codes
UPDATE public.vouchers
SET is_active = false
WHERE code IN (
    'BETA-CLUB-60D',
    'PADEL-VIP-90D',
    'VOLLEY-CLUB-60D',
    'APP-STORE-REVIEW-PASS',
    'DEMO-TEST-PRO'
);

-- 5. [V2.4.1] Rate limiting on redeem_voucher() + [Lead #5] Fix permanent Pro grant on expired vouchers
CREATE TABLE IF NOT EXISTS public.voucher_redemption_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    succeeded BOOLEAN NOT NULL DEFAULT false,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_voucher_attempts_user_time
ON public.voucher_redemption_attempts (user_id, attempted_at DESC);

ALTER TABLE public.voucher_redemption_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.voucher_redemption_attempts FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.has_active_pro_subscription(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_tier public.subscription_tier;
    v_has_active_sub BOOLEAN;
    v_has_any_sub BOOLEAN;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.subscriptions
        WHERE user_id = p_user_id
          AND status = 'active'
          AND (current_period_end IS NULL OR current_period_end > now())
    ) INTO v_has_active_sub;

    IF v_has_active_sub THEN
        RETURN true;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.subscriptions
        WHERE user_id = p_user_id
    ) INTO v_has_any_sub;

    -- If user has subscription records and none are currently active/unexpired, they are not Pro
    IF v_has_any_sub THEN
        RETURN false;
    END IF;

    SELECT subscription_tier INTO v_tier
    FROM public.users
    WHERE id = p_user_id;

    RETURN v_tier = 'pro';
END;
$$;

CREATE OR REPLACE FUNCTION public.redeem_voucher(code_input TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_code TEXT;
    v_record RECORD;
    v_expires_at TIMESTAMPTZ;
    v_recent_failures INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED', 'message', 'You must be logged in to redeem a voucher.');
    END IF;

    -- Serialize attempts per user and enforce failed-attempt cooldown (max 5 failures per 15 min)
    PERFORM pg_advisory_xact_lock(hashtext('redeem_voucher_' || v_user_id::text));

    SELECT COUNT(*) INTO v_recent_failures
    FROM public.voucher_redemption_attempts
    WHERE user_id = v_user_id
      AND succeeded = false
      AND attempted_at > now() - interval '15 minutes';

    IF v_recent_failures >= 5 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'RATE_LIMITED',
            'message', 'Too many failed voucher attempts. Please try again in 15 minutes.'
        );
    END IF;

    v_code := UPPER(TRIM(code_input));
    IF v_code IS NULL OR length(v_code) = 0 THEN
        INSERT INTO public.voucher_redemption_attempts (user_id, succeeded) VALUES (v_user_id, false);
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_CODE', 'message', 'Please enter a valid voucher code.');
    END IF;

    SELECT * INTO v_record
    FROM public.vouchers
    WHERE code = v_code
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.voucher_redemption_attempts (user_id, succeeded) VALUES (v_user_id, false);
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Invalid voucher code.');
    END IF;

    IF NOT v_record.is_active THEN
        INSERT INTO public.voucher_redemption_attempts (user_id, succeeded) VALUES (v_user_id, false);
        RETURN jsonb_build_object('success', false, 'error', 'INACTIVE', 'message', 'This voucher code is no longer active.');
    END IF;

    IF v_record.valid_until IS NOT NULL AND v_record.valid_until < now() THEN
        INSERT INTO public.voucher_redemption_attempts (user_id, succeeded) VALUES (v_user_id, false);
        RETURN jsonb_build_object('success', false, 'error', 'EXPIRED', 'message', 'This voucher code has expired.');
    END IF;

    IF v_record.times_redeemed >= v_record.max_redemptions THEN
        INSERT INTO public.voucher_redemption_attempts (user_id, succeeded) VALUES (v_user_id, false);
        RETURN jsonb_build_object('success', false, 'error', 'MAX_REACHED', 'message', 'This voucher code has reached its maximum redemptions.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.voucher_redemptions
        WHERE voucher_id = v_record.id AND user_id = v_user_id
    ) THEN
        INSERT INTO public.voucher_redemption_attempts (user_id, succeeded) VALUES (v_user_id, false);
        RETURN jsonb_build_object('success', false, 'error', 'ALREADY_REDEEMED', 'message', 'You have already redeemed this voucher.');
    END IF;

    IF v_record.duration_days IS NOT NULL THEN
        v_expires_at := now() + (v_record.duration_days || ' days')::interval;
    ELSE
        v_expires_at := NULL;
    END IF;

    INSERT INTO public.voucher_redemptions (voucher_id, user_id, redeemed_at, expires_at)
    VALUES (v_record.id, v_user_id, now(), v_expires_at);

    UPDATE public.vouchers
    SET times_redeemed = times_redeemed + 1
    WHERE id = v_record.id;

    INSERT INTO public.subscriptions (
        user_id,
        provider,
        status,
        plan_type,
        current_period_end,
        cancel_at_period_end,
        updated_at
    ) VALUES (
        v_user_id,
        'voucher',
        'active',
        'voucher',
        v_expires_at,
        false,
        now()
    )
    ON CONFLICT (user_id, provider) DO UPDATE SET
        status = 'active',
        plan_type = 'voucher',
        current_period_end = CASE
            WHEN EXCLUDED.current_period_end IS NULL THEN NULL
            WHEN public.subscriptions.current_period_end IS NULL THEN NULL
            ELSE GREATEST(public.subscriptions.current_period_end, EXCLUDED.current_period_end)
        END,
        updated_at = now();

    UPDATE public.users
    SET subscription_tier = 'pro',
        updated_at = now()
    WHERE id = v_user_id;

    INSERT INTO public.voucher_redemption_attempts (user_id, succeeded) VALUES (v_user_id, true);

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Voucher redeemed successfully! Welcome to Pro Organizer.',
        'duration_days', v_record.duration_days,
        'expires_at', v_expires_at
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_subscription()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_tier public.subscription_tier;
    v_sub RECORD;
    v_has_any_sub BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('tier', 'free', 'has_subscription', false);
    END IF;

    SELECT subscription_tier INTO v_tier
    FROM public.users
    WHERE id = v_user_id;

    SELECT * INTO v_sub
    FROM public.subscriptions
    WHERE user_id = v_user_id
      AND status = 'active'
      AND (current_period_end IS NULL OR current_period_end > now())
    ORDER BY
        CASE provider
            WHEN 'stripe' THEN 1
            WHEN 'voucher' THEN 2
            ELSE 3
        END ASC,
        created_at DESC
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'tier', COALESCE(v_tier, 'pro'::public.subscription_tier),
            'has_subscription', true,
            'provider', v_sub.provider,
            'plan_type', v_sub.plan_type,
            'status', v_sub.status,
            'current_period_end', v_sub.current_period_end,
            'cancel_at_period_end', v_sub.cancel_at_period_end
        );
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.subscriptions WHERE user_id = v_user_id
    ) INTO v_has_any_sub;

    IF v_has_any_sub THEN
        -- All subscriptions for this user have expired or been canceled: sync users.subscription_tier down to 'free'
        IF v_tier = 'pro' THEN
            UPDATE public.users
            SET subscription_tier = 'free', updated_at = now()
            WHERE id = v_user_id;
        END IF;

        RETURN jsonb_build_object(
            'tier', 'free',
            'has_subscription', false
        );
    ELSIF v_tier = 'pro' THEN
        RETURN jsonb_build_object(
            'tier', 'pro',
            'has_subscription', true,
            'provider', 'manual',
            'plan_type', 'lifetime',
            'status', 'active',
            'current_period_end', NULL,
            'cancel_at_period_end', false
        );
    ELSE
        RETURN jsonb_build_object(
            'tier', 'free',
            'has_subscription', false
        );
    END IF;
END;
$$;

-- Update tournaments INSERT policy to use has_active_pro_subscription
DROP POLICY IF EXISTS "Pro users can create their own tournaments" ON public.tournaments;
CREATE POLICY "Pro users can create their own tournaments"
ON public.tournaments FOR INSERT
WITH CHECK (
    organizer_id = (SELECT auth.uid())
    AND public.has_active_pro_subscription((SELECT auth.uid()))
);

-- 6. [V14.2.4] GDPR delete_user_account() scrubs tournament_participants PII
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id UUID;
  v_user_email TEXT;
  v_active_tournaments_count INT;
  v_active_matches_count INT;
  v_anonymized_tag TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to delete account';
  END IF;

  SELECT COUNT(*) INTO v_active_tournaments_count
  FROM public.tournaments
  WHERE organizer_id = v_user_id AND status IN ('pending', 'ongoing');

  IF v_active_tournaments_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete account while you have active or pending tournaments. Please complete or cancel them first.';
  END IF;

  SELECT COUNT(*) INTO v_active_matches_count
  FROM public.matches
  WHERE organizer_id = v_user_id AND status IN ('scheduled', 'ongoing');

  IF v_active_matches_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete account while you have ongoing matches. Please finish or cancel them first.';
  END IF;

  SELECT email INTO v_user_email
  FROM auth.users
  WHERE id = v_user_id;

  -- 1. Unassign as umpire
  UPDATE public.matches
  SET umpire_id = NULL
  WHERE umpire_id = v_user_id;

  -- 2. Delete notification tokens
  DELETE FROM public.user_tokens
  WHERE user_id = v_user_id;

  -- 3. Delete notifications
  DELETE FROM public.notifications
  WHERE user_id = v_user_id;

  -- 4. Delete follows
  DELETE FROM public.follows
  WHERE user_id = v_user_id;

  -- 5. Scrub PII from tournament_participants matching user's email
  IF v_user_email IS NOT NULL AND length(trim(v_user_email)) > 0 THEN
    UPDATE public.tournament_participants
    SET name = 'Former Participant',
        contact_email = NULL,
        form_responses = '{}'::jsonb
    WHERE lower(trim(contact_email)) = lower(trim(v_user_email));
  END IF;

  -- 6. Anonymize profile in public.users to preserve bracket and opponent history
  v_anonymized_tag := 'former_player_' || substr(md5(v_user_id::text), 1, 8);
  UPDATE public.users
  SET username = v_anonymized_tag,
      display_name = 'Former Player',
      email = NULL,
      preferences = '{}'::jsonb,
      deleted_at = NOW(),
      updated_at = NOW()
  WHERE id = v_user_id;

  -- 7. Permanently delete from auth.users
  DELETE FROM auth.users
  WHERE id = v_user_id;

  RETURN TRUE;
END;
$$;

-- 7. [V2.2.1] Validate p_new_scores & p_new_status in record_match_event_atomic()
CREATE OR REPLACE FUNCTION public.record_match_event_atomic(
  p_match_id uuid,
  p_idempotency_key uuid,
  p_new_scores jsonb,
  p_event_data jsonb,
  p_new_status public.match_status DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_updated_match jsonb;
  v_user_id uuid;
  v_current_status public.match_status;
  v_broadcast_payload jsonb;
BEGIN
  IF current_setting('role', true) != 'service_role' THEN
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.matches
      WHERE id = p_match_id
        AND (
          organizer_id = v_user_id
          OR (umpire_id = v_user_id AND umpire_invite_status = 'accepted')
        )
    ) THEN
      RAISE EXCEPTION 'UNAUTHORIZED_SCORER: Only the assigned umpire or organizer can score this match.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Validate payload shapes and sizes
  IF p_event_data IS NULL OR jsonb_typeof(p_event_data) != 'object' OR octet_length(p_event_data::text) > 16384 THEN
    RAISE EXCEPTION 'INVALID_EVENT_DATA: Event data must be a JSON object under 16KB.'
      USING ERRCODE = '22023';
  END IF;

  IF p_new_scores IS NOT NULL AND (jsonb_typeof(p_new_scores) != 'object' OR octet_length(p_new_scores::text) > 16384) THEN
    RAISE EXCEPTION 'INVALID_SCORES: Scores payload must be a JSON object under 16KB.'
      USING ERRCODE = '22023';
  END IF;

  SELECT status INTO v_current_status
  FROM public.matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'MATCH_NOT_FOUND: Match does not exist.'
      USING ERRCODE = 'P0002';
  END IF;

  IF v_current_status = 'completed' AND p_new_status IS DISTINCT FROM 'completed' AND p_new_status IS NOT NULL THEN
    RAISE EXCEPTION 'INVALID_STATUS_TRANSITION: Cannot revert a completed match.'
      USING ERRCODE = '22023';
  END IF;

  IF p_idempotency_key IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.match_events
    WHERE idempotency_key = p_idempotency_key
      AND created_at >= now() - interval '24 hours'
  ) THEN
    SELECT to_jsonb(m) INTO v_updated_match FROM public.matches m WHERE id = p_match_id;
    RETURN v_updated_match;
  END IF;

  INSERT INTO public.match_events (match_id, idempotency_key, event_data, created_at)
  VALUES (p_match_id, p_idempotency_key, p_event_data, now());

  UPDATE public.matches
  SET
    scores = COALESCE(p_new_scores, scores),
    status = COALESCE(p_new_status, status),
    updated_at = now()
  WHERE id = p_match_id
  RETURNING to_jsonb(matches.*) INTO v_updated_match;

  v_broadcast_payload := jsonb_build_object(
    'match_id', p_match_id,
    'scores', COALESCE(p_new_scores, v_updated_match->'scores'),
    'status', v_updated_match->>'status',
    'event_data', p_event_data
  );

  BEGIN
    PERFORM realtime.send(
      v_broadcast_payload,
      'score_update',
      'match:' || p_match_id::text,
      false
    );
    PERFORM realtime.send(
      v_broadcast_payload,
      'SCORE_UPDATED',
      'match:' || p_match_id::text,
      false
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN v_updated_match;
END;
$$;

-- 8. [Lead #1] Enable RLS & revoke direct PostgREST access on match_events_default & child partitions
DO $$
DECLARE
  v_part RECORD;
BEGIN
  FOR v_part IN
    SELECT c.relname
    FROM pg_inherits i
    JOIN pg_class c ON c.oid = i.inhrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE i.inhparent = 'public.match_events'::regclass
      AND n.nspname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', v_part.relname);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', v_part.relname);
  END LOOP;
END $$;

-- 9. [Lead #2] Atomic bracket participant slot assignment with FOR UPDATE row lock
CREATE OR REPLACE FUNCTION public.set_match_participant_slot(
  p_match_id UUID,
  p_slot_idx INT,
  p_participant JSONB,
  p_find_empty_slot BOOLEAN DEFAULT false
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_participants JSONB;
  v_slot INT;
  v_arr JSONB[];
BEGIN
  IF current_setting('role', true) != 'service_role' THEN
    RAISE EXCEPTION 'FORBIDDEN: service_role required.' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(participants, '[]'::jsonb)
  INTO v_participants
  FROM public.matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF p_find_empty_slot THEN
    IF v_participants->0 IS NULL OR v_participants->0 = 'null'::jsonb THEN
      v_slot := 0;
    ELSE
      v_slot := 1;
    END IF;
  ELSE
    v_slot := COALESCE(p_slot_idx, 0);
  END IF;

  v_arr := ARRAY[
    COALESCE(v_participants->0, 'null'::jsonb),
    COALESCE(v_participants->1, 'null'::jsonb)
  ];

  IF v_slot = 0 THEN
    v_arr[1] := p_participant;
  ELSE
    v_arr[2] := p_participant;
  END IF;

  UPDATE public.matches
  SET participants = to_jsonb(v_arr),
      updated_at = now()
  WHERE id = p_match_id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_match_participant_slot(UUID, INT, JSONB, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_match_participant_slot(UUID, INT, JSONB, BOOLEAN) TO service_role;

-- 10. [Lead #4] Enforce server-side created_at in check_match_creation_rate()
CREATE OR REPLACE FUNCTION public.check_match_creation_rate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_recent_count integer;
  v_is_pro boolean;
  v_max_per_minute integer;
BEGIN
  -- Always enforce server timestamp so clients cannot backdate created_at to bypass rate limits
  NEW.created_at := now();

  IF NEW.organizer_id IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('match_rate_' || NEW.organizer_id::text));

  v_is_pro := public.has_active_pro_subscription(NEW.organizer_id);

  v_max_per_minute := CASE
    WHEN v_is_pro THEN 64
    ELSE 15
  END;

  SELECT count(*) INTO v_recent_count
  FROM public.matches
  WHERE organizer_id = NEW.organizer_id
    AND created_at > now() - interval '60 seconds';

  IF v_recent_count >= v_max_per_minute THEN
    RAISE EXCEPTION 'RATE_LIMIT_EXCEEDED: Maximum of % matches per minute allowed for your tier.', v_max_per_minute
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;
