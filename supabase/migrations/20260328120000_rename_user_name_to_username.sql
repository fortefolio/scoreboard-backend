-- Rename name column to username in public.users
ALTER TABLE public.users RENAME COLUMN name TO username;

-- (Optional) Ensure username is unique
ALTER TABLE public.users ADD CONSTRAINT users_username_key UNIQUE (username);

-- Update the handle_new_user function to use the new column name
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, subscription_tier, email, username)
  VALUES (
    new.id, 
    'free', 
    new.email, 
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'username')
  ); -- Default new users to the free tier and sync email/username
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
