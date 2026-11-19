// supabase/functions/create-checkout-session/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@11.1.0?target=deno"
import {
  getCorsHeaders,
  getDefaultReturnOrigin,
  handleCorsPreflight,
  isAllowedReturnUrl,
} from "../_shared/cors.ts"
import { AppError, handleEdgeError, jsonError, jsonResponse } from "../_shared/errors.ts"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2022-11-15",
  httpClient: Stripe.createFetchHttpClient(),
})

serve(async (req) => {
  const preflight = handleCorsPreflight(req)
  if (preflight) return preflight

  const corsHeaders = getCorsHeaders(req)

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return jsonError(401, "Missing Authorization header", corsHeaders)
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    const token = authHeader.replace(/^Bearer\s+/i, "")
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return jsonError(401, "Invalid or expired auth token", corsHeaders)
    }

    const { plan = "monthly", returnUrl } = await req.json().catch(() => ({}))
    const isAnnual = plan === "annual"

    let targetOrigin: string
    if (returnUrl !== undefined && returnUrl !== null && returnUrl !== "") {
      if (typeof returnUrl !== "string" || !isAllowedReturnUrl(returnUrl)) {
        throw new AppError(400, "Invalid returnUrl origin.")
      }
      targetOrigin = new URL(returnUrl).origin
    } else {
      targetOrigin = getDefaultReturnOrigin()
    }

    // Check if user already has an associated Stripe customer
    const { data: subRecord } = await supabase
      .from("subscriptions")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .not("stripe_customer_id", "is", null)
      .maybeSingle()

    let customerId = subRecord?.stripe_customer_id

    if (!customerId) {
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

    const lineItems = priceId
      ? [{ price: priceId, quantity: 1 }]
      : [
          {
            price_data: {
              currency: "eur",
              unit_amount: isAnnual ? 3499 : 399,
              recurring: {
                interval: isAnnual ? "year" : "month",
              },
              product_data: {
                name: `ScoreBoard Pro Organizer (${isAnnual ? "Annual" : "Monthly"})`,
                description:
                  "Unlimited tournament creation, referee management, custom branding, and fixture exports.",
              },
            },
            quantity: 1,
          },
        ]

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
      success_url: `${targetOrigin}/settings?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${targetOrigin}/settings?checkout=cancelled`,
    })

    return jsonResponse({ url: session.url }, 200, corsHeaders)
  } catch (err) {
    return handleEdgeError(err, "create-checkout-session", corsHeaders)
  }
})
