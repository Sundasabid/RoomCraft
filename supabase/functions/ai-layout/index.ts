// ai-layout: asks Gemini for three furniture layouts as strict JSON.
// This function only checks the shape and size of what comes back; the app's
// own validator decides which layouts are safe. The Gemini key never leaves
// the function's secrets.

const SYSTEM_PROMPT = `You are the layout assistant inside a room-planning app. You receive a room, its doors and windows, and its furniture as JSON. Return exactly 3 different candidate layouts that achieve the user's goal.

Rules, all mandatory:
1. Positions are in metres. x and z are the centre of an item's footprint. The room polygon is room.corners, listed clockwise on the plan with z increasing downward. Every item's whole footprint must be inside it.
2. rotation is one of 0, 90, 180, 270, clockwise on the plan. At 0 an item's front faces +z; at 90 and 270 its width and depth swap on the plan.
3. Items must not overlap each other, except that an item with floorOnly true (a rug) may lie under others. An item's rectangle is x ± w/2 and z ± d/2, where w and d are width and depth at rotation 0 or 180, and depth and width at 90 or 270. Edges may touch.
4. No item may overlap a door's keepOut rectangle (floorOnly items excepted). Keep walking paths from every door to the rest of the room at least 0.9 m wide where possible.
5. Return every item whose locked is false exactly once, using its given id. Do not return locked items, invent ids, add items or remove items. Locked items stay exactly where they are: treat their rect as an obstacle that nothing may overlap.
6. Round x and z to the nearest 0.05.
7. Keep furniture sensible: a bed headboard against a wall, a sofa facing the room or the TV unit, a desk near a window if one exists, a wardrobe against a wall with free space in front of it.
8. The three candidates must differ meaningfully from each other and from the current layout.

Before answering, check each candidate: every rectangle inside room.bounds and the polygon, no two non-rug rectangles overlapping, none overlapping a locked rect or a door keepOut. Move anything that fails until it passes. Leaving an item where it already is, is allowed when that keeps the layout valid.

For each candidate give a short name (at most 3 words) and one plain sentence of reason (at most 20 words) addressed to the user. Output JSON only, matching the schema.`;

const SCHEMA = {
  type: 'OBJECT',
  properties: {
    candidates: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          name: { type: 'STRING' },
          reason: { type: 'STRING' },
          items: {
            type: 'ARRAY',
            items: {
              type: 'OBJECT',
              properties: {
                id: { type: 'STRING' },
                x: { type: 'NUMBER' },
                z: { type: 'NUMBER' },
                rotation: { type: 'INTEGER' },
              },
              required: ['id', 'x', 'z', 'rotation'],
            },
          },
        },
        required: ['name', 'reason', 'items'],
      },
    },
  },
  required: ['candidates'],
};

const ROTATIONS = new Set([0, 90, 180, 270]);
const CALL_TIMEOUT_MS = 20_000;

type Code = 'bad_request' | 'rate_limited' | 'ai_unavailable' | 'ai_bad_output' | 'ai_timeout';
const STATUS: Record<Code, number> = {
  bad_request: 400,
  rate_limited: 429,
  ai_unavailable: 502,
  ai_bad_output: 502,
  ai_timeout: 504,
};
const MESSAGE: Record<Code, string> = {
  bad_request: 'Something went wrong preparing your room. Nothing was changed.',
  rate_limited: 'Too many requests right now. Try again in a minute.',
  ai_unavailable: 'The AI is not available right now. Nothing was changed.',
  ai_bad_output: 'The AI gave an answer we could not use. Nothing was changed.',
  ai_timeout: 'The AI took too long. Nothing was changed.',
};

// The web build calls this from the browser, which needs CORS headers.
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const fail = (code: Code, upstream?: number, reason?: string) =>
  json({ error: { code, message: MESSAGE[code], ...(upstream ? { upstream, reason } : {}) } }, STATUS[code]);

// deno-lint-ignore no-explicit-any
type Any = any;

function validBody(body: Any): boolean {
  if (!body || typeof body !== 'object') return false;
  const { goal, input } = body;
  if (typeof goal !== 'string' || goal.trim().length < 1 || goal.length > 200) return false;
  if (!input || typeof input !== 'object' || !input.room || !Array.isArray(input.room.corners)) return false;
  if (!Array.isArray(input.items) || input.items.length > 40) return false;
  if (body.feedback !== undefined && (!Array.isArray(body.feedback) || body.feedback.length > 6)) return false;
  return JSON.stringify(body).length < 150_000;
}

/** Shape check only: 1 to 3 candidates, each item with a string id, finite x and z, and an allowed rotation. */
function shapeOk(parsed: Any): boolean {
  const list = parsed?.candidates;
  if (!Array.isArray(list) || list.length < 1 || list.length > 3) return false;
  return list.every(
    (c: Any) =>
      typeof c?.name === 'string' &&
      typeof c?.reason === 'string' &&
      Array.isArray(c?.items) &&
      c.items.every(
        (i: Any) =>
          typeof i?.id === 'string' &&
          Number.isFinite(i?.x) &&
          Number.isFinite(i?.z) &&
          Number.isInteger(i?.rotation) &&
          ROTATIONS.has(i.rotation),
      ),
  );
}

/** The user turn: goal, room, and any problems the app found last time. */
function prompt(body: Any): string {
  let text = `Goal: ${body.goal.trim()}\n\nRoom:\n${JSON.stringify(body.input)}`;
  if (Array.isArray(body.feedback) && body.feedback.length) {
    text +=
      '\n\nYour previous layouts were checked by the app and failed. Each entry shows a layout and every problem found. ' +
      'Return 3 corrected layouts that fix every problem while keeping the goal:\n' +
      JSON.stringify(body.feedback);
  }
  return text;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return fail('bad_request');
  let body: Any;
  try {
    body = await req.json();
  } catch {
    return fail('bad_request');
  }
  if (!validBody(body)) return fail('bad_request');

  const key = Deno.env.get('GEMINI_API_KEY');
  if (!key) return fail('ai_unavailable');
  // The chosen model first; if it is busy or gone, the next Flash model.
  const primary = Deno.env.get('GEMINI_MODEL') || 'gemini-3.5-flash-lite';
  const fallbacks = (Deno.env.get('GEMINI_FALLBACK_MODELS') || 'gemini-3.5-flash,gemini-3.8-flash')
    .split(',')
    .map((m) => m.trim())
    .filter((m) => m && m !== primary);
  const models = [primary, ...fallbacks];

  const request = JSON.stringify({
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: [{ role: 'user', parts: [{ text: prompt(body) }] }],
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 4096,
      responseMimeType: 'application/json',
      responseSchema: SCHEMA,
    },
  });

  // Two tries for unusable output; busy models move on to the next one. The
  // whole request stays inside 22 s so the app's 25 s limit never cuts it.
  const deadline = Date.now() + 22_000;
  let badOutputs = 0;
  let modelIndex = 0;
  let lastStatus = 0;
  let lastReason = '';
  while (badOutputs < 2 && modelIndex < models.length) {
    const left = deadline - Date.now();
    if (left < 1500) return fail('ai_timeout');
    const model = models[modelIndex];
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), Math.min(CALL_TIMEOUT_MS, left));
    let res: Response;
    try {
      res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
        body: request,
        signal: abort.signal,
      });
    } catch (e) {
      clearTimeout(timer);
      return fail(e instanceof DOMException && e.name === 'AbortError' ? 'ai_timeout' : 'ai_unavailable');
    }
    if (res.status === 429) {
      clearTimeout(timer);
      return fail('rate_limited');
    }
    if (!res.ok) {
      clearTimeout(timer);
      // Google's own short reason (never the key) tells a blocked project
      // from a busy model or a bad key.
      const detail = await res.text();
      console.error('gemini error', model, res.status, detail.slice(0, 300));
      lastStatus = res.status;
      try {
        const e = JSON.parse(detail)?.error;
        lastReason = `${model} ${e?.status ?? ''}: ${String(e?.message ?? '').slice(0, 160)}`;
      } catch {
        lastReason = `${model} ${res.status}`;
      }
      // Busy, failing or retired models: try the next one.
      if (res.status >= 500 || res.status === 404) {
        modelIndex++;
        continue;
      }
      return fail('ai_unavailable', lastStatus, lastReason);
    }
    let data: Any;
    try {
      data = await res.json();
    } catch (e) {
      clearTimeout(timer);
      if (e instanceof DOMException && e.name === 'AbortError') return fail('ai_timeout');
      badOutputs++;
      continue;
    }
    clearTimeout(timer);
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    try {
      const parsed = typeof text === 'string' ? JSON.parse(text) : null;
      if (shapeOk(parsed)) return json({ candidates: parsed.candidates.slice(0, 3), model });
    } catch {
      // unusable text; counted below
    }
    badOutputs++;
  }
  if (badOutputs < 2) return fail('ai_unavailable', lastStatus, lastReason);
  return fail('ai_bad_output');
});
