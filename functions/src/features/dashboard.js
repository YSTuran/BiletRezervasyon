const {resolveAuthContext} = require("../shared/auth");
const {withClient} = require("../shared/callable");
const {
  assertAllowedRoles,
  expireOverdueReservations,
  findCompanyByOfficerUserId,
  loadRequiredAppUser,
} = require("../shared/access");
const {serializeCompanyRow} = require("../shared/serializers");
const {
  quoteIdentifier,
  resolveCompanyTransportTypeColumn,
  resolveTripTransportTypeColumn,
} = require("../shared/postgres");

function buildEmptyCompanyOperationsStats() {
  return {
    overall_occupancy_rate_percent: 0,
    upcoming_trip_count: 0,
    active_trip_count: 0,
    passenger_count: 0,
    pending_reservation_count: 0,
  };
}

function mapCompanyOperationTrip(row) {
  const occupiedSeatCount = Number(row.occupied_seat_count || 0);
  const seatCapacity = Number(row.seat_capacity || 0);
  const occupancyRatePercent = seatCapacity > 0 ?
    Math.round((occupiedSeatCount / seatCapacity) * 100) :
    0;

  return {
    trip_id: row.trip_id,
    trip_code: row.trip_code,
    origin: row.origin,
    destination: row.destination,
    departure_at: row.departure_at,
    arrival_at: row.arrival_at,
    seat_capacity: seatCapacity,
    status: row.status,
    transport_type: row.transport_type,
    occupied_seat_count: occupiedSeatCount,
    paid_passenger_count: Number(row.paid_passenger_count || 0),
    occupancy_rate_percent: occupancyRatePercent,
  };
}

function mapPassengerManifestEntry(row) {
  return {
    reservation_id: row.reservation_id,
    trip_id: row.trip_id,
    trip_code: row.trip_code,
    origin: row.origin,
    destination: row.destination,
    departure_at: row.departure_at,
    seat_number: row.seat_number,
    passenger_name: row.passenger_name,
    passenger_email: row.passenger_email,
    reservation_status: row.reservation_status,
  };
}

function mapPendingCompany(row) {
  return {
    id: row.id,
    name: row.name,
    transport_type: row.transport_type,
    created_at: row.created_at,
    officer_name: row.officer_name,
    officer_email: row.officer_email,
  };
}

function mapPendingTrip(row) {
  return {
    id: row.id,
    trip_code: row.trip_code,
    origin: row.origin,
    destination: row.destination,
    departure_at: row.departure_at,
    arrival_at: row.arrival_at,
    transport_type: row.transport_type,
    company_name: row.company_name,
  };
}

function mapPendingReservation(row) {
  return {
    id: row.id,
    trip_id: row.trip_id,
    trip_code: row.trip_code,
    origin: row.origin,
    destination: row.destination,
    seat_number: row.seat_number,
    company_name: row.company_name,
    requested_at: row.requested_at,
  };
}

function mapRejectionReason(row) {
  return {
    category: row.category,
    subject: row.subject,
    reason: row.reason,
    occurred_at: row.occurred_at,
  };
}

async function getCompanyOperationsDashboardCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  return withClient(
      {createError, actionLabel: "Firma operasyon paneli"},
      async (client) => {
        await expireOverdueReservations(client);
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["company_officer"], createError);

        const company = await findCompanyByOfficerUserId(
            client,
            appUser.id,
            createError,
        );

        if (!company) {
          return {
            company: null,
            stats: buildEmptyCompanyOperationsStats(),
            upcoming_trips: [],
            passenger_manifest: [],
          };
        }

        if (company.status !== "approved") {
          return {
            company: serializeCompanyRow(company),
            stats: buildEmptyCompanyOperationsStats(),
            upcoming_trips: [],
            passenger_manifest: [],
          };
        }

        const tripTransportTypeColumn = await resolveTripTransportTypeColumn(
            client,
            createError,
        );

        const [
          tripCountResult,
          pendingReservationResult,
          occupancyResult,
          upcomingTripsResult,
          passengerManifestResult,
        ] = await Promise.all([
          client.query(
              `
                SELECT
                  COUNT(*) FILTER (
                    WHERE t.status = 'approved'::trip_status
                      AND t.departure_at > now()
                  )::int AS upcoming_trip_count,
                  COUNT(*) FILTER (
                    WHERE t.status = 'approved'::trip_status
                      AND t.departure_at <= now()
                      AND t.arrival_at > now()
                  )::int AS active_trip_count
                FROM trips t
                WHERE t.company_id = $1
              `,
              [company.id],
          ),
          client.query(
              `
                SELECT COUNT(*)::int AS pending_reservation_count
                FROM reservations r
                INNER JOIN trips t ON t.id = r.trip_id
                WHERE t.company_id = $1
                  AND r.status = 'pending_approval'::reservation_status
              `,
              [company.id],
          ),
          client.query(
              `
                SELECT
                  COALESCE(SUM(snapshot.occupied_seat_count), 0)::int AS occupied_seat_count,
                  COALESCE(SUM(snapshot.seat_capacity), 0)::int AS total_seat_capacity
                FROM (
                  SELECT
                    t.id,
                    t.seat_capacity,
                    COUNT(r.id) FILTER (
                      WHERE r.status = ANY(
                        ARRAY[
                          'approved'::reservation_status,
                          'paid'::reservation_status
                        ]
                      )
                    )::int AS occupied_seat_count
                  FROM trips t
                  LEFT JOIN reservations r ON r.trip_id = t.id
                  WHERE t.company_id = $1
                    AND t.status = 'approved'::trip_status
                    AND t.arrival_at > now()
                  GROUP BY t.id, t.seat_capacity
                ) snapshot
              `,
              [company.id],
          ),
          client.query(
              `
                SELECT
                  t.id AS trip_id,
                  t.trip_code,
                  t.origin,
                  t.destination,
                  t.departure_at,
                  t.arrival_at,
                  t.seat_capacity,
                  t.status,
                  t.${quoteIdentifier(tripTransportTypeColumn)} AS transport_type,
                  COUNT(r.id) FILTER (
                    WHERE r.status = ANY(
                      ARRAY[
                        'approved'::reservation_status,
                        'paid'::reservation_status
                      ]
                    )
                  )::int AS occupied_seat_count,
                  COUNT(r.id) FILTER (
                    WHERE r.status = 'paid'::reservation_status
                  )::int AS paid_passenger_count
                FROM trips t
                LEFT JOIN reservations r ON r.trip_id = t.id
                WHERE t.company_id = $1
                  AND t.status = 'approved'::trip_status
                  AND t.arrival_at > now()
                GROUP BY
                  t.id,
                  t.trip_code,
                  t.origin,
                  t.destination,
                  t.departure_at,
                  t.arrival_at,
                  t.seat_capacity,
                  t.status,
                  t.${quoteIdentifier(tripTransportTypeColumn)}
                ORDER BY t.departure_at ASC
                LIMIT 6
              `,
              [company.id],
          ),
          client.query(
              `
                SELECT
                  r.id AS reservation_id,
                  r.status AS reservation_status,
                  t.id AS trip_id,
                  t.trip_code,
                  t.origin,
                  t.destination,
                  t.departure_at,
                  ts.seat_number,
                  u.full_name AS passenger_name,
                  u.email AS passenger_email
                FROM reservations r
                INNER JOIN trips t ON t.id = r.trip_id
                INNER JOIN trip_seats ts
                  ON ts.id = r.trip_seat_id
                 AND ts.trip_id = r.trip_id
                INNER JOIN app_users u ON u.id = r.user_id
                WHERE t.company_id = $1
                  AND t.status = 'approved'::trip_status
                  AND t.arrival_at > now()
                  AND r.status = ANY(
                    ARRAY[
                      'approved'::reservation_status,
                      'paid'::reservation_status
                    ]
                  )
                ORDER BY t.departure_at ASC, ts.seat_number ASC
                LIMIT 12
              `,
              [company.id],
          ),
        ]);

        const tripCountRow = tripCountResult.rows[0] || {};
        const pendingReservationRow = pendingReservationResult.rows[0] || {};
        const occupancyRow = occupancyResult.rows[0] || {};
        const passengerCount = passengerManifestResult.rows.length;
        const occupiedSeatCount = Number(occupancyRow.occupied_seat_count || 0);
        const totalSeatCapacity = Number(occupancyRow.total_seat_capacity || 0);
        const overallOccupancyRatePercent = totalSeatCapacity > 0 ?
          Math.round((occupiedSeatCount / totalSeatCapacity) * 100) :
          0;

        return {
          company: serializeCompanyRow(company),
          stats: {
            overall_occupancy_rate_percent: overallOccupancyRatePercent,
            upcoming_trip_count: Number(tripCountRow.upcoming_trip_count || 0),
            active_trip_count: Number(tripCountRow.active_trip_count || 0),
            passenger_count: passengerCount,
            pending_reservation_count: Number(
                pendingReservationRow.pending_reservation_count || 0,
            ),
          },
          upcoming_trips: upcomingTripsResult.rows.map(mapCompanyOperationTrip),
          passenger_manifest: passengerManifestResult.rows.map(
              mapPassengerManifestEntry,
          ),
        };
      },
  );
}

async function getAdminDashboardCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
  }

  return withClient(
      {createError, actionLabel: "Admin dashboard"},
      async (client) => {
        await expireOverdueReservations(client);
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["admin"], createError);

        const companyTransportTypeColumn = await resolveCompanyTransportTypeColumn(
            client,
            createError,
        );
        const tripTransportTypeColumn = await resolveTripTransportTypeColumn(
            client,
            createError,
        );

        const [
          summaryResult,
          pendingCompaniesResult,
          pendingTripsResult,
          pendingReservationsResult,
          rejectionReasonsResult,
        ] = await Promise.all([
          client.query(
              `
                SELECT
                  (
                    SELECT COUNT(*)::int
                    FROM companies
                    WHERE status = 'pending'::approval_status
                  ) AS pending_company_count,
                  (
                    SELECT COUNT(*)::int
                    FROM trips
                    WHERE status = 'pending_approval'::trip_status
                  ) AS pending_trip_count,
                  (
                    SELECT COUNT(*)::int
                    FROM reservations
                    WHERE status = 'pending_approval'::reservation_status
                  ) AS pending_reservation_count,
                  (
                    SELECT COUNT(*)::int
                    FROM reservations
                    WHERE status = 'paid'::reservation_status
                  ) AS paid_reservation_count,
                  (
                    SELECT COUNT(*)::int
                    FROM payments
                    WHERE status = 'paid'::payment_status
                  ) AS paid_payment_count,
                  (
                    SELECT COALESCE(SUM(amount_minor), 0)::int
                    FROM payments
                    WHERE status = 'paid'::payment_status
                  ) AS total_sales_minor
              `,
          ),
          client.query(
              `
                SELECT
                  c.id,
                  c.name,
                  c.${quoteIdentifier(companyTransportTypeColumn)} AS transport_type,
                  c.created_at,
                  u.full_name AS officer_name,
                  u.email AS officer_email
                FROM companies c
                INNER JOIN app_users u ON u.id = c.officer_user_id
                WHERE c.status = 'pending'::approval_status
                ORDER BY c.created_at ASC
                LIMIT 5
              `,
          ),
          client.query(
              `
                SELECT
                  t.id,
                  t.trip_code,
                  t.origin,
                  t.destination,
                  t.departure_at,
                  t.arrival_at,
                  t.${quoteIdentifier(tripTransportTypeColumn)} AS transport_type,
                  c.name AS company_name
                FROM trips t
                INNER JOIN companies c ON c.id = t.company_id
                WHERE t.status = 'pending_approval'::trip_status
                ORDER BY t.created_at ASC
                LIMIT 5
              `,
          ),
          client.query(
              `
                SELECT
                  r.id,
                  r.trip_id,
                  r.requested_at,
                  ts.seat_number,
                  t.trip_code,
                  t.origin,
                  t.destination,
                  c.name AS company_name
                FROM reservations r
                INNER JOIN trips t ON t.id = r.trip_id
                INNER JOIN companies c ON c.id = t.company_id
                INNER JOIN trip_seats ts
                  ON ts.id = r.trip_seat_id
                 AND ts.trip_id = r.trip_id
                WHERE r.status = 'pending_approval'::reservation_status
                ORDER BY r.requested_at ASC
                LIMIT 5
              `,
          ),
          client.query(
              `
                SELECT *
                FROM (
                  SELECT
                    'Firma'::text AS category,
                    c.name AS subject,
                    c.rejection_reason AS reason,
                    c.updated_at AS occurred_at
                  FROM companies c
                  WHERE c.status = 'rejected'::approval_status
                    AND c.rejection_reason IS NOT NULL

                  UNION ALL

                  SELECT
                    'Sefer'::text AS category,
                    CONCAT(t.trip_code, ' - ', t.origin, ' -> ', t.destination) AS subject,
                    t.rejection_reason AS reason,
                    t.updated_at AS occurred_at
                  FROM trips t
                  WHERE t.status = 'rejected'::trip_status
                    AND t.rejection_reason IS NOT NULL

                  UNION ALL

                  SELECT
                    'Rezervasyon'::text AS category,
                    CONCAT(t.trip_code, ' / Koltuk ', ts.seat_number) AS subject,
                    r.rejection_reason AS reason,
                    r.updated_at AS occurred_at
                  FROM reservations r
                  INNER JOIN trips t ON t.id = r.trip_id
                  INNER JOIN trip_seats ts
                    ON ts.id = r.trip_seat_id
                   AND ts.trip_id = r.trip_id
                  WHERE r.status = 'rejected'::reservation_status
                    AND r.rejection_reason IS NOT NULL
                ) rejected_items
                ORDER BY occurred_at DESC
                LIMIT 10
              `,
          ),
        ]);

        return {
          summary: summaryResult.rows[0],
          pending_companies: pendingCompaniesResult.rows.map(mapPendingCompany),
          pending_trips: pendingTripsResult.rows.map(mapPendingTrip),
          pending_reservations: pendingReservationsResult.rows.map(
              mapPendingReservation,
          ),
          rejection_reasons: rejectionReasonsResult.rows.map(mapRejectionReason),
        };
      },
  );
}

module.exports = {
  getAdminDashboardCore,
  getCompanyOperationsDashboardCore,
};
