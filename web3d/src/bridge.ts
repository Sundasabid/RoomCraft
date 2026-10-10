// Channel to the Flutter app. On phones Flutter calls
// window.roomcraft.receive(json) and we answer through the JavaScript channel
// named Bridge. In the browser the page sits in an iframe and both sides use
// postMessage: {roomcraftIn: json} in, {roomcraft: json} out.

export type Message = { t: string; seq?: number; [key: string]: unknown };
type Handler = (m: Message) => void;

declare global {
  interface Window {
    Bridge?: { postMessage(message: string): void };
    roomcraft: { receive(json: string): void };
  }
}

const handlers = new Map<string, Handler[]>();
let outSeq = 0;

export function on(type: string, handler: Handler): void {
  const list = handlers.get(type) ?? [];
  list.push(handler);
  handlers.set(type, list);
}

export function send(t: string, payload: Record<string, unknown> = {}): void {
  const message = JSON.stringify({ t, seq: ++outSeq, ...payload });
  if (window.Bridge) window.Bridge.postMessage(message);
  else if (window.parent !== window) window.parent.postMessage({ roomcraft: message }, '*');
  else console.debug('[bridge out]', message);
}

window.roomcraft = {
  receive(json: string) {
    let message: Message;
    try {
      message = JSON.parse(json) as Message;
    } catch {
      return;
    }
    for (const handler of handlers.get(message.t) ?? []) handler(message);
  },
};

window.addEventListener('message', (e: MessageEvent) => {
  if (e.source !== window.parent || window.parent === window) return;
  const data = e.data as { roomcraftIn?: unknown } | null;
  if (data && typeof data.roomcraftIn === 'string') window.roomcraft.receive(data.roomcraftIn);
});
