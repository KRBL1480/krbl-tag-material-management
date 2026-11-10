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
  if (!url || !serviceKey) return reply(500, { error: "Server authentication is not configured." });

  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!token) return reply(401, { error: "Administrator sign-in required." });

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: auth, error: authError } = await admin.auth.getUser(token);
  if (authError || !auth.user) return reply(401, { error: "Session expired. Sign in again." });

  const { data: callerRole, error: roleError } = await admin.from("krbl_user_roles")
    .select("role").eq("user_id", auth.user.id).maybeSingle();
  if (roleError) return reply(500, { error: "Could not verify administrator access." });
  if (callerRole?.role !== "admin") return reply(403, { error: "Only Super Admin can manage employee accounts." });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "Invalid request." }); }
  const action = String(body.action || "create");

  if (action === "reset_password") {
    const userId = String(body.user_id || "");
    const password = String(body.password || "");
    if (!/^[0-9a-f-]{36}$/i.test(userId)) return reply(400, { error: "Invalid employee account." });
    if (password.length < 10) return reply(400, { error: "Password must contain at least 10 characters." });
    const { data: profile, error: pErr } = await admin.from("krbl_team_profiles").select("user_id,full_name").eq("user_id", userId).maybeSingle();
    if (pErr || !profile) return reply(404, { error: "Employee profile not found." });
    const { error } = await admin.auth.admin.updateUserById(userId, { password });
    if (error) return reply(400, { error: error.message });
    await admin.from("krbl_activity_log").insert({ actor_id: auth.user.id, action: "admin_password_reset", entity: "krbl_team_profiles", entity_id: userId, new_data: { target_name: profile.full_name } });
    return reply(200, { ok: true, message: "Employee password reset successfully." });
  }

  if (action !== "create") return reply(400, { error: "Unsupported action." });

  const fullName = String(body.full_name || "").trim();
  const employeeId = String(body.employee_id || "").trim().toUpperCase();
  const username = String(body.username || "").trim().toLowerCase();
  const password = String(body.password || "");
  const role = String(body.role || "team");
  const area = String(body.area || (role === "office" ? "office" : "team"));
  const mandis = Array.isArray(body.assigned_mandis) ? body.assigned_mandis : [];

  if (!fullName) return reply(400, { error: "Employee name is required." });
  if (!/^[A-Z0-9][A-Z0-9_-]{1,19}$/.test(employeeId)) return reply(400, { error: "Employee ID must be 2–20 letters/numbers, underscore or hyphen." });
  if (!/^[a-z0-9][a-z0-9._-]{2,31}$/.test(username)) return reply(400, { error: "Username must be 3–32 characters: letters, numbers, dot, underscore or hyphen." });
  if (password.length < 10) return reply(400, { error: "Initial password must contain at least 10 characters." });
  if (!["office", "team", "viewer"].includes(role)) return reply(400, { error: "Only Office, Team or Viewer accounts can be created here." });
  if (!["office", "team"].includes(area)) return reply(400, { error: "Invalid department." });
  if (role === "team" && mandis.length === 0) return reply(400, { error: "Assign at least one mandi to a Team employee." });

  const { data: existing, error: lookupError } = await admin.from("krbl_team_profiles")
    .select("user_id,employee_id,username").or("employee_id.ilike." + employeeId + ",username.ilike." + username).limit(2);
  if (lookupError) return reply(500, { error: "Could not check employee ID/username uniqueness." });
  if (existing?.length) return reply(409, { error: "Employee ID or username already exists. Choose a unique value." });

  // Internal synthetic Auth email: never shown to staff and no invitation or email is sent.
  const internalEmail = username + "@employees.krbl.invalid";
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: internalEmail,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName, employee_id: employeeId, username, krbl_managed: true },
  });
  if (createError || !created.user) return reply(400, { error: createError?.message || "Could not create employee login." });

  const userId = created.user.id;
  const firstMandi = mandis[0] as Record<string, unknown> | undefined;
  const profile = {
    user_id: userId, full_name: fullName, employee_id: employeeId, username,
    email: internalEmail, role, department: area, area,
    mandi_code: firstMandi?.code || null, mandi_name: firstMandi?.name || null,
    assigned_mandis: mandis, active: true,
  };
  const { error: profileError } = await admin.from("krbl_team_profiles").insert(profile);
  if (profileError) {
    await admin.auth.admin.deleteUser(userId);
    return reply(500, { error: "Profile creation failed: " + profileError.message });
  }
  const { error: roleSaveError } = await admin.from("krbl_user_roles").upsert({ user_id: userId, role }, { onConflict: "user_id" });
  if (roleSaveError) {
    await admin.from("krbl_team_profiles").delete().eq("user_id", userId);
    await admin.auth.admin.deleteUser(userId);
    return reply(500, { error: "Role assignment failed: " + roleSaveError.message });
  }
  await admin.from("krbl_activity_log").insert({ actor_id: auth.user.id, action: "admin_create_employee", entity: "krbl_team_profiles", entity_id: userId, new_data: { full_name: fullName, employee_id: employeeId, username, role, assigned_mandis: mandis } });
  return reply(200, { ok: true, user_id: userId, employee_id: employeeId, username, message: "Employee account created. No email was sent." });
});