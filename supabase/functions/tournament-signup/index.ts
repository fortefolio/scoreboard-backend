import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  getCorsHeaders,
  getDefaultReturnOrigin,
  handleCorsPreflight,
  isAllowedReturnUrl,
} from "../_shared/cors.ts"
import { AppError, handleEdgeError, jsonError, jsonResponse } from "../_shared/errors.ts"

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input)
  const hashBuffer = await crypto.subtle.digest("SHA-256", data)
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
}

async function verifyTurnstile(token: string | undefined, remoteIp: string): Promise<boolean> {
  const secret = Deno.env.get("TURNSTILE_SECRET_KEY")
  if (!secret) {
    // Turnstile not configured (e.g., local dev)
    return true
  }
  if (!token) return false

  const form = new URLSearchParams()
  form.set("secret", secret)
  form.set("response", token)
  if (remoteIp && remoteIp !== "unknown") {
    form.set("remoteip", remoteIp)
  }

  const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    body: form,
  })
  if (!res.ok) return false
  const payload = await res.json()
  return Boolean(payload?.success)
}

serve(async (req) => {
  const preflight = handleCorsPreflight(req)
  if (preflight) return preflight

  const corsHeaders = getCorsHeaders(req)

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    const body = await req.json().catch(() => ({}))

    // Confirmation flow
    if (body?.action === "confirm") {
      const rawToken = typeof body?.token === "string" ? body.token.trim() : ""
      if (!rawToken || rawToken.length < 16) {
        throw new AppError(400, "Invalid confirmation token.")
      }
      const tokenHash = await sha256Hex(rawToken)
      const { data: confirmedRow, error: confirmErr } = await supabase
        .from("tournament_participants")
        .update({
          confirmation_status: "confirmed",
          confirmed_at: new Date().toISOString(),
          confirmation_token_hash: null,
        })
        .eq("confirmation_token_hash", tokenHash)
        .eq("confirmation_status", "pending_confirmation")
        .select("id, tournament_id, name")
        .maybeSingle()

      if (confirmErr || !confirmedRow) {
        throw new AppError(400, "Confirmation link is invalid or has already been used.")
      }

      return jsonResponse({ success: true, confirmed: true, participant: confirmedRow }, 200, corsHeaders)
    }

    // Signup flow
    const {
      tournamentId,
      name,
      contactEmail,
      formResponses,
      turnstileToken,
      returnOrigin,
    } = body

    if (
      typeof tournamentId !== "string" ||
      typeof name !== "string" ||
      typeof contactEmail !== "string" ||
      !name.trim() ||
      !contactEmail.trim()
    ) {
      throw new AppError(400, "Tournament ID, team name, and contact email are required.")
    }

    const trimmedName = name.trim().slice(0, 120)
    const normalizedEmail = contactEmail.trim().toLowerCase().slice(0, 254)
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      throw new AppError(400, "Please provide a valid email address.")
    }

    const clientIp =
      req.headers.get("cf-connecting-ip") ??
      req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
      "unknown"

    const turnstileOk = await verifyTurnstile(turnstileToken, clientIp)
    if (!turnstileOk) {
      return jsonError(400, "CAPTCHA verification failed. Please try again.", corsHeaders)
    }

    // Rate limit: max 5 signups per IP per 15 minutes
    const fifteenMinAgo = new Date(Date.now() - 15 * 60 * 1000).toISOString()
    const ipRateKey = `ip:${clientIp}`
    const { count: ipCount } = await supabase
      .from("signup_rate_limits")
      .select("id", { count: "exact", head: true })
      .eq("rate_key", ipRateKey)
      .gte("created_at", fifteenMinAgo)

    if ((ipCount ?? 0) >= 5) {
      return jsonError(429, "Too many signup attempts. Please try again later.", corsHeaders)
    }

    // Rate limit: max 3 signups per email+tournament per hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    const emailRateKey = `email:${tournamentId}:${normalizedEmail}`
    const { count: emailCount } = await supabase
      .from("signup_rate_limits")
      .select("id", { count: "exact", head: true })
      .eq("rate_key", emailRateKey)
      .gte("created_at", oneHourAgo)

    if ((emailCount ?? 0) >= 3) {
      return jsonError(429, "Too many signup attempts for this email. Please check your inbox or try later.", corsHeaders)
    }

    await supabase.from("signup_rate_limits").insert([
      { rate_key: ipRateKey },
      { rate_key: emailRateKey },
    ])

    // Verify tournament is public/unlisted and pending
    const { data: tournament, error: tError } = await supabase
      .from("tournaments")
      .select("id, name, status, visibility")
      .eq("id", tournamentId)
      .single()

    if (tError || !tournament || !["public", "unlisted"].includes(tournament.visibility)) {
      throw new AppError(404, "Tournament not found.")
    }
    if (tournament.status !== "pending") {
      throw new AppError(400, "Signups are closed for this tournament.")
    }

    const rawToken = crypto.randomUUID() + crypto.randomUUID().replace(/-/g, "")
    const tokenHash = await sha256Hex(rawToken)
    const resendKey = Deno.env.get("RESEND_API_KEY")
    const requiresConfirmation = Boolean(resendKey)

    const { error: insertErr } = await supabase.from("tournament_participants").insert({
      tournament_id: tournamentId,
      name: trimmedName,
      contact_email: normalizedEmail,
      form_responses: formResponses && typeof formResponses === "object" ? formResponses : {},
      confirmation_status: requiresConfirmation ? "pending_confirmation" : "confirmed",
      confirmation_token_hash: requiresConfirmation ? tokenHash : null,
      confirmed_at: requiresConfirmation ? null : new Date().toISOString(),
    })

    if (insertErr) {
      if (insertErr.message?.includes("already registered") || insertErr.message?.includes("maximum number")) {
        throw new AppError(400, insertErr.message)
      }
      console.error("[tournament-signup] Insert failed:", insertErr)
      throw new AppError(500, "Could not complete registration. Please try again.")
    }

    if (requiresConfirmation && resendKey) {
      const baseOrigin =
        typeof returnOrigin === "string" && isAllowedReturnUrl(returnOrigin)
          ? new URL(returnOrigin).origin
          : getDefaultReturnOrigin()
      const confirmUrl = `${baseOrigin}/tournament/${tournamentId}/signup?confirm=${rawToken}`

      await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: Deno.env.get("RESEND_FROM_EMAIL") ?? "ScoreBoard <noreply@score-board.net>",
          to: [normalizedEmail],
          subject: `Confirm your registration for ${tournament.name}`,
          text: `You registered "${trimmedName}" for ${tournament.name}.\n\nConfirm your spot here:\n${confirmUrl}\n`,
        }),
      }).catch((mailErr) => {
        console.error("[tournament-signup] Confirmation email send failed:", mailErr)
      })
    }

    return jsonResponse(
      {
        success: true,
        requiresConfirmation,
      },
      200,
      corsHeaders
    )
  } catch (err) {
    return handleEdgeError(err, "tournament-signup", corsHeaders)
  }
})
