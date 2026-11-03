-- Migration: Ensure legacy/manual Pro users have active subscription records
-- and update get_my_subscription() to gracefully handle manual/lifetime pro users.

-- Backfill any existing users who have subscription_tier = 'pro' but no record in subscriptions
INSERT INTO public.subscriptions (
    user_id,
    provider,
    status,
    plan_type,
    current_period_end,
    cancel_at_period_end,
    updated_at
)
SELECT 
    id AS user_id,
    'manual' AS provider,
    'active' AS status,
    'lifetime' AS plan_type,
    NULL AS current_period_end,
    false AS cancel_at_period_end,
    now() AS updated_at
FROM public.users
WHERE subscription_tier = 'pro'
ON CONFLICT (user_id, provider) DO UPDATE SET
    status = 'active',
    plan_type = 'lifetime',
    updated_at = now();

-- Update get_my_subscription() function
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

    -- Find most relevant active subscription (priority: stripe, then voucher, then manual/other)
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
    ELSIF v_tier = 'pro' THEN
        -- Legacy, admin-granted, or lifetime pro without provider-specific row
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
