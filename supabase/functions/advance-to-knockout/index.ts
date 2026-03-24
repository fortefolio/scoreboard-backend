// supabase/functions/advance-to-knockout/index.ts

serve(async (req) => {
  const { tournamentId } = await req.json();
  const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'));

  // 1. Fetch the standings from the SQL View we created
  const { data: standings, error } = await supabase
    .from('group_standings')
    .select('*')
    .eq('tournament_id', tournamentId);

  // 2. GET DIRECT QUALIFIERS (Top 2 from each group)
  const qualifiedTeams = [];
  const groups = [...new Set(standings.map(s => s.group_label))];
  
  groups.forEach(label => {
    const groupWinners = standings
      .filter(s => s.group_label === label)
      .slice(0, 2); // Take top 2
    qualifiedTeams.push(...groupWinners);
  });

  // 3. THE "ODD NUMBER" STRATEGY (Wildcards)
  // If we need 8 teams but only have 6 from groups, find the best 3rd places
  const totalSlotsNeeded = 8;
  if (qualifiedTeams.length < totalSlotsNeeded) {
    const remainingNeeded = totalSlotsNeeded - qualifiedTeams.length;
    
    // Get all teams NOT already qualified, sorted by the View's tie-breaking logic
    const qualifiedNames = qualifiedTeams.map(t => t.team_name);
    const wildcards = standings
      .filter(s => !qualifiedNames.includes(s.team_name))
      .slice(0, remainingNeeded);
      
    qualifiedTeams.push(...wildcards);
  }

  // 4. GENERATE THE ROUND 2 BRACKET
  // Map these team names into the 'participants' array for new matches
  const knockoutMatches = [
    { 
      tournament_id: tournamentId, 
      round_number: 2, 
      match_order: 1, 
      participants: [ {name: qualifiedTeams[0].team_name}, {name: qualifiedTeams[7].team_name} ] 
    },
    // ... continue mapping matches
  ];

  await supabase.from('matches').insert(knockoutMatches);
  
  return new Response(JSON.stringify({ success: true }));
});