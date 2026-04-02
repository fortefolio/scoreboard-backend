-- Create tournament_visibility type
CREATE TYPE tournament_visibility AS ENUM ('public', 'private', 'unlisted');

-- Add visibility to tournaments
ALTER TABLE public.tournaments 
ADD COLUMN IF NOT EXISTS visibility tournament_visibility DEFAULT 'public' NOT NULL;

-- Create an index for faster filtering by visibility
CREATE INDEX IF NOT EXISTS idx_tournaments_visibility ON public.tournaments(visibility);

-- 3. Update RLS for Tournaments
DROP POLICY IF EXISTS "Tournaments are viewable by everyone" ON public.tournaments;

CREATE POLICY "Tournaments visibility policy"
ON public.tournaments FOR SELECT
USING (
    visibility = 'public' 
    OR visibility = 'unlisted' 
    OR auth.uid() = organizer_id
);

-- 4. Update RLS for Matches to inherit tournament visibility
DROP POLICY IF EXISTS "Matches are viewable by everyone" ON public.matches;

CREATE POLICY "Matches visibility policy"
ON public.matches FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
        AND (t.visibility = 'public' OR t.visibility = 'unlisted' OR t.organizer_id = auth.uid())
    )
    OR (tournament_id IS NULL) -- For standalone matches
);

-- 5. Update RLS for Match Events to inherit match/tournament visibility
DROP POLICY IF EXISTS "Match events are viewable by everyone" ON public.match_events;

CREATE POLICY "Match events visibility policy"
ON public.match_events FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.matches m
        JOIN public.tournaments t ON t.id = m.tournament_id
        WHERE m.id = match_id
        AND (t.visibility = 'public' OR t.visibility = 'unlisted' OR t.organizer_id = auth.uid())
    )
    OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE m.id = match_id
        AND m.tournament_id IS NULL -- For standalone matches
    )
);
