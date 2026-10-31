import { createHandler } from "../_shared/study_handler.ts";

Deno.serve(createHandler("flashcards"));
