import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

/**
 * Full-privilege client. Only ever used server-side inside an edge function --
 * it bypasses RLS and is the only identity allowed to decrypt a stored key.
 */
export function serviceClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Client that carries the caller's JWT, so RLS applies as if the user asked. */
export function userClient(req: Request): SupabaseClient {
  return createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
}

export function bearer(req: Request): string | null {
  const header = req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

/** Constant-time compare so a caller cannot probe the service key byte by byte. */
function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

export function isServiceRoleCaller(req: Request): boolean {
  const token = bearer(req);
  return token !== null && timingSafeEqual(token, SERVICE_ROLE_KEY);
}

export type Caller = { userId: string; token: string };

/** Resolve the signed-in user, or null when the JWT is missing/invalid. */
export async function requireUser(req: Request): Promise<Caller | null> {
  const token = bearer(req);
  if (!token) return null;
  const { data, error } = await serviceClient().auth.getUser(token);
  if (error || !data.user) return null;
  return { userId: data.user.id, token };
}
