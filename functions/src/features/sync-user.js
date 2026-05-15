const {resolveAuthContext, resolveFullName, resolveRoleFromAuthToken} = require("../shared/auth");
const {admin} = require("../config/runtime");
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
        "Bu işlem için giriş yapmalısınız.",
    );
  }

  const firebaseUid = resolvedAuth.uid;
  const email = resolvedAuth.token?.email;
  if (typeof email !== "string" || !email.trim()) {
    throw createError(
        "failed-precondition",
        "Kullanıcı e-postası bulunamadı.",
    );
  }

  const normalizedEmail = email.trim().toLowerCase();
  const fullName = resolveFullName(data?.fullName, normalizedEmail);

  return withClient(
      {createError, actionLabel: "Kullanıcı senkronizasyonu"},
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

async function deleteMyAccountCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError(
        "unauthenticated",
        "Bu işlem için giriş yapmalısınız.",
    );
  }

  const firebaseUid = resolvedAuth.uid;

  await withClient(
      {createError, actionLabel: "Hesap silme"},
      async (client) => {
        const userResult = await client.query(
            `
              SELECT role
              FROM app_users
              WHERE firebase_uid = $1
              LIMIT 1
            `,
            [firebaseUid],
        );
        if (userResult.rows[0]?.role === "admin") {
          throw createError("permission-denied", "Admin hesabı silinemez.");
        }

        await client.query(
            `
              UPDATE app_users
              SET
                firebase_uid = CONCAT('deleted:', firebase_uid, ':', id::text),
                email = CONCAT('deleted-', id::text, '@deleted.local'),
                full_name = 'Silinmiş Kullanıcı',
                updated_at = now()
              WHERE firebase_uid = $1
            `,
            [firebaseUid],
        );
      },
  );

  try {
    await admin.auth().deleteUser(firebaseUid);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") {
      throw createError(
          "internal",
          "Firebase hesabı silinemedi. Lütfen daha sonra tekrar deneyin.",
      );
    }
  }

  return {ok: true};
}

module.exports = {
  deleteMyAccountCore,
  syncUserCore,
};
