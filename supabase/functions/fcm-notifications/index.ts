import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { JWT } from 'https://esm.sh/google-auth-library@8.7.0'

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE' | 'SELECT'
  table: string
  record: any
  old_record: any
  schema: string
}

const getAccessToken = async (serviceAccount: any) => {
  const jwtClient = new JWT(
    serviceAccount.client_email,
    null,
    serviceAccount.private_key,
    ['https://www.googleapis.com/auth/firebase.messaging']
  )
  const tokens = await jwtClient.authorize()
  return tokens.access_token
}

serve(async (req) => {
  const payload: WebhookPayload = await req.json()

  // Trigger on new notifications for push delivery
  if (payload.table !== 'notifications' || payload.type !== 'INSERT') {
    return new Response('Not a new notification', { status: 200 })
  }

  const notification = payload.record
  const userId = notification.user_id

  // Initialize Supabase Client
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  // 1. Fetch the FCM tokens for this specific user
  const { data: tokenData, error: tokenError } = await supabase
    .from('user_tokens')
    .select('fcm_token')
    .eq('user_id', userId)

  if (tokenError || !tokenData) {
    console.error('Error fetching tokens:', tokenError)
    return new Response('Error fetching tokens', { status: 500 })
  }

  const tokens = [...new Set(tokenData.map(t => t.fcm_token))]

  if (tokens.length === 0) {
    return new Response('No tokens found for user', { status: 200 })
  }

  // 2. Authenticate with Google FCM
  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}')
  const accessToken = await getAccessToken(serviceAccount)
  const projectId = serviceAccount.project_id

  // 3. Dispatch notifications
  const notificationPromises = tokens.map(token => {
    return fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: {
            ...notification.data,
            notification_id: notification.id
          }
        },
      }),
    })
  })

  await Promise.all(notificationPromises)

  return new Response(JSON.stringify({ sent: tokens.length }), {
    headers: { 'Content-Type': 'application/json' },
    status: 200,
  })
})
