import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { getCorsHeaders, handleCorsPreflight } from "../_shared/cors.ts"
import { AppError, handleEdgeError, jsonError, jsonResponse } from "../_shared/errors.ts"

serve(async (req) => {
  const preflight = handleCorsPreflight(req)
  if (preflight) return preflight

  const corsHeaders = getCorsHeaders(req)

  try {
    // Verify caller identity BEFORE querying the database (prevents pre-auth existence oracle)
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

    const { matchId, setHistory } = await req.json()
    if (!matchId || !Array.isArray(setHistory)) {
      throw new AppError(400, "Invalid request: matchId and setHistory are required.")
    }

    // Fetch Match and Tournament Rules
    const { data: match, error: fetchError } = await supabase
      .from("matches")
      .select("*, tournaments(*)")
      .eq("id", matchId)
      .single()

    if (fetchError || !match) {
      throw new AppError(404, "Match not found.")
    }

    const isOrganizer = user.id === match.organizer_id
    const isAcceptedUmpire = user.id === match.umpire_id && match.umpire_invite_status === "accepted"

    if (!isOrganizer && !isAcceptedUmpire) {
      return jsonError(
        403,
        "Forbidden: Only the match organizer or accepted umpire can finalize this match",
        corsHeaders
      )
    }

    if (match.status === "completed") {
      return jsonError(409, "Conflict: Match is already completed", corsHeaders)
    }

    // Priority: Match settings > Tournament Round overrides > Tournament Default settings
    const tournamentSettings = match.tournaments?.settings || {}
    const rules =
      match.settings && Object.keys(match.settings).length > 0
        ? match.settings
        : tournamentSettings.overrides?.[match.round_number] ||
          tournamentSettings.default || { max_sets: 3, points_per_set: 25 }

    // 2. BACKEND VALIDATION
    let t1Sets = 0
    let t2Sets = 0
    const maxSets = rules.max_sets || 3
    const setsToWin = Math.ceil(maxSets / 2)

    for (const set of setHistory) {
      const p1 = set.team1
      const p2 = set.team2
      const target = rules.points_per_set || 25
      const cap = rules.point_cap
      const winnerScore = Math.max(p1, p2)
      const loserScore = Math.min(p1, p2)
      const lead = winnerScore - loserScore

      if (winnerScore < target && (!cap || winnerScore < cap)) {
        throw new AppError(
          400,
          `Set not finished: ${p1}-${p2}. Target is ${target}${cap ? ` (Cap: ${cap})` : ""}.`
        )
      }
      if (cap && winnerScore === cap) {
        if (p1 > cap || p2 > cap) {
          throw new AppError(400, `Score exceeds cap ${cap}.`)
        }
      } else {
        if (lead < 2) {
          throw new AppError(400, "Must win by 2 unless Cap is reached.")
        }
        if (winnerScore > target && lead !== 2) {
          throw new AppError(400, `Impossible score: ${p1}-${p2}.`)
        }
      }
      if (p1 > p2) t1Sets++
      else t2Sets++
    }

    if (t1Sets < setsToWin && t2Sets < setsToWin) {
      throw new AppError(
        400,
        `Match not yet finished. Sets: ${t1Sets}-${t2Sets}. Need ${setsToWin} to win.`
      )
    }

    // 3. SECURE ADVANCEMENT
    const winnerIdx = t1Sets > t2Sets ? 0 : 1
    const loserIdx = winnerIdx === 0 ? 1 : 0
    const winner = match.participants?.[winnerIdx]
    const loser = match.participants?.[loserIdx]

    if (!winner) {
      throw new AppError(400, "Could not determine winner from participants list.")
    }

    // Atomic conditional update prevents TOCTOU race where two concurrent requests both see non-completed
    const { data: updatedMatch, error: updateError } = await supabase
      .from("matches")
      .update({
        status: "completed",
        scores: {
          ...match.scores,
          final_history: setHistory,
          final_sets: [t1Sets, t2Sets],
        },
      })
      .eq("id", matchId)
      .neq("status", "completed")
      .select("id")
      .maybeSingle()

    if (updateError) {
      console.error("[finalize-match] Failed to update match:", updateError)
      throw new AppError(500, "Failed to update match.")
    }

    if (!updatedMatch) {
      return jsonError(409, "Conflict: Match is already completed", corsHeaders)
    }

    const advanceSlot = async (
      targetMatchId: string,
      slotIdx: number | null,
      participant: unknown,
      findEmptySlot = false
    ) => {
      const { error: rpcErr } = await supabase.rpc("set_match_participant_slot", {
        p_match_id: targetMatchId,
        p_slot_idx: slotIdx,
        p_participant: participant,
        p_find_empty_slot: findEmptySlot,
      })
      if (rpcErr) {
        console.error("[finalize-match] Failed to advance participant:", rpcErr)
        throw new AppError(500, "Failed to advance bracket participant.")
      }
    }

    const tournamentType = match.tournaments?.settings?.stage_1?.type

    // --- CASE A: WINNERS BRACKET (DOUBLE ELIMINATION) ---
    if (match.bracket_type === "main" && tournamentType === "double_elimination") {
      const nextRound = match.round_number + 1
      const nextOrder = Math.ceil(match.match_order / 2)
      const { data: nextWinnersMatch } = await supabase
        .from("matches")
        .select("id")
        .eq("tournament_id", match.tournament_id)
        .eq("bracket_type", "main")
        .eq("round_number", nextRound)
        .eq("match_order", nextOrder)
        .maybeSingle()

      if (nextWinnersMatch) {
        const slotIdx = match.match_order % 2 === 1 ? 0 : 1
        await advanceSlot(nextWinnersMatch.id, slotIdx, winner)
      } else {
        const { data: grandFinal } = await supabase
          .from("matches")
          .select("id")
          .eq("tournament_id", match.tournament_id)
          .eq("bracket_type", "grand_final")
          .maybeSingle()
        if (grandFinal) {
          await advanceSlot(grandFinal.id, 0, winner)
        }
      }

      // 2. Loser drops to Losers Bracket
      let destinationRound: number
      let destinationOrder: number

      if (match.round_number === 1) {
        destinationRound = 1
        destinationOrder = Math.ceil(match.match_order / 2)
      } else {
        destinationRound = match.round_number * 2 - 2
        destinationOrder = match.match_order
      }

      const { data: losersMatch } = await supabase
        .from("matches")
        .select("id")
        .eq("tournament_id", match.tournament_id)
        .eq("bracket_type", "losers")
        .eq("round_number", destinationRound)
        .eq("match_order", destinationOrder)
        .maybeSingle()

      if (losersMatch && loser) {
        await advanceSlot(losersMatch.id, null, loser, true)
      }
    }
    // --- CASE B: LOSERS BRACKET (DOUBLE ELIMINATION) ---
    else if (match.bracket_type === "losers" && tournamentType === "double_elimination") {
      const nextRound = match.round_number + 1
      const isDroppingInRound = match.round_number % 2 === 1
      const nextOrder = isDroppingInRound ? match.match_order : Math.ceil(match.match_order / 2)

      const { data: nextLosersMatch } = await supabase
        .from("matches")
        .select("id")
        .eq("tournament_id", match.tournament_id)
        .eq("bracket_type", "losers")
        .eq("round_number", nextRound)
        .eq("match_order", nextOrder)
        .maybeSingle()

      if (nextLosersMatch) {
        const slotIdx = isDroppingInRound ? 1 : match.match_order % 2 === 1 ? 0 : 1
        await advanceSlot(nextLosersMatch.id, slotIdx, winner)
      } else {
        const { data: grandFinal } = await supabase
          .from("matches")
          .select("id")
          .eq("tournament_id", match.tournament_id)
          .eq("bracket_type", "grand_final")
          .maybeSingle()
        if (grandFinal) {
          await advanceSlot(grandFinal.id, 1, winner)
        }
      }
    }
    // --- CASE C: SINGLE ELIMINATION / MAIN ---
    else {
      const nextRound = match.round_number + 1
      const nextOrder = Math.ceil(match.match_order / 2)
      const { data: nextMatch } = await supabase
        .from("matches")
        .select("id")
        .eq("tournament_id", match.tournament_id)
        .eq("bracket_type", match.bracket_type)
        .eq("round_number", nextRound)
        .eq("match_order", nextOrder)
        .maybeSingle()

      if (nextMatch) {
        const slotIdx = match.match_order % 2 === 1 ? 0 : 1
        await advanceSlot(nextMatch.id, slotIdx, winner)
      }
    }

    return jsonResponse({ success: true }, 200, corsHeaders)
  } catch (err) {
    return handleEdgeError(err, "finalize-match", corsHeaders)
  }
})
