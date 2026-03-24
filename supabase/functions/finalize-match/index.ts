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

    // 1. Fetch Match and Tournament Rules (The Source of Truth)
    const { data: match, error: fetchError } = await supabase
      .from('matches')
      .select('*, tournaments(*)')
      .eq('id', matchId)
      .single()

    if (fetchError || !match) throw new Error("Match not found")

    const rules = match.tournaments.settings?.overrides?.[match.round_number] || 
                  match.tournaments.settings?.default || {}
    
    // 2. BACKEND VALIDATION: Did they actually win?
    let t1Sets = 0;
    let t2Sets = 0;
    const setsToWin = Math.ceil(rules.max_sets / 2);

    for (const set of setHistory) {
      const p1 = set.team1;
      const p2 = set.team2;
      const target = rules.points_per_set;
      const cap = rules.point_cap;

      const winnerScore = Math.max(p1, p2);
      const loserScore = Math.min(p1, p2);
      const lead = winnerScore - loserScore;

      // 1. Did they reach the target or cap?
      if (winnerScore < target && (!cap || winnerScore < cap)) {
        throw new Error(`Set not finished: ${p1}-${p2}. Target is ${target}${cap ? ` (Cap: ${cap})` : ''}.`);
      }

      // 2. Did they reach the cap?
      if (cap && winnerScore === cap) {
        // At the cap, we don't care about the 2-point lead anymore.
        // The set is valid as long as they didn't EXCEED the cap.
        if (p1 > cap || p2 > cap) {
          throw new Error(`Score exceeds the point cap of ${cap}.`);
        }
      } 
      // 3. If not at the cap, enforce standard "Win by 2" logic
      else {
        if (lead < 2) {
          throw new Error(`Invalid score: ${p1}-${p2}. Must win by 2 unless Point Cap is reached.`);
        }
        
        // Ensure they didn't play "Ghost Points"
        if (winnerScore > target && lead !== 2) {
          throw new Error(`Impossible score: ${p1}-${p2}. Match should have ended at ${loserScore + 2}.`);
        }
      }

      if (p1 > p2) t1Sets++; else t2Sets++;
    }

    if (t1Sets < setsToWin && t2Sets < setsToWin) {
      throw new Error("Match is not yet finished according to the rules.");
    }

    // 3. SECURE ADVANCEMENT
    const winnerIdx = t1Sets > t2Sets ? 0 : 1;
    const winner = match.participants[winnerIdx];

    // Update current match
    await supabase.from('matches').update({
      status: 'completed',
      current_score: { sets: setHistory }
    }).eq('id', matchId)

    // Find and update next match
    const nextRound = match.round_number + 1;
    const nextOrder = Math.ceil(match.match_order / 2);

    const { data: nextMatch } = await supabase
      .from('matches')
      .select('*')
      .eq('tournament_id', match.tournament_id)
      .eq('round_number', nextRound)
      .eq('match_order', nextOrder)
      .single()

    if (nextMatch) {
      const slotIdx = match.match_order % 2 === 1 ? 0 : 1;
      const updatedParticipants = [...nextMatch.participants];
      updatedParticipants[slotIdx] = winner;

      await supabase.from('matches').update({ participants: updatedParticipants }).eq('id', nextMatch.id);
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