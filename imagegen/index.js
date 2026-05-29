const {loadEnvFiles} = require("./load-env");
loadEnvFiles();

const {initializeApp} = require("firebase-admin/app");
const {getStorage} = require("firebase-admin/storage");
const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");

initializeApp();
setGlobalOptions({maxInstances: 5});

// OpenAI `gpt-image-1` at low quality 1024x1024:
//  - ~$0.011 per image (272 output tokens at $40/1M)
//  - 4 images / call = ~$0.044 + tiny input text
//  - Best prompt adherence of any cheap option today
const OPENAI_IMAGE_URL = "https://api.openai.com/v1/images/generations";
const OPENAI_MODEL = "gpt-image-1";
const IMAGE_SIZE = "1024x1024";
const IMAGE_QUALITY = "low";
const MAX_PROMPT_LENGTH = 4000;
const DEFAULT_IMAGE_COUNT = 4;

const childSafePrefix =
  "Child-safe storybook book cover illustration for ages 9-12, " +
  "colorful, whimsical, magical, soft warm lighting, " +
  "no scary, violent, romantic, or adult content, no text or letters in image. ";

function getOpenAiKey() {
  const key = String(process.env.OPENAI_API_KEY || "").trim();
  if (!key) {
    throw new Error(
      "OPENAI_API_KEY is missing. Add it to the project root .env file.",
    );
  }
  return key;
}

function buildPrompt(prompt) {
  const scene = prompt.trim();
  if (scene.toLowerCase().includes("child-safe storybook")) {
    return scene.slice(0, MAX_PROMPT_LENGTH);
  }
  return (childSafePrefix + scene).slice(0, MAX_PROMPT_LENGTH);
}

function parseRequestBody(req) {
  const body = req.body;
  if (body && typeof body === "object" && !Buffer.isBuffer(body)) return body;
  if (typeof body === "string" && body.trim()) {
    try {
      return JSON.parse(body);
    } catch (_) {
      return {};
    }
  }
  return {};
}

async function callOpenAiImages(apiKey, prompt, n) {
  const response = await fetch(OPENAI_IMAGE_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      prompt: buildPrompt(prompt),
      n,
      size: IMAGE_SIZE,
      quality: IMAGE_QUALITY,
      output_format: "png",
    }),
  });

  if (!response.ok) {
    const bodyText = await response.text();
    let detail = bodyText;
    try {
      const parsed = JSON.parse(bodyText);
      detail = parsed?.error?.message || parsed?.message || bodyText;
    } catch (_) {
      // keep raw text
    }
    const err = new Error(String(detail || "OpenAI image request failed."));
    err.status = response.status;
    throw err;
  }

  const json = await response.json();
  const data = Array.isArray(json?.data) ? json.data : [];
  return data
    .map((item) => item?.b64_json)
    .filter((b64) => typeof b64 === "string" && b64.length > 0)
    .map((b64) => ({
      buffer: Buffer.from(b64, "base64"),
      mimeType: "image/png",
      base64: b64,
    }));
}

exports.generateStoryImages = onRequest(
  {
    cors: true,
    invoker: "public",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "Use POST."});
      return;
    }

    const body = parseRequestBody(req);
    const prompt = String(body.prompt || "").trim();
    const requested = Number(body.n);
    const count = Math.max(
      1,
      Math.min(
        Number.isFinite(requested) && requested > 0 ?
          Math.floor(requested) :
          DEFAULT_IMAGE_COUNT,
        4,
      ),
    );

    if (!prompt) {
      res.status(400).json({error: "Missing prompt."});
      return;
    }
    if (prompt.length > MAX_PROMPT_LENGTH) {
      res.status(400).json({error: "Prompt is too long."});
      return;
    }

    try {
      const apiKey = getOpenAiKey();
      const generated = await callOpenAiImages(apiKey, prompt, count);

      if (generated.length === 0) {
        res.status(502).json({error: "OpenAI returned no images."});
        return;
      }

      const urls = [];
      const images = [];
      for (const item of generated) {
        try {
          urls.push(await uploadImage(item.buffer, item.mimeType));
        } catch (uploadError) {
          logger.warn("Storage upload failed for one image", uploadError);
          urls.push("");
        }
        images.push({mimeType: item.mimeType, base64: item.base64});
      }

      res.json({urls, images});
    } catch (error) {
      logger.error("Image generation failed", error);
      const status = Number(error?.status) || 500;
      const message = String(error?.message || "");
      const lower = message.toLowerCase();

      if (status === 429 || lower.includes("rate")) {
        res.status(429).json({
          error:
            "OpenAI is rate-limited. Wait a minute and try again.",
        });
        return;
      }

      if (
        status === 401 ||
        status === 403 ||
        lower.includes("invalid api key") ||
        lower.includes("incorrect api key")
      ) {
        res.status(401).json({
          error:
            "OpenAI API key was rejected. Put your key in project .env as " +
            "OPENAI_API_KEY, then redeploy.",
        });
        return;
      }

      if (
        status === 402 ||
        lower.includes("insufficient_quota") ||
        lower.includes("billing") ||
        lower.includes("credit")
      ) {
        res.status(402).json({
          error:
            "OpenAI billing/credits issue. Top up at platform.openai.com or " +
            "verify your $5 prepaid credit is on the same account as the API key.",
        });
        return;
      }

      if (lower.includes("safety") || lower.includes("moderation")) {
        res.status(400).json({
          error:
            "OpenAI safety system blocked this prompt. Try a more " +
            "child-friendly story description.",
        });
        return;
      }

      res.status(status >= 400 && status < 600 ? status : 500).json({
        error: message || "Image generation failed.",
      });
    }
  },
);

function storageBucketName() {
  return (
    process.env.FIREBASE_STORAGE_BUCKET ||
    process.env.STORAGE_BUCKET ||
    "story-app-dc5c4.firebasestorage.app"
  );
}

async function uploadImage(buffer, mimeType) {
  const bucket = getStorage().bucket(storageBucketName());
  const extension = mimeType.includes("jpeg") ? "jpg" : "png";
  const filePath =
    `generated-story-images/${Date.now()}-${crypto.randomUUID()}.${extension}`;
  const token = crypto.randomUUID();
  const file = bucket.file(filePath);

  await file.save(buffer, {
    resumable: false,
    contentType: mimeType,
    metadata: {
      cacheControl: "public, max-age=31536000",
      metadata: {
        firebaseStorageDownloadTokens: token,
      },
    },
  });

  try {
    await file.makePublic();
  } catch (publicError) {
    logger.warn("makePublic skipped (token URL still works)", publicError);
  }

  const bucketHost = bucket.name.includes("firebasestorage.app") ?
    bucket.name :
    `${bucket.name.split(".")[0]}.firebasestorage.app`;

  return (
    `https://firebasestorage.googleapis.com/v0/b/${bucketHost}/o/` +
    `${encodeURIComponent(filePath)}?alt=media&token=${token}`
  );
}
