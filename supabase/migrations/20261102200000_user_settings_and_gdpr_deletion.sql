-- Migration: 20261102200000_user_settings_and_gdpr_deletion.sql
-- Description: Adds user preferences, display_name, deleted_at, GDPR data export RPC, and anonymized soft-delete RPC.

-- 1. Extend public.users table
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS display_name TEXT,
  ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{"language": "en", "default_sport": null, "haptics_enabled": true, "sound_enabled": true}'::jsonb NOT NULL,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Backfill display_name from username if empty
UPDATE public.users
SET display_name = username
WHERE display_name IS NULL AND username IS NOT NULL;

-- 2. Drop the cascading foreign key constraint from public.users to auth.users if it exists,
-- and recreate it without ON DELETE CASCADE so that deleting auth.users does NOT purge
-- tournament brackets and match history records of opponents/teams.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'users_id_fkey' AND table_name = 'users'
  ) THEN
    ALTER TABLE public.users DROP CONSTRAINT users_id_fkey;
  END IF;
END $$;

-- Also ensure matches.umpire_id does not block auth.users deletion
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'matches_umpire_id_fkey' AND table_name = 'matches'
  ) THEN
    ALTER TABLE public.matches DROP CONSTRAINT matches_umpire_id_fkey;
    ALTER TABLE public.matches ADD CONSTRAINT matches_umpire_id_fkey FOREIGN KEY (umpire_id) REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 3. Update permissions for authenticated users on public.users
GRANT UPDATE (username, display_name, preferences, updated_at) ON public.users TO authenticated;

-- 4. Update handle_new_user() trigger to initialize display_name and preferences
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, subscription_tier, email, username, display_name, preferences)
  VALUES (
    new.id, 
    'free', 
    new.email, 
    COALESCE(
      new.raw_user_meta_data->>'full_name', 
      new.raw_user_meta_data->>'name', 
      new.raw_user_meta_data->>'username',
      new.raw_user_meta_data->>'display_name',
      split_part(new.email, '@', 1)
    ),
    COALESCE(
      new.raw_user_meta_data->>'full_name', 
      new.raw_user_meta_data->>'name', 
      new.raw_user_meta_data->>'display_name',
      split_part(new.email, '@', 1)
    ),
    '{"language": "en", "default_sport": null, "haptics_enabled": true, "sound_enabled": true}'::jsonb
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. GDPR Article 20: Data Portability Export RPC
CREATE OR REPLACE FUNCTION public.export_user_data()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_user_id UUID;
  v_profile JSONB;
  v_tournaments JSONB;
  v_matches JSONB;
  v_follows JSONB;
  v_export JSONB;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to export account data';
  END IF;

  -- 1. Profile information
  SELECT jsonb_build_object(
    'id', id,
    'username', username,
    'display_name', display_name,
    'email', email,
    'subscription_tier', subscription_tier,
    'preferences', preferences,
    'created_at', created_at,
    'updated_at', updated_at
  ) INTO v_profile
  FROM public.users
  WHERE id = v_user_id;

  -- 2. Follows
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'entity_id', entity_id,
    'entity_type', entity_type,
    'created_at', created_at
  )), '[]'::jsonb) INTO v_follows
  FROM public.follows
  WHERE user_id = v_user_id;

  -- 3. Tournaments organized
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', id,
    'name', name,
    'sport_type', sport_type,
    'status', status,
    'created_at', created_at
  )), '[]'::jsonb) INTO v_tournaments
  FROM public.tournaments
  WHERE organizer_id = v_user_id;

  -- 4. Matches (organized or umpired)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', id,
    'sport_type', sport_type,
    'status', status,
    'is_organizer', (organizer_id = v_user_id),
    'is_umpire', (umpire_id = v_user_id),
    'created_at', created_at
  )), '[]'::jsonb) INTO v_matches
  FROM public.matches
  WHERE organizer_id = v_user_id OR umpire_id = v_user_id;

  v_export := jsonb_build_object(
    'exported_at', NOW(),
    'gdpr_notice', 'This export contains personal data associated with your ScoreBoard account under GDPR Article 20.',
    'profile', v_profile,
    'preferences', COALESCE(v_profile->'preferences', '{}'::jsonb),
    'follows', v_follows,
    'tournaments', v_tournaments,
    'matches', v_matches
  );

  RETURN v_export;
END;
$$;

GRANT EXECUTE ON FUNCTION public.export_user_data() TO authenticated;

-- 6. GDPR Article 17: Anonymized Soft-Delete RPC
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_user_id UUID;
  v_active_tournaments_count INT;
  v_active_matches_count INT;
  v_anonymized_tag TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to delete account';
  END IF;

  -- Safeguard 1: User cannot delete account if active or pending tournaments exist
  SELECT COUNT(*) INTO v_active_tournaments_count
  FROM public.tournaments
  WHERE organizer_id = v_user_id AND status IN ('pending', 'ongoing');

  IF v_active_tournaments_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete account while you have active or pending tournaments. Please complete or cancel them first.';
  END IF;

  -- Safeguard 2: User cannot delete account if active matches exist
  SELECT COUNT(*) INTO v_active_matches_count
  FROM public.matches
  WHERE organizer_id = v_user_id AND status IN ('scheduled', 'ongoing');

  IF v_active_matches_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete account while you have ongoing matches. Please finish or cancel them first.';
  END IF;

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

  -- 5. Anonymize profile in public.users to preserve bracket and opponent history
  v_anonymized_tag := 'former_player_' || substr(md5(v_user_id::text), 1, 8);
  UPDATE public.users
  SET username = v_anonymized_tag,
      display_name = 'Former Player',
      email = NULL,
      preferences = '{}'::jsonb,
      deleted_at = NOW(),
      updated_at = NOW()
  WHERE id = v_user_id;

  -- 6. Permanently delete from auth.users (erasing login credentials, password hash, email, and identity tokens)
  DELETE FROM auth.users
  WHERE id = v_user_id;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
