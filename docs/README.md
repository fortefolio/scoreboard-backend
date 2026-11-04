# ScoreBoard Backend — Technical Wiki & Database Architecture

Welcome to the technical knowledge base for **`scoreboard-backend`**, the Supabase data and services foundation for the ScoreBoard ecosystem (PostgreSQL 15, Row Level Security, Deno Edge Functions, Realtime replication, and Stripe/FCM webhooks).

```mermaid
flowchart TD
    subgraph Clients["Consumers"]
        Web["scoreboard-web<br/>Next.js 16 (App Router)"]
        Mobile["scoreboard-mobile<br/>React Native (Expo)"]
        Overlays["OBS / vMix Broadcast Overlays"]
    end

    subgraph Backend["scoreboard-backend (Supabase)"]
        DB[("PostgreSQL 15<br/>Tables + RLS Policies")]
        RPCs["Custom Database RPCs<br/>(appoint_umpire, redeem_voucher, etc.)"]
        Realtime["Realtime Engine<br/>Postgres CDC Broadcast"]
        Auth["Supabase Auth (GoTrue)"]
        Edge["Deno Edge Functions<br/>(stripe-webhook, checkout, portal, push)"]
    end

    subgraph External["External Integrations"]
        Stripe["Stripe Payments API"]
        FCM["Firebase Cloud Messaging (FCM v1)"]
    end

    Web -->|PostgREST & RPCs| DB
    Web -->|Auth Session| Auth
    Web -->|Invoke| Edge
    Mobile -->|PostgREST & RPCs| DB
    Mobile -->|Auth Session| Auth
    Overlays -->|Realtime WebSockets| Realtime
    DB --> Realtime

    Edge -->|Service Role DB Access| DB
    Edge -->|Webhook Lifecycle| Stripe
    Edge -->|Push Notifications| FCM
```

---

## 📚 Backend Wiki Index

| Document | Topic | Description |
| :--- | :--- | :--- |
| **[`00-database-schema.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/00-database-schema.md)** | **Database & RLS Layer** | PostgreSQL schema, tables (`users`, `matches`, `tournaments`, `subscriptions`, `vouchers`), RLS policies, custom RPCs, and Mermaid ERD. |
| **[`01-edge-functions.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/01-edge-functions.md)** | **Deno Edge Functions** | Edge functions catalog (`stripe-webhook`, `create-checkout-session`, `create-portal-session`, `fcm-push`), Supabase Realtime channels. |
| **[`02-database-rpcs-and-scoring.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/02-database-rpcs-and-scoring.md)** | **Database RPCs & Sport Engine** | Stored procedures (`appoint_match_umpire`, `redeem_voucher`), state machines, and scoring constraints across supported sports. |
| **[`03-subscriptions-and-gdpr.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/03-subscriptions-and-gdpr.md)** | **Billing, Vouchers & GDPR** | Stripe tier mappings (€3.99/mo, €34.99/yr), beta voucher redemption engine, and GDPR Article 17 user deletion procedures. |

---

## 🛠️ Repository Layout

```text
scoreboard-backend/
├── docs/                        # Backend technical wiki
├── supabase/
│   ├── config.toml              # Supabase CLI project configuration
│   ├── functions/               # Deno Edge Functions
│   │   ├── create-checkout-session/
│   │   ├── create-portal-session/
│   │   ├── fcm-push/
│   │   └── stripe-webhook/
│   └── migrations/              # Version-controlled PostgreSQL migrations
└── .agents/                     # AI Agent configuration
    ├── rules/docs-sync.md       # Backend documentation synchronization rule
    └── skills/living-docs/      # Living Docs skill
```
