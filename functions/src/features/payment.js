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
const {normalizeTrimmedString} = require("../shared/parsers");
const {serializePaymentRow} = require("../shared/serializers");
const {
  buildPaymentSelectClause,
  quoteIdentifier,
  resolveTripTransportTypeColumn,
} = require("../shared/postgres");
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
      refundPolicy.isEligible;
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
          throw createError("not-found", "Rezervasyon bulunamadi.");
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
    throw createError("invalid-argument", "Kart numarasi 16 haneli olmalidir.");
  }
  if (!/^\d{2}$/.test(expiryMonth)) {
    throw createError("invalid-argument", "Ay bilgisi MM formatinda olmalidir.");
  }
  const parsedMonth = Number.parseInt(expiryMonth, 10);
  if (parsedMonth < 1 || parsedMonth > 12) {
    throw createError("invalid-argument", "Ay bilgisi 01-12 arasinda olmalidir.");
  }
  if (!/^\d{2,4}$/.test(expiryYear)) {
    throw createError("invalid-argument", "Yil bilgisi gecersiz.");
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
    throw createError("invalid-argument", "CVV 3 veya 4 haneli olmalidir.");
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
          throw createError("not-found", "Rezervasyon bulunamadi.");
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

  return withClient(
      {createError, actionLabel: "İade işlemi"},
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
          throw createError("not-found", "Rezervasyon bulunamadi.");
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
          const paymentUpdateResult = await client.query(
              `
                UPDATE payments
                SET
                  status = 'refunded'::payment_status,
                  updated_at = now()
                WHERE id = $1
                  AND status = 'paid'::payment_status
              `,
              [payment.id],
          );
          if (paymentUpdateResult.rowCount === 0) {
            throw createError(
                "failed-precondition",
                "Ödeme durumu değiştiği için iade tamamlanamadı.",
            );
          }

          const reservationUpdateResult = await client.query(
              `
                UPDATE reservations
                SET
                  status = 'cancelled_by_user'::reservation_status,
                  cancelled_at = now(),
                  updated_at = now()
                WHERE id = $1
                  AND user_id = $2
                  AND status = 'paid'::reservation_status
              `,
              [reservationId, appUser.id],
          );
          if (reservationUpdateResult.rowCount === 0) {
            throw createError(
                "failed-precondition",
                "Rezervasyon durumu değiştiği için iade tamamlanamadı.",
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
          payment: serializePaymentForClient(updatedPayment, actionAt),
          refundAmountMinor: refundPolicy.refundAmountMinor,
          refundSummary: refundPolicy.refundSummary,
        };
      },
  );
}

module.exports = {
  getReservationPaymentCore,
  listPaymentsCore,
  processFakePaymentCore,
  requestRefundCore,
};
