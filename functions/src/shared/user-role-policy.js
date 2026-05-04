const {parseRole} = require("./auth");

const DEFAULT_USER_ROLE = "normal_user";
const SELF_SERVICE_USER_ROLES = new Set([
  "normal_user",
  "company_officer",
]);

function resolveRequestedSelfServiceRole(requestedRole, createError) {
  if (typeof requestedRole !== "string" || !requestedRole.trim()) {
    return null;
  }

  const parsedRole = parseRole(requestedRole);
  if (!parsedRole) {
    throw createError("invalid-argument", "Gecersiz rol bilgisi gonderildi.");
  }

  if (!SELF_SERVICE_USER_ROLES.has(parsedRole)) {
    throw createError(
        "permission-denied",
        "Bu rol istemci tarafindan atanamaz.",
    );
  }

  return parsedRole;
}

function resolveUserRoleForSync({
  existingRole,
  roleFromToken,
  requestedSelfServiceRole,
}) {
  if (roleFromToken) {
    return roleFromToken;
  }

  if (typeof existingRole === "string" && existingRole.trim()) {
    return existingRole.trim();
  }

  if (requestedSelfServiceRole) {
    return requestedSelfServiceRole;
  }

  return DEFAULT_USER_ROLE;
}

module.exports = {
  DEFAULT_USER_ROLE,
  resolveRequestedSelfServiceRole,
  resolveUserRoleForSync,
};
