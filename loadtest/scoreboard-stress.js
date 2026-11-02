import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  scenarios: {
    // 1. Spectator polling & viewing match state
    spectators: {
      executor: "ramping-vus",
      startVUs: 10,
      stages: [
        { duration: "20s", target: 100 },
        { duration: "40s", target: 200 },
        { duration: "20s", target: 0 },
      ],
      gracefulRampDown: "5s",
      exec: "spectatorScenario",
    },
    // 2. Umpires rapidly scoring points
    umpires: {
      executor: "ramping-vus",
      startVUs: 2,
      stages: [
        { duration: "20s", target: 10 },
        { duration: "40s", target: 20 },
        { duration: "20s", target: 0 },
      ],
      gracefulRampDown: "5s",
      exec: "umpireScenario",
    },
  },
  thresholds: {
    http_req_duration: ["p(95)<250"], // 95% of requests must complete under 250ms
    http_req_failed: ["rate<0.01"],   // Less than 1% errors
  },
};

const BASE_URL = __ENV.SUPABASE_URL || "http://127.0.0.1:54321";
const ANON_KEY = __ENV.SUPABASE_ANON_KEY || "";
const SERVICE_KEY = __ENV.SUPABASE_SERVICE_KEY || "";
const MATCH_ID = __ENV.MATCH_ID || "00000000-0000-0000-0000-000000000001";

const spectatorHeaders = {
  "Content-Type": "application/json",
  apikey: ANON_KEY,
  Authorization: `Bearer ${ANON_KEY}`,
};

const umpireHeaders = {
  "Content-Type": "application/json",
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
};

function generateUUID() {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

export function spectatorScenario() {
  const res = http.get(
    `${BASE_URL}/rest/v1/matches?id=eq.${MATCH_ID}&select=*`,
    { headers: spectatorHeaders }
  );

  check(res, {
    "spectator status is 200": (r) => r.status === 200,
    "spectator response latency < 250ms": (r) => r.timings.duration < 250,
  });

  sleep(0.5);
}

export function umpireScenario() {
  const idempotencyKey = generateUUID();
  const payload = JSON.stringify({
    p_match_id: MATCH_ID,
    p_idempotency_key: idempotencyKey,
    p_new_scores: { current: { home: Math.floor(Math.random() * 20), away: Math.floor(Math.random() * 20) } },
    p_event_data: { type: "point_scored", side: Math.random() > 0.5 ? "home" : "away" },
    p_new_status: "ongoing",
  });

  // Call Atomic Scoring RPC
  const res = http.post(
    `${BASE_URL}/rest/v1/rpc/record_match_event_atomic`,
    payload,
    { headers: umpireHeaders }
  );

  check(res, {
    "atomic scoring status is 200": (r) => r.status === 200,
    "atomic scoring latency < 250ms": (r) => r.timings.duration < 250,
  });

  // Immediate retry with identical idempotency_key to test idempotency guard under concurrency
  const retryRes = http.post(
    `${BASE_URL}/rest/v1/rpc/record_match_event_atomic`,
    payload,
    { headers: umpireHeaders }
  );

  check(retryRes, {
    "idempotent retry status is 200": (r) => r.status === 200,
  });

  sleep(1);
}
