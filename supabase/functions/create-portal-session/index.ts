// supabase/functions/create-portal-session/index.ts
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

    const { returnUrl } = await req.json().catch(() => ({}))

    let targetOrigin: string
    if (returnUrl !== undefined && returnUrl !== null && returnUrl !== "") {
      if (typeof returnUrl !== "string" || !isAllowedReturnUrl(returnUrl)) {
        throw new AppError(400, "Invalid returnUrl origin.")
      }
      targetOrigin = new URL(returnUrl).origin
    } else {
      targetOrigin = getDefaultReturnOrigin()
    }

    const { data: subRecord, error: subError } = await supabase
      .from("subscriptions")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .not("stripe_customer_id", "is", null)
      .maybeSingle()

    if (subError || !subRecord?.stripe_customer_id) {
      return jsonError(404, "No active Stripe customer found for this user.", corsHeaders)
    }

    const portalSession = await stripe.billingPortal.sessions.create({
      customer: subRecord.stripe_customer_id,
      return_url: `${targetOrigin}/settings`,
    })

    return jsonResponse({ url: portalSession.url }, 200, corsHeaders)
  } catch (err) {
    return handleEdgeError(err, "create-portal-session", corsHeaders)
  }
})
