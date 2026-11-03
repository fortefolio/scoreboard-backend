import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@11.1.0?target=deno"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2022-11-15",
  httpClient: Stripe.createFetchHttpClient(),
})

const endpointSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")

serve(async (req) => {
  const signature = req.headers.get("stripe-signature")

  if (!signature) {
    return new Response("Missing signature", { status: 400 })
  }

  const body = await req.text()
  let event

  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      endpointSecret!,
      undefined
    )
  } catch (err) {
    return new Response(`Webhook Error: ${err.message}`, { status: 400 })
  }

  // Use service role key to bypass RLS for tier and subscription updates
  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  )

  const syncUserTier = async (userId: string) => {
    // Check if user has any active subscriptions or non-expired vouchers
    const { data: subs } = await supabaseClient
      .from("subscriptions")
      .select("id, status, current_period_end")
      .eq("user_id", userId)
      .eq("status", "active")

    const now = new Date()
    const hasActiveSub = (subs ?? []).some(
      (s) => !s.current_period_end || new Date(s.current_period_end) > now
    )

    const newTier = hasActiveSub ? "pro" : "free"
    await supabaseClient
      .from("users")
      .update({ subscription_tier: newTier, updated_at: now.toISOString() })
      .eq("id", userId)

    console.log(`Synced user ${userId} tier to: ${newTier}`)
  }

  try {
    switch (event.type) {
      case "checkout.session.completed":
      case "checkout.session.async_payment_succeeded": {
        const session = event.data.object as any

        if (session.payment_status !== "paid") {
          console.log(`Payment status is ${session.payment_status}, deferring pro upgrade until payment succeeds.`)
          return new Response(JSON.stringify({ received: true, status: "pending_payment" }), {
            headers: { "Content-Type": "application/json" },
            status: 200,
          })
        }

        const userId = session.metadata?.supabase_user_id || session.client_reference_id
        const customerId = session.customer as string | undefined
        const subscriptionId = session.subscription as string | undefined
        const planType = session.metadata?.plan_type || "monthly"

        if (userId) {
          let currentPeriodEnd: string | null = null
          if (subscriptionId) {
            try {
              const subObj = await stripe.subscriptions.retrieve(subscriptionId)
              if (subObj.current_period_end) {
                currentPeriodEnd = new Date(subObj.current_period_end * 1000).toISOString()
              }
            } catch (err) {
              console.warn("Could not retrieve subscription details from Stripe:", err)
            }
          }

          // Upsert into subscriptions table
          const { error: subErr } = await supabaseClient
            .from("subscriptions")
            .upsert(
              {
                user_id: userId,
                provider: "stripe",
                status: "active",
                plan_type: planType,
                stripe_customer_id: customerId ?? null,
                stripe_subscription_id: subscriptionId ?? null,
                current_period_end: currentPeriodEnd,
                cancel_at_period_end: false,
                updated_at: new Date().toISOString(),
              },
              { onConflict: "user_id,provider" }
            )

          if (subErr) {
            console.error("Error upserting subscription record:", subErr)
          }

          await syncUserTier(userId)
          console.log(`Successfully upgraded user ${userId} to pro via Stripe checkout.`)
        } else {
          console.warn("No supabase_user_id found in checkout session metadata.")
        }
        break
      }

      case "customer.subscription.updated": {
        const subscription = event.data.object as any
        const customerId = subscription.customer as string
        const status = subscription.status === "active" ? "active" : subscription.status === "past_due" ? "past_due" : "canceled"
        const currentPeriodEnd = subscription.current_period_end
          ? new Date(subscription.current_period_end * 1000).toISOString()
          : null
        const cancelAtPeriodEnd = subscription.cancel_at_period_end ?? false

        // Locate corresponding user by stripe_customer_id or stripe_subscription_id
        const { data: subRecord } = await supabaseClient
          .from("subscriptions")
          .select("user_id")
          .eq("stripe_subscription_id", subscription.id)
          .maybeSingle()

        if (subRecord?.user_id) {
          await supabaseClient
            .from("subscriptions")
            .update({
              status,
              current_period_end: currentPeriodEnd,
              cancel_at_period_end: cancelAtPeriodEnd,
              updated_at: new Date().toISOString(),
            })
            .eq("stripe_subscription_id", subscription.id)

          await syncUserTier(subRecord.user_id)
        }
        break
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as any
        const { data: subRecord } = await supabaseClient
          .from("subscriptions")
          .select("user_id")
          .eq("stripe_subscription_id", subscription.id)
          .maybeSingle()

        if (subRecord?.user_id) {
          await supabaseClient
            .from("subscriptions")
            .update({
              status: "canceled",
              cancel_at_period_end: false,
              updated_at: new Date().toISOString(),
            })
            .eq("stripe_subscription_id", subscription.id)

          await syncUserTier(subRecord.user_id)
          console.log(`Subscription ${subscription.id} deleted. Downgraded user ${subRecord.user_id}.`)
        }
        break
      }

      case "invoice.payment_succeeded": {
        const invoice = event.data.object as any
        const subscriptionId = invoice.subscription as string | undefined

        if (subscriptionId) {
          const { data: subRecord } = await supabaseClient
            .from("subscriptions")
            .select("user_id")
            .eq("stripe_subscription_id", subscriptionId)
            .maybeSingle()

          if (subRecord?.user_id) {
            const periodEnd = invoice.lines?.data?.[0]?.period?.end
            const currentPeriodEnd = periodEnd ? new Date(periodEnd * 1000).toISOString() : null

            await supabaseClient
              .from("subscriptions")
              .update({
                status: "active",
                current_period_end: currentPeriodEnd,
                updated_at: new Date().toISOString(),
              })
              .eq("stripe_subscription_id", subscriptionId)

            await syncUserTier(subRecord.user_id)
          }
        }
        break
      }

      case "invoice.payment_failed": {
        const invoice = event.data.object as any
        const subscriptionId = invoice.subscription as string | undefined

        if (subscriptionId) {
          const { data: subRecord } = await supabaseClient
            .from("subscriptions")
            .select("user_id")
            .eq("stripe_subscription_id", subscriptionId)
            .maybeSingle()

          if (subRecord?.user_id) {
            await supabaseClient
              .from("subscriptions")
              .update({
                status: "past_due",
                updated_at: new Date().toISOString(),
              })
              .eq("stripe_subscription_id", subscriptionId)
          }
        }
        break
      }

      default:
        console.log(`Unhandled stripe event type: ${event.type}`)
    }
  } catch (err) {
    console.error(`Error processing webhook event ${event.type}:`, err)
    return new Response(`Processing error: ${err.message}`, { status: 500 })
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
    status: 200,
  })
})
