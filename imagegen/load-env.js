const fs = require("fs");
const path = require("path");
const dotenv = require("dotenv");

/**
 * Loads project root `.env` first, then `imagegen/.env`.
 * Empty values never override a key already set.
 */
function loadEnvFiles() {
  const envPaths = [
    path.join(__dirname, "..", ".env"),
    path.join(__dirname, ".env"),
  ];

  for (const envPath of envPaths) {
    if (!fs.existsSync(envPath)) continue;
    const parsed = dotenv.parse(fs.readFileSync(envPath));
    for (const [key, value] of Object.entries(parsed)) {
      const trimmed = String(value ?? "").trim();
      if (trimmed.length > 0) {
        process.env[key] = trimmed;
      }
    }
  }
}

module.exports = {loadEnvFiles};
