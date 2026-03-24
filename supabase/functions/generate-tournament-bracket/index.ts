import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// 1. Define CORS headers for the browser
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // 2. Handle the browser "preflight" check
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { tournament_id, organizer_id, sport_type, teams } = await req.json()

    if (!tournament_id || !organizer_id || !teams || teams.length < 2) {
      throw new Error("Need a tournament_id, organizer_id, and at least 2 teams")
    }

    // 3. The Core Bracket Math
    const numTeams = teams.length
    const bracketSize = Math.pow(2, Math.ceil(Math.log2(numTeams)))
    const byes = bracketSize - numTeams
    const totalRounds = Math.log2(bracketSize)

    console.log(`Generating bracket for ${numTeams} teams. Size: ${bracketSize}, Byes: ${byes}`)

    const matchesToInsert = []
    let currentTeamIndex = 0

    // Generate First Round (Handling Byes)
    const firstRoundSlots = bracketSize / 2
    for (let i = 0; i < firstRoundSlots; i++) {
      let matchParticipants = []
      if (i < byes) {
        matchParticipants = [{ id: teams[currentTeamIndex].id, name: teams[currentTeamIndex].name }]
        currentTeamIndex++
      } else {
        matchParticipants = [
          { id: teams[currentTeamIndex].id, name: teams[currentTeamIndex].name },
          { id: teams[currentTeamIndex + 1].id, name: teams[currentTeamIndex + 1].name }
        ]
        currentTeamIndex += 2
      }

      matchesToInsert.push({
        tournament_id,
        organizer_id,
        sport_type,
        status: matchParticipants.length === 1 ? 'completed' : 'scheduled',
        participants: matchParticipants,
        round_number: 1,
        match_order: i + 1
      })
    }

    // Generate Future Empty Rounds
    for (let round = 2; round <= totalRounds; round++) {
      const matchesInRound = bracketSize / Math.pow(2, round)
      for (let i = 0; i < matchesInRound; i++) {
        matchesToInsert.push({
          tournament_id,
          organizer_id,
          sport_type,
          status: 'scheduled', 
          participants: [],  
          round_number: round,
          match_order: i + 1
        })
      }
    }

    // 4. Connect to Supabase
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 5. Insert Matches
    const { data: matchData, error: matchError } = await supabase
      .from('matches')
      .insert(matchesToInsert)
      .select()

    if (matchError) throw matchError

    // 6. Update Tournament Status to 'scheduled'
    const { error: updateError } = await supabase
      .from('tournaments')
      .update({ status: 'scheduled' })
      .eq('id', tournament_id)

    if (updateError) throw updateError

    // 7. Success Response with CORS headers
    return new Response(JSON.stringify({ 
      message: "Bracket generated successfully", 
      total_matches_created: matchesToInsert.length,
      matches: matchData
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    })

  } catch (err: any) {
    console.error("Critical Error:", err.message)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    })
  }
})