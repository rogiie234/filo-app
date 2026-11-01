import { createRecoveryHandler } from "../delete-account/deletion.ts";
import { createStore } from "../delete-account/store.ts";

Deno.serve(createRecoveryHandler(createStore(), Deno.env.get("ACCOUNT_DELETION_SECRET")));
