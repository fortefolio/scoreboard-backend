import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { getCorsHeaders, handleCorsPreflight } from "../_shared/cors.ts"
import { AppError, handleEdgeError, jsonError, jsonResponse } from "../_shared/errors.ts"

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req)
  if (preflight) return preflight

  const corsHeaders = getCorsHeaders(req)

  try {
    // Verify caller identity before processing request
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

    const { tournament_id, sport_type, teams: rawTeams, settings: manualSettings } = await req.json()

    // 0. Clean and Validate Teams
    const teams = (rawTeams || []).filter((t: any) => {
      if (typeof t === "string") return t.trim() !== ""
      return t && (t.name || t.id)
    })

    if (!tournament_id || teams.length < 2) {
      throw new AppError(400, "Invalid request: at least 2 valid teams and a tournament_id are required.")
    }

    const { data: tournamentRecord, error: fetchError } = await supabase
      .from("tournaments")
      .select("organizer_id, settings")
      .eq("id", tournament_id)
      .single()

    if (fetchError || !tournamentRecord) {
      throw new AppError(404, "Tournament not found.")
    }
    if (tournamentRecord.organizer_id !== user.id) {
      return jsonError(403, "Forbidden: Only the tournament organizer can generate brackets", corsHeaders)
    }

    const organizer_id = tournamentRecord.organizer_id
    const settings = manualSettings || tournamentRecord.settings || {}

    // 1. Transform teams into Participant Objects
    const participants = teams.map((team: any) => {
      if (typeof team === "string") return { name: team }
      return { id: team.id, name: team.name }
    })

    const rawMaxTeams = settings?.max_teams ?? settings?.stage_1?.max_teams
    const maxTeams = rawMaxTeams ? parseInt(String(rawMaxTeams), 10) : participants.length
    const limitedParticipants = participants.slice(0, maxTeams)

    const matchesToCreate: any[] = []
    const type = settings?.stage_1?.type || "bracket"

    // --- STAGE 1: GROUPS (ROUND ROBIN) ---
    if (type === "groups") {
      const teamsPerGroup = 4
      const numGroups = Math.ceil(limitedParticipants.length / teamsPerGroup)

      const groups: Record<string, any[]> = {}
      for (let i = 0; i < numGroups; i++) {
        const groupLabel = String.fromCharCode(65 + i)
        groups[groupLabel] = limitedParticipants.slice(i * teamsPerGroup, (i + 1) * teamsPerGroup)
      }

      Object.entries(groups).forEach(([label, groupTeams]) => {
        for (let i = 0; i < groupTeams.length; i++) {
          for (let j = i + 1; j < groupTeams.length; j++) {
            matchesToCreate.push({
              tournament_id,
              organizer_id,
              sport_type,
              group_label: label,
              round_number: 1,
              participants: [groupTeams[i], groupTeams[j]],
              status: "scheduled",
              bracket_type: "main",
            })
          }
        }
      })
    }
    // --- STAGE 1: DOUBLE ELIMINATION ---
    else if (type === "double_elimination") {
      const teamCount = limitedParticipants.length
      const bracketSize = Math.pow(2, Math.ceil(Math.log2(teamCount)))
      const winnersRounds = Math.log2(bracketSize)

      const seededTeams = Array(bracketSize).fill(null)
      for (let i = 0; i < teamCount; i++) seededTeams[i] = limitedParticipants[i]

      const round2Participants = Array.from({ length: Math.max(1, bracketSize / 4) }, () => [null, null])

      for (let i = 0; i < bracketSize / 2; i++) {
        const t1 = seededTeams[i]
        const t2 = seededTeams[bracketSize - 1 - i]
        const matchOrder = i + 1
        const nextOrder = Math.ceil(matchOrder / 2)
        const nextSlot = matchOrder % 2 === 1 ? 0 : 1

        if (t1 && t2) {
          matchesToCreate.push({
            tournament_id,
            organizer_id,
            sport_type,
            round_number: 1,
            match_order: matchOrder,
            participants: [t1, t2],
            status: "scheduled",
            bracket_type: "main",
          })
        } else if (t1 || t2) {
          const byeTeam = t1 || t2
          if (bracketSize > 2) round2Participants[nextOrder - 1][nextSlot] = byeTeam
        }
      }

      if (winnersRounds >= 2) {
        for (let m = 1; m <= bracketSize / 4; m++) {
          const currentParticipants = (round2Participants[m - 1] || []).filter(Boolean)
          matchesToCreate.push({
            tournament_id,
            organizer_id,
            sport_type,
            round_number: 2,
            match_order: m,
            participants: currentParticipants,
            status: "scheduled",
            bracket_type: "main",
          })
        }
      }

      let currentRoundSize = bracketSize / 8
      for (let r = 3; r <= winnersRounds; r++) {
        for (let m = 1; m <= currentRoundSize; m++) {
          matchesToCreate.push({
            tournament_id,
            organizer_id,
            sport_type,
            round_number: r,
            match_order: m,
            participants: [],
            status: "scheduled",
            bracket_type: "main",
          })
        }
        currentRoundSize /= 2
      }

      const numLosersRounds = (winnersRounds - 1) * 2
      let losersRoundSize = bracketSize / 4
      for (let r = 1; r <= numLosersRounds; r++) {
        for (let m = 1; m <= losersRoundSize; m++) {
          matchesToCreate.push({
            tournament_id,
            organizer_id,
            sport_type,
            round_number: r,
            match_order: m,
            participants: [],
            status: "scheduled",
            bracket_type: "losers",
          })
        }
        if (r % 2 === 0) losersRoundSize /= 2
      }

      matchesToCreate.push({
        tournament_id,
        organizer_id,
        sport_type,
        round_number: 1,
        match_order: 1,
        participants: [],
        status: "scheduled",
        bracket_type: "grand_final",
      })
    }
    // --- STAGE 1: SINGLE ELIMINATION BRACKET ---
    else {
      const teamCount = limitedParticipants.length
      const bracketSize = Math.pow(2, Math.ceil(Math.log2(teamCount)))
      const roundsCount = Math.log2(bracketSize)

      const seededTeams = Array(bracketSize).fill(null)
      for (let i = 0; i < teamCount; i++) seededTeams[i] = limitedParticipants[i]

      const round2Participants = Array.from({ length: Math.max(1, bracketSize / 4) }, () => [null, null])

      for (let i = 0; i < bracketSize / 2; i++) {
        const t1 = seededTeams[i]
        const t2 = seededTeams[bracketSize - 1 - i]
        const matchOrder = i + 1
        const nextOrder = Math.ceil(matchOrder / 2)
        const nextSlot = matchOrder % 2 === 1 ? 0 : 1

        if (t1 && t2) {
          matchesToCreate.push({
            tournament_id,
            organizer_id,
            sport_type,
            round_number: 1,
            match_order: matchOrder,
            participants: [t1, t2],
            status: "scheduled",
            bracket_type: "main",
          })
        } else if (t1 || t2) {
          const byeTeam = t1 || t2
          if (bracketSize > 2) {
            const idx = nextOrder - 1
            if (round2Participants[idx]) round2Participants[idx][nextSlot] = byeTeam
          }
        }
      }

      if (roundsCount >= 2) {
        for (let m = 1; m <= bracketSize / 4; m++) {
          const currentParticipants = (round2Participants[m - 1] || []).filter(Boolean)
          matchesToCreate.push({
            tournament_id,
            organizer_id,
            sport_type,
            round_number: 2,
            match_order: m,
            participants: currentParticipants,
            status: "scheduled",
            bracket_type: "main",
          })
        }
      }

      let currentRoundSize = bracketSize / 8
      for (let r = 3; r <= roundsCount; r++) {
        for (let m = 1; m <= currentRoundSize; m++) {
          matchesToCreate.push({
            tournament_id,
            organizer_id,
            sport_type,
            round_number: r,
            match_order: m,
            participants: [],
            status: "scheduled",
            bracket_type: "main",
          })
        }
        currentRoundSize /= 2
      }
    }

    const roundDates = settings?.round_dates || {}
    matchesToCreate.forEach((match) => {
      if (match.round_number && roundDates[match.round_number]) {
        match.round_date = roundDates[match.round_number]
        match.scheduled_at = match.round_date
      }
    })

    const numberOfCourts = settings?.number_of_courts || 0
    if (numberOfCourts > 0) {
      matchesToCreate.forEach((match, index) => {
        match.court = ((index % numberOfCourts) + 1).toString()
      })
    }

    const { data: matchData, error: matchError } = await supabase
      .from("matches")
      .insert(matchesToCreate)
      .select()

    if (matchError) {
      console.error("[generate-tournament-bracket] Match insert error:", matchError)
      throw new AppError(500, "Failed to create tournament matches.")
    }

    const { error: updateError } = await supabase
      .from("tournaments")
      .update({ status: "ongoing" })
      .eq("id", tournament_id)

    if (updateError) {
      console.error("[generate-tournament-bracket] Tournament status update error:", updateError)
      throw new AppError(500, "Failed to update tournament status.")
    }

    return jsonResponse(
      {
        success: true,
        total_matches_created: matchesToCreate.length,
        matches: matchData,
      },
      200,
      corsHeaders
    )
  } catch (err) {
    return handleEdgeError(err, "generate-tournament-bracket", corsHeaders)
  }
})
