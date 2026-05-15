const {randomUUID} = require("node:crypto");

async function createNotification(
    client,
    {
      userId,
      title,
      body,
      category = "general",
      relatedTripId = null,
      relatedReservationId = null,
      relatedPaymentId = null,
    },
) {
  if (!userId || !title || !body) {
    return null;
  }

  const id = randomUUID();
  await client.query(
      `
        INSERT INTO user_notifications (
          id,
          user_id,
          title,
          body,
          category,
          related_trip_id,
          related_reservation_id,
          related_payment_id,
          created_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
      `,
      [
        id,
        userId,
        title,
        body,
        category,
        relatedTripId,
        relatedReservationId,
        relatedPaymentId,
      ],
  );
  return id;
}

async function createNotifications(client, notifications) {
  for (const notification of notifications) {
    await createNotification(client, notification);
  }
}

module.exports = {
  createNotification,
  createNotifications,
};
