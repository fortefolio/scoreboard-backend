// supabase/functions/advance-to-knockout/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { getCorsHeaders, handleCorsPreflight } from "../_shared/cors.ts"
import { AppError, handleEdgeError, jsonError, jsonResponse } from "../_shared/errors.ts"

Deno.serve(async (req) => {
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

    const { tournamentId } = await req.json()
    if (!tournamentId) {
      throw new AppError(400, "Missing tournamentId")
    }

    const { data: tournament, error: tError } = await supabase
      .from("tournaments")
      .select("id, organizer_id, sport_type, settings")
      .eq("id", tournamentId)
      .single()

    if (tError || !tournament) {
      throw new AppError(404, "Tournament not found")
    }
    if (tournament.organizer_id !== user.id) {
      return jsonError(403, "Forbidden: Only the tournament organizer can advance to knockout", corsHeaders)
    }

    // 1. Fetch the standings from the SQL View
    const { data: standings, error } = await supabase
      .from("group_standings")
      .select("*")
      .eq("tournament_id", tournamentId)

    if (error || !standings || standings.length < 2) {
      throw new AppError(400, "Insufficient group standings to generate knockout bracket")
    }

    // 2. GET DIRECT QUALIFIERS (Top N from each group)
    const advancePerGroup = tournament.settings?.stage_1?.advance_per_group || 2
    const qualifiedTeams: any[] = []
    const groups = [...new Set(standings.map((s: any) => s.group_label))].sort()

    groups.forEach((label) => {
      const groupWinners = standings
        .filter((s: any) => s.group_label === label)
        .slice(0, advancePerGroup)
      qualifiedTeams.push(...groupWinners)
    })

    // 3. THE "ODD NUMBER" STRATEGY (Wildcards to reach nearest power of 2)
    let totalSlotsNeeded = 2
    while (totalSlotsNeeded < qualifiedTeams.length) totalSlotsNeeded *= 2

    if (qualifiedTeams.length < totalSlotsNeeded) {
      const remainingNeeded = totalSlotsNeeded - qualifiedTeams.length
      const qualifiedNames = qualifiedTeams.map((t) => t.team_name)
      const wildcards = standings
        .filter((s: any) => !qualifiedNames.includes(s.team_name))
        .slice(0, remainingNeeded)

      qualifiedTeams.push(...wildcards)
    }

    // 4. GENERATE THE KNOCKOUT BRACKET
    const knockoutMatches: any[] = []
    const firstRoundMatches = totalSlotsNeeded / 2
    const totalRounds = Math.log2(totalSlotsNeeded)

    for (let i = 0; i < firstRoundMatches; i++) {
      const t1 = qualifiedTeams[i]
      const t2 = qualifiedTeams[totalSlotsNeeded - 1 - i]
      const participants = [
        t1 ? { name: t1.team_name } : null,
        t2 ? { name: t2.team_name } : null,
      ].filter(Boolean)

      knockoutMatches.push({
        tournament_id: tournamentId,
        organizer_id: tournament.organizer_id,
        sport_type: tournament.sport_type,
        round_number: 1,
        match_order: i + 1,
        participants,
        status: "scheduled",
        bracket_type: "main",
      })
    }

    let currentRoundSize = firstRoundMatches / 2
    for (let r = 2; r <= totalRounds; r++) {
      for (let m = 1; m <= currentRoundSize; m++) {
        knockoutMatches.push({
          tournament_id: tournamentId,
          organizer_id: tournament.organizer_id,
          sport_type: tournament.sport_type,
          round_number: r,
          match_order: m,
          participants: [],
          status: "scheduled",
          bracket_type: "main",
        })
      }
      currentRoundSize /= 2
    }

    const { error: insertError } = await supabase.from("matches").insert(knockoutMatches)
    if (insertError) {
      console.error("[advance-to-knockout] Failed to insert knockout matches:", insertError)
      throw new AppError(500, "Failed to create knockout matches.")
    }

    return jsonResponse({ success: true, matches_created: knockoutMatches.length }, 200, corsHeaders)
  } catch (err) {
    return handleEdgeError(err, "advance-to-knockout", corsHeaders)
  }
})
