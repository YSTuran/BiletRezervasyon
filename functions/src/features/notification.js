const {resolveAuthContext} = require("../shared/auth");
const {withClient, withTransaction} = require("../shared/callable");
const {loadRequiredAppUser} = require("../shared/access");
const {normalizeTrimmedString} = require("../shared/parsers");
const {serializeNotificationRow} = require("../shared/serializers");

async function listNotificationsCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  return withClient(
      {createError, actionLabel: "Bildirim listeleme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        const result = await client.query(
            `
              SELECT
                id,
                user_id,
                title,
                body,
                category,
                related_trip_id,
                related_reservation_id,
                related_payment_id,
                read_at,
                created_at
              FROM user_notifications
              WHERE user_id = $1
              ORDER BY created_at DESC
              LIMIT 50
            `,
            [appUser.id],
        );
        const unreadResult = await client.query(
            `
              SELECT COUNT(*)::int AS unread_count
              FROM user_notifications
              WHERE user_id = $1
                AND read_at IS NULL
            `,
            [appUser.id],
        );

        return {
          notifications: result.rows.map(serializeNotificationRow),
          unreadCount: Number(unreadResult.rows[0]?.unread_count || 0),
        };
      },
  );
}

async function markNotificationReadCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const notificationId = normalizeTrimmedString(data?.notificationId);
  if (!notificationId) {
    throw createError("invalid-argument", "notificationId zorunludur.");
  }

  return withClient(
      {createError, actionLabel: "Bildirim okundu işaretleme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        const result = await client.query(
            `
              UPDATE user_notifications
              SET read_at = COALESCE(read_at, now())
              WHERE id = $1
                AND user_id = $2
              RETURNING
                id,
                user_id,
                title,
                body,
                category,
                related_trip_id,
                related_reservation_id,
                related_payment_id,
                read_at,
                created_at
            `,
            [notificationId, appUser.id],
        );

        if (result.rows.length === 0) {
          throw createError("not-found", "Bildirim bulunamadı.");
        }

        return {
          notification: serializeNotificationRow(result.rows[0]),
        };
      },
  );
}

async function markAllNotificationsReadCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  return withClient(
      {createError, actionLabel: "Tüm bildirimleri okundu işaretleme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        const result = await withTransaction(client, async () => {
          await client.query(
              `
                UPDATE user_notifications
                SET read_at = COALESCE(read_at, now())
                WHERE user_id = $1
                  AND read_at IS NULL
              `,
              [appUser.id],
          );
          return client.query(
              `
                SELECT
                  id,
                  user_id,
                  title,
                  body,
                  category,
                  related_trip_id,
                  related_reservation_id,
                  related_payment_id,
                  read_at,
                  created_at
                FROM user_notifications
                WHERE user_id = $1
                ORDER BY created_at DESC
                LIMIT 50
              `,
              [appUser.id],
          );
        });

        return {
          notifications: result.rows.map(serializeNotificationRow),
          unreadCount: 0,
        };
      },
  );
}

module.exports = {
  listNotificationsCore,
  markAllNotificationsReadCore,
  markNotificationReadCore,
};
