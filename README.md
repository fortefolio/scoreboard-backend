# ScoreBoard Backend

A robust backend engine for real-time sports scoring, tournament management, and social engagement. Powered by **Supabase**.

## 🚀 Tech Stack

- **Database:** PostgreSQL (with PostgREST and Real-time)
- **Authentication:** Supabase Auth
- **Business Logic:** PostgreSQL Triggers & Functions (PL/pgSQL)
- **Edge Functions:** Deno / TypeScript
- **Integrations:** Stripe (Payments), Firebase Cloud Messaging (Push Notifications)

## 🏗️ Database Architecture

The core schema is designed for high performance and real-time updates:

- **Users:** Profiles with subscription tiering (`free` vs `pro`).
- **Tournaments:** Full bracket and participant management.
- **Matches:** Real-time scoring using `JSONB` for flexible sport-specific data.
- **Match Events:** Granular event tracking that automatically updates match scores via triggers (supports Football, Basketball, Tennis, and more).
- **Social Graph:** Follow system for teams, players, and competitions.
- **Social Feed:** A unified `user_feed` view for infinite scrolling of followed activities.
- **User Tokens:** Management of FCM tokens for targeted push notifications.

### 🔒 Security (RLS)
Rigorous Row Level Security policies ensure data integrity:
- Public read access for matches and tournaments.
- Write access restricted to authorized organizers.
- Tournament creation restricted to `pro` tier users.

## ⚡ Edge Functions

- **`stripe-webhook`**: Handles subscription upgrades by verifying Stripe signatures and updating user tiers.
- **`fcm-notifications`**: Dispatches push notifications to followers when matches are completed.

## 🛠️ Local Development

### Prerequisites
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- [Docker](https://www.docker.com/)

### Getting Started
1. **Clone the repository.**
2. **Initialize Supabase:**
   ```bash
   supabase init
   ```
3. **Start the local environment:**
   ```bash
   supabase start
   ```
4. **Apply migrations:**
   ```bash
   supabase db reset
   ```

### Environment Variables
The following secrets are required for Edge Functions:
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `FIREBASE_SERVICE_ACCOUNT` (JSON)

## 📜 Project Structure
```
├── supabase/
│   ├── functions/          # Deno Edge Functions
│   ├── migrations/         # PostgreSQL migrations
│   └── config.toml         # Supabase configuration
├── GEMINI.md               # Core schema & directives
└── .gitignore
```
