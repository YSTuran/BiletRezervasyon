const {randomUUID} = require("node:crypto");

const {resolveAuthContext} = require("../shared/auth");
const {withClient, withTransaction} = require("../shared/callable");
const {
  assertAllowedRoles,
  findCompanyByOfficerUserId,
  loadAccessibleTripRow,
  loadRequiredAppUser,
} = require("../shared/access");
const {
  normalizeTrimmedString,
  parseIsoDate,
  parsePositiveInteger,
  parseTransportType,
  parseTripStatus,
} = require("../shared/parsers");
const {serializeTripRow, serializeTripSeatRow} = require("../shared/serializers");
const {
  buildTripSelectClause,
  quoteIdentifier,
  resolveTripTransportTypeColumn,
} = require("../shared/postgres");
const {createTripCode, isTripCodeConflict} = require("./trip-code");

const SEAT_CAPACITY_OPTIONS_BY_TRANSPORT = {
  bus: [31, 34, 37, 40, 43],
  flight: [150, 160, 170, 180, 190],
};

function assertAllowedSeatCapacity({
  createError,
  seatCapacity,
  transportType,
}) {
  const allowedCapacities =
    SEAT_CAPACITY_OPTIONS_BY_TRANSPORT[transportType] || [];
  if (!allowedCapacities.includes(seatCapacity)) {
    throw createError(
        "invalid-argument",
        "Koltuk kapasitesi seçili ulaşım türü için geçerli değil.",
    );
  }
}

async function insertTripWithUniqueCode({
  client,
  appUser,
  arrivalAt,
  company,
  createError,
  departureAt,
  destination,
  origin,
  priceMinor,
  seatCapacity,
  tripTransportTypeColumn,
}) {
  const maxAttempts = 5;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const tripId = randomUUID();
    const tripCode = createTripCode({
      transportType: company.transport_type,
      departureAt,
    });

    try {
      const insertTripResult = await client.query(
          `
            INSERT INTO trips (
              id,
              company_id,
              created_by_officer_id,
              ${quoteIdentifier(tripTransportTypeColumn)},
              trip_code,
              origin,
              destination,
              departure_at,
              arrival_at,
              seat_capacity,
              price_minor,
              status,
              created_at,
              updated_at
            )
            VALUES (
              $1, $2, $3, $4, $5, $6, $7,
              $8, $9, $10, $11, 'pending_approval', now(), now()
            )
            RETURNING ${buildTripSelectClause(quoteIdentifier(tripTransportTypeColumn))}
          `,
          [
            tripId,
            company.id,
            appUser.id,
            company.transport_type,
            tripCode,
            origin,
            destination,
            departureAt.toISOString(),
            arrivalAt.toISOString(),
            seatCapacity,
            priceMinor,
          ],
      );

      return {
        tripId,
        tripRow: insertTripResult.rows[0],
      };
    } catch (error) {
      if (attempt < maxAttempts - 1 && isTripCodeConflict(error)) {
        continue;
      }
      throw error;
    }
  }

  throw createError(
      "aborted",
      "Sefer kodu oluşturulurken beklenmeyen bir çakışma oluştu.",
  );
}

async function listTripsCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  return withClient(
      {createError, actionLabel: "Sefer listeleme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        const transportTypeColumn = await resolveTripTransportTypeColumn(
            client,
            createError,
        );

        let result;
        if (appUser.role === "admin") {
          result = await client.query(
              `
                SELECT ${buildTripSelectClause(quoteIdentifier(transportTypeColumn))}
                FROM trips
                ORDER BY departure_at ASC
              `,
          );
        } else if (appUser.role === "company_officer") {
          result = await client.query(
              `
                SELECT ${buildTripSelectClause(`t.${quoteIdentifier(transportTypeColumn)}`, "t")}
                FROM trips t
                INNER JOIN companies c ON c.id = t.company_id
                WHERE c.officer_user_id = $1
                ORDER BY t.departure_at ASC
              `,
              [appUser.id],
          );
        } else {
          result = await client.query(
              `
                SELECT ${buildTripSelectClause(quoteIdentifier(transportTypeColumn))}
                FROM trips
                WHERE status = 'approved'
                  AND arrival_at > now()
                ORDER BY departure_at ASC
              `,
          );
        }

        return {
          trips: result.rows.map(serializeTripRow),
        };
      },
  );
}

async function getTripDetailCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const tripId = normalizeTrimmedString(data?.tripId);
  if (!tripId) {
    throw createError("invalid-argument", "tripId zorunludur.");
  }

  return withClient(
      {createError, actionLabel: "Sefer detay getirme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        const trip = await loadAccessibleTripRow(
            client,
            appUser,
            tripId,
            createError,
        );
        if (!trip) {
          return {
            trip: null,
            seats: [],
          };
        }

        const seatResult = await client.query(
            `
              SELECT id, trip_id, seat_number, created_at
              FROM trip_seats
              WHERE trip_id = $1
              ORDER BY seat_number ASC
            `,
            [tripId],
        );

        return {
          trip: serializeTripRow(trip),
          seats: seatResult.rows.map(serializeTripSeatRow),
        };
      },
  );
}

async function createTripCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const origin = normalizeTrimmedString(data?.origin);
  const destination = normalizeTrimmedString(data?.destination);
  if (!origin || !destination) {
    throw createError(
        "invalid-argument",
        "Kalkış ve varış alanları zorunludur.",
    );
  }
  if (origin.toLowerCase() === destination.toLowerCase()) {
    throw createError(
        "invalid-argument",
        "Kalkış ve varış noktası farklı olmalıdır.",
    );
  }

  const departureAt = parseIsoDate(data?.departureAt, "departureAt", createError);
  const arrivalAt = parseIsoDate(data?.arrivalAt, "arrivalAt", createError);
  if (departureAt.getTime() >= arrivalAt.getTime()) {
    throw createError(
        "invalid-argument",
        "Varış saati kalkış saatinden sonra olmalıdır.",
    );
  }

  const seatCapacity = parsePositiveInteger(
      data?.seatCapacity,
      "seatCapacity",
      createError,
  );
  const priceMinor = parsePositiveInteger(
      data?.priceMinor,
      "priceMinor",
      createError,
  );
  const requestedTransportType = parseTransportType(
      data?.transportType,
      createError,
  );
  assertAllowedSeatCapacity({
    createError,
    seatCapacity,
    transportType: requestedTransportType,
  });

  return withClient(
      {createError, actionLabel: "Sefer oluşturma"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["company_officer"], createError);
        const tripTransportTypeColumn = await resolveTripTransportTypeColumn(
            client,
            createError,
        );

        const company = await findCompanyByOfficerUserId(
            client,
            appUser.id,
            createError,
        );
        if (!company) {
          throw createError(
              "failed-precondition",
              "Once firma bilgilerinizi doldurmalisiniz.",
          );
        }
        if (company.status !== "approved") {
          throw createError(
              "failed-precondition",
              "Firma bilgileri onaylanmadan sefer oluşturulamaz.",
          );
        }
        if (company.transport_type !== requestedTransportType) {
          throw createError(
              "failed-precondition",
              "Firma yalnizca kendi ulasim turunde sefer acabilir.",
          );
        }

        return withTransaction(client, async () => {
          const {tripId, tripRow} = await insertTripWithUniqueCode({
            client,
            appUser,
            arrivalAt,
            company,
            createError,
            departureAt,
            destination,
            origin,
            priceMinor,
            seatCapacity,
            tripTransportTypeColumn,
          });

          const seatValues = [];
          const seatPlaceholders = [];
          for (let index = 0; index < seatCapacity; index++) {
            const offset = index * 4;
            seatValues.push(
                randomUUID(),
                tripId,
                String(index + 1).padStart(2, "0"),
                new Date().toISOString(),
            );
            seatPlaceholders.push(
                `($${offset + 1}, $${offset + 2}, $${offset + 3}, $${offset + 4})`,
            );
          }

          const insertSeatsResult = seatValues.length === 0 ?
            {rows: []} :
            await client.query(
                `
                  INSERT INTO trip_seats (
                    id,
                    trip_id,
                    seat_number,
                    created_at
                  )
                  VALUES ${seatPlaceholders.join(", ")}
                  RETURNING id, trip_id, seat_number, created_at
                `,
                seatValues,
            );

          return {
            trip: serializeTripRow(tripRow),
            seats: insertSeatsResult.rows.map(serializeTripSeatRow),
          };
        });
      },
  );
}

async function reviewTripCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  const tripId = normalizeTrimmedString(data?.tripId);
  if (!tripId) {
    throw createError("invalid-argument", "tripId zorunludur.");
  }

  const status = parseTripStatus(data?.status, createError);
  if (status !== "approved" && status !== "rejected") {
    throw createError(
        "invalid-argument",
        "Admin yalnızca approved veya rejected kararı verebilir.",
    );
  }

  const rejectionReason = normalizeTrimmedString(data?.rejectionReason);
  if (status === "rejected" && !rejectionReason) {
    throw createError("invalid-argument", "Red nedeni zorunludur.");
  }

  return withClient(
      {createError, actionLabel: "Sefer inceleme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["admin"], createError);
        const transportTypeColumn = await resolveTripTransportTypeColumn(
            client,
            createError,
        );

        const result = await client.query(
            `
              UPDATE trips
              SET
                status = $2::trip_status,
                rejection_reason = CASE
                  WHEN $2::trip_status = 'rejected'::trip_status THEN $3
                  ELSE NULL
                END,
                updated_at = now()
              WHERE id = $1
              RETURNING ${buildTripSelectClause(quoteIdentifier(transportTypeColumn))}
            `,
            [tripId, status, rejectionReason || null],
        );

        if (result.rows.length === 0) {
          throw createError("not-found", "Sefer bulunamadi.");
        }

        return {
          trip: serializeTripRow(result.rows[0]),
        };
      },
  );
}

module.exports = {
  createTripCore,
  getTripDetailCore,
  listTripsCore,
  reviewTripCore,
};
