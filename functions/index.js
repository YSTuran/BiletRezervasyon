const {setGlobalOptions, logger} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const functionsV1 = require("firebase-functions/v1");
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
