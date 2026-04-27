-- Security Cleanup: Fix "Function Search Path Mutable" warnings
-- This migration explicitly sets the search_path to 'public' for all functions
-- to prevent potential search_path hijacking attacks.

BEGIN;

-- 1. public.start_match_scoreboard
ALTER FUNCTION public.start_match_scoreboard(UUID, INTEGER) SET search_path = public;

-- 2. public.update_match_score
ALTER FUNCTION public.update_match_score() SET search_path = public;

-- 3. public.handle_match_umpire_default
ALTER FUNCTION public.handle_match_umpire_default() SET search_path = public;

-- 4. public.handle_new_user
ALTER FUNCTION public.handle_new_user() SET search_path = public;

-- 5. public.update_tennis_score
-- This one was missing the 'public.' prefix in its original definition
ALTER FUNCTION public.update_tennis_score(UUID, INTEGER) SET search_path = public;

-- 6. public.handle_new_signup
ALTER FUNCTION public.handle_new_signup() SET search_path = public;

-- 7. public.check_tournament_participant_limit
ALTER FUNCTION public.check_tournament_participant_limit() SET search_path = public;

-- 8. public.handle_umpire_invitation
ALTER FUNCTION public.handle_umpire_invitation() SET search_path = public;

-- 9. public.handle_match_completion_notification
ALTER FUNCTION public.handle_match_completion_notification() SET search_path = public;

COMMIT;
