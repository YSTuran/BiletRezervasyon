const {randomUUID} = require("node:crypto");

const {resolveAuthContext} = require("../shared/auth");
const {withClient, withTransaction} = require("../shared/callable");
const {
  assertAllowedRoles,
  ensurePendingPaymentForReservation,
  expireOverdueReservations,
  loadAccessiblePaymentRowByReservationId,
  loadAccessibleReservationRow,
  loadRequiredAppUser,
} = require("../shared/access");
const {
  normalizeTrimmedString,
  parseRefundRequestStatus,
} = require("../shared/parsers");
const {serializePaymentRow} = require("../shared/serializers");
const {
  buildPaymentSelectClause,
  quoteIdentifier,
  resolveTripTransportTypeColumn,
} = require("../shared/postgres");
const {createNotification} = require("../shared/notifications");
const {evaluateRefundPolicy} = require("../shared/refund-policy");

function serializePaymentForClient(row, actionAt = new Date()) {
  if (!row) {
    return null;
  }

  const canEvaluateRefund =
    row.trip_departure_at &&
    (row.status === "paid" || row.status === "refunded");

  let refundAmountMinor = null;
  let refundSummary = null;
  let canRequestRefund = false;

  if (canEvaluateRefund) {
    const refundPolicy = evaluateRefundPolicy({
      amountMinor: row.amount_minor,
      departureAt: row.trip_departure_at,
      actionAt: row.reservation_cancelled_at || actionAt,
    });
    refundAmountMinor = refundPolicy.refundAmountMinor;
    refundSummary = refundPolicy.refundSummary;
    canRequestRefund =
      row.status === "paid" &&
      row.reservation_status === "paid" &&
      refundPolicy.isEligible &&
      row.refund_request_status !== "pending" &&
      row.refund_request_status !== "approved";
  }

  return serializePaymentRow({
    ...row,
    refund_amount_minor: refundAmountMinor,
    can_request_refund: canRequestRefund,
    refund_summary: refundSummary,
  });
}

async function listPaymentsCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  return withClient(
      {createError, actionLabel: "Ödeme listeleme"},
      async (client) => {
        await expireOverdueReservations(client);
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        const transportTypeColumn = await resolveTripTransportTypeColumn(
            client,
            createError,
        );
        const selectClause = buildPaymentSelectClause(
            `t.${quoteIdentifier(transportTypeColumn)}`,
        );

        let result;
        if (appUser.role === "admin") {
          result = await client.query(
              `
                SELECT ${selectClause}
                FROM payments p
                INNER JOIN reservations r ON r.id = p.reservation_id
                INNER JOIN trip_seats ts
                  ON ts.id = r.trip_seat_id
                 AND ts.trip_id = r.trip_id
                INNER JOIN trips t ON t.id = r.trip_id
                INNER JOIN companies c ON c.id = t.company_id
                ORDER BY p.created_at DESC
              `,
          );
        } else if (appUser.role === "company_officer") {
          result = await client.query(
              `
                SELECT ${selectClause}
                FROM payments p
                INNER JOIN reservations r ON r.id = p.reservation_id
                INNER JOIN trip_seats ts
                  ON ts.id = r.trip_seat_id
                 AND ts.trip_id = r.trip_id
                INNER JOIN trips t ON t.id = r.trip_id
                INNER JOIN companies c ON c.id = t.company_id
                WHERE c.officer_user_id = $1
                ORDER BY p.created_at DESC
              `,
              [appUser.id],
          );
        } else {
          result = await client.query(
              `
                SELECT ${selectClause}
                FROM payments p
                INNER JOIN reservations r ON r.id = p.reservation_id
                INNER JOIN trip_seats ts
                  ON ts.id = r.trip_seat_id
                 AND ts.trip_id = r.trip_id
                INNER JOIN trips t ON t.id = r.trip_id
                INNER JOIN companies c ON c.id = t.company_id
                WHERE r.user_id = $1
                ORDER BY p.created_at DESC
              `,
              [appUser.id],
          );
        }

        return {
          payments: result.rows.map((row) => serializePaymentForClient(row)),
        };
      },
  );
}

async function getReservationPaymentCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const reservationId = normalizeTrimmedString(data?.reservationId);
  if (!reservationId) {
    throw createError("invalid-argument", "reservationId zorunludur.");
  }

  return withClient(
      {createError, actionLabel: "Ödeme bilgisi getirme"},
      async (client) => {
        await expireOverdueReservations(client);
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        const reservation = await loadAccessibleReservationRow(
            client,
            appUser,
            reservationId,
            createError,
        );
        if (!reservation) {
          throw createError("not-found", "Rezervasyon bulunamadı.");
        }

        if (reservation.status === "approved") {
          await ensurePendingPaymentForReservation(client, reservationId);
        }

        const payment = await loadAccessiblePaymentRowByReservationId(
            client,
            appUser,
            reservationId,
            createError,
        );

        return {
          payment: serializePaymentForClient(payment),
        };
      },
  );
}

async function processFakePaymentCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const reservationId = normalizeTrimmedString(data?.reservationId);
  if (!reservationId) {
    throw createError("invalid-argument", "reservationId zorunludur.");
  }

  const cardHolderName = normalizeTrimmedString(data?.cardHolderName);
  const cardNumber = normalizeTrimmedString(data?.cardNumber).replace(/\s+/g, "");
  const expiryMonth = normalizeTrimmedString(data?.expiryMonth);
  const expiryYear = normalizeTrimmedString(data?.expiryYear);
  const cvv = normalizeTrimmedString(data?.cvv);

  if (!cardHolderName) {
    throw createError("invalid-argument", "Kart sahibi adi zorunludur.");
  }
  if (!/^\d{16}$/.test(cardNumber)) {
    throw createError("invalid-argument", "Kart numarası 16 haneli olmalıdır.");
  }
  if (!/^\d{2}$/.test(expiryMonth)) {
    throw createError("invalid-argument", "Ay bilgisi MM formatında olmalıdır.");
  }
  const parsedMonth = Number.parseInt(expiryMonth, 10);
  if (parsedMonth < 1 || parsedMonth > 12) {
    throw createError("invalid-argument", "Ay bilgisi 01-12 arasında olmalıdır.");
  }
  if (!/^\d{2,4}$/.test(expiryYear)) {
    throw createError("invalid-argument", "Yıl bilgisi geçersiz.");
  }
  const parsedYear = Number.parseInt(expiryYear, 10);
  const normalizedYear = expiryYear.length === 2 ? 2000 + parsedYear : parsedYear;
  const currentMonthStart = new Date();
  currentMonthStart.setUTCDate(1);
  currentMonthStart.setUTCHours(0, 0, 0, 0);
  const expiryBoundary = new Date(Date.UTC(normalizedYear, parsedMonth, 1));
  if (expiryBoundary.getTime() <= currentMonthStart.getTime()) {
    throw createError("invalid-argument", "Kart son kullanma tarihi gecmis.");
  }
  if (!/^\d{3,4}$/.test(cvv)) {
    throw createError("invalid-argument", "CVV 3 veya 4 haneli olmalıdır.");
  }

  return withClient(
      {createError, actionLabel: "Sahte ödeme işleme"},
      async (client) => {
        await expireOverdueReservations(client);
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["normal_user"], createError);

        const reservation = await loadAccessibleReservationRow(
            client,
            appUser,
            reservationId,
            createError,
        );
        if (!reservation) {
          throw createError("not-found", "Rezervasyon bulunamadı.");
        }
        if (reservation.status === "paid") {
          throw createError("failed-precondition", "Bu rezervasyon zaten odendi.");
        }
        if (reservation.status === "expired") {
          throw createError(
              "failed-precondition",
              "Ödeme süresi dolan rezervasyonlar için ödeme yapılamaz.",
          );
        }
        if (reservation.status !== "approved") {
          throw createError(
              "failed-precondition",
              "Ödeme yalnızca onaylanmış rezervasyonlar için yapılabilir.",
          );
        }

        await ensurePendingPaymentForReservation(client, reservationId);
        const payment = await loadAccessiblePaymentRowByReservationId(
            client,
            appUser,
            reservationId,
            createError,
        );
        if (!payment) {
          throw createError("not-found", "Ödeme kaydı bulunamadı.");
        }
        if (payment.status === "paid") {
          throw createError("failed-precondition", "Bu ödeme zaten tamamlandı.");
        }

        const isFailedCard = cardNumber === "4000000000000002";
        const updatedPayment = await withTransaction(client, async () => {
          if (isFailedCard) {
            await client.query(
                `
                  UPDATE payments
                  SET
                    status = 'failed'::payment_status,
                    provider = 'fake_gateway',
                    paid_at = NULL,
                    updated_at = now()
                  WHERE id = $1
                `,
                [payment.id],
            );
          } else {
            await client.query(
                `
                  UPDATE payments
                  SET
                    status = 'paid'::payment_status,
                    provider = 'fake_gateway',
                    paid_at = now(),
                    updated_at = now()
                  WHERE id = $1
                `,
                [payment.id],
            );
            await client.query(
                `
                  UPDATE reservations
                  SET
                    status = 'paid'::reservation_status,
                    paid_at = now(),
                    updated_at = now()
                  WHERE id = $1
                `,
                [reservationId],
            );
          }

          return loadAccessiblePaymentRowByReservationId(
              client,
              appUser,
              reservationId,
              createError,
          );
        });

        return {
          payment: serializePaymentForClient(updatedPayment),
          succeeded: !isFailedCard,
        };
      },
  );
}

async function requestRefundCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const reservationId = normalizeTrimmedString(data?.reservationId);
  if (!reservationId) {
    throw createError("invalid-argument", "reservationId zorunludur.");
  }
  const reason = normalizeTrimmedString(data?.reason);

  return withClient(
      {createError, actionLabel: "İade talebi"},
      async (client) => {
        await expireOverdueReservations(client);
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["normal_user"], createError);

        const reservation = await loadAccessibleReservationRow(
            client,
            appUser,
            reservationId,
            createError,
        );
        if (!reservation) {
          throw createError("not-found", "Rezervasyon bulunamadı.");
        }
        if (reservation.status !== "paid") {
          throw createError(
              "failed-precondition",
              "İade yalnızca ödenmiş rezervasyonlar için yapılabilir.",
          );
        }

        const payment = await loadAccessiblePaymentRowByReservationId(
            client,
            appUser,
            reservationId,
            createError,
        );
        if (!payment) {
          throw createError("not-found", "Ödeme kaydı bulunamadı.");
        }
        if (payment.status === "refunded") {
          throw createError(
              "failed-precondition",
              "Bu ödeme için iade zaten tamamlanmış.",
          );
        }
        if (payment.status !== "paid") {
          throw createError(
              "failed-precondition",
              "İade yalnızca tamamlanmış ödemeler için yapılabilir.",
          );
        }

        const actionAt = new Date();
        const refundPolicy = evaluateRefundPolicy({
          amountMinor: payment.amount_minor,
          departureAt: payment.trip_departure_at,
          actionAt,
        });
        if (!refundPolicy.isEligible) {
          throw createError("failed-precondition", refundPolicy.refundSummary);
        }

        const updatedPayment = await withTransaction(client, async () => {
          const existingRequestResult = await client.query(
              `
                SELECT id, status
                FROM refund_requests
                WHERE payment_id = $1
                ORDER BY created_at DESC
                LIMIT 1
              `,
              [payment.id],
          );

          if (existingRequestResult.rows[0]?.status === "pending") {
            throw createError(
                "failed-precondition",
                "Bu ödeme için bekleyen bir iade talebi zaten var.",
            );
          }
          if (existingRequestResult.rows[0]?.status === "approved") {
            throw createError(
                "failed-precondition",
                "Bu ödeme için iade zaten onaylanmış.",
            );
          }

          const companyResult = await client.query(
              `
                SELECT
                  c.officer_user_id,
                  t.trip_code,
                  t.origin,
                  t.destination,
                  t.id AS trip_id
                FROM reservations r
                INNER JOIN trips t ON t.id = r.trip_id
                INNER JOIN companies c ON c.id = t.company_id
                WHERE r.id = $1
                LIMIT 1
              `,
              [reservationId],
          );
          const companyRow = companyResult.rows[0];
          const refundRequestId = randomUUID();
          await client.query(
              `
                INSERT INTO refund_requests (
                  id,
                  reservation_id,
                  payment_id,
                  requested_by_user_id,
                  status,
                  reason,
                  refund_amount_minor,
                  refund_summary,
                  requested_at,
                  created_at,
                  updated_at
                )
                VALUES (
                  $1,
                  $2,
                  $3,
                  $4,
                  'pending'::refund_request_status,
                  NULLIF($5, ''),
                  $6,
                  $7,
                  now(),
                  now(),
                  now()
                )
              `,
              [
                refundRequestId,
                reservationId,
                payment.id,
                appUser.id,
                reason,
                refundPolicy.refundAmountMinor,
                refundPolicy.refundSummary,
              ],
          );

          if (companyRow?.officer_user_id) {
            await createNotification(client, {
              userId: companyRow.officer_user_id,
              title: "Yeni iade talebi",
              body:
                `${companyRow.trip_code} kodlu ${companyRow.origin} - ${companyRow.destination} seferi için bir iade talebi var.`,
              category: "refund_requested",
              relatedTripId: companyRow.trip_id,
              relatedReservationId: reservationId,
              relatedPaymentId: payment.id,
            });
          }

          return loadAccessiblePaymentRowByReservationId(
              client,
              appUser,
              reservationId,
              createError,
          );
        });

        return {
          payment: serializePaymentForClient(updatedPayment, actionAt),
          refundAmountMinor: refundPolicy.refundAmountMinor,
          refundSummary: "İade talebiniz firmaya gönderildi.",
        };
      },
  );
}

async function reviewRefundRequestCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const refundRequestId = normalizeTrimmedString(data?.refundRequestId);
  if (!refundRequestId) {
    throw createError("invalid-argument", "refundRequestId zorunludur.");
  }

  const status = parseRefundRequestStatus(data?.status, createError);
  if (status !== "approved" && status !== "rejected") {
    throw createError(
        "invalid-argument",
        "İade talebi yalnızca approved veya rejected olarak sonuçlandırılabilir.",
    );
  }

  const rejectionReason = normalizeTrimmedString(data?.rejectionReason);
  if (status === "rejected" && !rejectionReason) {
    throw createError("invalid-argument", "Red nedeni zorunludur.");
  }

  return withClient(
      {createError, actionLabel: "İade talebi inceleme"},
      async (client) => {
        await expireOverdueReservations(client);
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["company_officer"], createError);

        const updatedPayment = await withTransaction(client, async () => {
          const requestResult = await client.query(
              `
                SELECT
                  rr.id,
                  rr.reservation_id,
                  rr.payment_id,
                  rr.requested_by_user_id,
                  rr.status,
                  rr.refund_amount_minor,
                  rr.refund_summary,
                  t.id AS trip_id,
                  t.trip_code,
                  t.origin,
                  t.destination
                FROM refund_requests rr
                INNER JOIN reservations r ON r.id = rr.reservation_id
                INNER JOIN payments p ON p.id = rr.payment_id
                INNER JOIN trips t ON t.id = r.trip_id
                INNER JOIN companies c ON c.id = t.company_id
                WHERE rr.id = $1
                  AND c.officer_user_id = $2
                FOR UPDATE OF rr, p, r
                LIMIT 1
              `,
              [refundRequestId, appUser.id],
          );

          if (requestResult.rows.length === 0) {
            throw createError("not-found", "İade talebi bulunamadı.");
          }

          const request = requestResult.rows[0];
          if (request.status !== "pending") {
            throw createError(
                "failed-precondition",
                "Yalnızca bekleyen iade talepleri sonuçlandırılabilir.",
            );
          }

          await client.query(
              `
                UPDATE refund_requests
                SET
                  status = $2::refund_request_status,
                  decided_by_officer_id = $3,
                  decided_at = now(),
                  rejection_reason = CASE
                    WHEN $2::refund_request_status = 'rejected'::refund_request_status THEN $4
                    ELSE NULL
                  END,
                  updated_at = now()
                WHERE id = $1
              `,
              [refundRequestId, status, appUser.id, rejectionReason || null],
          );

          if (status === "approved") {
            const paymentUpdateResult = await client.query(
                `
                  UPDATE payments
                  SET
                    status = 'refunded'::payment_status,
                    updated_at = now()
                  WHERE id = $1
                    AND status = 'paid'::payment_status
                `,
                [request.payment_id],
            );
            if (paymentUpdateResult.rowCount === 0) {
              throw createError(
                  "failed-precondition",
                  "Ödeme durumu değiştiği için iade onaylanamadı.",
              );
            }

            await client.query(
                `
                  UPDATE reservations
                  SET
                    status = 'cancelled_by_user'::reservation_status,
                    cancelled_at = now(),
                    updated_at = now()
                  WHERE id = $1
                    AND status = 'paid'::reservation_status
                `,
                [request.reservation_id],
            );

            await createNotification(client, {
              userId: request.requested_by_user_id,
              title: "İade talebiniz onaylandı",
              body:
                `${request.trip_code} kodlu ${request.origin} - ${request.destination} seferi için iade talebiniz onaylandı.`,
              category: "refund_approved",
              relatedTripId: request.trip_id,
              relatedReservationId: request.reservation_id,
              relatedPaymentId: request.payment_id,
            });
          } else {
            await createNotification(client, {
              userId: request.requested_by_user_id,
              title: "İade talebiniz reddedildi",
              body:
                `${request.trip_code} kodlu ${request.origin} - ${request.destination} seferi için iade talebiniz reddedildi. Neden: ${rejectionReason}`,
              category: "refund_rejected",
              relatedTripId: request.trip_id,
              relatedReservationId: request.reservation_id,
              relatedPaymentId: request.payment_id,
            });
          }

          return loadAccessiblePaymentRowByReservationId(
              client,
              appUser,
              request.reservation_id,
              createError,
          );
        });

        return {
          payment: serializePaymentForClient(updatedPayment),
        };
      },
  );
}

module.exports = {
  getReservationPaymentCore,
  listPaymentsCore,
  processFakePaymentCore,
  requestRefundCore,
  reviewRefundRequestCore,
};
