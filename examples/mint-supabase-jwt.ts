/**
 * ShiftAI :: issue a Supabase-compatible session for a mirrored user.
 *
 * ShiftAI authenticates its own users; Supabase never sees their password. To
 * make RLS work, the ShiftAI server mints a JWT signed with the Supabase
 * project's JWT secret whose `sub` is the *mirrored* Supabase user id. Postgres
 * then resolves auth.uid() normally and every policy applies unchanged.
 *
 * The secret is under Project Settings > API > JWT Settings ("legacy JWT
 * secret" on projects that have moved to asymmetric signing keys). It is as
 * sensitive as the service role key: server-side only.
 *
 *   npm install jose
 */
import { SignJWT } from "jose";

const JWT_SECRET = new TextEncoder().encode(process.env.SUPABASE_JWT_SECRET!);
const SESSION_TTL_SECONDS = 60 * 60;

/**
 * Translate a ShiftAI user id into its mirrored Supabase user id.
 * Requires the service role key, so call this from the server only.
 */
export async function resolveSupabaseUserId(externalId: string): Promise<string | null> {
  const res = await fetch(
    `${process.env.SUPABASE_URL}/rest/v1/rpc/resolve_external_user`,
    {
      method: "POST",
      headers: {
        apikey: process.env.SUPABASE_SERVICE_ROLE_KEY!,
        Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY!}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ p_external_id: externalId }),
    },
  );
  if (!res.ok) throw new Error(`resolve failed: ${res.status} ${await res.text()}`);
  return (await res.json()) as string | null;
}

/**
 * Mint the access token. Claims match what Supabase issues itself: any
 * deviation and either the API gateway or RLS will reject the request.
 */
export async function mintSupabaseToken(supabaseUserId: string, email?: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT({
    sub: supabaseUserId,
    email,
    role: "authenticated",
    aud: "authenticated",
    // Marks the token as minted by ShiftAI rather than by Supabase's own login
    // flow; useful when reading logs, and ignored by RLS.
    app_metadata: { provider: "shiftai", mirrored: true },
  })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setIssuedAt(now)
    .setExpirationTime(now + SESSION_TTL_SECONDS)
    .sign(JWT_SECRET);
}

/**
 * End to end: ShiftAI user id in, a token the app can send to ai-proxy out.
 * Keep the TTL short and mint per request rather than storing these.
 */
export async function sessionForShiftAIUser(externalId: string, email?: string) {
  const supabaseUserId = await resolveSupabaseUserId(externalId);
  if (!supabaseUserId) {
    throw new Error(`user ${externalId} has not been mirrored; run scripts/sync-users.mjs`);
  }
  const accessToken = await mintSupabaseToken(supabaseUserId, email);
  return { supabaseUserId, accessToken, expiresInSeconds: SESSION_TTL_SECONDS };
}

/** The app then calls the proxy with that token, exactly as a Supabase session would. */
export async function callProxy(accessToken: string, body: unknown) {
  const res = await fetch(`${process.env.SUPABASE_URL}/functions/v1/ai-proxy`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      apikey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  return res;
}
