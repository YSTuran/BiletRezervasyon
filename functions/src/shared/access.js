const {randomUUID} = require("node:crypto");

const {
  buildCompanySelectClause,
  buildPaymentSelectClause,
  buildReservationSelectClause,
  buildTripSelectClause,
  quoteIdentifier,
  resolveCompanyTransportTypeColumn,
  resolveTripTransportTypeColumn,
} = require("./postgres");

async function loadRequiredAppUser(client, resolvedAuth, createError) {
  const result = await client.query(
      `
        SELECT id, email, full_name, role
        FROM app_users
        WHERE firebase_uid = $1
        LIMIT 1
      `,
      [resolvedAuth.uid],
  );

  if (result.rows.length === 0) {
    throw createError(
        "failed-precondition",
        "app_users kaydi bulunamadi. Once kullanici senkronizasyonunu tamamlayin.",
    );
  }

  return result.rows[0];
}

function assertAllowedRoles(appUser, allowedRoles, createError) {
  if (!allowedRoles.includes(appUser.role)) {
    throw createError(
        "permission-denied",
        "Bu islem icin yeterli yetkiniz bulunmuyor.",
    );
  }
}

async function findCompanyByOfficerUserId(client, officerUserId, createError) {
  const transportTypeColumn = await resolveCompanyTransportTypeColumn(
      client,
      createError,
  );
  const result = await client.query(
      `
        SELECT
          ${buildCompanySelectClause(quoteIdentifier(transportTypeColumn))}
        FROM companies
        WHERE officer_user_id = $1
        ORDER BY created_at DESC
        LIMIT 1
      `,
      [officerUserId],
  );

  return result.rows[0] ?? null;
}

async function loadAccessibleTripRow(client, appUser, tripId, createError) {
  const transportTypeColumn = await resolveTripTransportTypeColumn(
      client,
      createError,
  );

  if (appUser.role === "admin") {
    const result = await client.query(
        `
          SELECT ${buildTripSelectClause(quoteIdentifier(transportTypeColumn))}
          FROM trips
          WHERE id = $1
          LIMIT 1
        `,
        [tripId],
    );
    return result.rows[0] ?? null;
  }

  if (appUser.role === "company_officer") {
    const result = await client.query(
        `
          SELECT ${buildTripSelectClause(`t.${quoteIdentifier(transportTypeColumn)}`, "t")}
          FROM trips t
          INNER JOIN companies c ON c.id = t.company_id
          WHERE t.id = $1
            AND c.officer_user_id = $2
          LIMIT 1
        `,
        [tripId, appUser.id],
    );
    return result.rows[0] ?? null;
  }

  const result = await client.query(
      `
        SELECT ${buildTripSelectClause(quoteIdentifier(transportTypeColumn))}
        FROM trips
        WHERE id = $1
          AND status = 'approved'
        LIMIT 1
      `,
      [tripId],
  );
  return result.rows[0] ?? null;
}

async function loadAccessibleReservationRow(
    client,
    appUser,
    reservationId,
    createError,
) {
  const transportTypeColumn = await resolveTripTransportTypeColumn(
      client,
      createError,
  );
  const selectClause = buildReservationSelectClause(
      `t.${quoteIdentifier(transportTypeColumn)}`,
  );

  if (appUser.role === "admin") {
    const result = await client.query(
        `
          SELECT ${selectClause}
          FROM reservations r
          INNER JOIN trip_seats ts
            ON ts.id = r.trip_seat_id
           AND ts.trip_id = r.trip_id
          INNER JOIN trips t ON t.id = r.trip_id
          INNER JOIN companies c ON c.id = t.company_id
          WHERE r.id = $1
          LIMIT 1
        `,
        [reservationId],
    );
    return result.rows[0] ?? null;
  }

  if (appUser.role === "company_officer") {
    const result = await client.query(
        `
          SELECT ${selectClause}
          FROM reservations r
          INNER JOIN trip_seats ts
            ON ts.id = r.trip_seat_id
           AND ts.trip_id = r.trip_id
          INNER JOIN trips t ON t.id = r.trip_id
          INNER JOIN companies c ON c.id = t.company_id
          WHERE r.id = $1
            AND c.officer_user_id = $2
          LIMIT 1
        `,
        [reservationId, appUser.id],
    );
    return result.rows[0] ?? null;
  }

  const result = await client.query(
      `
        SELECT ${selectClause}
        FROM reservations r
        INNER JOIN trip_seats ts
          ON ts.id = r.trip_seat_id
         AND ts.trip_id = r.trip_id
        INNER JOIN trips t ON t.id = r.trip_id
        INNER JOIN companies c ON c.id = t.company_id
        WHERE r.id = $1
          AND r.user_id = $2
        LIMIT 1
      `,
      [reservationId, appUser.id],
  );
  return result.rows[0] ?? null;
}

async function expireOverdueReservations(client) {
  await client.query(
      `
        UPDATE reservations r
        SET
          status = 'expired'::reservation_status,
          updated_at = now()
        WHERE r.status = 'approved'::reservation_status
          AND r.payment_deadline_at < now()
          AND NOT EXISTS (
            SELECT 1
            FROM payments p
            WHERE p.reservation_id = r.id
              AND p.status = 'paid'::payment_status
          )
      `,
  );

  await client.query(
      `
        UPDATE payments p
        SET
          status = 'failed'::payment_status,
          updated_at = now()
        WHERE p.status = 'pending'::payment_status
          AND EXISTS (
            SELECT 1
            FROM reservations r
            WHERE r.id = p.reservation_id
              AND r.status = 'expired'::reservation_status
          )
      `,
  );
}

async function ensurePendingPaymentForReservation(client, reservationId) {
  const existingPaymentResult = await client.query(
      `
        SELECT id
        FROM payments
        WHERE reservation_id = $1
        ORDER BY created_at DESC
        LIMIT 1
      `,
      [reservationId],
  );
  if (existingPaymentResult.rows.length > 0) {
    return existingPaymentResult.rows[0].id;
  }

  const reservationResult = await client.query(
      `
        SELECT r.id, t.price_minor
        FROM reservations r
        INNER JOIN trips t ON t.id = r.trip_id
        WHERE r.id = $1
          AND r.status = 'approved'::reservation_status
        LIMIT 1
      `,
      [reservationId],
  );
  if (reservationResult.rows.length === 0) {
    return null;
  }

  const row = reservationResult.rows[0];
  const paymentId = randomUUID();
  await client.query(
      `
        INSERT INTO payments (
          id,
          reservation_id,
          amount_minor,
          status,
          provider,
          created_at,
          updated_at,
          paid_at
        )
        VALUES (
          $1,
          $2,
          $3,
          'pending'::payment_status,
          'fake_gateway',
          now(),
          now(),
          NULL
        )
      `,
      [paymentId, row.id, row.price_minor],
  );
  return paymentId;
}

async function loadAccessiblePaymentRowByReservationId(
    client,
    appUser,
    reservationId,
    createError,
) {
  const transportTypeColumn = await resolveTripTransportTypeColumn(
      client,
      createError,
  );
  const selectClause = buildPaymentSelectClause(
      `t.${quoteIdentifier(transportTypeColumn)}`,
  );

  if (appUser.role === "admin") {
    const result = await client.query(
        `
          SELECT ${selectClause}
          FROM payments p
          INNER JOIN reservations r ON r.id = p.reservation_id
          INNER JOIN trip_seats ts
            ON ts.id = r.trip_seat_id
           AND ts.trip_id = r.trip_id
          INNER JOIN trips t ON t.id = r.trip_id
          INNER JOIN companies c ON c.id = t.company_id
          WHERE p.reservation_id = $1
          ORDER BY p.created_at DESC
          LIMIT 1
        `,
        [reservationId],
    );
    return result.rows[0] ?? null;
  }

  if (appUser.role === "company_officer") {
    const result = await client.query(
        `
          SELECT ${selectClause}
          FROM payments p
          INNER JOIN reservations r ON r.id = p.reservation_id
          INNER JOIN trip_seats ts
            ON ts.id = r.trip_seat_id
           AND ts.trip_id = r.trip_id
          INNER JOIN trips t ON t.id = r.trip_id
          INNER JOIN companies c ON c.id = t.company_id
          WHERE p.reservation_id = $1
            AND c.officer_user_id = $2
          ORDER BY p.created_at DESC
          LIMIT 1
        `,
        [reservationId, appUser.id],
    );
    return result.rows[0] ?? null;
  }

  const result = await client.query(
      `
        SELECT ${selectClause}
        FROM payments p
        INNER JOIN reservations r ON r.id = p.reservation_id
        INNER JOIN trip_seats ts
          ON ts.id = r.trip_seat_id
         AND ts.trip_id = r.trip_id
        INNER JOIN trips t ON t.id = r.trip_id
        INNER JOIN companies c ON c.id = t.company_id
        WHERE p.reservation_id = $1
          AND r.user_id = $2
        ORDER BY p.created_at DESC
        LIMIT 1
      `,
      [reservationId, appUser.id],
  );
  return result.rows[0] ?? null;
}

module.exports = {
  assertAllowedRoles,
  ensurePendingPaymentForReservation,
  expireOverdueReservations,
  findCompanyByOfficerUserId,
  loadAccessiblePaymentRowByReservationId,
  loadAccessibleReservationRow,
  loadAccessibleTripRow,
  loadRequiredAppUser,
};
