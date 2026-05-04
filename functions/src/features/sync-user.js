const {resolveAuthContext, resolveFullName, resolveRole, resolveRoleFromAuthToken} = require("../shared/auth");
const {withClient} = require("../shared/callable");

async function syncUserCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError(
        "unauthenticated",
        "Bu islem icin giris yapmalisiniz.",
    );
  }

  const firebaseUid = resolvedAuth.uid;
  const email = resolvedAuth.token?.email;
  if (typeof email !== "string" || !email.trim()) {
    throw createError(
        "failed-precondition",
        "Kullanici e-postasi bulunamadi.",
    );
  }

  const normalizedEmail = email.trim().toLowerCase();
  const fullName = resolveFullName(data?.fullName, normalizedEmail);
  const requestedRole = data?.role;
  const roleFromToken = resolveRoleFromAuthToken(resolvedAuth.token);
  const roleFromRequest = requestedRole ? resolveRole(requestedRole) : null;
  const role = roleFromRequest || roleFromToken || null;

  return withClient(
      {createError, actionLabel: "Kullanici senkronizasyonu"},
      async (client) => {
        const result = await client.query(
            `
              INSERT INTO app_users (firebase_uid, email, full_name, role)
              VALUES ($1, $2, $3, COALESCE($4::user_role, 'normal_user'::user_role))
              ON CONFLICT (firebase_uid)
              DO UPDATE SET
                email = EXCLUDED.email,
                full_name = EXCLUDED.full_name,
                role = CASE
                  WHEN $4::user_role IS NULL THEN app_users.role
                  ELSE $4::user_role
                END,
                updated_at = now()
              RETURNING id, email, full_name, role
            `,
            [firebaseUid, normalizedEmail, fullName, role],
        );

        const user = result.rows[0];
        return {
          ok: true,
          userId: user.id,
          email: user.email,
          fullName: user.full_name,
          role: user.role,
        };
      },
  );
}

module.exports = {
  syncUserCore,
};
