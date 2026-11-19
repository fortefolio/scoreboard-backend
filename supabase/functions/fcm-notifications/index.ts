import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { JWT } from "https://esm.sh/google-auth-library@8.7.0";
import {
  dispatchPushNotifications,
  shouldDispatchWebhook,
  type ApnsConfig,
  type WebhookPayload,
} from "./dispatch.ts";

const getAccessToken = async (serviceAccount: any) => {
  const jwtClient = new JWT(
    serviceAccount.client_email,
    null,
    serviceAccount.private_key,
    ["https://www.googleapis.com/auth/firebase.messaging"]
  );
  const tokens = await jwtClient.authorize();
  return tokens.access_token;
};

function loadApnsConfig(): ApnsConfig | null {
  const keyId = Deno.env.get("APNS_KEY_ID")?.trim() ?? "";
  const teamId = Deno.env.get("APNS_TEAM_ID")?.trim() ?? "";
  const privateKeyPem = Deno.env.get("APNS_PRIVATE_KEY")?.trim() ?? "";
  const bundleId = Deno.env.get("APNS_BUNDLE_ID")?.trim() || "dev.goncaloforte.scoreboard";

  if (!keyId || !teamId || !privateKeyPem) {
    return null;
  }

  return { keyId, teamId, privateKeyPem, bundleId };
}

serve(async (req) => {
  const authHeader = req.headers.get("Authorization") ?? "";
  const webhookSecret = req.headers.get("X-Webhook-Secret") ?? "";
  const expectedSecret = Deno.env.get("INTERNAL_WEBHOOK_SECRET");
  const expectedServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  const isServiceRole = Boolean(expectedServiceKey && authHeader === `Bearer ${expectedServiceKey}`);
  const isValidSecret = Boolean(expectedSecret && webhookSecret === expectedSecret);

  if (!isServiceRole && !isValidSecret) {
    return new Response(JSON.stringify({ error: "Unauthorized: internal callers only" }), {
      headers: { "Content-Type": "application/json" },
      status: 401,
    });
  }

  const payload: WebhookPayload = await req.json();

  if (!shouldDispatchWebhook(payload)) {
    return new Response("Notification event ignored", { status: 200 });
  }

  const notification = payload.record!;
  const userId = notification.user_id;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  const { data: tokenData, error: tokenError } = await supabase
    .from("user_tokens")
    .select("fcm_token")
    .eq("user_id", userId);

  if (tokenError || !tokenData) {
    console.error("Error fetching tokens:", tokenError);
    return new Response("Error fetching tokens", { status: 500 });
  }

  const tokens = [...new Set(tokenData.map((t) => t.fcm_token))];
  if (tokens.length === 0) {
    return new Response("No tokens found for user", { status: 200 });
  }

  const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");
  const apnsConfig = loadApnsConfig();

  const summary = await dispatchPushNotifications(tokens, notification, {
    fcmProjectId: serviceAccount.project_id,
    getFcmAccessToken: () => getAccessToken(serviceAccount),
    apnsConfig,
  });

  if (summary.errors.length > 0) {
    console.error("Push dispatch errors:", summary.errors);
  }

  return new Response(JSON.stringify(summary), {
    headers: { "Content-Type": "application/json" },
    status: 200,
  });
});
