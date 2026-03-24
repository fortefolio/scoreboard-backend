ALTER TABLE matches
ADD COLUMN group_label TEXT;

-- Index for performance when querying groups in a tournament
CREATE INDEX idx_matches_tournament_group ON matches(tournament_id, group_label) WHERE group_label IS NOT NULL;