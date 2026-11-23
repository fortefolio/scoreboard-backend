-- ============================================================================
-- Migration: Restore tr_update_match_score Trigger on Partitioned match_events
-- Description:
--   20261104150100_partition_match_events.sql renamed the legacy match_events
--   table to match_events_legacy and dropped it with CASCADE, which also
--   dropped tr_update_match_score without recreating it on the new partitioned
--   public.match_events table.
--   This restores AFTER INSERT trigger execution for clients that dispatch
--   point_won/score events with p_new_scores = NULL.
-- ============================================================================

DROP TRIGGER IF EXISTS tr_update_match_score ON public.match_events;
CREATE TRIGGER tr_update_match_score
AFTER INSERT ON public.match_events
FOR EACH ROW
EXECUTE FUNCTION public.update_match_score();
