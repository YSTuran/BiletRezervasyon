const {initializeFirebaseRuntime} = require("./src/config/runtime");
const {onSchedule} = require("./src/config/runtime");
const {createCallablePair} = require("./src/shared/callable");
const {
  getPool,
  POSTGRES_SECRETS,
} = require("./src/shared/postgres");
const {expireOverdueReservations} = require("./src/shared/access");
const {
  createReservationCore,
  createTripCore,
  getAdminDashboardCore,
  getCompanyOperationsDashboardCore,
  getMyCompanyCore,
  getReservationPaymentCore,
  getTripDetailCore,
  getTripReservationAvailabilityCore,
  listCompaniesCore,
  listPaymentsCore,
  listNotificationsCore,
  listReservationsCore,
  listTripsCore,
  processFakePaymentCore,
  requestRefundCore,
  markAllNotificationsReadCore,
  markNotificationReadCore,
  reviewRefundRequestCore,
  reviewCompanyCore,
  reviewReservationCore,
  reviewTripCore,
  syncUserCore,
  upsertCompanyProfileCore,
  cancelReservationCore,
  cancelTripCore,
  deleteMyAccountCore,
} = require("./src/features");

initializeFirebaseRuntime();

const callableHandlers = {
  syncUserToPostgres: syncUserCore,
  deleteMyAccount: deleteMyAccountCore,
  getCompanyOperationsDashboard: getCompanyOperationsDashboardCore,
  getAdminDashboard: getAdminDashboardCore,
  listNotifications: listNotificationsCore,
  markNotificationRead: markNotificationReadCore,
  markAllNotificationsRead: markAllNotificationsReadCore,
  getMyCompany: getMyCompanyCore,
  upsertCompanyProfile: upsertCompanyProfileCore,
  listCompanies: listCompaniesCore,
  reviewCompany: reviewCompanyCore,
  listTrips: listTripsCore,
  getTripDetail: getTripDetailCore,
  createTrip: createTripCore,
  cancelTrip: cancelTripCore,
  reviewTrip: reviewTripCore,
  listReservations: listReservationsCore,
  getTripReservationAvailability: getTripReservationAvailabilityCore,
  createReservation: createReservationCore,
  cancelReservation: cancelReservationCore,
  reviewReservation: reviewReservationCore,
  listPayments: listPaymentsCore,
  getReservationPayment: getReservationPaymentCore,
  processFakePayment: processFakePaymentCore,
  requestRefund: requestRefundCore,
  reviewRefundRequest: reviewRefundRequestCore,
};

for (const [name, handler] of Object.entries(callableHandlers)) {
  createCallablePair(exports, name, handler);
}

exports.expireOverdueReservationsJob = onSchedule(
    {
      schedule: "every 15 minutes",
      timeZone: "Europe/Istanbul",
      timeoutSeconds: 60,
      memory: "256MiB",
      secrets: POSTGRES_SECRETS,
    },
    async () => {
      const client = await getPool().connect();
      try {
        await expireOverdueReservations(client);
      } finally {
        client.release();
      }
    },
);
