# Backend Documentation Synchronization Rule (Docs-as-Code)

This repository maintains a living technical wiki in `docs/` describing the Supabase schema, RLS policies, custom RPCs, and Edge Functions.

## 1. Synchronization Mandate
Whenever you create, modify, or delete backend components, you **must update the corresponding documentation in `docs/` within the same working session**:

| Area Modified | Target Documentation File | What to Update |
| :--- | :--- | :--- |
| **Migrations & Tables** (`supabase/migrations/`) | [`docs/00-database-schema.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/00-database-schema.md) | Table definitions, columns, foreign keys, constraints, and the Mermaid ERD. |
| **RLS Policies & Permissions** (`supabase/migrations/`) | [`docs/00-database-schema.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/00-database-schema.md) | SELECT / INSERT / UPDATE / DELETE policies, roles, and security boundaries. |
| **Edge Functions** (`supabase/functions/`) | [`docs/01-edge-functions.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/01-edge-functions.md) | Function endpoints, payloads, environment variables, secrets, and Stripe/FCM events. |
| **Database RPCs & Scoring** (`supabase/migrations/`) | [`docs/02-database-rpcs-and-scoring.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/02-database-rpcs-and-scoring.md) | Stored procedures (`appoint_match_umpire`, `redeem_voucher`), trigger functions, and scoring rules. |
| **Billing, Vouchers & GDPR** (`supabase/`) | [`docs/03-subscriptions-and-gdpr.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/03-subscriptions-and-gdpr.md) | Subscription statuses, voucher rules, and account deletion / data retention flows. |

## 2. Diagram Standards
- When data structures or flow changes, update the relevant **Mermaid diagrams** (`erDiagram`, `sequenceDiagram`, `flowchart TD`).
- Always quote special characters in labels: `id["Node (Details)"]`.

## 3. Commit Rule
- Include the updated documentation in the same git commit as the backend SQL or Deno code changes.
