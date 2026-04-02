-- Update the handle_new_user function to be more resilient with common Supabase metadata keys
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, subscription_tier, email, username)
  VALUES (
    new.id, 
    'free', 
    new.email, 
    COALESCE(
      new.raw_user_meta_data->>'full_name', 
      new.raw_user_meta_data->>'name', 
      new.raw_user_meta_data->>'username',
      new.raw_user_meta_data->>'display_name',
      new.raw_user_meta_data->>'user_name',
      split_part(new.email, '@', 1)
    )
  ); -- Default new users to the free tier and sync email/username
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
