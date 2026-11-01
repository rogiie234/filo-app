import { authenticate } from "../_shared/otp.ts";
import { createHandler } from "./deletion.ts";
import { createStore } from "./store.ts";

Deno.serve(createHandler(createStore(), authenticate));
