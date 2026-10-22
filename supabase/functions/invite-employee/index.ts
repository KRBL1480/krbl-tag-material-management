import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://krbl1480.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const json = (status: number, body: Record<string, unknown>) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json(500, { error: "Server function is missing its Supabase secrets." });
  }

  const authHeader = req.headers.get("Authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return json(401, { error: "Sign in as an administrator first." });

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userResult, error: userError } = await adminClient.auth.getUser(token);
  if (userError || !userResult.user) return json(401, { error: "Session is invalid or expired. Please sign in again." });

  const callerId = userResult.user.id;
  const { data: roleRow, error: roleError } = await adminClient
    .from("krbl_user_roles")
    .select("role")
    .eq("user_id", callerId)
    .maybeSingle();

  if (roleError) return json(500, { error: "Could not verify administrator role." });
  if (roleRow?.role !== "admin") return json(403, { error: "Only an administrator can invite employees." });

  let input: Record<string, unknown>;
  try {
    input = await req.json();
  } catch {
    return json(400, { error: "Invalid request body." });
  }

  const fullName = String(input.full_name || "").trim();
  const email = String(input.email || "").trim().toLowerCase();
  const employeeId = input.employee_id ? String(input.employee_id).trim() : null;
  const role = String(input.role || "");
  const area = String(input.area || "team");
  const assignedMandis = Array.isArray(input.assigned_mandis) ? input.assigned_mandis : [];

  if (!fullName || !/^\S+@\S+\.\S+$/.test(email)) return json(400, { error: "Enter a valid employee name and email." });
  if (!["office", "team", "viewer"].includes(role)) return json(400, { error: "New invitations may use Office, Team or Viewer role only." });
  if (!["office", "team"].includes(area)) return json(400, { error: "Invalid access group." });
  if (role === "team" && assignedMandis.length === 0) return json(400, { error: "Select at least one mandi for a Team employee." });

  const redirectTo = "https://krbl1480.github.io/krbl-tag-material-management/";
  const { data: inviteData, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, {
    redirectTo,
    data: { full_name: fullName, employee_id: employeeId },
  });

  let userId = inviteData.user?.id || null;
  if (inviteError) {
    // Allow an already-existing Auth account to be linked by email; do not create a duplicate.
    const { data: usersData, error: listError } = await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 });
    if (listError) return json(400, { error: inviteError.message });
    const existing = usersData.users.find((u) => (u.email || "").toLowerCase() === email);
    if (!existing) return json(400, { error: inviteError.message });
    userId = existing.id;
  }
  if (!userId) return json(500, { error: "Invitation did not return an account ID." });

  const profile = {
    user_id: userId,
    full_name: fullName,
    employee_id: employeeId,
    email,
    role,
    department: area,
    area,
    mandi_code: (assignedMandis[0] as Record<string, unknown> | undefined)?.code || null,
    mandi_name: (assignedMandis[0] as Record<string, unknown> | undefined)?.name || null,
    assigned_mandis: assignedMandis,
    active: true,
  };

  const { error: profileError } = await adminClient.from("krbl_team_profiles").upsert(profile, { onConflict: "user_id" });
  if (profileError) return json(500, { error: "Auth account was invited/located, but profile save failed: " + profileError.message, user_id: userId });

  const { error: roleSaveError } = await adminClient.from("krbl_user_roles").upsert({ user_id: userId, role }, { onConflict: "user_id" });
  if (roleSaveError) return json(500, { error: "Profile saved but role save failed: " + roleSaveError.message, user_id: userId });

  return json(200, {
    ok: true,
    user_id: userId,
    invited: !inviteError,
    message: inviteError ? "Existing Auth account linked and profile saved. If the employee has no password, send a password recovery email from Supabase Auth." : "Invitation sent and profile saved.",
  });
});
