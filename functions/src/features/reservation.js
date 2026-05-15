const {randomUUID} = require("node:crypto");

const {resolveAuthContext} = require("../shared/auth");
const {withClient, withTransaction} = require("../shared/callable");
const {
  assertAllowedRoles,
  ensurePendingPaymentForReservation,
  expireOverdueReservations,
  loadAccessibleReservationRow,
  loadAccessibleTripRow,
  loadRequiredAppUser,
} = require("../shared/access");
const {
  ACTIVE_RESERVATION_STATUSES_SQL,
  normalizeTrimmedString,
  parseReservationStatus,
} = require("../shared/parsers");
const {serializeReservationRow} = require("../shared/serializers");
const {
  buildReservationSelectClause,
  quoteIdentifier,
  resolveTripTransportTypeColumn,
} = require("../shared/postgres");

async function listReservationsCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  return withClient(
      {createError, actionLabel: "Rezervasyon listeleme"},
      async (client) => {
        await expireOverdueReservations(client);
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        const transportTypeColumn = await resolveTripTransportTypeColumn(
            client,
            createError,
        );
        const selectClause = buildReservationSelectClause(
            `t.${quoteIdentifier(transportTypeColumn)}`,
        );

        let result;
        if (appUser.role === "admin") {
          result = await client.query(
              `
                SELECT ${selectClause}
                FROM reservations r
                INNER JOIN trip_seats ts
                  ON ts.id = r.trip_seat_id
                 AND ts.trip_id = r.trip_id
                INNER JOIN trips t ON t.id = r.trip_id
                INNER JOIN companies c ON c.id = t.company_id
                ORDER BY r.requested_at DESC
              `,
          );
        } else if (appUser.role === "company_officer") {
          result = await client.query(
              `
                SELECT ${selectClause}
                FROM reservations r
                INNER JOIN trip_seats ts
                  ON ts.id = r.trip_seat_id
                 AND ts.trip_id = r.trip_id
                INNER JOIN trips t ON t.id = r.trip_id
                INNER JOIN companies c ON c.id = t.company_id
                WHERE c.officer_user_id = $1
                ORDER BY
                  CASE
                    WHEN r.status = 'pending_approval'::reservation_status THEN 0
                    WHEN r.status = 'approved'::reservation_status THEN 1
                    WHEN r.status = 'paid'::reservation_status THEN 2
                    ELSE 3
                  END,
                  r.requested_at DESC
              `,
              [appUser.id],
          );
        } else {
          result = await client.query(
              `
                SELECT ${selectClause}
                FROM reservations r
                INNER JOIN trip_seats ts
                  ON ts.id = r.trip_seat_id
                 AND ts.trip_id = r.trip_id
                INNER JOIN trips t ON t.id = r.trip_id
                INNER JOIN companies c ON c.id = t.company_id
                WHERE r.user_id = $1
                ORDER BY r.requested_at DESC
              `,
              [appUser.id],
          );
        }

        return {
          reservations: result.rows.map(serializeReservationRow),
        };
      },
  );
}

async function getTripReservationAvailabilityCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const tripId = normalizeTrimmedString(data?.tripId);
  if (!tripId) {
    throw createError("invalid-argument", "tripId zorunludur.");
  }

  return withClient(
      {createError, actionLabel: "Rezervasyon uygunlugu getirme"},
      async (client) => {
        await expireOverdueReservations(client);
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        const trip = await loadAccessibleTripRow(
            client,
            appUser,
            tripId,
            createError,
        );
        if (!trip) {
          throw createError("not-found", "Sefer bulunamadi.");
        }

        const transportTypeColumn = await resolveTripTransportTypeColumn(
            client,
            createError,
        );
        const result = await client.query(
            `
              SELECT ${buildReservationSelectClause(`t.${quoteIdentifier(transportTypeColumn)}`)}
              FROM reservations r
              INNER JOIN trip_seats ts
                ON ts.id = r.trip_seat_id
               AND ts.trip_id = r.trip_id
              INNER JOIN trips t ON t.id = r.trip_id
              INNER JOIN companies c ON c.id = t.company_id
              WHERE r.trip_id = $1
                AND r.status = ANY(${ACTIVE_RESERVATION_STATUSES_SQL})
              ORDER BY r.requested_at DESC
            `,
            [tripId],
        );

        const reservations = result.rows.map(serializeReservationRow);
        const blockedSeatIds = [
          ...new Set(
              reservations
                  .map((reservation) => reservation.trip_seat_id)
                  .filter(Boolean),
          ),
        ];
        const currentUserReservation = reservations.find(
            (reservation) => reservation.user_id === appUser.id,
        ) || null;

        return {
          blockedSeatIds,
          currentUserReservation,
        };
      },
  );
}

async function createReservationCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const tripId = normalizeTrimmedString(data?.tripId);
  const tripSeatId = normalizeTrimmedString(data?.tripSeatId);
  if (!tripId || !tripSeatId) {
    throw createError(
        "invalid-argument",
        "tripId ve tripSeatId zorunludur.",
    );
  }

  return withClient(
      {createError, actionLabel: "Rezervasyon oluşturma"},
      async (client) => {
        await expireOverdueReservations(client);
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["normal_user"], createError);

        const trip = await loadAccessibleTripRow(
            client,
            appUser,
            tripId,
            createError,
        );
        if (!trip) {
          throw createError("not-found", "Sefer bulunamadi.");
        }
        if (new Date(trip.departure_at).getTime() <= Date.now()) {
          throw createError(
              "failed-precondition",
              "Kalkışı geçmiş seferler için rezervasyon yapılamaz.",
          );
        }

        const seatResult = await client.query(
            `
              SELECT id, trip_id
              FROM trip_seats
              WHERE id = $1
                AND trip_id = $2
              LIMIT 1
            `,
            [tripSeatId, tripId],
        );
        if (seatResult.rows.length === 0) {
          throw createError("not-found", "Seçilen koltuk bulunamadı.");
        }

        const existingReservation = await client.query(
            `
              SELECT id
              FROM reservations
              WHERE trip_id = $1
                AND user_id = $2
                AND status = ANY(${ACTIVE_RESERVATION_STATUSES_SQL})
              LIMIT 1
            `,
            [tripId, appUser.id],
        );
        if (existingReservation.rows.length > 0) {
          throw createError(
              "failed-precondition",
              "Bu sefer için zaten aktif bir rezervasyonunuz bulunuyor.",
          );
        }

        const reservationId = randomUUID();
        try {
          await withTransaction(client, async () => {
            await client.query(
                `
                  INSERT INTO reservations (
                    id,
                    trip_id,
                    trip_seat_id,
                    user_id,
                    status,
                    requested_at,
                    payment_deadline_at,
                    created_at,
                    updated_at
                  )
                  VALUES (
                    $1,
                    $2,
                    $3,
                    $4,
                    'pending_approval'::reservation_status,
                    now(),
                    now() + interval '1 day',
                    now(),
                    now()
                  )
                `,
                [reservationId, tripId, tripSeatId, appUser.id],
            );
          });
        } catch (error) {
          if (error.code === "23505") {
            throw createError(
                "already-exists",
                "Seçilen koltuk için aktif bir rezervasyon bulunuyor.",
            );
          }
          throw error;
        }

        const reservation = await loadAccessibleReservationRow(
            client,
            appUser,
            reservationId,
            createError,
        );

        return {
          reservation: serializeReservationRow(reservation),
        };
      },
  );
}

async function cancelReservationCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const reservationId = normalizeTrimmedString(data?.reservationId);
  if (!reservationId) {
    throw createError("invalid-argument", "reservationId zorunludur.");
  }

  return withClient(
      {createError, actionLabel: "Rezervasyon iptal etme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["normal_user"], createError);

        const reservation = await loadAccessibleReservationRow(
            client,
            appUser,
            reservationId,
            createError,
        );
        if (!reservation) {
          throw createError("not-found", "Rezervasyon bulunamadi.");
        }
        if (
          reservation.status !== "pending_approval" &&
          reservation.status !== "approved"
        ) {
          throw createError(
              "failed-precondition",
              "Bu rezervasyon artik iptal edilemez.",
          );
        }

        const updatedReservation = await withTransaction(client, async () => {
          const cancellationResult = await client.query(
              `
                UPDATE reservations
                SET
                  status = 'cancelled_by_user'::reservation_status,
                  cancelled_at = now(),
                  updated_at = now()
                WHERE id = $1
                  AND user_id = $2
                  AND status = ANY(
                    ARRAY[
                      'pending_approval'::reservation_status,
                      'approved'::reservation_status
                    ]
                  )
              `,
              [reservationId, appUser.id],
          );
          if (cancellationResult.rowCount === 0) {
            throw createError(
                "failed-precondition",
                "Rezervasyon durumu değiştiği için iptal edilemedi.",
            );
          }

          await client.query(
              `
                UPDATE payments
                SET
                  status = 'failed'::payment_status,
                  updated_at = now()
                WHERE reservation_id = $1
                  AND status = 'pending'::payment_status
              `,
              [reservationId],
          );

          return loadAccessibleReservationRow(
              client,
              appUser,
              reservationId,
              createError,
          );
        });

        return {
          reservation: serializeReservationRow(updatedReservation),
        };
      },
  );
}

async function reviewReservationCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const reservationId = normalizeTrimmedString(data?.reservationId);
  if (!reservationId) {
    throw createError("invalid-argument", "reservationId zorunludur.");
  }

  const status = parseReservationStatus(data?.status, createError);
  if (status !== "approved" && status !== "rejected") {
    throw createError(
        "invalid-argument",
        "Rezervasyon yalnizca approved veya rejected olarak sonuclandirilebilir.",
    );
  }

  const rejectionReason = normalizeTrimmedString(data?.rejectionReason);
  if (status === "rejected" && !rejectionReason) {
    throw createError("invalid-argument", "Red nedeni zorunludur.");
  }

  return withClient(
      {createError, actionLabel: "Rezervasyon inceleme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["company_officer"], createError);

        const reservation = await loadAccessibleReservationRow(
            client,
            appUser,
            reservationId,
            createError,
        );
        if (!reservation) {
          throw createError("not-found", "Rezervasyon bulunamadi.");
        }
        if (reservation.status !== "pending_approval") {
          throw createError(
              "failed-precondition",
              "Yalnızca bekleyen rezervasyonlar işleme alınabilir.",
          );
        }

        const updatedReservation = await withTransaction(client, async () => {
          await client.query(
              `
                UPDATE reservations
                SET
                  status = $2::reservation_status,
                  payment_deadline_at = CASE
                    WHEN $2::reservation_status = 'approved'::reservation_status
                      THEN now() + interval '30 minutes'
                    ELSE payment_deadline_at
                  END,
                  rejection_reason = CASE
                    WHEN $2::reservation_status = 'rejected'::reservation_status THEN $3
                    ELSE NULL
                  END,
                  updated_at = now()
                WHERE id = $1
                  AND status = 'pending_approval'::reservation_status
              `,
              [reservationId, status, rejectionReason || null],
          );

          if (status === "approved") {
            await ensurePendingPaymentForReservation(client, reservationId);
          }

          return loadAccessibleReservationRow(
              client,
              appUser,
              reservationId,
              createError,
          );
        });

        return {
          reservation: serializeReservationRow(updatedReservation),
        };
      },
  );
}

module.exports = {
  cancelReservationCore,
  createReservationCore,
  getTripReservationAvailabilityCore,
  listReservationsCore,
  reviewReservationCore,
};
