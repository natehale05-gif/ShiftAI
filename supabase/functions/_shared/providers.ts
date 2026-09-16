import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export type Provider = {
  id: string;
  display_name: string;
  base_url: string;
  auth_scheme: "bearer" | "header" | "query";
  auth_name: string;
  extra_headers: Record<string, string>;
  key_pattern: string | null;
  verify_path: string | null;
  chat_path: string | null;
  is_enabled: boolean;
};

export async function loadProvider(
  db: SupabaseClient,
  id: string,
): Promise<Provider | null> {
  const { data, error } = await db
    .from("ai_providers")
    .select("*")
    .eq("id", id)
    .eq("is_enabled", true)
    .maybeSingle();
  if (error) throw new Error(`provider lookup failed: ${error.message}`);
  return (data as Provider) ?? null;
}

/** Build the upstream URL, substituting {model} where a provider needs it in the path. */
export function upstreamUrl(
  provider: Provider,
  path: string,
  apiKey: string,
  model?: string,
): string {
  const resolved = path.replace("{model}", encodeURIComponent(model ?? ""));
  // Deliberate string join rather than URL resolution: a leading "/" in the
  // path would otherwise discard a base_url path segment (e.g. Groq's /openai).
  const url = new URL(
    provider.base_url.replace(/\/+$/, "") + "/" + resolved.replace(/^\/+/, ""),
  );
  if (provider.auth_scheme === "query") url.searchParams.set(provider.auth_name, apiKey);
  return url.toString();
}

/** Attach the credential the way this provider expects it. */
export function upstreamHeaders(provider: Provider, apiKey: string): Headers {
  const headers = new Headers({ "content-type": "application/json" });
  for (const [name, value] of Object.entries(provider.extra_headers ?? {})) {
    headers.set(name, String(value));
  }
  if (provider.auth_scheme === "bearer") {
    headers.set(provider.auth_name, `Bearer ${apiKey}`);
  } else if (provider.auth_scheme === "header") {
    headers.set(provider.auth_name, apiKey);
  }
  return headers;
}

/**
 * Cheap authenticated GET against the provider to prove a key works before we
 * commit it to the vault. Returns null when the provider has no verify path.
 */
export async function verifyKey(
  provider: Provider,
  apiKey: string,
): Promise<{ ok: boolean; status: number; message?: string } | null> {
  if (!provider.verify_path) return null;
  try {
    const res = await fetch(upstreamUrl(provider, provider.verify_path, apiKey), {
      method: "GET",
      headers: upstreamHeaders(provider, apiKey),
      signal: AbortSignal.timeout(10_000),
    });
    if (res.ok) {
      await res.body?.cancel();
      return { ok: true, status: res.status };
    }
    const body = await res.text();
    return { ok: false, status: res.status, message: body.slice(0, 300) };
  } catch (err) {
    return { ok: false, status: 0, message: (err as Error).message };
  }
}

/** Best-effort token accounting across the provider response shapes we support. */
export function extractUsage(
  payload: unknown,
): { prompt: number | null; completion: number | null; total: number | null } {
  const usage = (payload as { usage?: Record<string, number> } | null)?.usage;
  if (!usage) return { prompt: null, completion: null, total: null };
  const prompt = usage.prompt_tokens ?? usage.input_tokens ?? null;
  const completion = usage.completion_tokens ?? usage.output_tokens ?? null;
  const total = usage.total_tokens ??
    (prompt !== null && completion !== null ? prompt + completion : null);
  return { prompt, completion, total };
}
