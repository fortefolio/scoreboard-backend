-- Migration: Subscriptions and Voucher Engine
-- Enables Pro subscription lifecycle tracking (Stripe/Vouchers/IAP) and Club Beta voucher redemptions.

-- 1. Create subscriptions table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL CHECK (provider IN ('stripe', 'voucher', 'apple', 'google', 'manual')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'past_due', 'canceled', 'expired', 'trialing', 'incomplete')),
    plan_type TEXT DEFAULT 'monthly' CHECK (plan_type IN ('monthly', 'annual', 'voucher', 'lifetime')),
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_subscriptions_user_provider UNIQUE (user_id, provider)
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_sub ON public.subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_cust ON public.subscriptions(stripe_customer_id);

-- Enable RLS on subscriptions
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own subscriptions"
    ON public.subscriptions
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 2. Create vouchers table
CREATE TABLE IF NOT EXISTS public.vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    description TEXT,
    duration_days INTEGER CHECK (duration_days IS NULL OR duration_days > 0),
    max_redemptions INTEGER NOT NULL DEFAULT 1 CHECK (max_redemptions > 0),
    times_redeemed INTEGER NOT NULL DEFAULT 0 CHECK (times_redeemed >= 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_vouchers_code ON public.vouchers(code);

-- Enable RLS on vouchers (No direct client SELECT to prevent code harvesting)
ALTER TABLE public.vouchers ENABLE ROW LEVEL SECURITY;

-- 3. Create voucher_redemptions table
CREATE TABLE IF NOT EXISTS public.voucher_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voucher_id UUID NOT NULL REFERENCES public.vouchers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    CONSTRAINT uq_voucher_user UNIQUE (voucher_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_voucher_redemptions_user ON public.voucher_redemptions(user_id);

-- Enable RLS on voucher_redemptions
ALTER TABLE public.voucher_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own voucher redemptions"
    ON public.voucher_redemptions
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 4. Function: Redeem Voucher (Atomic RPC)
CREATE OR REPLACE FUNCTION public.redeem_voucher(code_input TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_code TEXT;
    v_record RECORD;
    v_expires_at TIMESTAMPTZ;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED', 'message', 'You must be logged in to redeem a voucher.');
    END IF;

    v_code := UPPER(TRIM(code_input));
    IF v_code IS NULL OR length(v_code) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_CODE', 'message', 'Please enter a valid voucher code.');
    END IF;

    -- Lock the voucher row for concurrency
    SELECT * INTO v_record
    FROM public.vouchers
    WHERE code = v_code
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Invalid voucher code.');
    END IF;

    IF NOT v_record.is_active THEN
        RETURN jsonb_build_object('success', false, 'error', 'INACTIVE', 'message', 'This voucher code is no longer active.');
    END IF;

    IF v_record.valid_until IS NOT NULL AND v_record.valid_until < now() THEN
        RETURN jsonb_build_object('success', false, 'error', 'EXPIRED', 'message', 'This voucher code has expired.');
    END IF;

    IF v_record.times_redeemed >= v_record.max_redemptions THEN
        RETURN jsonb_build_object('success', false, 'error', 'MAX_REACHED', 'message', 'This voucher code has reached its maximum redemptions.');
    END IF;

    -- Check if user has already redeemed this specific voucher
    IF EXISTS (
        SELECT 1 FROM public.voucher_redemptions
        WHERE voucher_id = v_record.id AND user_id = v_user_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'ALREADY_REDEEMED', 'message', 'You have already redeemed this voucher.');
    END IF;

    -- Calculate expiration date
    IF v_record.duration_days IS NOT NULL THEN
        v_expires_at := now() + (v_record.duration_days || ' days')::interval;
    ELSE
        v_expires_at := NULL; -- Lifetime access
    END IF;

    -- Record redemption
    INSERT INTO public.voucher_redemptions (voucher_id, user_id, redeemed_at, expires_at)
    VALUES (v_record.id, v_user_id, now(), v_expires_at);

    -- Increment counter
    UPDATE public.vouchers
    SET times_redeemed = times_redeemed + 1
    WHERE id = v_record.id;

    -- Create/Update active subscription for this user
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
            WHEN subscriptions.current_period_end IS NULL THEN NULL
            ELSE GREATEST(subscriptions.current_period_end, EXCLUDED.current_period_end)
        END,
        updated_at = now();

    -- Grant Pro status to user profile
    UPDATE public.users
    SET subscription_tier = 'pro',
        updated_at = now()
    WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Voucher redeemed successfully! Welcome to Pro Organizer.',
        'duration_days', v_record.duration_days,
        'expires_at', v_expires_at
    );
END;
$$;

-- 5. Function: Get Current User Active Subscription Details
CREATE OR REPLACE FUNCTION public.get_my_subscription()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_sub RECORD;
    v_tier subscription_tier;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('tier', 'free', 'has_subscription', false);
    END IF;

    SELECT subscription_tier INTO v_tier
    FROM public.users
    WHERE id = v_user_id;

    -- Find most relevant active subscription (priority: stripe, then voucher, then others)
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
            'tier', COALESCE(v_tier, 'pro'::subscription_tier),
            'has_subscription', true,
            'provider', v_sub.provider,
            'plan_type', v_sub.plan_type,
            'status', v_sub.status,
            'current_period_end', v_sub.current_period_end,
            'cancel_at_period_end', v_sub.cancel_at_period_end
        );
    ELSE
        RETURN jsonb_build_object(
            'tier', COALESCE(v_tier, 'free'::subscription_tier),
            'has_subscription', false
        );
    END IF;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.redeem_voucher(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_subscription() TO authenticated;

-- 6. Seed initial beta testing vouchers
INSERT INTO public.vouchers (code, description, duration_days, max_redemptions, is_active)
VALUES
    ('BETA-CLUB-60D', 'Club Beta Test Pass (60 Days Full Pro Access)', 60, 50, true),
    ('PADEL-VIP-90D', 'Padel Academy Partner Pass (90 Days Full Pro Access)', 90, 25, true),
    ('VOLLEY-CLUB-60D', 'Volleyball Club Partner Pass (60 Days Full Pro Access)', 60, 25, true),
    ('APP-STORE-REVIEW-PASS', 'Official App Store Reviewer Pass (365 Days)', 365, 10, true),
    ('DEMO-TEST-PRO', 'Internal QA & Demo Pass (30 Days)', 30, 100, true)
ON CONFLICT (code) DO NOTHING;
