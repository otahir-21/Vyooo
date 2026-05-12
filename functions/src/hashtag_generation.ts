import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';

/** Bound to this function via `secrets` so values come from Secret Manager in production. */
const geminiApiSecret = defineSecret('GEMINI_API_KEY');
const openaiApiSecret = defineSecret('OPENAI_API_KEY');

/**
 * Prefer Secret Manager (defineSecret) at runtime; fall back to process.env for the
 * Functions emulator. Use HASHTAG_* env names so `functions/.env.vyooov1` does not set
 * GEMINI_API_KEY / OPENAI_API_KEY as plain env (Cloud Run forbids the same name as both
 * secret and non-secret on one service).
 */
function readAiKey(secret: { value(): string }, envFallback: string | undefined): string {
  try {
    const v = secret.value().trim();
    if (v.length > 0 && v !== '-') return v;
  } catch {
    // Emulator / analysis contexts where secret.value() is not available
  }
  const e = (envFallback ?? '').trim();
  return e.length > 0 && e !== '-' ? e : '';
}

function geminiApiKey(): string {
  return readAiKey(geminiApiSecret, process.env.HASHTAG_GEMINI_API_KEY);
}
function openaiApiKey(): string {
  return readAiKey(openaiApiSecret, process.env.HASHTAG_OPENAI_API_KEY);
}
/** `gemini` | `openai` | `auto` (prefer Gemini when both keys exist). */
function hashtagAiProvider(): string {
  return (process.env.HASHTAG_AI_PROVIDER ?? 'auto').trim().toLowerCase();
}

const MIN_HASHTAGS = 30;
const MAX_HASHTAGS = 40;
const TITLE_MAX = 200;
const DESC_MAX = 500;
const CAT_MAX = 50;

/** Gen2: `firebase functions:log` often prints empty lines for logger.x("msg", {object}); prefer one string. */
function logHashtag(msg: string): void {
  logger.info(msg);
}

function logHashtagError(msg: string): void {
  logger.error(msg);
}

function normalizeTag(raw: unknown): string {
  if (typeof raw !== 'string') return '';
  let s = raw.trim();
  if (s.startsWith('#')) s = s.slice(1).trim();
  return s
    .toLowerCase()
    .replace(/[^a-z0-9_ ]/g, '')
    .replace(/\s+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .trim();
}

function clampInt(n: unknown, min: number, max: number, fallback: number): number {
  const v = typeof n === 'number' ? n : Number(n);
  if (!Number.isFinite(v)) return fallback;
  return Math.max(min, Math.min(max, Math.floor(v)));
}

function extractFallbackWords(title: string, description: string, category: string): string[] {
  const blob = `${title} ${description} ${category}`.toLowerCase();
  const parts = blob.split(/[^a-z0-9]+/);
  const stop = new Set([
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'as', 'is', 'it',
    'my', 'your', 'we', 'you', 'they', 'this', 'that', 'with', 'from', 'by', 'be', 'are', 'was',
  ]);
  const out: string[] = [];
  for (const p of parts) {
    const t = p.trim();
    if (t.length < 2 || t.length > 32) continue;
    if (stop.has(t)) continue;
    out.push(t);
  }
  return out;
}

function dedupeTags(tags: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const t of tags) {
    if (!t || seen.has(t)) continue;
    seen.add(t);
    out.push(t);
  }
  return out;
}

/** Adds single words and adjacent pairs from title/description/category (normalized). */
function enrichWithCorpus(
  existing: string[],
  title: string,
  description: string,
  category: string,
  max: number,
): string[] {
  const seen = new Set(existing);
  const out = [...existing];
  const words = extractFallbackWords(title, description, category);
  for (const w of words) {
    if (out.length >= max) break;
    const n = normalizeTag(w);
    if (n.length < 2 || n.length > 32 || seen.has(n)) continue;
    seen.add(n);
    out.push(n);
  }
  for (let i = 0; i < words.length - 1; i++) {
    if (out.length >= max) break;
    const bi = normalizeTag(`${words[i]}_${words[i + 1]}`);
    if (bi.length < 2 || bi.length > 32 || seen.has(bi)) continue;
    seen.add(bi);
    out.push(bi);
  }
  return out.slice(0, max);
}

function parseHashtagJson(text: string): string[] {
  const trimmed = text.trim();
  let slice = trimmed;
  const fence = /^```(?:json)?\s*([\s\S]*?)```$/m.exec(trimmed);
  if (fence) slice = fence[1].trim();

  let parsed: unknown;
  try {
    parsed = JSON.parse(slice);
  } catch (parseErr) {
    const preview = slice.length > 200 ? `${slice.slice(0, 197)}…` : slice;
    const oneLine = preview.replace(/\s+/g, ' ').slice(0, 220);
    logHashtagError(
      `[HashtagGen] JSON.parse failed err=${String(parseErr)} preview=${oneLine}`,
    );
    throw new Error(`AI returned invalid JSON: ${String(parseErr)}`);
  }
  if (Array.isArray(parsed)) {
    return parsed.map((x) => normalizeTag(x)).filter((t) => t.length >= 2 && t.length <= 32);
  }
  if (parsed && typeof parsed === 'object' && Array.isArray((parsed as { hashtags?: unknown }).hashtags)) {
    return (parsed as { hashtags: unknown[] }).hashtags
      .map((x) => normalizeTag(x))
      .filter((t) => t.length >= 2 && t.length <= 32);
  }
  throw new Error('Response was not a JSON array or {hashtags:[]} object.');
}

function resolveProvider(): 'gemini' | 'openai' {
  const prov = hashtagAiProvider();
  const gem = geminiApiKey();
  const oai = openaiApiKey();
  if (prov === 'openai') {
    if (!oai) {
      throw new Error(
        'HASHTAG_AI_PROVIDER is openai but OPENAI_API_KEY is empty. Production: `firebase functions:secrets:set OPENAI_API_KEY` (project vyooov1), then `firebase deploy --only functions --project vyooov1`. Local/emulator: set HASHTAG_OPENAI_API_KEY in functions/.env.vyooov1 (not OPENAI_API_KEY — avoids Cloud Run secret/plain name clash).',
      );
    }
    return 'openai';
  }
  if (prov === 'gemini') {
    if (!gem) {
      throw new Error(
        'HASHTAG_AI_PROVIDER is gemini but GEMINI_API_KEY is empty. Production: `firebase functions:secrets:set GEMINI_API_KEY`, then `firebase deploy --only functions --project vyooov1`. Local: HASHTAG_GEMINI_API_KEY in functions/.env.vyooov1.',
      );
    }
    return 'gemini';
  }
  if (gem) return 'gemini';
  if (oai) return 'openai';
  throw new Error(
    'No AI API keys on the server. Production: secrets `GEMINI_API_KEY` and `OPENAI_API_KEY` in Secret Manager (`firebase functions:secrets:set …`; use `-` for unused provider). Local/emulator: `HASHTAG_GEMINI_API_KEY` / `HASHTAG_OPENAI_API_KEY` in functions/.env.vyooov1 (do not use plain GEMINI_API_KEY in .env when this function mounts those names as secrets).',
  );
}

async function callGemini(prompt: string): Promise<string> {
  const model = process.env.GEMINI_MODEL?.trim() || 'gemini-flash-latest';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-goog-api-key': geminiApiKey(),
    },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.45,
        maxOutputTokens: 4096,
        responseMimeType: 'application/json',
      },
    }),
  });
  const bodyText = await res.text();
  if (!res.ok) {
    const bodyOneLine = bodyText.slice(0, 600).replace(/\s+/g, ' ');
    logHashtagError(`[HashtagGen] Gemini HTTP status=${res.status} body=${bodyOneLine}`);
    const hint = bodyText.slice(0, 280).replace(/\s+/g, ' ');
    throw new Error(`Gemini HTTP ${res.status}: ${hint}`);
  }
  let body: {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    error?: { message?: string; code?: number };
  };
  try {
    body = JSON.parse(bodyText) as typeof body;
  } catch (parseErr) {
    logHashtagError(
      `[HashtagGen] Gemini response not JSON parseErr=${String(parseErr)} body=${bodyText.slice(0, 400).replace(/\s+/g, ' ')}`,
    );
    throw new Error(`Gemini returned non-JSON (${String(parseErr)}).`);
  }
  if (body.error?.message) {
    logHashtagError(
      `[HashtagGen] Gemini API error message=${body.error.message} code=${body.error.code ?? 'n/a'}`,
    );
    throw new Error(`Gemini API: ${body.error.message}`);
  }
  const text =
    body.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
  if (!text.trim()) throw new Error('Empty Gemini response.');
  return text;
}

async function callOpenAI(prompt: string): Promise<string> {
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${openaiApiKey()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      temperature: 0.45,
      max_tokens: 4096,
      response_format: { type: 'json_object' },
      messages: [
        {
          role: 'system',
          content:
            'You output only valid JSON. Keys and string values use ASCII. No markdown, no commentary.',
        },
        { role: 'user', content: prompt },
      ],
    }),
  });
  const bodyText = await res.text();
  if (!res.ok) {
    const bodyOneLine = bodyText.slice(0, 600).replace(/\s+/g, ' ');
    logHashtagError(`[HashtagGen] OpenAI HTTP status=${res.status} body=${bodyOneLine}`);
    const hint = bodyText.slice(0, 280).replace(/\s+/g, ' ');
    throw new Error(`OpenAI HTTP ${res.status}: ${hint}`);
  }
  let body: {
    choices?: Array<{ message?: { content?: string } }>;
    error?: { message?: string };
  };
  try {
    body = JSON.parse(bodyText) as typeof body;
  } catch (parseErr) {
    logHashtagError(
      `[HashtagGen] OpenAI response not JSON parseErr=${String(parseErr)} body=${bodyText.slice(0, 400).replace(/\s+/g, ' ')}`,
    );
    throw new Error(`OpenAI returned non-JSON (${String(parseErr)}).`);
  }
  if (body.error?.message) {
    logHashtagError(`[HashtagGen] OpenAI API error message=${body.error.message}`);
    throw new Error(`OpenAI API: ${body.error.message}`);
  }
  const text = body.choices?.[0]?.message?.content ?? '';
  if (!text.trim()) throw new Error('Empty OpenAI response.');
  return text;
}

async function callAi(provider: 'gemini' | 'openai', prompt: string): Promise<string> {
  if (provider === 'gemini') return callGemini(prompt);
  return callOpenAI(prompt);
}

function buildPrompt(title: string, description: string, category: string, minCount: number): string {
  return [
    `You are a hashtag assistant for the short-video app Vyooo.`,
    `Return a JSON object with a single key "hashtags" whose value is an array of at least ${minCount} and at most ${MAX_HASHTAGS} distinct strings.`,
    `Each string is one hashtag WITHOUT a leading #.`,
    `Use only lowercase English letters a-z, digits 0-9, and underscores; length 2–32 characters each.`,
    `Tags must be relevant to THIS specific post (title, description, category). Include a mix of specific/niche tags and a few broader vertical tags that still fit the topic.`,
    `Do not invent unrelated viral tags. Do not repeat the same tag twice.`,
    `No profanity, slurs, sexual content, graphic violence, hate, harassment, politics, medical claims, or illegal topics.`,
    `No hashtags that are only generic platform words like fyp, foryou, viral, trending unless they clearly fit the described content.`,
    ``,
    `Title: ${title}`,
    `Description: ${description || '(none)'}`,
    `Category: ${category || '(none)'}`,
  ].join('\n');
}

function buildSupplementPrompt(
  existing: string[],
  need: number,
  title: string,
  description: string,
  category: string,
): string {
  return [
    `You are a hashtag assistant for Vyooo.`,
    `Return JSON {"hashtags": [...]} with exactly ${need} NEW hashtag strings (no # prefix).`,
    `They must still match this post and must NOT duplicate any tag in this list:`,
    JSON.stringify(existing),
    `Rules: lowercase a-z, digits, underscores only; 2–32 characters each; no unsafe content.`,
    `Title: ${title}`,
    `Description: ${description || '(none)'}`,
    `Category: ${category || '(none)'}`,
  ].join('\n');
}

export const processHashtagGenerationRequest = onDocumentCreated(
  {
    document: 'hashtag_generation_requests/{requestId}',
    timeoutSeconds: 60,
    memory: '256MiB',
    secrets: [geminiApiSecret, openaiApiSecret],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const markError = async (msg: string) => {
      logHashtagError(`[HashtagGen] FAILED requestId=${event.params.requestId} error=${msg}`);
      await snap.ref.update({
        status: 'error',
        error: msg,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    };

    const requestId = event.params.requestId as string;
    logHashtag(
      `[HashtagGen] START requestId=${requestId} geminiKeySet=${geminiApiKey().length > 0} openaiKeySet=${openaiApiKey().length > 0} HASHTAG_AI_PROVIDER=${hashtagAiProvider()}`,
    );

    const data = snap.data() as {
      userId?: unknown;
      title?: unknown;
      description?: unknown;
      category?: unknown;
      minCount?: unknown;
    };

    const userId = typeof data.userId === 'string' ? data.userId.trim() : '';
    const titleRaw = typeof data.title === 'string' ? data.title : '';
    const title = titleRaw.trim().slice(0, TITLE_MAX);
    const description =
      typeof data.description === 'string' ? data.description.trim().slice(0, DESC_MAX) : '';
    const category =
      typeof data.category === 'string' ? data.category.trim().slice(0, CAT_MAX) : '';
    const minCount = clampInt(data.minCount, MIN_HASHTAGS, MAX_HASHTAGS, MIN_HASHTAGS);

    if (!userId) {
      await markError('Missing userId.');
      return;
    }
    if (!title) {
      await markError('Add a title before generating hashtags.');
      return;
    }

    let provider: 'gemini' | 'openai';
    try {
      provider = resolveProvider();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      const stackOne = err instanceof Error ? (err.stack ?? '').replace(/\n/g, ' | ') : '';
      logHashtagError(`[HashtagGen] resolveProvider FAILED requestId=${requestId} error=${msg} stack=${stackOne}`);
      await markError(msg);
      return;
    }

    const prompt = buildPrompt(title, description, category, minCount);

    try {
      let rawJson = await callAi(provider, prompt);
      let unique = dedupeTags(parseHashtagJson(rawJson));

      if (unique.length < minCount) {
        const need = minCount - unique.length;
        const supplement = buildSupplementPrompt(unique, need, title, description, category);
        try {
          const raw2 = await callAi(provider, supplement);
          unique = dedupeTags([...unique, ...parseHashtagJson(raw2)]);
        } catch (supErr) {
          const s = supErr instanceof Error ? (supErr.stack ?? '').replace(/\n/g, ' | ') : '';
          logger.warn(
            `[HashtagGen] supplement FAILED requestId=${requestId} error=${String(supErr)} stack=${s}`,
          );
        }
      }

      unique = enrichWithCorpus(unique, title, description, category, MAX_HASHTAGS);

      if (unique.length < minCount) {
        await markError(
          `Only ${unique.length} valid hashtags could be produced (need ${minCount}). Try again or add a longer description.`,
        );
        return;
      }

      await snap.ref.update({
        status: 'done',
        hashtags: unique.slice(0, MAX_HASHTAGS),
        provider,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      logHashtag(
        `[HashtagGen] SUCCESS requestId=${event.params.requestId} count=${unique.length} provider=${provider}`,
      );
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      const stackOne = e instanceof Error ? (e.stack ?? '').replace(/\n/g, ' | ') : '';
      logHashtagError(
        `[HashtagGen] HANDLER_EXCEPTION requestId=${requestId} error=${message} stack=${stackOne}`,
      );
      const safe =
        message.length > 400 ? `${message.slice(0, 397)}…` : message;
      await markError(safe);
    }
  },
);
