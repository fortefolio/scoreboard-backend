-- Allow organizers to delete their own tournaments
CREATE POLICY "Organizers can delete their own tournaments" 
ON public.tournaments FOR DELETE 
USING (auth.uid() = organizer_id);