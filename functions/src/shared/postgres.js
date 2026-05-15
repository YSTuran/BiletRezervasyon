const {Pool} = require("pg");

const {defineSecret} = require("../config/runtime");

const PGHOST = defineSecret("PGHOST");
const PGPORT = defineSecret("PGPORT");
const PGDATABASE = defineSecret("PGDATABASE");
const PGUSER = defineSecret("PGUSER");
const PGPASSWORD = defineSecret("PGPASSWORD");
const PGSSL = defineSecret("PGSSL");

const POSTGRES_SECRETS = [PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD, PGSSL];
const POSTGRES_SECRET_NAMES = [
  "PGHOST",
  "PGPORT",
  "PGDATABASE",
  "PGUSER",
  "PGPASSWORD",
  "PGSSL",
];

let pool;
const schemaColumnCache = new Map();

function parsePort(value) {
  const parsedPort = Number.parseInt(value, 10);
  if (Number.isNaN(parsedPort)) {
    throw new Error("PGPORT numeric olmalıdır.");
  }
  return parsedPort;
}

function shouldUseSsl(value) {
  const normalized = (value || "true").trim().toLowerCase();
  return normalized !== "false" && normalized !== "0" && normalized !== "no";
}

function validatePostgresConfig({host, database, user, password}) {
  const normalizedHost = (host || "").trim().toLowerCase();
  const normalizedDb = (database || "").trim().toLowerCase();
  const normalizedUser = (user || "").trim().toLowerCase();
  const normalizedPassword = (password || "").trim();

  if (!normalizedHost || normalizedHost === "your-postgres-host") {
    throw new Error("CONFIG_PLACEHOLDER_PGHOST");
  }

  if (!normalizedDb || normalizedDb === "your-database-name") {
    throw new Error("CONFIG_PLACEHOLDER_PGDATABASE");
  }

  if (!normalizedUser || normalizedUser === "your-database-user") {
    throw new Error("CONFIG_PLACEHOLDER_PGUSER");
  }

  if (!normalizedPassword) {
    throw new Error("CONFIG_PLACEHOLDER_PGPASSWORD");
  }
}

function readSecret(name, param) {
  const valueFromEnv = process.env[name];
  if (typeof valueFromEnv === "string" && valueFromEnv.trim()) {
    return valueFromEnv.trim();
  }

  if (param) {
    try {
      const valueFromParam = param.value();
      if (typeof valueFromParam === "string" && valueFromParam.trim()) {
        return valueFromParam.trim();
      }
    } catch (_) {
      // ignore; the secret may be unavailable in this runtime flavor
    }
  }

  throw new Error(`${name} secret bulunamadi.`);
}

function getPool() {
  if (!pool) {
    const host = readSecret("PGHOST", PGHOST);
    const port = readSecret("PGPORT", PGPORT);
    const database = readSecret("PGDATABASE", PGDATABASE);
    const user = readSecret("PGUSER", PGUSER);
    const password = readSecret("PGPASSWORD", PGPASSWORD);
    const ssl = readSecret("PGSSL", PGSSL);
    validatePostgresConfig({host, database, user, password});

    pool = new Pool({
      host,
      port: parsePort(port),
      database,
      user,
      password,
      ssl: shouldUseSsl(ssl) ? {rejectUnauthorized: false} : false,
      max: 10,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 10_000,
    });
  }

  return pool;
}

function quoteIdentifier(identifier) {
  return `"${String(identifier).replace(/"/g, "\"\"")}"`;
}

async function getTableColumns(client, tableName) {
  if (schemaColumnCache.has(tableName)) {
    return schemaColumnCache.get(tableName);
  }

  const result = await client.query(
      `
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = $1
          AND table_schema = ANY(current_schemas(false))
      `,
      [tableName],
  );

  const columns = result.rows.map((row) => row.column_name);
  schemaColumnCache.set(tableName, columns);
  return columns;
}

async function resolveColumnName({
  client,
  tableName,
  logicalName,
  candidates,
  createError,
}) {
  const columns = await getTableColumns(client, tableName);
  for (const candidate of candidates) {
    if (columns.includes(candidate)) {
      return candidate;
    }
  }

  const availableColumns = columns.length > 0 ? columns.join(", ") : "yok";
  throw createError(
      "failed-precondition",
      `${tableName} tablosunda ${logicalName} kolonu bulunamadi. Bulunan kolonlar: ${availableColumns}`,
  );
}

async function resolveCompanyTransportTypeColumn(client, createError) {
  return resolveColumnName({
    client,
    tableName: "companies",
    logicalName: "ulasim tipi",
    candidates: ["transport_type", "transportType", "transportation_type", "travel_type", "type"],
    createError,
  });
}

async function resolveTripTransportTypeColumn(client, createError) {
  return resolveColumnName({
    client,
    tableName: "trips",
    logicalName: "ulasim tipi",
    candidates: ["transport_type", "transportType", "transportation_type", "travel_type", "type"],
    createError,
  });
}

function buildCompanySelectClause(transportTypeExpression) {
  return `
    id,
    name,
    officer_user_id,
    ${transportTypeExpression} AS transport_type,
    status,
    NULL::uuid AS reviewed_by_admin_id,
    NULL::timestamptz AS reviewed_at,
    rejection_reason,
    created_at,
    updated_at
  `;
}

function buildTripSelectClause(transportTypeExpression, tableAlias = null) {
  const prefix = tableAlias ? `${tableAlias}.` : "";
  return `
    ${prefix}id,
    ${prefix}company_id,
    ${prefix}created_by_officer_id,
    ${transportTypeExpression} AS transport_type,
    ${prefix}trip_code,
    ${prefix}origin,
    ${prefix}destination,
    ${prefix}departure_at,
    ${prefix}arrival_at,
    ${prefix}seat_capacity,
    ${prefix}price_minor,
    ${prefix}status,
    NULL::uuid AS reviewed_by_admin_id,
    NULL::timestamptz AS reviewed_at,
    ${prefix}rejection_reason,
    ${prefix}created_at,
    ${prefix}updated_at
  `;
}

function buildReservationSelectClause(tripTransportTypeExpression, reservationAlias = "r") {
  const prefix = reservationAlias ? `${reservationAlias}.` : "";
  return `
    ${prefix}id,
    ${prefix}trip_id,
    ${prefix}trip_seat_id,
    ${prefix}user_id,
    ${prefix}status,
    ${prefix}requested_at,
    ${prefix}payment_deadline_at,
    NULL::uuid AS decided_by_officer_id,
    NULL::timestamptz AS decided_at,
    ${prefix}rejection_reason,
    ${prefix}paid_at,
    ${prefix}cancelled_at,
    ts.seat_number,
    t.trip_code,
    t.origin AS trip_origin,
    t.destination AS trip_destination,
    t.departure_at AS trip_departure_at,
    t.arrival_at AS trip_arrival_at,
    ${tripTransportTypeExpression} AS trip_transport_type,
    c.name AS company_name
  `;
}

function buildPaymentSelectClause(
    tripTransportTypeExpression,
    paymentAlias = "p",
) {
  const prefix = paymentAlias ? `${paymentAlias}.` : "";
  return `
    ${prefix}id,
    ${prefix}reservation_id,
    ${prefix}amount_minor,
    ${prefix}status,
    ${prefix}provider,
    NULL::text AS provider_payment_id,
    ${prefix}created_at,
    ${prefix}updated_at,
    ${prefix}paid_at,
    r.status AS reservation_status,
    r.payment_deadline_at,
    r.cancelled_at AS reservation_cancelled_at,
    ts.seat_number,
    t.trip_code,
    t.origin AS trip_origin,
    t.destination AS trip_destination,
    t.departure_at AS trip_departure_at,
    t.arrival_at AS trip_arrival_at,
    ${tripTransportTypeExpression} AS trip_transport_type,
    c.name AS company_name
  `;
}

module.exports = {
  POSTGRES_SECRET_NAMES,
  POSTGRES_SECRETS,
  buildCompanySelectClause,
  buildPaymentSelectClause,
  buildReservationSelectClause,
  buildTripSelectClause,
  getPool,
  quoteIdentifier,
  resolveCompanyTransportTypeColumn,
  resolveTripTransportTypeColumn,
};
