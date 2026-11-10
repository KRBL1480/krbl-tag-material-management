import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "https://krbl1480.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !serviceKey || !anonKey) return reply(500, { error: "Login service is not configured." });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "Invalid login request." }); }
  const identifier = String(body.identifier || "").trim();
  const password = String(body.password || "");
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{1,31}$/.test(identifier) || !password || password.length > 128) return reply(400, { error: "Enter a valid Employee ID/Username and password." });

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileError } = await admin.from("krbl_team_profiles")
    .select("user_id,email,active,full_name,employee_id,username")
    .or("employee_id.ilike." + identifier.replace(/[,.()]/g, "") + ",username.ilike." + identifier.replace(/[,.()]/g, ""))
    .limit(1).maybeSingle();

  // Keep the response generic so account status/existence is not disclosed.
  if (profileError || !profile || profile.active === false || !profile.email) return reply(401, { error: "Invalid login details or inactive account." });

  const authClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: signed, error: signError } = await authClient.auth.signInWithPassword({ email: profile.email, password });
  if (signError || !signed.session || !signed.user) return reply(401, { error: "Invalid login details or inactive account." });

  const now = new Date().toISOString();
  await admin.from("krbl_team_profiles").update({ last_login_at: now, last_activity_at: now }).eq("user_id", profile.user_id);
  await admin.from("krbl_activity_log").insert({ actor_id: profile.user_id, action: "login", entity: "auth", entity_id: profile.user_id, new_data: { login_method: "employee_id_or_username" } });

  return reply(200, { session: signed.session, user: { id: signed.user.id, email: signed.user.email, user_metadata: signed.user.user_metadata }, profile: { full_name: profile.full_name, employee_id: profile.employee_id, username: profile.username } });
});