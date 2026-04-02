-- Allow users to be searched by username or email
CREATE POLICY "Allow public read of users" ON public.users
    FOR SELECT
    USING (true);
