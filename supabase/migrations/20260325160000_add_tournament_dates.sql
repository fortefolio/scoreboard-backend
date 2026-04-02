-- Add start_date and end_date to tournaments to accommodate multi-day events
ALTER TABLE public.tournaments 
ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ;

-- Add a constraint to ensure end_date is after start_date
ALTER TABLE public.tournaments
ADD CONSTRAINT check_dates_order
CHECK (end_date >= start_date);
