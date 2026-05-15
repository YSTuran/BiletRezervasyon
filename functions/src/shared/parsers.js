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
  throw createError("invalid-argument", "Ulaşım türü bus veya flight olmalıdır.");
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
      "Firma durumu pending, approved veya rejected olmalıdır.",
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
      "Sefer durumu pending_approval, approved, rejected veya cancelled olmalıdır.",
  );
}

function parseReservationStatus(value, createError) {
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
  if (normalized === "cancelled_by_user") {
    return "cancelled_by_user";
  }
  if (normalized === "cancelled_by_company") {
    return "cancelled_by_company";
  }
  if (normalized === "expired") {
    return "expired";
  }
  if (normalized === "paid") {
    return "paid";
  }
  throw createError(
      "invalid-argument",
      "Rezervasyon durumu pending_approval, approved, rejected, cancelled_by_user, cancelled_by_company, expired veya paid olmalıdır.",
  );
}

function parseRefundRequestStatus(value, createError) {
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
      "İade talebi durumu pending, approved veya rejected olmalıdır.",
  );
}

const ACTIVE_RESERVATION_STATUSES_SQL = `
  ARRAY[
    'pending_approval'::reservation_status,
    'approved'::reservation_status,
    'paid'::reservation_status
  ]
`;

function parseIsoDate(value, fieldName, createError) {
  const trimmed = normalizeTrimmedString(value);
  if (!trimmed) {
    throw createError("invalid-argument", `${fieldName} zorunludur.`);
  }
  const parsed = new Date(trimmed);
  if (Number.isNaN(parsed.getTime())) {
    throw createError("invalid-argument", `${fieldName} geçersiz.`);
  }
  return parsed;
}

function parsePositiveInteger(value, fieldName, createError) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw createError("invalid-argument", `${fieldName} sıfırdan büyük olmalıdır.`);
  }
  return parsed;
}

module.exports = {
  ACTIVE_RESERVATION_STATUSES_SQL,
  normalizeTrimmedString,
  parseApprovalStatus,
  parseIsoDate,
  parsePositiveInteger,
  parseRefundRequestStatus,
  parseReservationStatus,
  parseTransportType,
  parseTripStatus,
};
