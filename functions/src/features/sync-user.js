const {resolveAuthContext, resolveFullName, resolveRoleFromAuthToken} = require("../shared/auth");
const {withClient} = require("../shared/callable");
const {
  resolveRequestedSelfServiceRole,
  resolveUserRoleForSync,
} = require("../shared/user-role-policy");

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

  return withClient(
      {createError, actionLabel: "Kullanici senkronizasyonu"},
      async (client) => {
        const existingUserResult = await client.query(
            `
              SELECT id, role
              FROM app_users
              WHERE firebase_uid = $1
              LIMIT 1
            `,
            [firebaseUid],
        );
        const existingUser = existingUserResult.rows[0] ?? null;
        const roleFromToken = resolveRoleFromAuthToken(resolvedAuth.token);
        const requestedSelfServiceRole = resolveRequestedSelfServiceRole(
            roleFromToken ? null : data?.role,
            createError,
        );
        const role = resolveUserRoleForSync({
          existingRole: existingUser?.role,
          roleFromToken,
          requestedSelfServiceRole,
        });

        const result = await client.query(
            `
              INSERT INTO app_users (firebase_uid, email, full_name, role)
              VALUES ($1, $2, $3, $4::user_role)
              ON CONFLICT (firebase_uid)
              DO UPDATE SET
                email = EXCLUDED.email,
                full_name = EXCLUDED.full_name,
                role = $4::user_role,
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
