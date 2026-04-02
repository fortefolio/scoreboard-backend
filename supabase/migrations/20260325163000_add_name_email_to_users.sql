-- Add name and email columns to the public.users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS name TEXT,
ADD COLUMN IF NOT EXISTS email TEXT;

-- (Optional) If we want to ensure uniqueness on email if we're managing it manually
-- ALTER TABLE public.users ADD CONSTRAINT users_email_key UNIQUE (email);
