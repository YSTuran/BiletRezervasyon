const {randomUUID} = require("node:crypto");

const {resolveAuthContext} = require("../shared/auth");
const {withClient, withTransaction} = require("../shared/callable");
const {
  assertAllowedRoles,
  findCompanyByOfficerUserId,
  loadRequiredAppUser,
} = require("../shared/access");
const {normalizeTrimmedString, parseApprovalStatus, parseTransportType} = require("../shared/parsers");
const {serializeCompanyRow} = require("../shared/serializers");
const {
  buildCompanySelectClause,
  quoteIdentifier,
  resolveCompanyTransportTypeColumn,
} = require("../shared/postgres");

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

module.exports = {
  getMyCompanyCore,
  listCompaniesCore,
  reviewCompanyCore,
  upsertCompanyProfileCore,
};
