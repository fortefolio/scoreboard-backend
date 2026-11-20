export interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE" | "SELECT";
  table: string;
  record: Record<string, any> | null;
  old_record?: Record<string, any> | null;
  schema?: string;
}

export interface ApnsConfig {
  keyId: string;
  teamId: string;
  privateKeyPem: string;
  bundleId: string;
}

export interface DispatchDependencies {
  fetchFn?: typeof fetch;
  getFcmAccessToken?: () => Promise<string>;
  fcmProjectId?: string;
  apnsConfig?: ApnsConfig | null;
  badgeCount?: number;
  nowSeconds?: () => number;
}

export interface DispatchSummary {
  fcmSent: number;
  apnsSent: number;
  apnsSandboxFallback: number;
  errors: string[];
}

const APNS_TOKEN_RE = /^[0-9a-f]{64}$/i;
const APNS_PROD_BASE = "https://api.push.apple.com/3/device";
const APNS_SANDBOX_BASE = "https://api.sandbox.push.apple.com/3/device";

export function isApnsDeviceToken(token: string): boolean {
  return APNS_TOKEN_RE.test(token.trim());
}

export function classifyToken(token: string): "apns" | "fcm" {
  return isApnsDeviceToken(token) ? "apns" : "fcm";
}

/**
 * Determines whether a Supabase notifications webhook event should trigger a push.
 * - INSERT: always dispatches (unless already marked read).
 * - UPDATE: dispatches only when unread (read_at == null) and content changed
 *   (e.g. score aggregation updating 1-0 -> 2-0), skipping mark-as-read updates.
 */
export function shouldDispatchWebhook(payload: WebhookPayload): boolean {
  if (payload.table !== "notifications" || !payload.record) {
    return false;
  }

  if (payload.type === "INSERT") {
    return payload.record.read_at == null;
  }

  if (payload.type !== "UPDATE") {
    return false;
  }

  const next = payload.record;
  if (next.read_at != null) {
    return false;
  }

  const prev = payload.old_record;
  if (!prev) {
    return true;
  }

  const contentChanged =
    next.title !== prev.title ||
    next.body !== prev.body ||
    JSON.stringify(next.data ?? null) !== JSON.stringify(prev.data ?? null);

  return contentChanged || prev.read_at != null;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): ArrayBuffer {
  const normalized = pem.replace(/\\n/g, "\n");
  const body = normalized
    .replace(/-----BEGIN [A-Z ]+-----/g, "")
    .replace(/-----END [A-Z ]+-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

export async function createApnsJwt(
  config: Pick<ApnsConfig, "keyId" | "teamId" | "privateKeyPem">,
  iatSeconds = Math.floor(Date.now() / 1000)
): Promise<string> {
  const header = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: config.keyId }))
  );
  const claims = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify({ iss: config.teamId, iat: iatSeconds }))
  );
  const signingInput = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(config.privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  );

  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
}

function stringifyDataMap(data: Record<string, any> | null | undefined, notificationId: any): Record<string, string> {
  const out: Record<string, string> = {};
  if (data && typeof data === "object") {
    for (const [k, v] of Object.entries(data)) {
      if (v !== undefined && v !== null) {
        out[k] = typeof v === "string" ? v : JSON.stringify(v);
      }
    }
  }
  if (notificationId !== undefined && notificationId !== null) {
    out.notification_id = String(notificationId);
  }
  return out;
}

async function sendApnsSingle(
  token: string,
  notification: Record<string, any>,
  apnsJwt: string,
  bundleId: string,
  fetchFn: typeof fetch,
  badgeCount?: number
): Promise<{ ok: boolean; sandboxFallback: boolean; error?: string }> {
  const aps: Record<string, any> = {
    alert: {
      title: notification.title ?? "",
      body: notification.body ?? "",
    },
    sound: "default",
  };
  if (typeof badgeCount === "number" && Number.isFinite(badgeCount)) {
    aps.badge = Math.max(0, Math.floor(badgeCount));
  }

  const payload = JSON.stringify({
    aps,
    ...(notification.data && typeof notification.data === "object" ? notification.data : {}),
    notification_id: notification.id,
  });

  const headers = {
    authorization: `bearer ${apnsJwt}`,
    "apns-topic": bundleId,
    "apns-push-type": "alert",
    "apns-priority": "10",
    "content-type": "application/json",
  };

  const prodRes = await fetchFn(`${APNS_PROD_BASE}/${token}`, {
    method: "POST",
    headers,
    body: payload,
  });

  if (prodRes.ok) {
    return { ok: true, sandboxFallback: false };
  }

  let prodReason = "";
  let prodBodyText = "";
  try {
    prodBodyText = await prodRes.text();
    prodReason = JSON.parse(prodBodyText)?.reason ?? "";
  } catch {
    // ignore parse failure
  }

  // Dev/Xcode/TestFlight-sandbox device tokens return 400 BadDeviceToken on production APNs
  if (prodRes.status === 400 && prodReason === "BadDeviceToken") {
    const sandboxRes = await fetchFn(`${APNS_SANDBOX_BASE}/${token}`, {
      method: "POST",
      headers,
      body: payload,
    });
    if (sandboxRes.ok) {
      return { ok: true, sandboxFallback: true };
    }
    const sandboxBody = await sandboxRes.text().catch(() => "");
    return {
      ok: false,
      sandboxFallback: true,
      error: `APNs sandbox error (${sandboxRes.status}): ${sandboxBody}`,
    };
  }

  return {
    ok: false,
    sandboxFallback: false,
    error: `APNs prod error (${prodRes.status}): ${prodBodyText}`,
  };
}

export async function dispatchPushNotifications(
  tokens: string[],
  notification: Record<string, any>,
  deps: DispatchDependencies
): Promise<DispatchSummary> {
  const fetchFn = deps.fetchFn ?? fetch;
  const uniqueTokens = [...new Set(tokens.map((t) => t.trim()).filter(Boolean))];
  const fcmTokens = uniqueTokens.filter((t) => classifyToken(t) === "fcm");
  const apnsTokens = uniqueTokens.filter((t) => classifyToken(t) === "apns");

  const summary: DispatchSummary = {
    fcmSent: 0,
    apnsSent: 0,
    apnsSandboxFallback: 0,
    errors: [],
  };

  if (fcmTokens.length > 0) {
    if (!deps.fcmProjectId || !deps.getFcmAccessToken) {
      summary.errors.push("FCM configuration missing for FCM tokens");
    } else {
      const accessToken = await deps.getFcmAccessToken();
      const stringData = stringifyDataMap(notification.data, notification.id);

      await Promise.all(
        fcmTokens.map(async (token) => {
          const res = await fetchFn(
            `https://fcm.googleapis.com/v1/projects/${deps.fcmProjectId}/messages:send`,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${accessToken}`,
              },
              body: JSON.stringify({
                message: {
                  token,
                  notification: {
                    title: notification.title ?? "",
                    body: notification.body ?? "",
                  },
                  data: stringData,
                },
              }),
            }
          );

          if (res.ok) {
            summary.fcmSent += 1;
          } else {
            const errText = await res.text().catch(() => "");
            summary.errors.push(`FCM error (${res.status}): ${errText}`);
          }
        })
      );
    }
  }

  if (apnsTokens.length > 0) {
    if (!deps.apnsConfig?.keyId || !deps.apnsConfig?.teamId || !deps.apnsConfig?.privateKeyPem) {
      summary.errors.push("APNs configuration missing for iOS/iPadOS tokens");
    } else {
      const iat = deps.nowSeconds ? deps.nowSeconds() : Math.floor(Date.now() / 1000);
      const apnsJwt = await createApnsJwt(deps.apnsConfig, iat);

      await Promise.all(
        apnsTokens.map(async (token) => {
          const result = await sendApnsSingle(
            token,
            notification,
            apnsJwt,
            deps.apnsConfig!.bundleId,
            fetchFn,
            deps.badgeCount
          );
          if (result.sandboxFallback) {
            summary.apnsSandboxFallback += 1;
          }
          if (result.ok) {
            summary.apnsSent += 1;
          } else if (result.error) {
            summary.errors.push(result.error);
          }
        })
      );
    }
  }

  return summary;
}
