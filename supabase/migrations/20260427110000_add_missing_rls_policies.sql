-- 1. RLS Policies for public.bracket_matches
-- Allows visibility to be inherited from the parent tournament's visibility settings.
CREATE POLICY "Bracket matches visibility policy"
ON public.bracket_matches FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = public.bracket_matches.tournament_id
        AND (t.visibility = 'public' OR t.visibility = 'unlisted' OR t.organizer_id = auth.uid())
    )
);

-- Allows only the tournament organizer to manage (insert/update/delete) bracket structure.
CREATE POLICY "Organizers can manage bracket matches"
ON public.bracket_matches FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = public.bracket_matches.tournament_id
        AND t.organizer_id = auth.uid()
    )
);

-- 2. RLS Policies for public.user_tokens
-- Ensures users can only see and manage their own device tokens for privacy and security.
CREATE POLICY "Users can manage their own tokens"
ON public.user_tokens FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
