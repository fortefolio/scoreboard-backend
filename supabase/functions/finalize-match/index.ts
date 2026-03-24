import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { matchId, setHistory } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Fetch Match and Tournament Rules
    const { data: match, error: fetchError } = await supabase
      .from('matches')
      .select('*, tournaments(*)')
      .eq('id', matchId)
      .single()

    if (fetchError || !match) throw new Error("Match not found")

    const rules = match.tournaments.settings?.overrides?.[match.round_number] || 
                  match.tournaments.settings?.default || {}
    
    // 2. BACKEND VALIDATION
    let t1Sets = 0, t2Sets = 0;
    const setsToWin = Math.ceil(rules.max_sets / 2);

    for (const set of setHistory) {
      const p1 = set.team1, p2 = set.team2;
      const target = rules.points_per_set, cap = rules.point_cap;
      const winnerScore = Math.max(p1, p2), loserScore = Math.min(p1, p2);
      const lead = winnerScore - loserScore;

      if (winnerScore < target && (!cap || winnerScore < cap)) {
        throw new Error(`Set not finished: ${p1}-${p2}. Target is ${target}${cap ? ` (Cap: ${cap})` : ''}.`);
      }
      if (cap && winnerScore === cap) {
        if (p1 > cap || p2 > cap) throw new Error(`Score exceeds cap ${cap}.`);
      } else {
        if (lead < 2) throw new Error(`Must win by 2 unless Cap is reached.`);
        if (winnerScore > target && lead !== 2) throw new Error(`Impossible score: ${p1}-${p2}.`);
      }
      if (p1 > p2) t1Sets++; else t2Sets++;
    }

    if (t1Sets < setsToWin && t2Sets < setsToWin) throw new Error("Match not yet finished.");

    // 3. SECURE ADVANCEMENT
    const winnerIdx = t1Sets > t2Sets ? 0 : 1;
    const loserIdx = winnerIdx === 0 ? 1 : 0;
    const winner = match.participants[winnerIdx];
    const loser = match.participants[loserIdx];

    // Update current match
    await supabase.from('matches').update({
      status: 'completed',
      current_score: { sets: setHistory, final_sets: [t1Sets, t2Sets] }
    }).eq('id', matchId)

    const tournamentType = match.tournaments.settings?.stage_1?.type;

    // --- CASE A: WINNERS BRACKET (DOUBLE ELIMINATION) ---
    if (match.bracket_type === 'main' && tournamentType === 'double_elimination') {
      // 1. Winner advances in Winners Bracket
      const nextRound = match.round_number + 1;
      const nextOrder = Math.ceil(match.match_order / 2);
      const { data: nextWinnersMatch } = await supabase.from('matches')
        .select('*').eq('tournament_id', match.tournament_id).eq('bracket_type', 'main')
        .eq('round_number', nextRound).eq('match_order', nextOrder).single();

      if (nextWinnersMatch) {
        const slotIdx = match.match_order % 2 === 1 ? 0 : 1;
        const updatedParticipants = [...nextWinnersMatch.participants];
        updatedParticipants[slotIdx] = winner;
        await supabase.from('matches').update({ participants: updatedParticipants }).eq('id', nextWinnersMatch.id);
      } else {
        // Advance to Grand Final top slot
        const { data: grandFinal } = await supabase.from('matches')
          .select('*').eq('tournament_id', match.tournament_id).eq('bracket_type', 'grand_final').single();
        if (grandFinal) {
          const updatedParticipants = [...grandFinal.participants];
          updatedParticipants[0] = winner;
          await supabase.from('matches').update({ participants: updatedParticipants }).eq('id', grandFinal.id);
        }
      }

      // 2. Loser drops to Losers Bracket (Loser's Flight)
      let destinationRound: number;
      let destinationOrder: number;

      if (match.round_number === 1) {
        destinationRound = 1;
        destinationOrder = Math.ceil(match.match_order / 2); // WR1 (8 matches) -> LR1 (4 matches)
      } else {
        destinationRound = (match.round_number * 2) - 2;
        destinationOrder = match.match_order;
      }

      const { data: losersMatch } = await supabase.from('matches')
        .select('*').eq('tournament_id', match.tournament_id).eq('bracket_type', 'losers')
        .eq('round_number', destinationRound).eq('match_order', destinationOrder).single();

      if (losersMatch) {
        const updatedParticipants = [...losersMatch.participants];
        const slotIdx = updatedParticipants[0] ? 1 : 0;
        updatedParticipants[slotIdx] = loser;
        await supabase.from('matches').update({ participants: updatedParticipants }).eq('id', losersMatch.id);
      }
    }
    // --- CASE B: LOSERS BRACKET (DOUBLE ELIMINATION) ---
    else if (match.bracket_type === 'losers' && tournamentType === 'double_elimination') {
      const nextRound = match.round_number + 1;
      const isDroppingInRound = match.round_number % 2 === 1;
      const nextOrder = isDroppingInRound ? match.match_order : Math.ceil(match.match_order / 2);

      const { data: nextLosersMatch } = await supabase.from('matches')
        .select('*').eq('tournament_id', match.tournament_id).eq('bracket_type', 'losers')
        .eq('round_number', nextRound).eq('match_order', nextOrder).single();

      if (nextLosersMatch) {
        const slotIdx = isDroppingInRound ? 1 : (match.match_order % 2 === 1 ? 0 : 1);
        const updatedParticipants = [...nextLosersMatch.participants];
        updatedParticipants[slotIdx] = winner;
        await supabase.from('matches').update({ participants: updatedParticipants }).eq('id', nextLosersMatch.id);
      } else {
        // Losers Bracket Finished -> Advance to Grand Final bottom slot
        const { data: grandFinal } = await supabase.from('matches')
          .select('*').eq('tournament_id', match.tournament_id).eq('bracket_type', 'grand_final').single();
        if (grandFinal) {
          const updatedParticipants = [...grandFinal.participants];
          updatedParticipants[1] = winner;
          await supabase.from('matches').update({ participants: updatedParticipants }).eq('id', grandFinal.id);
        }
      }
    }
    // --- CASE C: SINGLE ELIMINATION / MAIN ---
    else {
      const nextRound = match.round_number + 1;
      const nextOrder = Math.ceil(match.match_order / 2);
      const { data: nextMatch } = await supabase.from('matches')
        .select('*').eq('tournament_id', match.tournament_id).eq('bracket_type', match.bracket_type)
        .eq('round_number', nextRound).eq('match_order', nextOrder).single();

      if (nextMatch) {
        const slotIdx = match.match_order % 2 === 1 ? 0 : 1;
        const updatedParticipants = [...nextMatch.participants];
        updatedParticipants[slotIdx] = winner;
        await supabase.from('matches').update({ participants: updatedParticipants }).eq('id', nextMatch.id);
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})