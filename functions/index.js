const {initializeFirebaseRuntime} = require("./src/config/runtime");
const {createCallablePair} = require("./src/shared/callable");
const {
  createReservationCore,
  createTripCore,
  getMyCompanyCore,
  getReservationPaymentCore,
  getTripDetailCore,
  getTripReservationAvailabilityCore,
  listCompaniesCore,
  listPaymentsCore,
  listReservationsCore,
  listTripsCore,
  processFakePaymentCore,
  requestRefundCore,
  reviewCompanyCore,
  reviewReservationCore,
  reviewTripCore,
  syncUserCore,
  upsertCompanyProfileCore,
  cancelReservationCore,
} = require("./src/features");

initializeFirebaseRuntime();

const callableHandlers = {
  syncUserToPostgres: syncUserCore,
  getMyCompany: getMyCompanyCore,
  upsertCompanyProfile: upsertCompanyProfileCore,
  listCompanies: listCompaniesCore,
  reviewCompany: reviewCompanyCore,
  listTrips: listTripsCore,
  getTripDetail: getTripDetailCore,
  createTrip: createTripCore,
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
};

for (const [name, handler] of Object.entries(callableHandlers)) {
  createCallablePair(exports, name, handler);
}
