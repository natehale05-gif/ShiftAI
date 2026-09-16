/**
 * ShiftAI :: how the app talks to the key server.
 *
 * The app only ever holds the Supabase URL and the anon key. A provider API key
 * is sent once, on save, and can never be read back.
 *
 *   npm install @supabase/supabase-js
 */
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!,
);

/** Save or rotate the signed-in user's key. Verified upstream before storage. */
export async function saveProviderKey(provider: string, secret: string, label = "default") {
  const { data, error } = await supabase.functions.invoke("keys", {
    body: { provider, secret, label },
  });
  if (error) throw error;
  return data as { id: string; key_hint: string; verified: boolean };
}

/** List key metadata for the settings screen. Never includes the key itself. */
export async function listProviderKeys() {
  const { data, error } = await supabase
    .from("my_ai_keys")
    .select("id, provider_id, provider_name, label, key_hint, is_active, last_used_at")
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data;
}

export async function deleteProviderKey(id: string) {
  const { error } = await supabase.functions.invoke(`keys?id=${id}`, { method: "DELETE" });
  if (error) throw error;
}

/** Chat completion. The key is injected inside Supabase; nothing leaks here. */
export async function chat(prompt: string) {
  const { data, error } = await supabase.functions.invoke("ai-proxy", {
    body: {
      provider: "anthropic",
      model: "claude-sonnet-4-5",
      payload: {
        max_tokens: 1024,
        messages: [{ role: "user", content: prompt }],
      },
    },
  });
  if (error) throw error;
  return data;
}

/**
 * Streaming needs a raw fetch: functions.invoke() buffers the whole body.
 * The proxy pipes the provider's SSE stream straight through.
 */
export async function chatStream(prompt: string): Promise<ReadableStream<Uint8Array>> {
  const { data: { session } } = await supabase.auth.getSession();
  const res = await fetch(`${process.env.SUPABASE_URL}/functions/v1/ai-proxy`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${session?.access_token}`,
      apikey: process.env.SUPABASE_ANON_KEY!,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      provider: "openai",
      model: "gpt-4o-mini",
      payload: {
        stream: true,
        messages: [{ role: "user", content: prompt }],
      },
    }),
  });
  if (!res.ok || !res.body) throw new Error(`proxy failed: ${res.status} ${await res.text()}`);
  return res.body;
}

/** Recent usage for a billing or activity screen. */
export async function recentUsage(limit = 50) {
  const { data, error } = await supabase
    .from("ai_usage_events")
    .select("provider_id, model, ok, status_code, total_tokens, latency_ms, created_at")
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return data;
}
