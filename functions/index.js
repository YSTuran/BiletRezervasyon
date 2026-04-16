const {setGlobalOptions, logger} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const functionsV1 = require("firebase-functions/v1");
const {randomUUID} = require("node:crypto");
const admin = require("firebase-admin");
const {Pool} = require("pg");

admin.initializeApp();
setGlobalOptions({region: "europe-west1", maxInstances: 10});

const PGHOST = defineSecret("PGHOST");
const PGPORT = defineSecret("PGPORT");
const PGDATABASE = defineSecret("PGDATABASE");
const PGUSER = defineSecret("PGUSER");
const PGPASSWORD = defineSecret("PGPASSWORD");
const PGSSL = defineSecret("PGSSL");

let pool;
const schemaColumnCache = new Map();

function parsePort(value) {
  const parsedPort = Number.parseInt(value, 10);
  if (Number.isNaN(parsedPort)) {
    throw new Error("PGPORT numeric olmalidir.");
  }
  return parsedPort;
}

function shouldUseSsl(value) {
  const normalized = (value || "true").trim().toLowerCase();
  return normalized !== "false" && normalized !== "0" && normalized !== "no";
}

function fallbackFullName(email) {
  const prefix = email.split("@")[0] || "kullanici";
  const normalized = prefix.replace(/[._-]+/g, " ").trim();
  if (!normalized) {
    return "Yeni Kullanici";
  }
  return normalized
      .split(" ")
      .filter(Boolean)
      .map((part) => part[0].toUpperCase() + part.slice(1))
      .join(" ");
}

function resolveFullName(requestedFullName, email) {
  const trimmed = (requestedFullName || "").trim();
  if (trimmed) {
    return trimmed;
  }
  return fallbackFullName(email);
}

function parseRole(roleValue) {
  const normalized = (roleValue || "").trim().toLowerCase();
  if (
    normalized === "normal_user" ||
    normalized === "normal-user" ||
    normalized === "normal user" ||
    normalized === "normaluser" ||
    normalized === "user"
  ) {
    return "normal_user";
  }
  if (
    normalized === "company_officer" ||
    normalized === "company-officer" ||
    normalized === "company officer" ||
    normalized === "companyofficer" ||
    normalized === "company" ||
    normalized === "firma_gorevlisi" ||
    normalized === "firma gorevlisi" ||
    normalized === "firma_yetkilisi" ||
    normalized === "firma yetkilisi"
  ) {
    return "company_officer";
  }
  if (normalized === "admin" || normalized === "administrator") {
    return "admin";
  }
  return null;
}

function resolveRole(requestedRole) {
  const parsed = parseRole(requestedRole);
  if (parsed) {
    return parsed;
  }
  return "normal_user";
}

function resolveRoleFromAuthToken(token) {
  if (!token || typeof token !== "object") {
    return null;
  }

  const roleCandidates = [
    token.role,
    token.user_role,
    token.userRole,
    token.app_role,
    token.appRole,
  ];

  for (const value of roleCandidates) {
    if (typeof value === "string") {
      const resolved = parseRole(value);
      if (resolved) {
        return resolved;
      }
    }
  }

  const isAdmin = token.isAdmin === true || token.admin === true || token.is_admin === true;
  if (isAdmin) {
    return "admin";
  }

  const isCompanyOfficer =
    token.isCompanyOfficer === true ||
    token.companyOfficer === true ||
    token.company_officer === true ||
    token.is_company_officer === true ||
    token.firmaYetkilisi === true ||
    token.firma_yetkilisi === true ||
    token.firmaGorevlisi === true ||
    token.firma_gorevlisi === true;

  if (isCompanyOfficer) {
    return "company_officer";
  }

  return null;
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

async function syncUserCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError(
        "unauthenticated",
        "Bu islem icin giris yapmalisiniz.",
    );
  }

  const firebaseUid = resolvedAuth.uid;
  const email = resolvedAuth.token?.email;
  if (typeof email !== "string" || !email.trim()) {
    throw createError(
        "failed-precondition",
        "Kullanici e-postasi bulunamadi.",
    );
  }

  const normalizedEmail = email.trim().toLowerCase();
  const fullName = resolveFullName(data?.fullName, normalizedEmail);
  const requestedRole = data?.role;
  const roleFromToken = resolveRoleFromAuthToken(resolvedAuth.token);
  const roleFromRequest = requestedRole ? resolveRole(requestedRole) : null;
  const role = roleFromRequest || roleFromToken || null;

  const query = `
    INSERT INTO app_users (firebase_uid, email, full_name, role)
    VALUES ($1, $2, $3, COALESCE($4::user_role, 'normal_user'::user_role))
    ON CONFLICT (firebase_uid)
    DO UPDATE SET
      email = EXCLUDED.email,
      full_name = EXCLUDED.full_name,
      role = CASE
        WHEN $4::user_role IS NULL THEN app_users.role
        ELSE $4::user_role
      END,
      updated_at = now()
    RETURNING id, email, full_name, role
  `;

  const values = [firebaseUid, normalizedEmail, fullName, role];

  let client;
  try {
    client = await getPool().connect();
    const result = await client.query(query, values);
    const user = result.rows[0];
    return {
      ok: true,
      userId: user.id,
      email: user.email,
      fullName: user.full_name,
      role: user.role,
    };
  } catch (error) {
    logger.error("syncUserToPostgres failed", {
      firebaseUid,
      errorCode: error.code,
      errorMessage: error.message,
    });

    if (
      typeof error.message === "string" &&
      error.message.startsWith("CONFIG_PLACEHOLDER_")
    ) {
      throw createError(
          "failed-precondition",
          "PostgreSQL ayarlari eksik. PGHOST/PGDATABASE/PGUSER/PGPASSWORD secret degerlerini guncelleyin.",
      );
    }

    if (error.code === "EAI_AGAIN" || error.code === "ENOTFOUND") {
      throw createError(
          "failed-precondition",
          "PostgreSQL host cozumlenemedi. PGHOST degerini kontrol edin.",
      );
    }

    if (error.code === "28P01") {
      throw createError(
          "failed-precondition",
          "PostgreSQL kimlik dogrulamasi basarisiz. PGUSER/PGPASSWORD degerlerini kontrol edin.",
      );
    }

    throw createError(
        "internal",
        "PostgreSQL senkronizasyonu basarisiz oldu.",
    );
  } finally {
    if (client) {
      client.release();
    }
  }
}

function resolveAuthContext({auth, data}) {
  if (auth) {
    return auth;
  }

  const isFunctionsEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  if (!isFunctionsEmulator) {
    return null;
  }

  const emulatorUid = data?.__emulatorUid;
  const emulatorEmail = data?.__emulatorEmail;
  if (typeof emulatorUid !== "string" || !emulatorUid.trim()) {
    return null;
  }
  if (typeof emulatorEmail !== "string" || !emulatorEmail.trim()) {
    return null;
  }

  return {
    uid: emulatorUid.trim(),
    token: {
      email: emulatorEmail.trim().toLowerCase(),
    },
  };
}

exports.syncUserToPostgres = onCall(
    {
      timeoutSeconds: 15,
      memory: "256MiB",
      invoker: "public",
      secrets: [PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD, PGSSL],
    },
    async (request) => syncUserCore({
      auth: request.auth,
      data: request.data,
      createError: (code, message) => new HttpsError(code, message),
    }),
);

exports.syncUserToPostgresV1 = functionsV1
    .region("europe-west1")
    .runWith({
      timeoutSeconds: 15,
      memory: "256MB",
      maxInstances: 10,
      secrets: ["PGHOST", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD", "PGSSL"],
    })
    .https.onCall(async (data, context) => syncUserCore({
      auth: context.auth,
      data,
      createError: (code, message) => new functionsV1.https.HttpsError(code, message),
    }));

const CALLABLE_ERROR_CODES = new Set([
  "cancelled",
  "unknown",
  "invalid-argument",
  "deadline-exceeded",
  "not-found",
  "already-exists",
  "permission-denied",
  "resource-exhausted",
  "failed-precondition",
  "aborted",
  "out-of-range",
  "unimplemented",
  "internal",
  "unavailable",
  "data-loss",
  "unauthenticated",
]);

const FUNCTION_V2_OPTIONS = {
  timeoutSeconds: 15,
  memory: "256MiB",
  invoker: "public",
  secrets: [PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD, PGSSL],
};

const FUNCTION_V1_OPTIONS = {
  timeoutSeconds: 15,
  memory: "256MB",
  maxInstances: 10,
  secrets: ["PGHOST", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD", "PGSSL"],
};

function isCallableError(error) {
  return Boolean(
      error &&
      typeof error === "object" &&
      typeof error.code === "string" &&
      CALLABLE_ERROR_CODES.has(error.code),
  );
}

function createCallablePair(name, coreHandler) {
  exports[name] = onCall(
      FUNCTION_V2_OPTIONS,
      async (request) => coreHandler({
        auth: request.auth,
        data: request.data,
        createError: (code, message) => new HttpsError(code, message),
      }),
  );

  exports[`${name}V1`] = functionsV1
      .region("europe-west1")
      .runWith(FUNCTION_V1_OPTIONS)
      .https.onCall(async (data, context) => coreHandler({
        auth: context.auth,
        data,
        createError: (code, message) => new functionsV1.https.HttpsError(code, message),
      }));
}

async function withClient({createError, actionLabel}, handler) {
  let client;
  try {
    client = await getPool().connect();
    return await handler(client);
  } catch (error) {
    if (isCallableError(error)) {
      throw error;
    }
    throw mapPostgresError({error, createError, actionLabel});
  } finally {
    if (client) {
      client.release();
    }
  }
}

async function withTransaction(client, handler) {
  await client.query("BEGIN");
  try {
    const result = await handler();
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  }
}

function mapPostgresError({error, createError, actionLabel}) {
  logger.error(actionLabel, {
    errorCode: error.code,
    errorMessage: error.message,
  });

  if (
    typeof error.message === "string" &&
    error.message.startsWith("CONFIG_PLACEHOLDER_")
  ) {
    return createError(
        "failed-precondition",
        "PostgreSQL ayarlari eksik. PGHOST/PGDATABASE/PGUSER/PGPASSWORD secret degerlerini guncelleyin.",
    );
  }

  if (error.code === "EAI_AGAIN" || error.code === "ENOTFOUND") {
    return createError(
        "failed-precondition",
        "PostgreSQL host cozumlenemedi. PGHOST degerini kontrol edin.",
    );
  }

  if (error.code === "28P01") {
    return createError(
        "failed-precondition",
        "PostgreSQL kimlik dogrulamasi basarisiz. PGUSER/PGPASSWORD degerlerini kontrol edin.",
    );
  }

  if (error.code === "42P01") {
    return createError(
        "failed-precondition",
        "PostgreSQL tablolari bulunamadi. companies, trips veya trip_seats tablolarini kontrol edin.",
    );
  }

  if (error.code === "42703") {
    const columnMessage = typeof error.column === "string" && error.column.trim() ?
      ` Eksik veya hatali kolon: ${error.column.trim()}.` :
      "";
    return createError(
        "failed-precondition",
        `PostgreSQL kolon yapisi kodla eslesmiyor.${columnMessage} companies/trips/trip_seats kolon isimlerini kontrol edin.`,
    );
  }

  if (error.code === "23503") {
    return createError(
        "failed-precondition",
        "Iliskili kayit bulunamadi. app_users, companies veya trips baglantilarini kontrol edin.",
    );
  }

  return createError("internal", `${actionLabel} basarisiz oldu.`);
}

function serializeDate(value) {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  return new Date(value).toISOString();
}

function serializeCompanyRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    name: row.name,
    officer_user_id: row.officer_user_id,
    transport_type: row.transport_type,
    status: row.status,
    reviewed_by_admin_id: row.reviewed_by_admin_id,
    reviewed_at: serializeDate(row.reviewed_at),
    rejection_reason: row.rejection_reason,
    created_at: serializeDate(row.created_at),
    updated_at: serializeDate(row.updated_at),
  };
}

function serializeTripRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    company_id: row.company_id,
    created_by_officer_id: row.created_by_officer_id,
    transport_type: row.transport_type,
    trip_code: row.trip_code,
    origin: row.origin,
    destination: row.destination,
    departure_at: serializeDate(row.departure_at),
    arrival_at: serializeDate(row.arrival_at),
    seat_capacity: row.seat_capacity,
    price_minor: row.price_minor,
    status: row.status,
    reviewed_by_admin_id: row.reviewed_by_admin_id,
    reviewed_at: serializeDate(row.reviewed_at),
    rejection_reason: row.rejection_reason,
    created_at: serializeDate(row.created_at),
    updated_at: serializeDate(row.updated_at),
  };
}

function serializeTripSeatRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    trip_id: row.trip_id,
    seat_number: row.seat_number,
    created_at: serializeDate(row.created_at),
  };
}

function normalizeTrimmedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function parseTransportType(value, createError) {
  const normalized = normalizeTrimmedString(value).toLowerCase();
  if (normalized === "bus") {
    return "bus";
  }
  if (normalized === "flight") {
    return "flight";
  }
  throw createError("invalid-argument", "Ulasim turu bus veya flight olmalidir.");
}

function parseApprovalStatus(value, createError) {
  const normalized = normalizeTrimmedString(value).toLowerCase();
  if (normalized === "pending") {
    return "pending";
  }
  if (normalized === "approved") {
    return "approved";
  }
  if (normalized === "rejected") {
    return "rejected";
  }
  throw createError(
      "invalid-argument",
      "Firma durumu pending, approved veya rejected olmalidir.",
  );
}

function parseTripStatus(value, createError) {
  const normalized = normalizeTrimmedString(value).toLowerCase();
  if (normalized === "pending_approval") {
    return "pending_approval";
  }
  if (normalized === "approved") {
    return "approved";
  }
  if (normalized === "rejected") {
    return "rejected";
  }
  if (normalized === "cancelled") {
    return "cancelled";
  }
  throw createError(
      "invalid-argument",
      "Sefer durumu pending_approval, approved, rejected veya cancelled olmalidir.",
  );
}

function parseIsoDate(value, fieldName, createError) {
  const trimmed = normalizeTrimmedString(value);
  if (!trimmed) {
    throw createError("invalid-argument", `${fieldName} zorunludur.`);
  }
  const parsed = new Date(trimmed);
  if (Number.isNaN(parsed.getTime())) {
    throw createError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return parsed;
}

function parsePositiveInteger(value, fieldName, createError) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw createError("invalid-argument", `${fieldName} sifirdan buyuk olmalidir.`);
  }
  return parsed;
}

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

async function getMyCompanyCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu islem icin giris yapmalisiniz.");
  }

  return withClient(
      {createError, actionLabel: "Firma bilgisi getirme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        const company = await findCompanyByOfficerUserId(
            client,
            appUser.id,
            createError,
        );
        return {
          company: serializeCompanyRow(company),
        };
      },
  );
}

async function upsertCompanyProfileCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu islem icin giris yapmalisiniz.");
  }

  const name = normalizeTrimmedString(data?.name);
  if (!name) {
    throw createError("invalid-argument", "Firma adi zorunludur.");
  }

  const transportType = parseTransportType(data?.transportType, createError);

  return withClient(
      {createError, actionLabel: "Firma kaydi"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["company_officer"], createError);
        const transportTypeColumn = await resolveCompanyTransportTypeColumn(
            client,
            createError,
        );

        const company = await withTransaction(client, async () => {
          const existingCompany = await findCompanyByOfficerUserId(
              client,
              appUser.id,
              createError,
          );
          if (!existingCompany) {
            const insertResult = await client.query(
                `
                  INSERT INTO companies (
                    id,
                    name,
                    officer_user_id,
                    ${quoteIdentifier(transportTypeColumn)},
                    status,
                    created_at,
                    updated_at
                  )
                  VALUES ($1, $2, $3, $4, 'pending', now(), now())
                  RETURNING
                    ${buildCompanySelectClause(quoteIdentifier(transportTypeColumn))}
                `,
                [randomUUID(), name, appUser.id, transportType],
            );
            return insertResult.rows[0];
          }

          const updateResult = await client.query(
              `
                UPDATE companies
                SET
                  name = $2,
                  ${quoteIdentifier(transportTypeColumn)} = $3,
                  status = 'pending',
                  rejection_reason = NULL,
                  updated_at = now()
                WHERE id = $1
                RETURNING
                  ${buildCompanySelectClause(quoteIdentifier(transportTypeColumn))}
              `,
              [existingCompany.id, name, transportType],
          );
          return updateResult.rows[0];
        });

        return {
          company: serializeCompanyRow(company),
        };
      },
  );
}

async function listCompaniesCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu islem icin giris yapmalisiniz.");
  }

  const status = parseApprovalStatus(data?.status, createError);
  if (status === "rejected") {
    throw createError(
        "invalid-argument",
        "Reddedilen firmalar bu ekran icin listelenmiyor.",
    );
  }

  return withClient(
      {createError, actionLabel: "Firma listeleme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["admin"], createError);
        const transportTypeColumn = await resolveCompanyTransportTypeColumn(
            client,
            createError,
        );

        const result = await client.query(
            `
              SELECT
                ${buildCompanySelectClause(quoteIdentifier(transportTypeColumn))}
              FROM companies
              WHERE status = $1
              ORDER BY updated_at DESC
            `,
            [status],
        );

        return {
          companies: result.rows.map(serializeCompanyRow),
        };
      },
  );
}

async function reviewCompanyCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu islem icin giris yapmalisiniz.");
  }

  const companyId = normalizeTrimmedString(data?.companyId);
  if (!companyId) {
    throw createError("invalid-argument", "companyId zorunludur.");
  }

  const status = parseApprovalStatus(data?.status, createError);
  const rejectionReason = normalizeTrimmedString(data?.rejectionReason);
  if (status === "rejected" && !rejectionReason) {
    throw createError("invalid-argument", "Red nedeni zorunludur.");
  }

  return withClient(
      {createError, actionLabel: "Firma inceleme"},
      async (client) => {
        const appUser = await loadRequiredAppUser(client, resolvedAuth, createError);
        assertAllowedRoles(appUser, ["admin"], createError);
        const transportTypeColumn = await resolveCompanyTransportTypeColumn(
            client,
            createError,
        );

        const result = await client.query(
            `
              UPDATE companies
              SET
                status = $2::approval_status,
                rejection_reason = CASE
                  WHEN $2::approval_status = 'rejected'::approval_status THEN $3
                  ELSE NULL
                END,
                updated_at = now()
              WHERE id = $1
              RETURNING
                ${buildCompanySelectClause(quoteIdentifier(transportTypeColumn))}
            `,
            [companyId, status, rejectionReason || null],
        );

        if (result.rows.length === 0) {
          throw createError("not-found", "Firma bulunamadi.");
        }

        return {
          company: serializeCompanyRow(result.rows[0]),
        };
      },
  );
}

async function listTripsCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu islem icin giris yapmalisiniz.");
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
    throw createError("unauthenticated", "Bu islem icin giris yapmalisiniz.");
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
    throw createError("unauthenticated", "Bu islem icin giris yapmalisiniz.");
  }

  const origin = normalizeTrimmedString(data?.origin);
  const destination = normalizeTrimmedString(data?.destination);
  if (!origin || !destination) {
    throw createError(
        "invalid-argument",
        "Kalkis ve varis alanlari zorunludur.",
    );
  }
  if (origin.toLowerCase() === destination.toLowerCase()) {
    throw createError(
        "invalid-argument",
        "Kalkis ve varis noktasi farkli olmalidir.",
    );
  }

  const departureAt = parseIsoDate(data?.departureAt, "departureAt", createError);
  const arrivalAt = parseIsoDate(data?.arrivalAt, "arrivalAt", createError);
  if (departureAt.getTime() >= arrivalAt.getTime()) {
    throw createError(
        "invalid-argument",
        "Varis saati kalkis saatinden sonra olmalidir.",
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

  return withClient(
      {createError, actionLabel: "Sefer olusturma"},
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
              "Firma bilgileri onaylanmadan sefer olusturulamaz.",
          );
        }
        if (company.transport_type !== requestedTransportType) {
          throw createError(
              "failed-precondition",
              "Firma yalnizca kendi ulasim turunde sefer acabilir.",
          );
        }

        return withTransaction(client, async () => {
          const countResult = await client.query(
              "SELECT COUNT(*)::int AS total FROM trips",
          );
          const serial = String(countResult.rows[0].total + 1).padStart(2, "0");
          const prefix = company.transport_type === "bus" ? "BUS" : "FLT";
          const month = String(departureAt.getUTCMonth() + 1).padStart(2, "0");
          const day = String(departureAt.getUTCDate()).padStart(2, "0");
          const tripCode = `${prefix}-${month}${day}-${serial}`;
          const tripId = randomUUID();

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
            trip: serializeTripRow(insertTripResult.rows[0]),
            seats: insertSeatsResult.rows.map(serializeTripSeatRow),
          };
        });
      },
  );
}

async function reviewTripCore({auth, data, createError}) {
  const resolvedAuth = resolveAuthContext({auth, data});
  if (!resolvedAuth) {
    throw createError("unauthenticated", "Bu islem icin giris yapmalisiniz.");
  }

  const tripId = normalizeTrimmedString(data?.tripId);
  if (!tripId) {
    throw createError("invalid-argument", "tripId zorunludur.");
  }

  const status = parseTripStatus(data?.status, createError);
  if (status !== "approved" && status !== "rejected") {
    throw createError(
        "invalid-argument",
        "Admin yalnizca approved veya rejected karari verebilir.",
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

createCallablePair("getMyCompany", getMyCompanyCore);
createCallablePair("upsertCompanyProfile", upsertCompanyProfileCore);
createCallablePair("listCompanies", listCompaniesCore);
createCallablePair("reviewCompany", reviewCompanyCore);
createCallablePair("listTrips", listTripsCore);
createCallablePair("getTripDetail", getTripDetailCore);
createCallablePair("createTrip", createTripCore);
createCallablePair("reviewTrip", reviewTripCore);
