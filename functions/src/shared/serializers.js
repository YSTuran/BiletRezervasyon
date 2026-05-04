function serializeDate(value) {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  return new Date(value).toISOString();
}

function serializeCompanyRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    name: row.name,
    officer_user_id: row.officer_user_id,
    transport_type: row.transport_type,
    status: row.status,
    reviewed_by_admin_id: row.reviewed_by_admin_id,
    reviewed_at: serializeDate(row.reviewed_at),
    rejection_reason: row.rejection_reason,
    created_at: serializeDate(row.created_at),
    updated_at: serializeDate(row.updated_at),
  };
}

function serializeTripRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    company_id: row.company_id,
    created_by_officer_id: row.created_by_officer_id,
    transport_type: row.transport_type,
    trip_code: row.trip_code,
    origin: row.origin,
    destination: row.destination,
    departure_at: serializeDate(row.departure_at),
    arrival_at: serializeDate(row.arrival_at),
    seat_capacity: row.seat_capacity,
    price_minor: row.price_minor,
    status: row.status,
    reviewed_by_admin_id: row.reviewed_by_admin_id,
    reviewed_at: serializeDate(row.reviewed_at),
    rejection_reason: row.rejection_reason,
    created_at: serializeDate(row.created_at),
    updated_at: serializeDate(row.updated_at),
  };
}

function serializeTripSeatRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    trip_id: row.trip_id,
    seat_number: row.seat_number,
    created_at: serializeDate(row.created_at),
  };
}

function serializeReservationRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    trip_id: row.trip_id,
    trip_seat_id: row.trip_seat_id,
    user_id: row.user_id,
    status: row.status,
    requested_at: serializeDate(row.requested_at),
    payment_deadline_at: serializeDate(row.payment_deadline_at),
    decided_by_officer_id: row.decided_by_officer_id,
    decided_at: serializeDate(row.decided_at),
    rejection_reason: row.rejection_reason,
    paid_at: serializeDate(row.paid_at),
    cancelled_at: serializeDate(row.cancelled_at),
    seat_number: row.seat_number,
    trip_code: row.trip_code,
    trip_origin: row.trip_origin,
    trip_destination: row.trip_destination,
    trip_departure_at: serializeDate(row.trip_departure_at),
    trip_arrival_at: serializeDate(row.trip_arrival_at),
    trip_transport_type: row.trip_transport_type,
    company_name: row.company_name,
  };
}

function serializePaymentRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    reservation_id: row.reservation_id,
    amount_minor: row.amount_minor,
    status: row.status,
    provider: row.provider,
    provider_payment_id: row.provider_payment_id,
    created_at: serializeDate(row.created_at),
    updated_at: serializeDate(row.updated_at),
    paid_at: serializeDate(row.paid_at),
    reservation_status: row.reservation_status,
    payment_deadline_at: serializeDate(row.payment_deadline_at),
    seat_number: row.seat_number,
    trip_code: row.trip_code,
    trip_origin: row.trip_origin,
    trip_destination: row.trip_destination,
    trip_departure_at: serializeDate(row.trip_departure_at),
    trip_arrival_at: serializeDate(row.trip_arrival_at),
    trip_transport_type: row.trip_transport_type,
    company_name: row.company_name,
  };
}

module.exports = {
  serializeCompanyRow,
  serializeDate,
  serializePaymentRow,
  serializeReservationRow,
  serializeTripRow,
  serializeTripSeatRow,
};
