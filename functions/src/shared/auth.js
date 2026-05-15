function fallbackFullName(email) {
  const prefix = email.split("@")[0] || "kullanıcı";
  const normalized = prefix.replace(/[._-]+/g, " ").trim();
  if (!normalized) {
    return "Yeni Kullanıcı";
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

module.exports = {
  parseRole,
  resolveAuthContext,
  resolveFullName,
  resolveRole,
  resolveRoleFromAuthToken,
};
