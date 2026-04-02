-- Change court_number to court (TEXT)
ALTER TABLE public.matches 
RENAME COLUMN court_number TO court;

ALTER TABLE public.matches
ALTER COLUMN court TYPE TEXT USING court::TEXT;
