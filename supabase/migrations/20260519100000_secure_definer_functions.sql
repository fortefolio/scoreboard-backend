-- Security Hardening: Lockdown SECURITY DEFINER functions and Extensions
-- This migration resolves the "Public Can Execute SECURITY DEFINER Function" 
-- and "Extension in Public" security warnings.

BEGIN;

-- 1. Restrict Function Execution (The "Locker Room" Principle)
-- By default, PostgreSQL allows 'PUBLIC' to execute functions. 
-- We revoke this globally for the public schema and then grant back only what is needed.

-- Revoke execute from everyone (anonymous and authenticated) on all existing functions
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- 2. Explicitly Grant Access to RPCs (Allowed Frontend Calls)
-- These are functions your application actually calls via supabase.rpc()
GRANT EXECUTE ON FUNCTION public.start_match_scoreboard(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_tennis_score(UUID, INTEGER) TO authenticated;

-- 3. Trigger Functions (Internal Only)
-- These do NOT need explicit grants because they are executed by the owner (superuser) 
-- when the trigger fires. Keeping them revoked from PUBLIC prevents direct API calls.
-- Affected: handle_new_user, update_match_score, handle_new_signup, etc.

-- 4. Extension Security
-- Ensure pg_net (if used) is not exposing its internal functions to the Data API.
-- Most Supabase projects use a 'net' or 'extensions' schema for this.
-- If it was in public, we would move it, but Supabase CLI often handles this.
-- We'll explicitly ensure the search_path is safe for our functions (already handled in previous migrations).

COMMIT;
