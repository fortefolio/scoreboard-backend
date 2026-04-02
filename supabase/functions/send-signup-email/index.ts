import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

serve(async (req) => {
  const { record } = await req.json()

  if (!record || !record.contact_email) {
    return new Response('No contact email provided', { status: 400 })
  }

  // Initialize Supabase Client to fetch tournament details
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const { data: tournament, error: tError } = await supabase
    .from('tournaments')
    .select('name')
    .eq('id', record.tournament_id)
    .single()

  if (tError || !tournament) {
    console.error('Error fetching tournament:', tError)
    return new Response('Error fetching tournament', { status: 500 })
  }

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: 'ScoreBoard <onboarding@resend.dev>',
      to: [record.contact_email],
      subject: `Registration Confirmed: ${tournament.name}`,
      html: `
        <h1>Welcome to ${tournament.name}!</h1>
        <p>Hi ${record.name},</p>
        <p>Your registration for <strong>${tournament.name}</strong> has been confirmed.</p>
        <p>We'll notify you when the bracket is generated and matches are scheduled.</p>
        <br />
        <p>Good luck!</p>
        <p>The ScoreBoard Team</p>
      `,
    }),
  })

  const data = await res.json()

  return new Response(JSON.stringify(data), {
    headers: { 'Content-Type': 'application/json' },
    status: res.status,
  })
})
