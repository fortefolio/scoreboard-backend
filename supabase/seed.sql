SET session_replication_role = 'replica';
SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- \restrict G6ESZZhvp2LmqZofroKZlaD81bkDZVhxsqPHtUBkBMi8zRqvzl1q9tWAit6eHeh

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."audit_log_entries" ("instance_id", "id", "payload", "created_at", "ip_address") VALUES
	('00000000-0000-0000-0000-000000000000', '06074c38-5e38-4eea-97eb-a5b49289d694', '{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"gmail@chucknorris.com","user_id":"171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0","user_phone":""}}', '2026-05-21 09:00:58.814624+00', ''),
	('00000000-0000-0000-0000-000000000000', 'fb0a5025-48ef-4701-83f6-029f5e000f81', '{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"gjoforte@proton.me","user_id":"608bf4ce-7f75-4d89-a6d4-65397b7b68aa","user_phone":""}}', '2026-05-21 09:01:12.28007+00', ''),
	('00000000-0000-0000-0000-000000000000', '9f6d30dc-acf7-48f6-a899-7a1d6b057d08', '{"action":"login","actor_id":"171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0","actor_username":"gmail@chucknorris.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2026-05-21 09:01:29.581949+00', ''),
	('00000000-0000-0000-0000-000000000000', '51b8e130-6bc3-4893-8eaa-8707b0a446a7', '{"action":"login","actor_id":"608bf4ce-7f75-4d89-a6d4-65397b7b68aa","actor_username":"gjoforte@proton.me","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2026-05-21 09:08:38.699461+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f71abcd7-11a0-4c68-8f6a-de7e50a3c30a', '{"action":"token_refreshed","actor_id":"171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0","actor_username":"gmail@chucknorris.com","actor_via_sso":false,"log_type":"token"}', '2026-05-21 09:59:41.527858+00', ''),
	('00000000-0000-0000-0000-000000000000', 'cdcfb377-a6a0-40b4-aa10-f95f6dc9b841', '{"action":"token_revoked","actor_id":"171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0","actor_username":"gmail@chucknorris.com","actor_via_sso":false,"log_type":"token"}', '2026-05-21 09:59:41.529959+00', '');


--
-- Data for Name: custom_oauth_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."users" ("instance_id", "id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "invited_at", "confirmation_token", "confirmation_sent_at", "recovery_token", "recovery_sent_at", "email_change_token_new", "email_change", "email_change_sent_at", "last_sign_in_at", "raw_app_meta_data", "raw_user_meta_data", "is_super_admin", "created_at", "updated_at", "phone", "phone_confirmed_at", "phone_change", "phone_change_token", "phone_change_sent_at", "email_change_token_current", "email_change_confirm_status", "banned_until", "reauthentication_token", "reauthentication_sent_at", "is_sso_user", "deleted_at", "is_anonymous") VALUES
	('00000000-0000-0000-0000-000000000000', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'authenticated', 'authenticated', 'gjoforte@proton.me', '$2a$10$U8EDWAYsWqUFWBZjg4Z8XuwJswaEEtf0bDyIrM0si1xUHvTbughTm', '2026-05-21 09:01:12.288918+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-05-21 09:08:38.701112+00', '{"provider": "email", "providers": ["email"]}', '{"email_verified": true}', NULL, '2026-05-21 09:01:12.275794+00', '2026-05-21 09:08:38.70527+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'authenticated', 'authenticated', 'gmail@chucknorris.com', '$2a$10$S7d1f13H2S6SFGv/.8cvGepiprHGRkDU2IGR4CnPtTuWbxtaCwjGi', '2026-05-21 09:00:58.819877+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-05-21 09:01:29.583222+00', '{"provider": "email", "providers": ["email"]}', '{"email_verified": true}', NULL, '2026-05-21 09:00:58.801705+00', '2026-05-21 09:59:41.533968+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."identities" ("provider_id", "user_id", "identity_data", "provider", "last_sign_in_at", "created_at", "updated_at", "id") VALUES
	('171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', '{"sub": "171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0", "email": "gmail@chucknorris.com", "email_verified": false, "phone_verified": false}', 'email', '2026-05-21 09:00:58.813678+00', '2026-05-21 09:00:58.81371+00', '2026-05-21 09:00:58.81371+00', '42291985-258f-439e-9ea2-81cb755bdfab'),
	('608bf4ce-7f75-4d89-a6d4-65397b7b68aa', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', '{"sub": "608bf4ce-7f75-4d89-a6d4-65397b7b68aa", "email": "gjoforte@proton.me", "email_verified": false, "phone_verified": false}', 'email', '2026-05-21 09:01:12.278992+00', '2026-05-21 09:01:12.279017+00', '2026-05-21 09:01:12.279017+00', 'c646f94b-0d62-4193-b1c4-7fb645bfa02e');


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."sessions" ("id", "user_id", "created_at", "updated_at", "factor_id", "aal", "not_after", "refreshed_at", "user_agent", "ip", "tag", "oauth_client_id", "refresh_token_hmac_key", "refresh_token_counter", "scopes") VALUES
	('ee390154-dc37-4e8b-b04b-bcada6a1e7e8', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', '2026-05-21 09:08:38.701198+00', '2026-05-21 09:08:38.701198+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36', '192.168.65.1', NULL, NULL, NULL, NULL, NULL),
	('13136671-0b0f-43c8-861b-ad5712cbb233', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', '2026-05-21 09:01:29.583713+00', '2026-05-21 09:59:41.53626+00', NULL, 'aal1', NULL, '2026-05-21 09:59:41.536195', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15', '192.168.65.1', NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."mfa_amr_claims" ("session_id", "created_at", "updated_at", "authentication_method", "id") VALUES
	('13136671-0b0f-43c8-861b-ad5712cbb233', '2026-05-21 09:01:29.590789+00', '2026-05-21 09:01:29.590789+00', 'password', 'e8038fb3-37f2-4fb9-bc81-a6013df0abf3'),
	('ee390154-dc37-4e8b-b04b-bcada6a1e7e8', '2026-05-21 09:08:38.70574+00', '2026-05-21 09:08:38.70574+00', 'password', 'd6287517-1184-4ba2-b194-8a56f4de8373');


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."refresh_tokens" ("instance_id", "id", "token", "user_id", "revoked", "created_at", "updated_at", "parent", "session_id") VALUES
	('00000000-0000-0000-0000-000000000000', 2, '2xmalkxsi6qs', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', false, '2026-05-21 09:08:38.703639+00', '2026-05-21 09:08:38.703639+00', NULL, 'ee390154-dc37-4e8b-b04b-bcada6a1e7e8'),
	('00000000-0000-0000-0000-000000000000', 1, 'vbw4btznxqgc', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', true, '2026-05-21 09:01:29.587418+00', '2026-05-21 09:59:41.530384+00', NULL, '13136671-0b0f-43c8-861b-ad5712cbb233'),
	('00000000-0000-0000-0000-000000000000', 3, '6ekaro2kbj6p', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', false, '2026-05-21 09:59:41.533078+00', '2026-05-21 09:59:41.533078+00', 'vbw4btznxqgc', '13136671-0b0f-43c8-861b-ad5712cbb233');


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: webauthn_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: webauthn_credentials; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."users" ("id", "subscription_tier", "created_at", "updated_at", "username", "email") VALUES
	('608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'free', '2026-05-21 09:01:12.275335+00', '2026-05-21 09:01:12.275335+00', 'gjoforte', 'gjoforte@proton.me'),
	('171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'pro', '2026-05-21 09:00:58.798514+00', '2026-05-21 09:00:58.798514+00', 'gmail', 'gmail@chucknorris.com');


--
-- Data for Name: tournaments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."tournaments" ("id", "organizer_id", "name", "sport_type", "status", "created_at", "updated_at", "settings", "start_date", "end_date", "visibility", "signup_schema") VALUES
	('eda9efc7-04cf-4cc2-bd02-579daf89e223', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Torneio Maribar 2026', 'Volleyball', 'ongoing', '2026-05-21 09:03:12.451753+00', '2026-05-21 09:03:12.451753+00', '{"default": {"max_sets": 3, "points_per_set": 25}, "stage_1": {"type": "groups", "advance_per_group": 2, "advance_best_thirds": 0}, "max_teams": 16}', '2026-07-25 00:00:00+00', '2026-07-26 00:00:00+00', 'public', '[]'),
	('673ad917-5d42-4dab-bd5e-9276f4b7c6f8', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Torneio Queima das Fitas 2026', 'Tennis', 'ongoing', '2026-05-21 09:03:54.086018+00', '2026-05-21 09:03:54.086018+00', '{"default": {"max_sets": 3}, "stage_1": {"type": "bracket"}, "max_teams": 16}', '2026-05-23 00:00:00+00', '2026-05-24 00:00:00+00', 'public', '[]'),
	('d0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Torneio Guadiana 2026', 'Football', 'ongoing', '2026-05-21 09:16:33.374277+00', '2026-05-21 09:16:33.374277+00', '{"default": {"format": "halves", "duration": 90}, "stage_1": {"type": "groups", "advance_per_group": 2, "advance_best_thirds": 0}, "max_teams": 8}', '2026-08-29 00:00:00+00', '2026-08-30 00:00:00+00', 'public', '[]'),
	('7526b704-0332-4792-ae62-7be563109f56', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', '35º Torneio de Voleibol de Praia – São Pedro de Moel ', 'Volleyball', 'ongoing', '2026-05-21 10:00:21.74463+00', '2026-05-21 10:00:21.74463+00', '{"default": {"max_sets": 3, "points_per_set": 25}, "stage_1": {"type": "groups", "advance_per_group": 2, "advance_best_thirds": 0}, "max_teams": 16, "number_of_courts": 2}', '2026-08-22 00:00:00+00', '2026-08-23 00:00:00+00', 'public', '[]'),
	('7b490506-79d3-486b-8111-cf339a6cadc9', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', '33º Torneio 4x4 - Paredes de Vitória ', 'Volleyball', 'ongoing', '2026-05-21 10:06:08.988149+00', '2026-05-21 10:06:08.988149+00', '{"default": {"max_sets": 3, "points_per_set": 25}, "stage_1": {"type": "groups", "advance_per_group": 2, "advance_best_thirds": 0}, "max_teams": 16, "number_of_courts": 4}', '2026-08-29 00:00:00+00', '2026-08-30 00:00:00+00', 'public', '[]');


--
-- Data for Name: matches; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."matches" ("id", "organizer_id", "sport_type", "participants", "status", "created_at", "updated_at", "round_number", "match_order", "tournament_id", "umpire_id", "group_label", "bracket_type", "court", "scheduled_at", "round_date", "settings", "scores") VALUES
	('74da4fda-f173-4e3b-af05-6b414567c04c', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 1"}, {"name": "Team 4"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('8113bfde-28e9-4a74-88a9-095415b53df7', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 2"}, {"name": "Team 3"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('85fbe42b-4c0b-4c99-adfd-fdebdfab6e28', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 2"}, {"name": "Team 4"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('b4181f5b-b1fe-47fb-814c-3b5cc8d513c4', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 3"}, {"name": "Team 4"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('66001de2-8331-417c-a5c2-55eea0388c2f', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 5"}, {"name": "Team 6"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('58d256a3-106b-4278-83f0-10374a7b7d0a', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 5"}, {"name": "Team 7"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('df654ae6-dc26-4c81-afed-02a83eee10eb', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 5"}, {"name": "Team 8"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('681f4b60-5bc6-4b41-bc16-05720ed96541', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 6"}, {"name": "Team 7"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('6f3be85a-0bc0-4690-adf4-38fb9291fbbc', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 6"}, {"name": "Team 8"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('877b5d56-e4fd-43ea-a253-7c92ff669c05', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 7"}, {"name": "Team 8"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('4e285673-26fb-4945-b718-764800d03672', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 9"}, {"name": "Team 10"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'C', 'main', NULL, NULL, NULL, '{}', '{}'),
	('c67fce6f-cf4e-4ea9-afb2-24a722b2809c', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 9"}, {"name": "Team 11"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'C', 'main', NULL, NULL, NULL, '{}', '{}'),
	('259f3975-ffbe-4c01-924b-30c06c46d299', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 9"}, {"name": "Team 12"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'C', 'main', NULL, NULL, NULL, '{}', '{}'),
	('01e1f5c3-0266-4a8d-a51c-fe28799b7e97', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 10"}, {"name": "Team 11"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'C', 'main', NULL, NULL, NULL, '{}', '{}'),
	('d85faae7-16e3-48d7-959c-2ab828c82620', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 10"}, {"name": "Team 12"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'C', 'main', NULL, NULL, NULL, '{}', '{}'),
	('4386626a-6970-4f66-b551-3de20eabde78', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 11"}, {"name": "Team 12"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'C', 'main', NULL, NULL, NULL, '{}', '{}'),
	('ca7b5278-f948-42d6-bfcb-f616645db6d3', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 13"}, {"name": "Team 14"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'D', 'main', NULL, NULL, NULL, '{}', '{}'),
	('01f518e9-a7c7-4de7-8048-640e96392be3', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 13"}, {"name": "Team 15"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'D', 'main', NULL, NULL, NULL, '{}', '{}'),
	('b5742eef-2e09-43c3-be81-79816b6d2f0b', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 13"}, {"name": "Team 16"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'D', 'main', NULL, NULL, NULL, '{}', '{}'),
	('d86555d7-4ce9-4b9e-81e1-8ee81de089b6', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 14"}, {"name": "Team 15"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'D', 'main', NULL, NULL, NULL, '{}', '{}'),
	('ba5280ff-8167-4db8-82ac-68101b84b65c', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 14"}, {"name": "Team 16"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'D', 'main', NULL, NULL, NULL, '{}', '{}'),
	('8820aeaa-ab72-46ad-ac18-f3c5ca60719a', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 15"}, {"name": "Team 16"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, 'D', 'main', NULL, NULL, NULL, '{}', '{}'),
	('ca9ac43b-f86f-42b4-8e6f-ef1af9a889d4', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[{"name": "Player 2"}, {"name": "Player 15"}]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 1, 2, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('d03f3840-18ea-4426-9205-de56cc957bae', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[{"name": "Player 3"}, {"name": "Player 14"}]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 1, 3, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('771bfc2e-c153-4453-a432-c197305b86da', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[{"name": "Player 4"}, {"name": "Player 13"}]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 1, 4, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('a9bfa066-2e04-438d-bab1-9706b6e8ee58', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[{"name": "Player 5"}, {"name": "Player 12"}]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 1, 5, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('23574a21-d908-435a-b922-f15948110c9d', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[{"name": "Player 6"}, {"name": "Player 11"}]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 1, 6, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('700e9f5d-e124-4fae-8e3e-22aa84a81307', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[{"name": "Player 7"}, {"name": "Player 10"}]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 1, 7, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('57f89f17-9f1c-4fa1-a2e8-2c65e301e97d', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[{"name": "Player 8"}, {"name": "Player 9"}]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 1, 8, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('df6f9bbf-71da-47eb-b148-800e2e185971', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 2, 1, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('f257b37a-725d-4584-8341-9231acfd3743', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 2, 2, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('552884bf-4a84-4691-ba2e-9fc60928fb45', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 2, 3, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('e2b122c2-bafd-4a4f-95b1-540e5c9d3295', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 2, 4, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('a3436c02-754b-440c-8f50-317c8c0b405f', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 3, 1, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('cf7626a2-7a6a-43c7-aa6f-0fdf6eea4dca', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 3, 2, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('b3a88f8e-6c47-47aa-9826-202796bf7956', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[]', 'scheduled', '2026-05-21 09:06:13.665689+00', '2026-05-21 09:06:13.665689+00', 4, 1, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, NULL, 'main', NULL, NULL, NULL, '{}', '{}'),
	('b6a65dc1-2d9b-4ac1-9e5a-389bca870074', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 1"}, {"name": "Team 2"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('28587f75-e33b-4563-aa0e-752764f5c53c', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "AAC OAF"}, {"name": "SC Ribeirense"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('bf436faf-3d23-4755-a154-d4657340f4c5', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "AAC OAF"}, {"name": "Esperança AC"}]', 'ongoing', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('97fdce39-638c-48e7-a975-fdedd2530d11', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "CF Marialvas"}, {"name": "Esperança AC"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('a769506a-0df1-4e1a-8372-121e2499c69e', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "CF Marialvas"}, {"name": "SC Ribeirense"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('7f5cb5b6-52d8-47ad-ba00-c166b8cfe65a', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "Esperança AC"}, {"name": "SC Ribeirense"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('60a25b6e-d27e-4380-a368-c9b986043ae8', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "Vigor Mocidade"}, {"name": "Red Eagles"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('c4aa5af6-8e2f-4448-b5e1-0b0442e0b13d', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "Vigor Mocidade"}, {"name": "União FC"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('8809c385-fbac-4194-975c-0a4c3f54e60d', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "Ançã FC"}, {"name": "Red Eagles"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('5f15f6e9-e84a-4e19-ba77-2f91f55d35cc', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "Ançã FC"}, {"name": "União FC"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('49fa9166-91cc-482a-8547-d00fcb9cf0bd', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "Red Eagles"}, {"name": "União FC"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('b3f211bb-192a-4cec-a904-89a115406a21', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 1"}, {"name": "Team 3"}]', 'scheduled', '2026-05-21 09:04:43.622708+00', '2026-05-21 09:04:43.622708+00', 1, NULL, 'eda9efc7-04cf-4cc2-bd02-579daf89e223', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('4424131e-bf4b-4dc8-9cbe-5273e1f85b19', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "AAC OAF"}, {"name": "CF Marialvas"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'A', 'main', NULL, NULL, NULL, '{}', '{}'),
	('40c578f2-a059-4712-85ac-d1bdc64118d9', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "Vigor Mocidade"}, {"name": "Ançã FC"}]', 'scheduled', '2026-05-21 09:19:22.322386+00', '2026-05-21 09:19:22.322386+00', 1, NULL, 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'B', 'main', NULL, NULL, NULL, '{}', '{}'),
	('f53c241a-125c-4934-8faf-9197b3f9d3e9', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Football', '[{"name": "SL Benfica"}, {"name": "FC Porto"}]', 'ongoing', '2026-05-21 09:49:28.8577+00', '2026-05-21 09:49:28.8577+00', NULL, NULL, NULL, '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', NULL, 'main', NULL, '2026-05-21 09:49:28.814+00', NULL, '{}', '{}'),
	('c54bf028-3735-412c-aa22-3ade1ce0cc7d', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Brasil"}, {"name": "EUA"}]', 'ongoing', '2026-05-21 09:49:11.366876+00', '2026-05-21 09:53:52.452376+00', NULL, NULL, NULL, '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', NULL, 'main', NULL, '2026-05-21 09:49:11.333+00', NULL, '{}', '{"sets": [], "current": {"away": 0, "home": 0}, "current_set": 1, "serving_index": 0}'),
	('f06b6026-d4cd-4f95-987c-e37ed5023274', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[{"name": "Janick Sinner"}, {"name": "Carlos Alcaraz"}]', 'ongoing', '2026-05-21 09:48:32.009872+00', '2026-05-21 09:54:27.983434+00', NULL, NULL, NULL, '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', NULL, 'main', NULL, '2026-05-21 09:48:31.967+00', NULL, '{}', '{"sets": [], "current": {"away": 0, "home": 0}, "current_set": 1, "serving_index": 0}'),
	('078bbc3f-1f9b-45a9-8a39-7224c8456b05', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 1"}, {"name": "Team 2"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'A', 'main', '1', NULL, NULL, '{}', '{}'),
	('ca386d1a-c727-4b9f-9f94-88263f474528', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 1"}, {"name": "Team 3"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'A', 'main', '2', NULL, NULL, '{}', '{}'),
	('c98bb593-1920-4943-a6e7-cb4f81297658', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 1"}, {"name": "Team 4"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'A', 'main', '1', NULL, NULL, '{}', '{}'),
	('763e43f8-0682-451d-a26e-70c18f7ec04b', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 2"}, {"name": "Team 3"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'A', 'main', '2', NULL, NULL, '{}', '{}'),
	('2f5ca0df-299b-420e-9e8d-7e69b3c007f0', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 2"}, {"name": "Team 4"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'A', 'main', '1', NULL, NULL, '{}', '{}'),
	('1af03d69-f9b1-4673-ad52-c47001bc3ec4', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 3"}, {"name": "Team 4"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'A', 'main', '2', NULL, NULL, '{}', '{}'),
	('4be6d726-a11a-4c08-9422-9bb3f111e469', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 5"}, {"name": "Team 6"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'B', 'main', '1', NULL, NULL, '{}', '{}'),
	('15a85f59-2c90-4f8c-9a2a-5f5821d5611a', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 5"}, {"name": "Team 7"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'B', 'main', '2', NULL, NULL, '{}', '{}'),
	('4fa3a896-c641-46f8-8c71-1db95f8b4116', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 5"}, {"name": "Team 8"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'B', 'main', '1', NULL, NULL, '{}', '{}'),
	('c2d478cf-d732-45df-9736-26019c153e16', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 6"}, {"name": "Team 7"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'B', 'main', '2', NULL, NULL, '{}', '{}'),
	('1d5ddd00-e4b1-4a7c-8d4a-e08cca323c5f', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 6"}, {"name": "Team 8"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'B', 'main', '1', NULL, NULL, '{}', '{}'),
	('f6cfc1c0-068d-4507-b542-23ec3ef16069', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 7"}, {"name": "Team 8"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'B', 'main', '2', NULL, NULL, '{}', '{}'),
	('d7e0ee9e-ee68-436e-a482-e0efc957560f', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 9"}, {"name": "Team 10"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'C', 'main', '1', NULL, NULL, '{}', '{}'),
	('110c8acd-5366-4701-834e-246742681a28', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 9"}, {"name": "Team 11"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'C', 'main', '2', NULL, NULL, '{}', '{}'),
	('b7c93328-aed5-4dc6-9274-d7ac780f160c', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 9"}, {"name": "Team 12"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'C', 'main', '1', NULL, NULL, '{}', '{}'),
	('fd26b592-6785-401d-a09b-4346277f2edb', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 10"}, {"name": "Team 11"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'C', 'main', '2', NULL, NULL, '{}', '{}'),
	('d8965299-8163-4c25-b368-61e5a2dffb41', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 10"}, {"name": "Team 12"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'C', 'main', '1', NULL, NULL, '{}', '{}'),
	('4e08c525-e883-49b8-a1ea-3cd77e3e5b63', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 11"}, {"name": "Team 12"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'C', 'main', '2', NULL, NULL, '{}', '{}'),
	('bd5fcff9-1ff7-4173-87f2-6396cef8a605', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 13"}, {"name": "Team 14"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'D', 'main', '1', NULL, NULL, '{}', '{}'),
	('75f1d044-c856-471a-99e8-c45cf1482e54', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 13"}, {"name": "Team 15"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'D', 'main', '2', NULL, NULL, '{}', '{}'),
	('ffacbb7f-df05-4d25-b0a4-aad6f7150630', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 13"}, {"name": "Team 16"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'D', 'main', '1', NULL, NULL, '{}', '{}'),
	('df7d769a-dac9-4aa8-b981-ec25f6ff86f4', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 14"}, {"name": "Team 15"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'D', 'main', '2', NULL, NULL, '{}', '{}'),
	('c40325f1-4be3-4637-a1be-4ec204cc36e9', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 14"}, {"name": "Team 16"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'D', 'main', '1', NULL, NULL, '{}', '{}'),
	('67ed0941-7823-4c59-9a57-4591d711bbc7', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 15"}, {"name": "Team 16"}]', 'scheduled', '2026-05-21 10:00:57.044786+00', '2026-05-21 10:00:57.044786+00', 1, NULL, '7526b704-0332-4792-ae62-7be563109f56', NULL, 'D', 'main', '2', NULL, NULL, '{}', '{}'),
	('8af936fe-0a2a-4aa6-ae0e-0d5710f14f22', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 1"}, {"name": "Team 2"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'A', 'main', '1', NULL, NULL, '{}', '{}'),
	('5d3c46ef-329d-4bc0-a4ab-0acdc6e4ebd7', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 1"}, {"name": "Team 3"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'A', 'main', '2', NULL, NULL, '{}', '{}'),
	('86b8fbde-e0ae-4090-88d8-20c11e52b7dd', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 1"}, {"name": "Team 4"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'A', 'main', '3', NULL, NULL, '{}', '{}'),
	('44616848-a696-4018-9a85-5e6276779cb5', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 2"}, {"name": "Team 3"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'A', 'main', '4', NULL, NULL, '{}', '{}'),
	('96b5dcfa-cde4-49e6-822d-86e0fe564db9', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 2"}, {"name": "Team 4"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'A', 'main', '1', NULL, NULL, '{}', '{}'),
	('ecdfaa90-7d69-4659-bb0c-8dbd2f977b13', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 3"}, {"name": "Team 4"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'A', 'main', '2', NULL, NULL, '{}', '{}'),
	('e6064627-a619-4cdf-969d-e6e50e6fe19a', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 5"}, {"name": "Team 6"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'B', 'main', '3', NULL, NULL, '{}', '{}'),
	('98d6a1d6-d9f0-4625-9c27-6ba22f82e0bc', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 5"}, {"name": "Team 7"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'B', 'main', '4', NULL, NULL, '{}', '{}'),
	('90440f8f-6997-437d-975c-bd710d9829b7', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 5"}, {"name": "Team 8"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'B', 'main', '1', NULL, NULL, '{}', '{}'),
	('a577e24f-7a0e-48fb-b190-23ff9c76c88d', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 6"}, {"name": "Team 7"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'B', 'main', '2', NULL, NULL, '{}', '{}'),
	('723fbbd8-bc97-4dc8-9b20-0c2eeec34fc1', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 6"}, {"name": "Team 8"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'B', 'main', '3', NULL, NULL, '{}', '{}'),
	('f05841c0-939d-4ba8-a0b7-8d1ce5082ff8', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 7"}, {"name": "Team 8"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'B', 'main', '4', NULL, NULL, '{}', '{}'),
	('57db529d-172e-4137-9bbf-d23b084dd243', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 9"}, {"name": "Team 10"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'C', 'main', '1', NULL, NULL, '{}', '{}'),
	('3fdd8bd5-5461-45a8-bc36-461aac42bcd2', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 9"}, {"name": "Team 11"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'C', 'main', '2', NULL, NULL, '{}', '{}'),
	('f3f3a601-6c70-4770-a0c3-9cd8b7d26a64', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 9"}, {"name": "Team 12"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'C', 'main', '3', NULL, NULL, '{}', '{}'),
	('7b210f30-f45c-4aa3-a161-e83072e87f62', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 10"}, {"name": "Team 11"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'C', 'main', '4', NULL, NULL, '{}', '{}'),
	('1053c58a-d3e5-49df-96d3-dc1b41e07c73', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 10"}, {"name": "Team 12"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'C', 'main', '1', NULL, NULL, '{}', '{}'),
	('560179e4-72b0-44f4-97c0-fc910e4e9f80', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 11"}, {"name": "Team 12"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'C', 'main', '2', NULL, NULL, '{}', '{}'),
	('9ebf1442-1b29-475f-8ea0-7c56537fc5be', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 13"}, {"name": "Team 14"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'D', 'main', '3', NULL, NULL, '{}', '{}'),
	('a1fc6ff9-53c6-42fe-9d46-4ce8712e1b5a', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 13"}, {"name": "Team 15"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'D', 'main', '4', NULL, NULL, '{}', '{}'),
	('addd3f9e-5906-449f-bbf7-2ae66c5c3822', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 13"}, {"name": "Team 16"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'D', 'main', '1', NULL, NULL, '{}', '{}'),
	('3752253a-a4e6-43e9-ba8c-049513b8a908', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 14"}, {"name": "Team 15"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'D', 'main', '2', NULL, NULL, '{}', '{}'),
	('bf95c9e3-f766-4f17-965b-be5dae2093b2', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 14"}, {"name": "Team 16"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'D', 'main', '3', NULL, NULL, '{}', '{}'),
	('8c503e10-fe00-47b4-ab9c-d11e1d6f080c', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Volleyball', '[{"name": "Team 15"}, {"name": "Team 16"}]', 'scheduled', '2026-05-21 10:06:31.754549+00', '2026-05-21 10:06:31.754549+00', 1, NULL, '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, 'D', 'main', '4', NULL, NULL, '{}', '{}'),
	('afd3fded-f7ff-4ea2-94b6-d4b65d923e22', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Tennis', '[{"name": "Player 1"}, {"name": "Player 16"}]', 'ongoing', '2026-05-21 09:06:13.665689+00', '2026-05-21 10:07:21.633865+00', 1, 1, '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', NULL, 'main', NULL, NULL, NULL, '{}', '{"sets": [], "current": {"away": 0, "home": 0}, "current_set": 1, "serving_index": 0}');


--
-- Data for Name: bracket_matches; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: follows; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: match_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."match_events" ("id", "match_id", "event_data", "created_at") VALUES
	('cc145dbe-1437-405b-9f38-3b0d9b751ab5', 'c54bf028-3735-412c-aa22-3ade1ce0cc7d', '{"type": "start_scoreboard", "initial_server_index": 1}', '2026-05-21 09:53:52.452376+00'),
	('c0133b0a-34c8-4b86-ab90-ebe3fce5bef5', 'f06b6026-d4cd-4f95-987c-e37ed5023274', '{"type": "start_scoreboard", "initial_server_index": 0}', '2026-05-21 09:54:27.983434+00'),
	('74124cd6-47c6-4bf4-8695-8ddfde24dfed', 'afd3fded-f7ff-4ea2-94b6-d4b65d923e22', '{"type": "start_scoreboard", "initial_server_index": 0}', '2026-05-21 10:07:21.633865+00');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."notifications" ("id", "user_id", "title", "body", "data", "read_at", "created_at") VALUES
	('426d3d77-8c96-43b7-8d74-eea56b9af0e5', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'You have been invited to score a match!', 'You are the umpire for the Volleyball match.', '{"link": "/matches/b6a65dc1-2d9b-4ac1-9e5a-389bca870074", "type": "umpire_invitation", "match_id": "b6a65dc1-2d9b-4ac1-9e5a-389bca870074", "tournament_id": "eda9efc7-04cf-4cc2-bd02-579daf89e223"}', NULL, '2026-05-21 09:08:01.279965+00'),
	('bc2922d4-05c2-489d-9f19-5a97f0ea9f0d', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'You have been invited to score a match!', 'You are the umpire for the Volleyball match.', '{"link": "/matches/b3f211bb-192a-4cec-a904-89a115406a21", "type": "umpire_invitation", "match_id": "b3f211bb-192a-4cec-a904-89a115406a21", "tournament_id": "eda9efc7-04cf-4cc2-bd02-579daf89e223"}', NULL, '2026-05-21 09:19:59.180207+00'),
	('6edc5e7d-a253-42d2-bdff-b678c119343c', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'You have been invited to score a match!', 'You are the umpire for the Tennis match.', '{"link": "/matches/afd3fded-f7ff-4ea2-94b6-d4b65d923e22", "type": "umpire_invitation", "match_id": "afd3fded-f7ff-4ea2-94b6-d4b65d923e22", "tournament_id": "673ad917-5d42-4dab-bd5e-9276f4b7c6f8"}', NULL, '2026-05-21 09:20:34.654232+00'),
	('bba8ff78-e520-41c5-9dab-749c79bc2585', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'You have been invited to score a match!', 'You are the umpire for the Football match.', '{"link": "/matches/4424131e-bf4b-4dc8-9cbe-5273e1f85b19", "type": "umpire_invitation", "match_id": "4424131e-bf4b-4dc8-9cbe-5273e1f85b19", "tournament_id": "d0c0fa4d-a5b1-47ad-9274-a63f5406ffe4"}', NULL, '2026-05-21 09:21:02.547538+00'),
	('215a41ee-eb2d-47ce-aee2-41e31f078e3b', '608bf4ce-7f75-4d89-a6d4-65397b7b68aa', 'You have been invited to score a match!', 'You are the umpire for the Football match.', '{"link": "/matches/40c578f2-a059-4712-85ac-d1bdc64118d9", "type": "umpire_invitation", "match_id": "40c578f2-a059-4712-85ac-d1bdc64118d9", "tournament_id": "d0c0fa4d-a5b1-47ad-9274-a63f5406ffe4"}', NULL, '2026-05-21 09:21:19.873193+00'),
	('ed51023d-5b85-4aa6-957b-6cc4f42033c2', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'You have been invited to score a match!', 'You are the umpire for the Tennis match.', '{"link": "/matches/f06b6026-d4cd-4f95-987c-e37ed5023274", "type": "umpire_invitation", "match_id": "f06b6026-d4cd-4f95-987c-e37ed5023274", "tournament_id": null}', NULL, '2026-05-21 09:48:32.009872+00'),
	('fbeaeb7b-0f8a-4b32-abfd-e5e930b7e0ed', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'You have been invited to score a match!', 'You are the umpire for the Volleyball match.', '{"link": "/matches/c54bf028-3735-412c-aa22-3ade1ce0cc7d", "type": "umpire_invitation", "match_id": "c54bf028-3735-412c-aa22-3ade1ce0cc7d", "tournament_id": null}', NULL, '2026-05-21 09:49:11.366876+00'),
	('7f768196-010f-45fa-a276-b93578124236', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'You have been invited to score a match!', 'You are the umpire for the Football match.', '{"link": "/matches/f53c241a-125c-4934-8faf-9197b3f9d3e9", "type": "umpire_invitation", "match_id": "f53c241a-125c-4934-8faf-9197b3f9d3e9", "tournament_id": null}', NULL, '2026-05-21 09:49:28.8577+00'),
	('eaf4a1fa-98e3-497a-9adf-624206d74658', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'You have been invited to score a match!', 'You are the umpire for the Football match.', '{"link": "/matches/bf436faf-3d23-4755-a154-d4657340f4c5", "type": "umpire_invitation", "match_id": "bf436faf-3d23-4755-a154-d4657340f4c5", "tournament_id": "d0c0fa4d-a5b1-47ad-9274-a63f5406ffe4"}', NULL, '2026-05-21 09:55:35.312507+00'),
	('c6244c8f-8cbb-4531-944f-b403e743c98c', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Umpire Invitation', 'You have been invited to score the match between AAC OAF and Esperança AC in Torneio Guadiana 2026.', '{"type": "umpire_assignment", "matchId": "bf436faf-3d23-4755-a154-d4657340f4c5"}', NULL, '2026-05-21 09:55:35.327992+00'),
	('cf1d184b-b064-4699-9b18-254b70ec3d0a', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'You have been invited to score a match!', 'You are the umpire for the Tennis match.', '{"link": "/matches/afd3fded-f7ff-4ea2-94b6-d4b65d923e22", "type": "umpire_invitation", "match_id": "afd3fded-f7ff-4ea2-94b6-d4b65d923e22", "tournament_id": "673ad917-5d42-4dab-bd5e-9276f4b7c6f8"}', NULL, '2026-05-21 10:07:14.469407+00'),
	('924c7388-7932-4c83-9e67-aea5ab7bb037', '171b2feb-e7f7-4ae2-87cc-aa2332e9f5f0', 'Umpire Invitation', 'You have been invited to score the match between Player 1 and Player 16 in Torneio Queima das Fitas 2026.', '{"type": "umpire_assignment", "matchId": "afd3fded-f7ff-4ea2-94b6-d4b65d923e22"}', NULL, '2026-05-21 10:07:14.48304+00');


--
-- Data for Name: tournament_participants; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."tournament_participants" ("id", "tournament_id", "seed", "created_at", "name", "contact_email", "form_responses") VALUES
	('b1dc6f45-fc8e-4e6a-9b15-cee58fd96056', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 1', NULL, '{}'),
	('ac2f906c-a0ba-4b5a-9d0a-8370652c54eb', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 2', NULL, '{}'),
	('5ce9aa70-48d7-4282-85a2-d3f244ec9f3a', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 3', NULL, '{}'),
	('b4fe883a-a9d8-4afe-8954-7ebb3fb0d00e', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 4', NULL, '{}'),
	('52acf682-ab35-41d8-8c01-82fd736f80b6', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 5', NULL, '{}'),
	('b1a5aa80-63c9-466c-9360-383779d94a56', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 6', NULL, '{}'),
	('7645e569-962b-4302-8934-3f5d73ce6d4f', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 7', NULL, '{}'),
	('1c0878bc-e66f-49cf-a25d-013421cb3212', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 8', NULL, '{}'),
	('60052fe9-31fd-4180-8dba-c228be18d63a', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 9', NULL, '{}'),
	('453be54b-e684-472f-a2be-66f1877454e8', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 10', NULL, '{}'),
	('6343eafb-6fb7-4608-9257-311bc8fa58a0', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 11', NULL, '{}'),
	('07360ce2-d7fa-435f-8176-ebf469e8071c', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 12', NULL, '{}'),
	('96d31f6f-c4a6-4b4b-84fe-5891d150d6e8', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 13', NULL, '{}'),
	('6e428422-c37a-4b58-b564-618097517596', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 14', NULL, '{}'),
	('3694df3e-4cea-4f8b-bdca-1da2460364c7', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 15', NULL, '{}'),
	('6bcad70f-e716-498f-aef6-c9118f5cc9da', 'eda9efc7-04cf-4cc2-bd02-579daf89e223', NULL, '2026-05-21 09:04:40.618889+00', 'Team 16', NULL, '{}'),
	('592b8e23-d656-48cf-b4a5-eb7b3a6fb08e', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 1', NULL, '{}'),
	('969ec270-8935-4b9d-8c1f-10c315e482bf', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 2', NULL, '{}'),
	('df948948-f319-41d6-b1be-31c6e1f50aea', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 3', NULL, '{}'),
	('f878b166-97e2-4729-a09a-21201ec75b50', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 4', NULL, '{}'),
	('c0b396eb-413c-4679-9053-3eaf7a7c3662', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 5', NULL, '{}'),
	('682ead5d-38ba-4e5b-a066-aec6478ce61e', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 6', NULL, '{}'),
	('d080601c-3e04-4fe6-a996-84b5eef7b446', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 7', NULL, '{}'),
	('f33a6fac-c708-47d2-a206-72bab6d7572e', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 8', NULL, '{}'),
	('286b6c81-b937-43ea-88e4-e7d3f003e12f', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 9', NULL, '{}'),
	('94d3f74a-6226-4ca2-a6f1-48f43d9f6609', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 10', NULL, '{}'),
	('9c6db082-1255-4504-a85d-61b07656a62e', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 11', NULL, '{}'),
	('7648e971-03be-4ba2-b0c3-5a23869abbc3', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 12', NULL, '{}'),
	('bbe9f74a-f0f4-49f8-96b5-c48dc17fe6c0', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 13', NULL, '{}'),
	('6f3615ed-f191-4882-977c-471a9f99e407', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 14', NULL, '{}'),
	('1076ce25-258b-433d-959e-0f337371cb75', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 15', NULL, '{}'),
	('e3e312a8-ff5a-4c31-9536-452f666c8342', '673ad917-5d42-4dab-bd5e-9276f4b7c6f8', NULL, '2026-05-21 09:06:13.59195+00', 'Player 16', NULL, '{}'),
	('9c37485f-1a82-473a-bbeb-fe5877a0f69f', 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, '2026-05-21 09:19:22.10614+00', 'AAC OAF', NULL, '{}'),
	('d856144b-d9fc-43b9-b570-fdcb8ea086e1', 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, '2026-05-21 09:19:22.10614+00', 'CF Marialvas', NULL, '{}'),
	('38ce1038-65cf-4293-9bb0-0df1b488a7a3', 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, '2026-05-21 09:19:22.10614+00', 'Esperança AC', NULL, '{}'),
	('13f238ee-3a2a-4cc4-a158-6fdd1e84e030', 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, '2026-05-21 09:19:22.10614+00', 'SC Ribeirense', NULL, '{}'),
	('de7db4eb-9429-4362-bc85-8a24d8e4415f', 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, '2026-05-21 09:19:22.10614+00', 'Vigor Mocidade', NULL, '{}'),
	('897e4355-d1f4-4700-81b4-ce530d0d0301', 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, '2026-05-21 09:19:22.10614+00', 'Ançã FC', NULL, '{}'),
	('f345dca4-bcbb-4280-a79b-87618483d755', 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, '2026-05-21 09:19:22.10614+00', 'Red Eagles', NULL, '{}'),
	('aaa054bc-cb26-4f11-a471-75c9ae005dce', 'd0c0fa4d-a5b1-47ad-9274-a63f5406ffe4', NULL, '2026-05-21 09:19:22.10614+00', 'União FC', NULL, '{}'),
	('d37f502c-4be4-4934-a549-46a7e9ee9022', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 1', NULL, '{}'),
	('f0c38227-e7d9-4857-93c0-bdb7ba199cda', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 2', NULL, '{}'),
	('1795bf8e-ee0d-4077-8eaa-7857d8c6df1b', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 3', NULL, '{}'),
	('4c8c2082-99e9-47be-9300-9265c89dd780', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 4', NULL, '{}'),
	('edd4af66-d2fd-45c2-91ce-10e00a1a57ca', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 5', NULL, '{}'),
	('9cb14ec6-7b6a-45a4-bf76-8fc983c5746f', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 6', NULL, '{}'),
	('7e0403b5-051f-412d-94c5-bf7cf5033100', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 7', NULL, '{}'),
	('8b9a77cf-abbd-4836-aa92-2c9cb35a831e', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 8', NULL, '{}'),
	('72834ef0-69e1-43a4-b291-ccd3c2ef44a9', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 9', NULL, '{}'),
	('56db2f06-b1da-4913-b81c-8dcf1ce691c1', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 10', NULL, '{}'),
	('460561ac-0ef9-4736-9b30-69a8e3f35b49', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 11', NULL, '{}'),
	('8f1dc53e-30c0-4bba-9354-bf9f5d6548dd', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 12', NULL, '{}'),
	('ee8636cb-9b52-427b-a003-dfc1ac07067f', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 13', NULL, '{}'),
	('069cd61e-be07-4c99-8732-0c97684c0157', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 14', NULL, '{}'),
	('67120cea-c6a7-4e20-92e5-db828e3af11c', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 15', NULL, '{}'),
	('3a123bd3-cedc-4ac2-a660-998687d6f28a', '7526b704-0332-4792-ae62-7be563109f56', NULL, '2026-05-21 10:00:56.812673+00', 'Team 16', NULL, '{}'),
	('d069d00f-8b2a-4adc-91ee-e0e5d40ee621', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 1', NULL, '{}'),
	('4d5dfdd7-d21e-4b60-a95e-45d93b39ebed', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 2', NULL, '{}'),
	('1b419f26-3637-4096-ad6c-bd9c3f55c64f', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 3', NULL, '{}'),
	('f8da31df-6434-4feb-9e7d-6f1c23ad0a98', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 4', NULL, '{}'),
	('0245b4b4-88af-4fe9-b30a-959fd433502a', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 5', NULL, '{}'),
	('57ce3e40-0b14-41d7-9c39-986cf1a8fe19', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 6', NULL, '{}'),
	('e8d67c76-9f41-4ae5-81e4-b8a342469477', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 7', NULL, '{}'),
	('fbca1db7-2dc9-454a-8310-b3e97b23fa19', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 8', NULL, '{}'),
	('c0aa739c-09da-4521-83cf-a97bf49ee49b', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 9', NULL, '{}'),
	('1cd3eb33-a0f1-4619-a9f3-1c17ea478062', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 10', NULL, '{}'),
	('7efcb0f0-220b-42bf-9be1-a8ebcb4cffea', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 11', NULL, '{}'),
	('ebef0f28-3940-45a8-905b-bd2fc646c3d8', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 12', NULL, '{}'),
	('4036296a-64e0-48f4-ad9a-66436989360c', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 13', NULL, '{}'),
	('e297ac7e-54ce-4535-b8ec-935cb0862f1a', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 14', NULL, '{}'),
	('a01e1944-1b30-44e7-8267-5704a3f5b823', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 15', NULL, '{}'),
	('b22dbda2-17b6-408a-8c48-3b742db3b989', '7b490506-79d3-486b-8111-cf339a6cadc9', NULL, '2026-05-21 10:06:31.614429+00', 'Team 16', NULL, '{}');


--
-- Data for Name: user_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: iceberg_namespaces; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: iceberg_tables; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: hooks; Type: TABLE DATA; Schema: supabase_functions; Owner: supabase_functions_admin
--



--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: supabase_auth_admin
--

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 3, true);


--
-- Name: hooks_id_seq; Type: SEQUENCE SET; Schema: supabase_functions; Owner: supabase_functions_admin
--

SELECT pg_catalog.setval('"supabase_functions"."hooks_id_seq"', 1, false);


--
-- PostgreSQL database dump complete
--

-- \unrestrict G6ESZZhvp2LmqZofroKZlaD81bkDZVhxsqPHtUBkBMi8zRqvzl1q9tWAit6eHeh

RESET ALL;
SET session_replication_role = 'origin';
