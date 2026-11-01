import type { Notice, Outcome, Sender, Token } from "./push.ts";
const encoder = new TextEncoder();
const base64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
const encoded = (x: unknown) => base64url(encoder.encode(JSON.stringify(x)));
export function classify(status: number, body: unknown): Outcome {
  if (status >= 200 && status < 300 && typeof (body as { name?: unknown })?.name === "string") return { status: "sent" };
  const error = (body as { error?: { details?: { "@type"?: string; errorCode?: string }[]; message?: string } })?.error;
  const details = Array.isArray(error?.details) ? error.details : [];
  const code = details.find((d) => d["@type"] === "type.googleapis.com/google.firebase.fcm.v1.FcmError")?.errorCode;
  // INVALID_ARGUMENT alone may mean a bad payload, not a bad registration.
  const invalid = status === 404 && code === "UNREGISTERED" || status === 400 && code === "INVALID_ARGUMENT" &&
    /(?:registration token is not a valid FCM registration token|invalid registration token)/i.test(error?.message ?? "");
  return invalid ? { status: "invalid_token" } : { status: "failed", error: "provider" };
}
export function createFcm(raw: string | undefined, http: typeof fetch = fetch): Sender {
  let access = ""; let expires = 0; let project = "";
  async function prepare() {
    if (access && Date.now() < expires) return;
    const account = JSON.parse(raw ?? "null");
    if (!account || typeof account.project_id !== "string" || !/^[a-z0-9-]+$/.test(account.project_id) ||
      typeof account.client_email !== "string" || typeof account.private_key !== "string") throw new Error("FCM configuration");
    project = account.project_id;
    const pem = account.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
    const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
    const now = Math.floor(Date.now() / 1000);
    const unsigned = encoded({ alg: "RS256", typ: "JWT" }) + "." + encoded({ iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging", aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 });
    const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, encoder.encode(unsigned));
    const response = await http("https://oauth2.googleapis.com/token", { method: "POST", signal: AbortSignal.timeout(10000),
      headers: { "content-type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: unsigned + "." + base64url(new Uint8Array(signature)) }) });
    const result = await response.json();
    if (!response.ok || typeof result.access_token !== "string" || !Number.isFinite(result.expires_in) || result.expires_in <= 60) throw new Error("FCM authorization");
    access = result.access_token; expires = Date.now() + Math.min(result.expires_in - 60, 3540) * 1000;
  }
  return { prepare, async send(n: Notice, t: Token): Promise<Outcome> {
    try {
      const response = await http(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`, {
        method: "POST", signal: AbortSignal.timeout(10000),
        headers: { authorization: `Bearer ${access}`, "content-type": "application/json" },
        body: JSON.stringify({ message: { token: t.fcm_token, notification: { title: n.title, body: n.body ?? "" },
          data: { notification_id: n.id, type: n.type, class_id: n.class_id ?? "",
            target_type: n.target_type ?? "", target_id: n.target_id ?? "" } } }) });
      return classify(response.status, await response.json());
    } catch (error) {
      return { status: "failed", error: error instanceof DOMException && (error.name === "TimeoutError" || error.name === "AbortError") ? "timeout" : "transport" };
    }
  } };
}
