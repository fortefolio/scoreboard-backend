// supabase/functions/create-checkout-session/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@11.1.0?target=deno"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2022-11-15",
  httpClient: Stripe.createFetchHttpClient(),
})

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      })
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    const token = authHeader.replace(/^Bearer\s+/i, "")
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid or expired auth token" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      })
    }

    const { plan = "monthly", returnUrl } = await req.json().catch(() => ({}))
    const isAnnual = plan === "annual"
    const fallbackOrigin = returnUrl || "http://localhost:3000"

    // Check if user already has an associated Stripe customer
    const { data: subRecord } = await supabase
      .from("subscriptions")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .not("stripe_customer_id", "is", null)
      .maybeSingle()

    let customerId = subRecord?.stripe_customer_id

    if (!customerId) {
      // Find or create customer in Stripe
      const existingCustomers = await stripe.customers.list({
        email: user.email,
        limit: 1,
      })

      if (existingCustomers.data.length > 0) {
        customerId = existingCustomers.data[0].id
      } else {
        const newCust = await stripe.customers.create({
          email: user.email,
          metadata: {
            supabase_user_id: user.id,
          },
        })
        customerId = newCust.id
      }
    }

    const priceId = isAnnual
      ? Deno.env.get("STRIPE_PRICE_ANNUAL_ID")
      : Deno.env.get("STRIPE_PRICE_MONTHLY_ID")

    let lineItems: any[]
    if (priceId) {
      lineItems = [{ price: priceId, quantity: 1 }]
    } else {
      // Dynamic inline price if pre-configured price ID is not set
      lineItems = [
        {
          price_data: {
            currency: "eur",
            unit_amount: isAnnual ? 3499 : 399, // €34.99 / yr vs €3.99 / mo
            recurring: {
              interval: isAnnual ? "year" : "month",
            },
            product_data: {
              name: `ScoreBoard Pro Organizer (${isAnnual ? "Annual" : "Monthly"})`,
              description: "Unlimited tournament creation, referee management, custom branding, and broadcast overlays.",
            },
          },
          quantity: 1,
        },
      ]
    }

    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      client_reference_id: user.id,
      payment_method_types: ["card"],
      mode: "subscription",
      line_items: lineItems,
      metadata: {
        supabase_user_id: user.id,
        plan_type: isAnnual ? "annual" : "monthly",
      },
      success_url: `${fallbackOrigin}/settings?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${fallbackOrigin}/settings?checkout=cancelled`,
    })

    return new Response(JSON.stringify({ url: session.url }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    })
  } catch (err) {
    console.error("Error creating checkout session:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    })
  }
})
