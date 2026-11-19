const DEFAULT_PROD_ORIGINS = [
  "https://score-board.net",
  "https://www.score-board.net",
];

const DEV_ORIGINS = [
  "http://localhost:3000",
  "http://127.0.0.1:3000",
  "http://localhost:8081",
  "http://127.0.0.1:8081",
];

export function getAllowedOrigins(): string[] {
  const configured = Deno.env.get("ALLOWED_ORIGINS");
  const baseOrigins = configured
    ? configured
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean)
    : DEFAULT_PROD_ORIGINS;

  const env = (Deno.env.get("ENVIRONMENT") ?? "development").toLowerCase();
  if (env !== "production" && env !== "staging") {
    return Array.from(new Set([...baseOrigins, ...DEV_ORIGINS]));
  }
  return Array.from(new Set(baseOrigins));
}

export function getCorsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin");
  const allowedOrigins = getAllowedOrigins();

  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };

  if (origin && allowedOrigins.includes(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }

  return headers;
}

export function handleCorsPreflight(req: Request): Response | null {
  if (req.method !== "OPTIONS") return null;
  const origin = req.headers.get("Origin");
  const allowedOrigins = getAllowedOrigins();

  if (origin && !allowedOrigins.includes(origin)) {
    return new Response("Forbidden origin", { status: 403 });
  }

  return new Response("ok", { headers: getCorsHeaders(req) });
}

export function isAllowedReturnUrl(rawUrl: string): boolean {
  try {
    const parsed = new URL(rawUrl);
    const allowedOrigins = getAllowedOrigins();
    if (!allowedOrigins.includes(parsed.origin)) {
      return false;
    }
    if (parsed.protocol === "https:") {
      return true;
    }
    const env = (Deno.env.get("ENVIRONMENT") ?? "development").toLowerCase();
    if (
      env !== "production" &&
      env !== "staging" &&
      parsed.protocol === "http:" &&
      (parsed.hostname === "localhost" || parsed.hostname === "127.0.0.1")
    ) {
      return true;
    }
    return false;
  } catch {
    return false;
  }
}

export function getDefaultReturnOrigin(): string {
  const allowed = getAllowedOrigins();
  const prod = allowed.find((o) => o.startsWith("https://"));
  return prod ?? allowed[0] ?? "https://score-board.net";
}
