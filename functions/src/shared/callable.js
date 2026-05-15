const {
  functionsV1,
  HttpsError,
  logger,
  onCall,
} = require("../config/runtime");
const {
  getPool,
  POSTGRES_SECRET_NAMES,
  POSTGRES_SECRETS,
} = require("./postgres");

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
  secrets: POSTGRES_SECRETS,
};

const FUNCTION_V1_OPTIONS = {
  timeoutSeconds: 15,
  memory: "256MB",
  maxInstances: 10,
  secrets: POSTGRES_SECRET_NAMES,
};

function isCallableError(error) {
  return Boolean(
      error &&
      typeof error === "object" &&
      typeof error.code === "string" &&
      CALLABLE_ERROR_CODES.has(error.code),
  );
}

function createCallablePair(targetExports, name, coreHandler) {
  targetExports[name] = onCall(
      FUNCTION_V2_OPTIONS,
      async (request) => coreHandler({
        auth: request.auth,
        data: request.data,
        createError: (code, message) => new HttpsError(code, message),
      }),
  );

  targetExports[`${name}V1`] = functionsV1
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
        "PostgreSQL ayarları eksik. PGHOST/PGDATABASE/PGUSER/PGPASSWORD secret değerlerini güncelleyin.",
    );
  }

  if (error.code === "EAI_AGAIN" || error.code === "ENOTFOUND") {
    return createError(
        "failed-precondition",
        "PostgreSQL host çözümlenemedi. PGHOST değerini kontrol edin.",
    );
  }

  if (error.code === "28P01") {
    return createError(
        "failed-precondition",
        "PostgreSQL kimlik doğrulaması başarısız. PGUSER/PGPASSWORD değerlerini kontrol edin.",
    );
  }

  if (error.code === "42P01") {
    return createError(
        "failed-precondition",
        "PostgreSQL tabloları bulunamadı. companies, trips, trip_seats, reservations veya payments tablolarını kontrol edin.",
    );
  }

  if (error.code === "42703") {
    const columnMessage = typeof error.column === "string" && error.column.trim() ?
      ` Eksik veya hatalı kolon: ${error.column.trim()}.` :
      "";
    return createError(
        "failed-precondition",
        `PostgreSQL kolon yapısı kodla eşleşmiyor.${columnMessage} companies/trips/trip_seats/reservations/payments kolon isimlerini kontrol edin.`,
    );
  }

  if (error.code === "23503") {
    return createError(
        "failed-precondition",
        "İlişkili kayıt bulunamadı. app_users, companies, trips veya reservations bağlantılarını kontrol edin.",
    );
  }

  return createError("internal", `${actionLabel} başarısız oldu.`);
}

module.exports = {
  createCallablePair,
  withClient,
  withTransaction,
};
