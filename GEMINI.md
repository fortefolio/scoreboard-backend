# ScoreBoard - Core Schema & Backend Directives

## 1. Tech Stack
* **Backend:** Supabase (PostgreSQL, Authentication, Edge Functions, Real-time WebSockets) [4, 5].

## 2. PostgreSQL Database Schema
* **Users:** Profiles, authentication, `username`, `email`, and `subscription_tier` ('free' or 'pro') [6, 7].
* **Tournaments:** `id`, `organizer_id` (UUID), `name`, `sport_type`, `status`, `visibility` ('public', 'private', 'unlisted'), `start_date`, `end_date` [8].
* **Tournament_Participants:** `id`, `tournament_id`, `team_id`, `seed` [9].
* **Bracket_Matches:** `id`, `tournament_id`, `match_id`, `round_number`, `next_match_id`, `next_match_slot` [9].
* **Matches:** `id`, `organizer_id`, sport type, participants, `status`, `scheduled_at`, `round_date`, `court` (TEXT), `settings` (JSONB), and `scores` (JSONB) [6, 10].
* **Match_Events:** `id` (UUID), `match_id`, `created_at`, `event_data` (JSONB) [6, 11].
* **Follows:** `id`, `user_id`, `entity_id`, `entity_type` ('team', 'player', 'competition') [12].
* **User_Tokens:** `id`, `user_id`, `fcm_token` (Text) [13].

## 3. JSONB Event Structures (`event_data`)
* **Football (Soccer):** `{ "type": "goal", "player_id": "123", "minute": 45 }` [6, 14].
* **Basketball:** Points Scored or Foul events [14].
* **Tennis:** Point Won tracking context (Sets, Games, Points), `toss_coin` (winner_index), `start_scoreboard` [14].
* **Volleyball/Beach Volleyball:** Point Scored or Timeout events [15].

## 4. Backend Engine Directives
* **PostgreSQL Triggers:** Write PL/pgSQL database triggers that automatically calculate and update the `scores` JSON column on the `Matches` table whenever a new `Match_Event` is inserted [3, 16].
* **Real-time Broadcaster:** All updates to the `Matches` table are broadcast via Supabase Real-time to connected clients for live scoreboard updates.
* **Row Level Security (RLS):** 
  * Matches: SELECT is public if the tournament is 'public'/'unlisted' or if `auth.uid() = organizer_id`. INSERT/UPDATE requires `auth.uid() = organizer_id` [17, 18].
  * Match Events: SELECT is public if the parent match/tournament is 'public'/'unlisted' or if `auth.uid()` is the organizer. INSERT requires `auth.uid()` IN (SELECT `organizer_id` FROM `matches` WHERE `id` = `match_id`) [17, 19].
  * Tournaments (Pro Tier): SELECT is public if `visibility` IN ('public', 'unlisted') OR `auth.uid() = organizer_id`. INSERT requires EXISTS (SELECT 1 FROM `users` WHERE `users.id` = `auth.uid()` AND `users.subscription_tier` = 'pro') [17, 20].
* **Social Feed View:** Create a PostgreSQL View (UNION ALL query) that stitches together completed matches and new tournaments for infinite scrolling [3, 21, 22].
* **Edge Functions & Webhooks:**
  * Stripe Webhook: Listens for `checkout.session.completed`, extracts `supabase_user_id` from metadata, and updates `users.subscription_tier` to 'pro' [3, 23, 24].
  * FCM Push Notifications: Triggered by a Database Webhook when `matches.status = 'completed'`. Queries `follows` and `user_tokens` tables to send payloads to Firebase HTTP v1 API [3, 23, 25].

## 5. Operational Procedures
* **Database Updates:** Always inform the user if a database reset (`supabase db reset`), migration application, or any other manual action is required after changing the database schema, triggers, or views.

