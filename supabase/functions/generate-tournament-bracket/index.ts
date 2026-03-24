import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { tournament_id, organizer_id, sport_type, teams: rawTeams, settings: manualSettings } = await req.json()

    // 0. Clean and Validate Teams
    const teams = (rawTeams || []).filter((t: any) => {
      if (typeof t === 'string') return t.trim() !== '';
      return t && (t.name || t.id);
    });

    console.log(`Generating bracket for ${teams.length} teams (Tournament: ${tournament_id})`);

    if (!tournament_id || !organizer_id || teams.length < 2) {
      throw new Error(`Invalid request: ${teams.length} valid teams found. Need at least 2.`)
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch settings if not provided in request
    let settings = manualSettings;
    if (!settings) {
      const { data: tournament, error: fetchError } = await supabase
        .from('tournaments')
        .select('settings')
        .eq('id', tournament_id)
        .single();
      
      if (fetchError) throw new Error(`Could not fetch tournament settings: ${fetchError.message}`);
      settings = tournament?.settings || {};
    }

    // 1. Transform teams into Participant Objects
    const participants = teams.map((team: any) => {
      if (typeof team === 'string') return { name: team };
      return { id: team.id, name: team.name };
    });

    const matchesToCreate = [];
    const type = settings?.stage_1?.type || 'bracket';

    // --- STAGE 1: GROUPS (ROUND ROBIN) ---
    if (type === "groups") {
      const teamsPerGroup = settings.stage_1.teams_per_group || 4;
      const numGroups = Math.ceil(participants.length / teamsPerGroup);
      
      const groups: Record<string, any[]> = {};
      for (let i = 0; i < numGroups; i++) {
        const groupLabel = String.fromCharCode(65 + i);
        groups[groupLabel] = participants.slice(i * teamsPerGroup, (i + 1) * teamsPerGroup);
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
              status: 'scheduled',
              bracket_type: 'main'
            });
          }
        }
      });
    } 
    // --- STAGE 1: DOUBLE ELIMINATION ---
    else if (type === 'double_elimination') {
      const teamCount = participants.length;
      const bracketSize = Math.pow(2, Math.ceil(Math.log2(teamCount)));
      const winnersRounds = Math.log2(bracketSize);

      const seededTeams = Array(bracketSize).fill(null);
      for (let i = 0; i < teamCount; i++) seededTeams[i] = participants[i];

      const round2Participants = Array.from({ length: Math.max(1, bracketSize / 4) }, () => [null, null]);

      // Winners Round 1
      for (let i = 0; i < bracketSize / 2; i++) {
        const t1 = seededTeams[i];
        const t2 = seededTeams[bracketSize - 1 - i];
        const matchOrder = i + 1;
        const nextOrder = Math.ceil(matchOrder / 2);
        const nextSlot = matchOrder % 2 === 1 ? 0 : 1;

        if (t1 && t2) {
          matchesToCreate.push({
            tournament_id, organizer_id, sport_type,
            round_number: 1, match_order: matchOrder,
            participants: [t1, t2], status: 'scheduled',
            bracket_type: 'main'
          });
        } else if (t1 || t2) {
          const byeTeam = t1 || t2;
          if (bracketSize > 2) round2Participants[nextOrder - 1][nextSlot] = byeTeam;
        }
      }

      // Winners Round 2
      if (winnersRounds >= 2) {
        for (let m = 1; m <= bracketSize / 4; m++) {
          const currentParticipants = (round2Participants[m - 1] || []).filter(Boolean);
          matchesToCreate.push({
            tournament_id, organizer_id, sport_type,
            round_number: 2, match_order: m,
            participants: currentParticipants, status: 'scheduled',
            bracket_type: 'main'
          });
        }
      }

      // Winners Round 3+
      let currentRoundSize = bracketSize / 8;
      for (let r = 3; r <= winnersRounds; r++) {
        for (let m = 1; m <= currentRoundSize; m++) {
          matchesToCreate.push({
            tournament_id, organizer_id, sport_type,
            round_number: r, match_order: m,
            participants: [], status: 'scheduled',
            bracket_type: 'main'
          });
        }
        currentRoundSize /= 2;
      }

      // Losers Bracket
      const numLosersRounds = (winnersRounds - 1) * 2;
      let losersRoundSize = bracketSize / 4;
      for (let r = 1; r <= numLosersRounds; r++) {
        for (let m = 1; m <= losersRoundSize; m++) {
          matchesToCreate.push({
            tournament_id, organizer_id, sport_type,
            round_number: r, match_order: m,
            participants: [], status: 'scheduled',
            bracket_type: 'losers'
          });
        }
        if (r % 2 === 0) losersRoundSize /= 2;
      }

      // Grand Final
      matchesToCreate.push({
        tournament_id, organizer_id, sport_type,
        round_number: 1, match_order: 1,
        participants: [], status: 'scheduled',
        bracket_type: 'grand_final'
      });
    }
    // --- STAGE 1: SINGLE ELIMINATION BRACKET ---
    else {
      const teamCount = participants.length;
      const bracketSize = Math.pow(2, Math.ceil(Math.log2(teamCount)));
      const roundsCount = Math.log2(bracketSize);

      const seededTeams = Array(bracketSize).fill(null);
      for (let i = 0; i < teamCount; i++) seededTeams[i] = participants[i];

      const round2Participants = Array.from({ length: Math.max(1, bracketSize / 4) }, () => [null, null]);

      for (let i = 0; i < bracketSize / 2; i++) {
        const t1 = seededTeams[i];
        const t2 = seededTeams[bracketSize - 1 - i];
        const matchOrder = i + 1;
        const nextOrder = Math.ceil(matchOrder / 2);
        const nextSlot = matchOrder % 2 === 1 ? 0 : 1;

        if (t1 && t2) {
          matchesToCreate.push({
            tournament_id, organizer_id, sport_type,
            round_number: 1, match_order: matchOrder,
            participants: [t1, t2], status: 'scheduled',
            bracket_type: 'main'
          });
        } else if (t1 || t2) {
          const byeTeam = t1 || t2;
          if (bracketSize > 2) {
            // Ensure nextOrder-1 is valid
            const idx = nextOrder - 1;
            if (round2Participants[idx]) round2Participants[idx][nextSlot] = byeTeam;
          }
        }
      }

      if (roundsCount >= 2) {
        for (let m = 1; m <= bracketSize / 4; m++) {
          const currentParticipants = (round2Participants[m - 1] || []).filter(Boolean);
          matchesToCreate.push({
            tournament_id, organizer_id, sport_type,
            round_number: 2, match_order: m,
            participants: currentParticipants, status: 'scheduled',
            bracket_type: 'main'
          });
        }
      }

      let currentRoundSize = bracketSize / 8;
      for (let r = 3; r <= roundsCount; r++) {
        for (let m = 1; m <= currentRoundSize; m++) {
          matchesToCreate.push({
            tournament_id, organizer_id, sport_type,
            round_number: r, match_order: m,
            participants: [], status: 'scheduled',
            bracket_type: 'main'
          });
        }
        currentRoundSize /= 2;
      }
    }

    const { data: matchData, error: matchError } = await supabase
      .from('matches')
      .insert(matchesToCreate)
      .select()

    if (matchError) throw matchError

    const { error: updateError } = await supabase
      .from('tournaments')
      .update({ status: 'ongoing' })
      .eq('id', tournament_id)

    if (updateError) throw updateError

    return new Response(JSON.stringify({ 
      success: true, 
      total_matches_created: matchesToCreate.length,
      matches: matchData 
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (err: any) {
    console.error(`Error in generate-tournament-bracket: ${err.message}`);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})