-- Add scheduling columns to matches
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS round_date DATE;

-- Create an index for faster filtering by date
CREATE INDEX IF NOT EXISTS idx_matches_scheduled_at ON public.matches(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_matches_round_date ON public.matches(round_date);
