export class AppError extends Error {
  readonly status: number;
  readonly publicMessage: string;
  readonly code?: string;

  constructor(status: number, publicMessage: string, code?: string) {
    super(publicMessage);
    this.status = status;
    this.publicMessage = publicMessage;
    this.code = code;
  }
}

export function jsonResponse(
  payload: unknown,
  status: number,
  corsHeaders: Record<string, string>,
): Response {
  return new Response(JSON.stringify(payload), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}

export function jsonError(
  status: number,
  message: string,
  corsHeaders: Record<string, string>,
  code?: string,
): Response {
  const body = code ? { error: message, code } : { error: message };
  return jsonResponse(body, status, corsHeaders);
}

export function handleEdgeError(
  err: unknown,
  context: string,
  corsHeaders: Record<string, string>,
): Response {
  if (err instanceof AppError) {
    return jsonError(err.status, err.publicMessage, corsHeaders, err.code);
  }
  console.error(`[${context}] Unexpected error:`, err);
  return jsonError(500, "An unexpected error occurred.", corsHeaders);
}
