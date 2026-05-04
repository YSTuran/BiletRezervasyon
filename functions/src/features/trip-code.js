const {randomUUID} = require("node:crypto");

function createTripCode({transportType, departureAt}) {
  const prefix = transportType === "bus" ? "BUS" : "FLT";
  const month = String(departureAt.getUTCMonth() + 1).padStart(2, "0");
  const day = String(departureAt.getUTCDate()).padStart(2, "0");
  const suffix = randomUUID().split("-")[0].toUpperCase();
  return `${prefix}-${month}${day}-${suffix}`;
}

function isTripCodeConflict(error) {
  if (!error || error.code !== "23505") {
    return false;
  }

  const details = [
    error.constraint,
    error.detail,
    error.message,
  ].filter((value) => typeof value === "string" && value.trim().length > 0)
      .join(" ")
      .toLowerCase();

  return details.includes("trip_code");
}

module.exports = {
  createTripCode,
  isTripCodeConflict,
};
