// ShiftAI :: /keys -- manage stored AI provider credentials.
//
//   GET    /keys                      list the caller's key metadata
//   POST   /keys   {provider,secret}  verify then store (or rotate) a key
//   DELETE /keys?id=<uuid>            destroy a key and its vault secret
//
// A plaintext key enters through POST and is never readable again by any
// client. Callers presenting the service-role key may manage platform keys
// (scope: "platform") that all users fall back to.

import { fail, json, preflight } from "../_shared/http.ts";
import { isServiceRoleCaller, requireUser, serviceClient, userClient } from "../_shared/supabase.ts";
import { loadProvider, verifyKey } from "../_shared/providers.ts";

type StoreBody = {
  provider?: string;
  secret?: string;
  label?: string;
  scope?: "user" | "platform";
  owner_id?: string;
  verify?: boolean;
};

Deno.serve(async (req: Request) => {
  const pre = preflight(req);
  if (pre) return pre;

  const isService = isServiceRoleCaller(req);
  const caller = isService ? null : await requireUser(req);
  if (!isService && !caller) return fail(req, 401, "authentication required");

  try {
    if (req.method === "GET") {
      if (isService) return fail(req, 400, "listing requires a user token");
      const { data, error } = await userClient(req)
        .from("my_ai_keys")
        .select("*")
        .order("created_at", { ascending: false });
      if (error) return fail(req, 400, "could not list keys", error.message);
      return json(req, { keys: data });
    }

    if (req.method === "DELETE") {
      const id = new URL(req.url).searchParams.get("id");
      if (!id) return fail(req, 400, "missing ?id=");
      const db = isService ? serviceClient() : userClient(req);
      const { data, error } = await db.rpc("revoke_provider_key", { p_key_id: id });
      if (error) return fail(req, 400, "could not revoke key", error.message);
      return json(req, { revoked: data === true });
    }

    if (req.method !== "POST") return fail(req, 405, "method not allowed");

    const body = (await req.json().catch(() => ({}))) as StoreBody;
    const provider = (body.provider ?? "").trim();
    const secret = (body.secret ?? "").trim();
    const label = (body.label ?? "default").trim();

    if (!provider || !secret) return fail(req, 400, "provider and secret are required");

    const platform = isService && body.scope === "platform";
    if (body.scope === "platform" && !isService) {
      return fail(req, 403, "platform keys require the service role");
    }

    const db = serviceClient();
    const providerRow = await loadProvider(db, provider);
    if (!providerRow) return fail(req, 400, `unknown or disabled provider: ${provider}`);

    // Prove the credential works before it is committed, so a typo surfaces
    // here rather than on the user's first real request.
    let verified = false;
    if (body.verify !== false) {
      const result = await verifyKey(providerRow, secret);
      if (result && !result.ok) {
        return fail(req, 422, "the provider rejected this key", {
          status: result.status,
          message: result.message,
        });
      }
      verified = result?.ok ?? false;
    }

    const ownerId = platform ? null : (isService ? body.owner_id ?? null : caller!.userId);
    if (!platform && !ownerId) return fail(req, 400, "owner_id is required for a user key");

    const { data: keyId, error } = await db.rpc("store_provider_key", {
      p_provider: provider,
      p_secret: secret,
      p_label: label,
      p_owner: ownerId,
    });
    if (error) return fail(req, 400, "could not store key", error.message);

    if (verified) {
      await db
        .from("ai_provider_keys")
        .update({ last_verified_at: new Date().toISOString() })
        .eq("id", keyId);
    }

    return json(req, {
      id: keyId,
      provider_id: provider,
      label,
      scope: platform ? "platform" : "user",
      key_hint: secret.slice(-4),
      verified,
    }, 201);
  } catch (err) {
    return fail(req, 500, "unexpected error", (err as Error).message);
  }
});
