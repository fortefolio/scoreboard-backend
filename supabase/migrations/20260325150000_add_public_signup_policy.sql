-- Allow anyone to insert into tournament_participants for public signups
-- (Optionally, you could add a check if tournament.status = 'pending')
ALTER TABLE public.tournament_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public signups" ON public.tournament_participants
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tournaments
            WHERE id = tournament_id
            AND status = 'pending'
        )
    );

-- Ensure anyone can read participants (needed for the public signup page and real-time updates)
CREATE POLICY "Allow public read of participants" ON public.tournament_participants
    FOR SELECT
    USING (true);
