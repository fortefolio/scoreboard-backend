-- Enable RLS on core tables (redundant if already enabled, but safe)
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;

-- 1. Matches RLS Policies
CREATE POLICY "Matches are viewable by everyone" 
ON public.matches FOR SELECT 
USING (true);

CREATE POLICY "Organizers can insert matches" 
ON public.matches FOR INSERT 
WITH CHECK (auth.uid() = organizer_id);

CREATE POLICY "Organizers can update their matches" 
ON public.matches FOR UPDATE 
USING (auth.uid() = organizer_id);

-- 2. Match Events RLS Policies
CREATE POLICY "Match events are viewable by everyone" 
ON public.match_events FOR SELECT 
USING (true);

CREATE POLICY "Only match organizers can insert events" 
ON public.match_events FOR INSERT 
WITH CHECK (
    auth.uid() IN (
        SELECT organizer_id FROM public.matches WHERE id = match_id
    )
);

-- 3. Tournaments RLS Policies
CREATE POLICY "Tournaments are viewable by everyone" 
ON public.tournaments FOR SELECT 
USING (true);

CREATE POLICY "Only Pro users can create tournaments" 
ON public.tournaments FOR INSERT 
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() 
        AND subscription_tier = 'pro'
    )
);

CREATE POLICY "Organizers can update their tournaments" 
ON public.tournaments FOR UPDATE 
USING (auth.uid() = organizer_id);
