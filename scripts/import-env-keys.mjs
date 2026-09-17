#!/usr/bin/env node
/**
 * ShiftAI :: load AI provider keys from a local .env file into the Supabase vault.
 *
 *   SUPABASE_URL=https://<ref>.supabase.co \
 *   SUPABASE_SERVICE_ROLE_KEY=<service-role-key> \
 *   node scripts/import-env-keys.mjs .env.local [--confirm]
 *
 * Without --confirm this only prints a plan. Key values are never printed, never
 * written to disk, and never sent anywhere but your own Supabase project.
 *
 * Run it from a trusted machine. The service role key can decrypt every stored
 * credential, so do not put it in a shell history file or a CI log.
 */
import { readFileSync } from "node:fs";

// Only AI provider credentials belong in this vault. Everything else in a
// typical .env is deliberately absent -- see REFUSED below.
const PROVIDER_BY_ENV_VAR = {
  ANTHROPIC_API_KEY: "anthropic",
  OPENAI_API_KEY: "openai",
  GOOGLE_API_KEY: "google",
  GEMINI_API_KEY: "google",
  GROQ_API_KEY: "groq",
  OPENROUTER_API_KEY: "openrouter",
  ELEVENLABS_API_KEY: "elevenlabs",
  HEYGEN_API_KEY: "heygen",
  REPLICATE_API_TOKEN: "replicate",
  FAL_KEY: "fal",
  FLUX_API_KEY: "flux",
  RUNWAY_API_KEY: "runway",
  LUMA_API_KEY: "luma",
};

// Named explicitly so the script can say why it skipped them rather than
// silently ignoring a key someone expected to be imported.
const REFUSED = {
  STRIPE_SECRET_KEY: "payment credential -- belongs in Stripe-specific handling, not the AI key vault",
  STRIPE_PUBLISHABLE_KEY: "publishable by design; ship it in the client",
  STRIPE_WEBHOOK_SECRET: "webhook signing secret, not an AI provider key",
  JWT_SECRET: "session signing secret -- rotating it through this vault would not help",
  APP_SESSION_SECRET: "session signing secret",
  DATABASE_URL: "database credential",
  SUPABASE_SERVICE_ROLE_KEY: "this is the credential the importer authenticates with",
};

function parseEnv(text) {
  const out = new Map();
  for (const rawLine of text.split("\n")) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    // dotenv semantics: a later assignment wins.
    out.set(key, value);
  }
  return out;
}

const hint = (v) => `${"*".repeat(6)}${v.slice(-4)}`;

async function storeKey(url, serviceKey, provider, secret) {
  const res = await fetch(`${url.replace(/\/+$/, "")}/rest/v1/rpc/store_provider_key`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "content-type": "application/json",
    },
    // p_owner null == platform key, usable by every account as fallback
    body: JSON.stringify({
      p_provider: provider,
      p_secret: secret,
      p_label: "default",
      p_owner: null,
    }),
  });
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
  return res.json();
}

async function main() {
  const [file, ...flags] = process.argv.slice(2);
  const confirm = flags.includes("--confirm");

  if (!file) {
    console.error("usage: node scripts/import-env-keys.mjs <path-to-.env> [--confirm]");
    process.exit(2);
  }

  const env = parseEnv(readFileSync(file, "utf8"));
  const found = [];
  const empty = [];

  for (const [name, provider] of Object.entries(PROVIDER_BY_ENV_VAR)) {
    const value = env.get(name);
    if (value === undefined) continue;
    if (value === "") {
      empty.push(name);
      continue;
    }
    found.push({ name, provider, value });
  }

  console.log(`\nParsed ${file}\n`);
  for (const { name, provider, value } of found) {
    console.log(`  import   ${name.padEnd(22)} -> ${provider.padEnd(11)} ${hint(value)}`);
  }
  for (const name of empty) {
    console.log(`  skip     ${name.padEnd(22)} -- empty`);
  }
  for (const [name, why] of Object.entries(REFUSED)) {
    if (env.has(name)) console.log(`  refuse   ${name.padEnd(22)} -- ${why}`);
  }

  if (!found.length) {
    console.log("\nNothing to import.\n");
    return;
  }

  if (!confirm) {
    console.log(`\n${found.length} key(s) ready. Re-run with --confirm to store them.\n`);
    return;
  }

  const url = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) {
    console.error("\nSet SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment.\n");
    process.exit(2);
  }

  console.log("");
  let failed = 0;
  for (const { provider, value, name } of found) {
    try {
      await storeKey(url, serviceKey, provider, value);
      console.log(`  stored   ${provider.padEnd(11)} ${hint(value)}`);
    } catch (err) {
      failed++;
      // err may quote the provider's response; it never contains the key.
      console.error(`  FAILED   ${provider.padEnd(11)} (${name}): ${err.message}`);
    }
  }

  console.log(
    `\n${found.length - failed}/${found.length} stored.` +
      (failed ? " Re-run for the failures once their cause is fixed.\n" : "\n"),
  );
  console.log(
    "These values have now been read from disk. Rotate anything that has ever\n" +
      "been pasted into a chat, a ticket, or a shared file.\n",
  );
  if (failed) process.exit(1);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
