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

  // Use service role key to bypass RLS for tier updates
  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  )

  if (event.type === "checkout.session.completed") {
    const session = event.data.object
    const userId = session.metadata?.supabase_user_id

    if (userId) {
      const { error } = await supabaseClient
        .from("users")
        .update({ subscription_tier: "pro" })
        .eq("id", userId)

      if (error) {
        console.error(`Error updating user ${userId} to pro:`, error)
        return new Response("Error updating user tier", { status: 500 })
      }
      
      console.log(`Successfully upgraded user ${userId} to pro.`)
    } else {
      console.warn("No supabase_user_id found in session metadata.")
    }
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
    status: 200,
  })
})
