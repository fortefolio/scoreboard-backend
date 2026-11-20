-- ============================================================================
-- Scaling indexes for follows fan-out & notifications queries
-- ============================================================================

-- Index-Only Scan for match/tournament/team follower fan-out in triggers
CREATE INDEX IF NOT EXISTS idx_follows_entity_lookup
  ON public.follows (entity_type, entity_id, user_id);

-- Partial index for fast unread badge counts (app, web bell, APNs badge)
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id, created_at DESC)
  WHERE read_at IS NULL;

-- Expression index for per-match notification aggregation lookup
CREATE INDEX IF NOT EXISTS idx_notifications_user_match_id
  ON public.notifications (user_id, ((data->>'match_id')));
