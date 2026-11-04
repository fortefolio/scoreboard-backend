# Subscriptions, Vouchers & GDPR Data Lifecycle

This document specifies the backend monetization logic, voucher engine, and data retention/deletion procedures for `scoreboard-backend`.

---

## 1. Subscription Tiers & Stripe Mapping

ScoreBoard supports two primary paid billing plans handled via Stripe Checkout and Customer Portal:

| Tier Code | Plan Name | Price (incl. VAT) | Billing Cycle | Stripe Webhook Action |
| :--- | :--- | :--- | :--- | :--- |
| **`free`** | Community Tier | €0.00 | Free Forever | Default role upon signup. |
| **`pro_monthly`** | Pro Organizer (Monthly) | €3.99 / month | Recurring monthly | Sets `users.subscription_tier = 'pro'`, records Stripe sub ID. |
| **`pro_annual`** | Pro Organizer (Annual) | €34.99 / year | Recurring yearly | Sets `users.subscription_tier = 'pro'`, records Stripe sub ID. |

### Webhook Event Handling (`stripe-webhook`)
1. **`checkout.session.completed`**:
   - Matches `client_reference_id` to `users.id`.
   - Inserts or updates a record in `subscriptions` with `status = 'active'`.
   - Updates `users.subscription_tier = 'pro'`.
2. **`customer.subscription.deleted`**:
   - Updates `subscriptions.status = 'canceled'`.
   - Downgrades `users.subscription_tier = 'free'`.
3. **`invoice.payment_failed`**:
   - Updates `subscriptions.status = 'past_due'`.

---

## 2. Beta Voucher Redemption Engine

ScoreBoard provides a database RPC `redeem_voucher` to grant promotional Pro subscriptions without Stripe checkout:

```sql
SELECT redeem_voucher('BETA-CLUB-60D');
```

### Constraints & Atomicity
- **Case-Insensitive Match**: Vouchers are stored uppercase (`UPPER(code)`).
- **Expiration Guard**: `expires_at IS NULL OR expires_at > NOW()`.
- **Max Redemptions**: `max_redemptions IS NULL OR redemptions_count < max_redemptions`.
- **One-per-User**: A user cannot redeem the same voucher multiple times (checked via `voucher_redemptions` table).
- **Outcome**: Inserts into `voucher_redemptions`, creates or extends an active entry in `subscriptions` with `provider = 'voucher'`, and sets `users.subscription_tier = 'pro'`.

---

## 3. GDPR Article 17 (Right to Erasure)

In compliance with the General Data Protection Regulation (GDPR), users have the right to permanently erase their account and personal data.

### Deletion RPC: `delete_user_account`
When a user triggers account deletion (via Web or Mobile settings):
1. **Cancellation of Active Stripe Billing**:
   - Backend or Edge Function cancels any active subscription in Stripe via API to prevent further recurring charges.
2. **Database Cascade Erasure**:
   - Deletes all user-owned records in `follows`, `voucher_redemptions`, `subscriptions`, `match_events`, `tournament_participants`.
   - Nullifies organizer/umpire references where historical integrity requires preserving anonymous scores, or cascades deletions according to foreign key constraints:
     ```sql
     DELETE FROM auth.users WHERE id = auth.uid();
     ```
3. **Audit Logging**:
   - No personally identifiable information (PII) is retained post-deletion.
