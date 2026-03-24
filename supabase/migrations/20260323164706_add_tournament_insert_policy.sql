-- Allow users to create their own tournaments
CREATE POLICY "Organizers can create their own tournaments"
ON public.tournaments
FOR INSERT
WITH CHECK (auth.uid() = organizer_id);

-- Also allow users to see their own tournaments (in case we missed this earlier)
CREATE POLICY "Organizers can view their own tournaments"
ON public.tournaments
FOR SELECT
USING (auth.uid() = organizer_id);