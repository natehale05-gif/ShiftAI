// ShiftAI :: /ai-proxy -- call an AI provider without the key ever leaving Supabase.
//
//   POST /ai-proxy
//   { "provider": "openai", "model": "gpt-4o-mini", "payload": { ...provider request... } }
//
// The caller supplies a normal provider request body; this function resolves the
// credential (the user's own key first, the ShiftAI platform key as fallback),
// injects it, forwards the call, streams the response back, and logs usage.

import { corsHeaders, fail, preflight } from "../_shared/http.ts";
import { requireUser, serviceClient } from "../_shared/supabase.ts";
import { extractUsage, loadProvider, upstreamHeaders, upstreamUrl } from "../_shared/providers.ts";

type ProxyBody = {
  provider?: string;
  model?: string;
  path?: string;
  payload?: Record<string, unknown>;
  label?: string;
};

Deno.serve(async (req: Request) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return fail(req, 405, "method not allowed");

  const caller = await requireUser(req);
  if (!caller) return fail(req, 401, "authentication required");

  const body = (await req.json().catch(() => ({}))) as ProxyBody;
  const providerId = (body.provider ?? "").trim();
  const payload = body.payload ?? {};
  const model = body.model ?? (payload.model as string | undefined);

  if (!providerId) return fail(req, 400, "provider is required");

  const db = serviceClient();

  const provider = await loadProvider(db, providerId).catch(() => null);
  if (!provider) return fail(req, 400, `unknown or disabled provider: ${providerId}`);

  const path = body.path ?? provider.chat_path;
  if (!path) return fail(req, 400, `no default path for ${providerId}; pass "path"`);
  if (path.includes("{model}") && !model) {
    return fail(req, 400, `${providerId} needs a model to build the request path`);
  }

  const { data: keys, error: keyError } = await db.rpc("get_active_provider_key", {
    p_provider: providerId,
    p_owner: caller.userId,
    p_label: body.label ?? null,
  });
  if (keyError) return fail(req, 500, "key lookup failed", keyError.message);

  const key = Array.isArray(keys) ? keys[0] : keys;
  if (!key?.api_key) {
    return fail(req, 402, `no active ${providerId} key for this account`);
  }

  // Quota gate. Checked after key resolution because the limits that apply
  // depend on who pays: a platform key spends ShiftAI's money, the user's own
  // key spends theirs. The check and the increment happen inside one locked
  // statement in Postgres, so concurrent isolates cannot slip past it.
  const { data: quotaRows, error: quotaError } = await db.rpc("consume_ai_quota", {
    p_user: caller.userId,
    p_key_scope: key.key_scope,
  });
  if (quotaError) return fail(req, 500, "quota check failed", quotaError.message);

  const quota = Array.isArray(quotaRows) ? quotaRows[0] : quotaRows;
  if (!quota?.allowed) {
    await logUsage(db, {
      user_id: caller.userId,
      key_id: key.key_id,
      provider_id: providerId,
      model: model ?? null,
      key_scope: key.key_scope,
      status_code: 429,
      ok: false,
      latency_ms: 0,
      error: quota?.reason ?? "quota denied",
    });
    return new Response(
      JSON.stringify({
        error: quota?.reason ?? "quota exceeded",
        limit: quota?.limit_name ?? null,
        retry_after_seconds: quota?.retry_after_seconds ?? null,
      }),
      {
        status: quota?.limit_name === "account_blocked" ? 403 : 429,
        headers: {
          ...corsHeaders(req),
          "content-type": "application/json",
          ...(quota?.retry_after_seconds
            ? { "retry-after": String(quota.retry_after_seconds) }
            : {}),
        },
      },
    );
  }

  // Model is carried in the path for some providers and in the body for others;
  // only send it in the body when the provider expects it there.
  const outboundPayload = path.includes("{model}")
    ? { ...payload, model: undefined }
    : model
    ? { ...payload, model }
    : payload;
  if (outboundPayload.model === undefined) delete outboundPayload.model;

  const started = performance.now();
  let upstream: Response;
  try {
    upstream = await fetch(upstreamUrl(provider, path, key.api_key, model), {
      method: "POST",
      headers: upstreamHeaders(provider, key.api_key),
      body: JSON.stringify(outboundPayload),
      signal: AbortSignal.timeout(120_000),
    });
  } catch (err) {
    await logUsage(db, {
      user_id: caller.userId,
      key_id: key.key_id,
      provider_id: providerId,
      model: model ?? null,
      key_scope: key.key_scope,
      status_code: 0,
      ok: false,
      latency_ms: Math.round(performance.now() - started),
      error: (err as Error).message,
    });
    return fail(req, 502, "upstream request failed", (err as Error).message);
  }

  const latency = Math.round(performance.now() - started);
  const headers: Record<string, string> = {
    ...corsHeaders(req),
    "content-type": upstream.headers.get("content-type") ?? "application/json",
  };
  if (quota.requests_remaining_day != null) {
    headers["x-ratelimit-remaining-requests"] = String(quota.requests_remaining_day);
  }
  if (quota.tokens_remaining_day != null) {
    headers["x-ratelimit-remaining-tokens"] = String(quota.tokens_remaining_day);
  }

  // Awaited rather than fired-and-forgotten: the isolate can be torn down as
  // soon as the response is returned, dropping any in-flight query.
  await db
    .from("ai_provider_keys")
    .update({ last_used_at: new Date().toISOString() })
    .eq("id", key.key_id);

  // Streaming responses are piped straight through; token usage is unavailable
  // without buffering, which would defeat the point of streaming.
  const isStream = (upstream.headers.get("content-type") ?? "").includes("text/event-stream");
  if (isStream) {
    await logUsage(db, {
      user_id: caller.userId,
      key_id: key.key_id,
      provider_id: providerId,
      model: model ?? null,
      key_scope: key.key_scope,
      status_code: upstream.status,
      ok: upstream.ok,
      latency_ms: latency,
      error: null,
    });
    return new Response(upstream.body, { status: upstream.status, headers });
  }

  const text = await upstream.text();
  let parsed: unknown = null;
  try {
    parsed = JSON.parse(text);
  } catch {
    // non-JSON provider error body; logged as-is below
  }

  const usage = extractUsage(parsed);

  // Charge real usage against the daily token cap. Streaming responses skip
  // this: their token counts are not available without buffering the stream,
  // which would defeat the point of streaming.
  if (upstream.ok && usage.total) {
    const { error } = await db.rpc("record_ai_tokens", {
      p_user: caller.userId,
      p_key_scope: key.key_scope,
      p_tokens: usage.total,
    });
    if (error) console.error("token accounting failed:", error.message);
  }

  await logUsage(db, {
    user_id: caller.userId,
    key_id: key.key_id,
    provider_id: providerId,
    model: model ?? null,
    key_scope: key.key_scope,
    status_code: upstream.status,
    ok: upstream.ok,
    latency_ms: latency,
    prompt_tokens: usage.prompt,
    completion_tokens: usage.completion,
    total_tokens: usage.total,
    error: upstream.ok ? null : text.slice(0, 500),
  });

  return new Response(text, { status: upstream.status, headers });
});

type UsageRow = Record<string, unknown>;

async function logUsage(
  db: ReturnType<typeof serviceClient>,
  row: UsageRow,
): Promise<void> {
  const { error } = await db.from("ai_usage_events").insert(row);
  // Logging must never take down a successful completion.
  if (error) console.error("usage log failed:", error.message);
}
