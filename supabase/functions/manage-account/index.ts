import { createClient } from "npm:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const validCargos = [
  "super_admin",
  "admin",
  "medico",
  "enfermeiro",
  "tecnico",
  "rececionista",
  "triagem",
];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return json({ ok: true });
  }

  try {
    if (req.method !== "POST") {
      return json({ error: "Método não permitido." }, 405);
    }

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Configuração Supabase em falta na função." }, 500);
    }

    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return json({ error: "Utilizador não autenticado." }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return json({ error: "Sessão inválida." }, 401);
    }

    const { data: callerProfile, error: callerProfileError } = await adminClient
      .from("app_users")
      .select("id, auth_user_id, nome, email, cargo, hospital, departamento, ativo")
      .eq("auth_user_id", user.id)
      .single();

    if (callerProfileError || !callerProfile) {
      return json({
        error: "Perfil profissional do utilizador autenticado não encontrado.",
      }, 403);
    }

    if (callerProfile.ativo !== true) {
      return json({ error: "A tua conta está inativa." }, 403);
    }

    const canManageAccounts =
      callerProfile.cargo === "super_admin" || callerProfile.cargo === "admin";

    if (!canManageAccounts) {
      return json({ error: "Sem permissão para gerir contas." }, 403);
    }

    const body = await req.json();
    const action = body.action;

    if (action === "list") {
      const search = String(body.search ?? "").trim();

      let query = adminClient
        .from("app_users")
        .select("id, auth_user_id, nome, email, cargo, hospital, departamento, ativo, created_at, updated_at")
        .order("created_at", { ascending: false });

      if (search.length > 0) {
        query = query.or(
          `nome.ilike.%${search}%,email.ilike.%${search}%,cargo.ilike.%${search}%,hospital.ilike.%${search}%,departamento.ilike.%${search}%`,
        );
      }

      const { data, error } = await query;

      if (error) {
        return json({ error: error.message }, 400);
      }

      return json({
        accounts: data ?? [],
        account: callerProfile,
        profile: callerProfile,
      });
    }

    if (action === "create") {
      const nome = String(body.nome ?? "").trim();
      const email = String(body.email ?? "").trim().toLowerCase();
      const password = String(body.password ?? "");
      const cargo = String(body.cargo ?? "").trim();
      const hospital = String(body.hospital ?? "").trim();
      const departamento = String(body.departamento ?? "").trim();
      const ativo = body.ativo === false ? false : true;

      if (!nome) {
        return json({ error: "O campo nome é obrigatório." }, 400);
      }

      if (!email) {
        return json({ error: "O campo email é obrigatório." }, 400);
      }

      if (!password) {
        return json({ error: "A password temporária é obrigatória." }, 400);
      }

      if (!cargo) {
        return json({ error: "Perfil profissional incompleto. O campo cargo está vazio." }, 400);
      }

      if (!validCargos.includes(cargo)) {
        return json({ error: `Cargo inválido recebido: ${cargo}` }, 400);
      }

      if (cargo === "super_admin" && callerProfile.cargo !== "super_admin") {
        return json({ error: "Só um super_admin pode criar outro super_admin." }, 403);
      }

      const { data: existingProfile, error: existingProfileError } =
        await adminClient
          .from("app_users")
          .select("auth_user_id, email")
          .eq("email", email)
          .maybeSingle();

      if (existingProfileError) {
        return json({ error: existingProfileError.message }, 400);
      }

      if (existingProfile) {
        return json({ error: "Já existe uma conta com este email." }, 400);
      }

      const { data: createdUser, error: createUserError } =
        await adminClient.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: {
            nome,
            cargo,
          },
        });

      if (createUserError || !createdUser.user) {
        return json({
          error: createUserError?.message ?? "Erro ao criar utilizador no Auth.",
        }, 400);
      }

      const { data: newProfile, error: insertProfileError } = await adminClient
        .from("app_users")
        .insert({
          auth_user_id: createdUser.user.id,
          nome,
          email,
          cargo,
          hospital,
          departamento,
          ativo,
        })
        .select("id, auth_user_id, nome, email, cargo, hospital, departamento, ativo, created_at, updated_at")
        .single();

      if (insertProfileError) {
        return json({ error: insertProfileError.message }, 400);
      }

      return json({
        success: true,
        account: newProfile,
        profile: newProfile,
      });
    }

    if (action === "update") {
      const authUserId = String(body.auth_user_id ?? "").trim();

      if (!authUserId) {
        return json({ error: "auth_user_id em falta." }, 400);
      }

      const nome = String(body.nome ?? "").trim();
      const email = String(body.email ?? "").trim().toLowerCase();
      const password = String(body.password ?? "");
      const cargo = String(body.cargo ?? "").trim();
      const hospital = String(body.hospital ?? "").trim();
      const departamento = String(body.departamento ?? "").trim();

      if (!nome) {
        return json({ error: "O campo nome é obrigatório." }, 400);
      }

      if (!email) {
        return json({ error: "O campo email é obrigatório." }, 400);
      }

      if (!cargo) {
        return json({ error: "Perfil profissional incompleto. O campo cargo está vazio." }, 400);
      }

      if (!validCargos.includes(cargo)) {
        return json({ error: `Cargo inválido recebido: ${cargo}` }, 400);
      }

      if (cargo === "super_admin" && callerProfile.cargo !== "super_admin") {
        return json({ error: "Só um super_admin pode atribuir cargo super_admin." }, 403);
      }

      const authUpdateData: Record<string, unknown> = {
        email,
        user_metadata: {
          nome,
          cargo,
        },
      };

      if (password) {
        authUpdateData.password = password;
      }

      const { error: updateAuthError } =
        await adminClient.auth.admin.updateUserById(authUserId, authUpdateData);

      if (updateAuthError) {
        return json({ error: updateAuthError.message }, 400);
      }

      const { data: updatedProfile, error: updateProfileError } = await adminClient
        .from("app_users")
        .update({
          nome,
          email,
          cargo,
          hospital,
          departamento,
        })
        .eq("auth_user_id", authUserId)
        .select("id, auth_user_id, nome, email, cargo, hospital, departamento, ativo, created_at, updated_at")
        .single();

      if (updateProfileError) {
        return json({ error: updateProfileError.message }, 400);
      }

      return json({
        success: true,
        account: updatedProfile,
        profile: updatedProfile,
      });
    }

    if (action === "set-active") {
      const authUserId = String(body.auth_user_id ?? "").trim();
      const ativo = body.ativo;

      if (!authUserId) {
        return json({ error: "auth_user_id em falta." }, 400);
      }

      if (typeof ativo !== "boolean") {
        return json({ error: "O campo ativo deve ser true ou false." }, 400);
      }

      if (authUserId === user.id && ativo === false) {
        return json({ error: "Não podes desativar a tua própria conta." }, 400);
      }

      const { data: updatedProfile, error: activeError } = await adminClient
        .from("app_users")
        .update({ ativo })
        .eq("auth_user_id", authUserId)
        .select("id, auth_user_id, nome, email, cargo, hospital, departamento, ativo, created_at, updated_at")
        .single();

      if (activeError) {
        return json({ error: activeError.message }, 400);
      }

      return json({
        success: true,
        account: updatedProfile,
        profile: updatedProfile,
      });
    }

    return json({ error: `Ação desconhecida: ${action}` }, 400);
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
