/**
 * Copies image-generation keys from the project root `.env` into
 * `imagegen/.env` so Firebase deploy can inject them into Cloud Functions.
 */
const fs = require("fs");
const path = require("path");

const rootEnvPath = path.join(__dirname, "..", ".env");
const imagegenEnvPath = path.join(__dirname, "..", "imagegen", ".env");

function parseEnvFile(envPath) {
  const out = {};
  if (!fs.existsSync(envPath)) return out;
  const content = fs.readFileSync(envPath, "utf8");
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
    if (!match) continue;
    out[match[1]] = match[2].trim().replace(/^["']|["']$/g, "");
  }
  return out;
}

if (!fs.existsSync(rootEnvPath)) {
  console.error("Missing .env at project root. Add OPENAI_API_KEY there.");
  process.exit(1);
}

const parsed = parseEnvFile(rootEnvPath);
const openaiKey = String(parsed.OPENAI_API_KEY || "").trim();

if (!openaiKey) {
  console.error(
    "OPENAI_API_KEY is empty in .env. Paste your OpenAI key, then deploy again.",
  );
  process.exit(1);
}

const lines = [
  "# Auto-synced from project root .env - do not commit.",
  `OPENAI_API_KEY=${openaiKey}`,
  "",
];

fs.writeFileSync(imagegenEnvPath, lines.join("\n"), "utf8");
console.log("Synced OPENAI_API_KEY to imagegen/.env for deploy.");
