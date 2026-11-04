---
name: living-docs
description: "Automated codebase wiki documentation and continuous drift synchronization engine for scoreboard-backend. Analyzes Supabase migrations, PostgreSQL schemas, RLS policies, custom RPC functions, and Deno Edge Functions to generate and maintain a living Markdown wiki in docs/ with Mermaid diagrams. Activate this skill whenever asked to document the backend, update database docs, or sync backend changes."
---

# Living Docs: Backend Documentation & Continuous Sync

A local, autonomous documentation engine that functions as an intelligent, self-updating Code Wiki for `scoreboard-backend`.

---

## 1. Documentation Architecture (`docs/`)

All project documentation lives in the `docs/` directory of `scoreboard-backend`:

| File | Purpose | Key Contents |
| :--- | :--- | :--- |
| **[`docs/README.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/README.md)** | **Backend Wiki Index** | Architecture overview, data flow diagram, and directory map. |
| **[`docs/00-database-schema.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/00-database-schema.md)** | **Database & RLS Layer** | PostgreSQL tables, JSONB schemas, RLS policies, custom RPC functions, ER diagram (`erDiagram`). |
| **[`docs/01-edge-functions.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/01-edge-functions.md)** | **Deno Edge Functions** | Functions (`stripe-webhook`, checkout/portal sessions, `fcm-push`), secrets, Realtime channels. |
| **[`docs/02-database-rpcs-and-scoring.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/02-database-rpcs-and-scoring.md)** | **Database RPCs & Scoring Logic** | Stored procedures (`appoint_match_umpire`, `redeem_voucher`), trigger functions, and scoring rules. |
| **[`docs/03-subscriptions-and-gdpr.md`](file:///Users/goncaloforte/Sandbox/ScoreBoard/scoreboard-backend/docs/03-subscriptions-and-gdpr.md)** | **Billing & GDPR** | Subscription statuses, beta voucher engine, and account erasure procedures. |

---

## 2. Workflows

### Incremental Drift Synchronization (After Code Changes)
Whenever migrations or edge functions are created or altered:
1. Inspect `git status` or `git diff` inside `scoreboard-backend`.
2. Update the corresponding `docs/` file per `.agents/rules/docs-sync.md`.
3. Keep Mermaid diagrams accurate.
4. Commit doc updates alongside the SQL or TypeScript files.
