import { purgeFetch } from "./request.ts";

function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}

Deno.test("stalled purge requests abort within the remaining worker budget", async () => {
  let signal: AbortSignal | null | undefined;
  const stalled: typeof fetch = (_input, init) => {
    signal = init?.signal;
    return new Promise((_resolve, reject) => {
      signal!.addEventListener("abort", () => reject(signal!.reason), { once: true });
    });
  };
  try {
    await purgeFetch(Date.now() + 50, stalled)("https://example.invalid");
    throw new Error("Request did not time out");
  } catch (error) {
    assert(error instanceof DOMException && error.name === "TimeoutError");
    assert(signal?.aborted);
  }
});

Deno.test("expired worker budget never dispatches another request", async () => {
  let dispatched = false;
  const http: typeof fetch = () => { dispatched = true; return Promise.resolve(new Response()); };
  try {
    await purgeFetch(Date.now() - 1, http)("https://example.invalid");
    throw new Error("Expired request dispatched");
  } catch (error) {
    assert(error instanceof DOMException && error.name === "TimeoutError");
    assert(!dispatched);
  }
});

Deno.test("a stalled request has a ten-second cap even with ample worker budget", async () => {
  const started = Date.now();
  const stalled: typeof fetch = (_input, init) => new Promise((_resolve, reject) => {
    init!.signal!.addEventListener("abort", () => reject(init!.signal!.reason), { once: true });
  });
  try {
    await purgeFetch(started + 90000, stalled)("https://example.invalid");
    throw new Error("Request did not time out");
  } catch (error) {
    assert(error instanceof DOMException && error.name === "TimeoutError");
    assert(Date.now() - started < 15000);
  }
});

Deno.test("purge requests preserve caller cancellation", async () => {
  const caller = new AbortController();
  caller.abort();
  const http: typeof fetch = (_input, init) => {
    assert(init?.signal?.aborted);
    return Promise.resolve(new Response("ok"));
  };
  await purgeFetch(Date.now() + 90000, http)("https://example.invalid", { signal: caller.signal });
});
