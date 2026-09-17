#!/usr/bin/env node
/**
 * ShiftAI :: mirror application users into Supabase Auth.
 *
 * ShiftAI's users live in its own Postgres. The key and quota schema keys off
 * auth.users, so each application user needs a corresponding Supabase Auth user
 * and a row in external_user_map tying the two ids together.
 *
 *   SOURCE_DATABASE_URL=postgresql://... \
 *   SUPABASE_URL=https://<ref>.supabase.co \
 *   SUPABASE_SERVICE_ROLE_KEY=<service-role-key> \
 *   node scripts/sync-users.mjs --table users --id-column id --email-column email [--confirm]
 *
 * Idempotent: users already mapped are skipped, and a user that exists in Auth
 * but lost its mapping row (a run interrupted halfway) is re-linked rather than
 * duplicated. Without --confirm it only reports what it would do.
 */
import pg from "pg";

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? fallback : args[i + 1];
};
const has = (name) => args.includes(`--${name}`);

const TABLE = flag("table", "users");
const ID_COLUMN = flag("id-column", "id");
const EMAIL_COLUMN = flag("email-column", "email");
const LIMIT = Number(flag("limit", "0")) || null;
const CONFIRM = has("confirm");

const SUPABASE_URL = (process.env.SUPABASE_URL ?? "").replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
const SOURCE_URL = process.env.SOURCE_DATABASE_URL ?? "";

// Identifiers cannot be parameterised, so they are whitelisted by shape rather
// than interpolated blind.
const SAFE_IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;
for (const [label, value] of [
  ["--table", TABLE],
  ["--id-column", ID_COLUMN],
  ["--email-column", EMAIL_COLUMN],
]) {
  if (!SAFE_IDENT.test(value)) {
    console.error(`${label} must be a plain identifier, got: ${value}`);
    process.exit(2);
  }
}

const api = (path, init = {}) =>
  fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
  });

async function rpc(name, body) {
  const res = await api(`/rest/v1/rpc/${name}`, { method: "POST", body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`${name}: ${res.status} ${await res.text()}`);
  return res.json();
}

async function createAuthUser(email, externalId) {
  const res = await api("/auth/v1/admin/users", {
    method: "POST",
    body: JSON.stringify({
      email,
      // These are mirrored accounts; the app remains the authority on identity,
      // so no password is set and the address is taken as already verified.
      email_confirm: true,
      user_metadata: { external_id: externalId, mirrored_from: "shiftai" },
    }),
  });
  if (res.ok) return (await res.json()).id;

  // Already present in Auth from an earlier interrupted run: adopt it.
  if (res.status === 422 || res.status === 409) {
    const existing = await rpc("find_auth_user_by_email", { p_email: email });
    if (existing) return existing;
  }
  throw new Error(`create user failed: ${res.status} ${await res.text()}`);
}

async function linkUser(externalId, userId, email) {
  const res = await api("/rest/v1/external_user_map", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify({ external_id: externalId, user_id: userId, email }),
  });
  if (!res.ok) throw new Error(`link failed: ${res.status} ${await res.text()}`);
}

async function main() {
  if (!SOURCE_URL) {
    console.error("Set SOURCE_DATABASE_URL to the database holding ShiftAI's users.");
    process.exit(2);
  }
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.");
    process.exit(2);
  }

  const client = new pg.Client({ connectionString: SOURCE_URL });
  await client.connect();

  const { rows } = await client.query(
    `select "${ID_COLUMN}"::text as external_id, "${EMAIL_COLUMN}" as email
       from "${TABLE}"
      where "${EMAIL_COLUMN}" is not null
      order by "${ID_COLUMN}"
      ${LIMIT ? `limit ${LIMIT}` : ""}`,
  );
  await client.end();

  const mapRes = await api("/rest/v1/external_user_map?select=external_id");
  if (!mapRes.ok) {
    console.error(`could not read external_user_map: ${mapRes.status} ${await mapRes.text()}`);
    process.exit(1);
  }
  const alreadyMapped = new Set((await mapRes.json()).map((r) => r.external_id));

  const todo = rows.filter((r) => !alreadyMapped.has(r.external_id));

  console.log(`\nSource ${TABLE}: ${rows.length} user(s) with an address`);
  console.log(`Already mirrored: ${rows.length - todo.length}`);
  console.log(`To mirror:        ${todo.length}\n`);

  if (!todo.length) return;
  if (!CONFIRM) {
    for (const r of todo.slice(0, 10)) console.log(`  would mirror  ${r.email}`);
    if (todo.length > 10) console.log(`  ... and ${todo.length - 10} more`);
    console.log(`\nRe-run with --confirm to create them.\n`);
    return;
  }

  let created = 0;
  let failed = 0;
  for (const { external_id, email } of todo) {
    try {
      const userId = await createAuthUser(email, external_id);
      await linkUser(external_id, userId, email);
      created++;
      if (created % 50 === 0) console.log(`  ${created}/${todo.length}...`);
    } catch (err) {
      failed++;
      console.error(`  FAILED ${email}: ${err.message}`);
    }
  }

  console.log(`\nmirrored ${created}/${todo.length}${failed ? `, ${failed} failed` : ""}.\n`);
  if (failed) process.exit(1);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
