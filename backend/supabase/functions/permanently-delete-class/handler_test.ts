import { createHandler } from "./handler.ts";
function assert(value: unknown) { if (!value) throw new Error("Assertion failed"); }
Deno.test("permanent class deletion rejects unsupported methods", async () => {
  const response = await createHandler(async () => null)(new Request("https://example.invalid", {method:"GET"}));
  assert(response.status===405);
});
Deno.test("permanent class deletion requires authenticated identity before parsing", async () => {
  const response = await createHandler(async () => null)(new Request("https://example.invalid", {method:"POST",body:"{}"}));
  assert(response.status===401);
});
Deno.test("malformed class identifiers cannot reach cleanup", async () => {
  const handler = createHandler(async () => ({admin:{} as never,userId:"fixture",email:"fixture@example.invalid",sessionId:"fixture"}));
  for (const body of [{class_id:"../other",section:"A"},{class_id:"00000000-0000-4000-8000-000000000001",section:""}]) {
    const response = await handler(new Request("https://example.invalid", {method:"POST",body:JSON.stringify(body)}));
    assert(response.status===400);
  }
});
