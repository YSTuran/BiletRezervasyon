const FULL_REFUND_WINDOW_HOURS = 24;
const MIN_REFUND_WINDOW_MINUTES = 60;

function normalizeDate(value) {
  if (value instanceof Date) {
    return value;
  }
  return new Date(value);
}

function evaluateRefundPolicy({
  amountMinor,
  departureAt,
  actionAt = new Date(),
}) {
  const normalizedDepartureAt = normalizeDate(departureAt);
  const normalizedActionAt = normalizeDate(actionAt);
  const millisecondsUntilDeparture =
    normalizedDepartureAt.getTime() - normalizedActionAt.getTime();

  if (millisecondsUntilDeparture <= MIN_REFUND_WINDOW_MINUTES * 60 * 1000) {
    return {
      isEligible: false,
      refundAmountMinor: 0,
      refundSummary: "Kalkışa 1 saatten az kaldığı için iade yapılamaz.",
    };
  }

  if (millisecondsUntilDeparture >= FULL_REFUND_WINDOW_HOURS * 60 * 60 * 1000) {
    return {
      isEligible: true,
      refundAmountMinor: amountMinor,
      refundSummary: "Tam iade",
    };
  }

  return {
    isEligible: true,
    refundAmountMinor: Math.floor(amountMinor / 2),
    refundSummary: "Yüzde 50 iade",
  };
}

module.exports = {
  evaluateRefundPolicy,
};
