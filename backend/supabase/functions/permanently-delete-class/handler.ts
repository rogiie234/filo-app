import { createClient } from "@supabase/supabase-js";
import { authenticate, corsHeaders, isUuid, json, requiredEnv } from "../_shared/otp.ts";

export function createHandler(authenticateRequest = authenticate) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, {headers: corsHeaders});
    if (req.method !== "POST") return json({error:"POST required"},405);
    try {
      const auth = await authenticateRequest(req);
      if (!auth) return json({error:"Unauthorized"},401);
      const body = await req.json().catch(() => null);
      if (!body || typeof body.class_id !== "string" || !isUuid(body.class_id) ||
          typeof body.section !== "string" || !body.section.length || body.section.length>60) return json({error:"Invalid request"},400);
      const userDb = createClient(requiredEnv("SUPABASE_URL"), requiredEnv("SUPABASE_ANON_KEY"), {
        global:{headers:{Authorization:req.headers.get("Authorization")!}},
        auth:{persistSession:false,autoRefreshToken:false},
      });
      const {error: denied} = await userDb.rpc("request_permanent_class_deletion",{p_class:body.class_id,p_section:body.section})
        .abortSignal(AbortSignal.timeout(15000));
      if (denied) return json({error:"Deletion could not be authorized"},403);
      const started = Date.now();
      while (Date.now()-started < 60000) {
        const {data: files,error} = await auth.admin.rpc("list_deleted_class_files",{p_class:body.class_id})
          .abortSignal(AbortSignal.timeout(15000));
        if (error) throw error;
        if (!files?.length) {
          const {data: deleted,error: failure} = await auth.admin.rpc("finish_deleted_class_purge",{p_class:body.class_id})
            .abortSignal(AbortSignal.timeout(15000));
          if (failure || !deleted) throw new Error("Deletion not confirmed");
          return json({deleted:true});
        }
        for (const bucket of ["banners","materials","submissions"]) {
          const paths = files.filter((f:{bucket_id:string}) => f.bucket_id===bucket).map((f:{name:string})=>f.name);
          if (paths.length) {
            const {error: failure} = await auth.admin.storage.from(bucket).remove(paths);
            if (failure) throw failure;
          }
        }
      }
      return json({error:"Deletion started; retry to finish"},503);
    } catch (_) { return json({error:"Could not confirm permanent deletion. Refresh and retry."},503); }
  };
}
