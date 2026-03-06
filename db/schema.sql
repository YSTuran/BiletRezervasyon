CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_role AS ENUM ('normal_user', 'company_officer', 'admin');
CREATE TYPE approval_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE transport_type AS ENUM ('bus', 'flight');
CREATE TYPE trip_status AS ENUM ('pending_approval', 'approved', 'rejected', 'cancelled');
CREATE TYPE reservation_status AS ENUM (
  'pending_approval',
  'approved',
  'rejected',
  'cancelled_by_user',
  'expired',
  'paid'
);
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'failed', 'refunded');

CREATE TABLE app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  role user_role NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  officer_user_id UUID NOT NULL UNIQUE REFERENCES app_users(id),
  status approval_status NOT NULL DEFAULT 'pending',
  reviewed_by_admin_id UUID REFERENCES app_users(id),
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT company_review_state_check CHECK (
    (status = 'pending' AND reviewed_by_admin_id IS NULL AND reviewed_at IS NULL AND rejection_reason IS NULL)
    OR (status = 'approved' AND reviewed_by_admin_id IS NOT NULL AND reviewed_at IS NOT NULL AND rejection_reason IS NULL)
    OR (status = 'rejected' AND reviewed_by_admin_id IS NOT NULL AND reviewed_at IS NOT NULL AND rejection_reason IS NOT NULL)
  )
);

CREATE TABLE trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  created_by_officer_id UUID NOT NULL REFERENCES app_users(id),
  transport_type transport_type NOT NULL,
  trip_code TEXT NOT NULL,
  origin TEXT NOT NULL,
  destination TEXT NOT NULL,
  departure_at TIMESTAMPTZ NOT NULL,
  arrival_at TIMESTAMPTZ NOT NULL,
  seat_capacity INT NOT NULL CHECK (seat_capacity > 0),
  price_minor INT NOT NULL CHECK (price_minor >= 0),
  status trip_status NOT NULL DEFAULT 'pending_approval',
  reviewed_by_admin_id UUID REFERENCES app_users(id),
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT trip_time_check CHECK (departure_at < arrival_at),
  CONSTRAINT trip_review_state_check CHECK (
    (status = 'pending_approval' AND reviewed_by_admin_id IS NULL AND reviewed_at IS NULL AND rejection_reason IS NULL)
    OR (status = 'approved' AND reviewed_by_admin_id IS NOT NULL AND reviewed_at IS NOT NULL AND rejection_reason IS NULL)
    OR (status = 'rejected' AND reviewed_by_admin_id IS NOT NULL AND reviewed_at IS NOT NULL AND rejection_reason IS NOT NULL)
    OR (status = 'cancelled')
  ),
  CONSTRAINT trip_origin_destination_check CHECK (origin <> destination)
);

CREATE UNIQUE INDEX uq_trips_company_code_departure
  ON trips (company_id, trip_code, departure_at);

CREATE TABLE trip_seats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  seat_number TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (trip_id, seat_number),
  UNIQUE (id, trip_id)
);

CREATE TABLE reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  trip_seat_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES app_users(id),
  status reservation_status NOT NULL DEFAULT 'pending_approval',
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  payment_deadline_at TIMESTAMPTZ NOT NULL,
  decided_by_officer_id UUID REFERENCES app_users(id),
  decided_at TIMESTAMPTZ,
  rejection_reason TEXT,
  paid_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_reservation_trip_seat
    FOREIGN KEY (trip_seat_id, trip_id) REFERENCES trip_seats(id, trip_id) ON DELETE CASCADE,
  CONSTRAINT reservation_payment_deadline_check CHECK (payment_deadline_at >= requested_at),
  CONSTRAINT reservation_state_check CHECK (
    (status = 'pending_approval' AND decided_by_officer_id IS NULL AND decided_at IS NULL AND rejection_reason IS NULL)
    OR (status = 'approved' AND decided_by_officer_id IS NOT NULL AND decided_at IS NOT NULL AND rejection_reason IS NULL)
    OR (status = 'rejected' AND decided_by_officer_id IS NOT NULL AND decided_at IS NOT NULL AND rejection_reason IS NOT NULL)
    OR (status = 'cancelled_by_user' AND cancelled_at IS NOT NULL)
    OR (status = 'expired')
    OR (status = 'paid' AND paid_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_reservations_active_seat
  ON reservations (trip_seat_id)
  WHERE status IN ('pending_approval', 'approved', 'paid');

CREATE INDEX idx_reservations_user_id ON reservations (user_id);
CREATE INDEX idx_reservations_trip_id ON reservations (trip_id);

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
  amount_minor INT NOT NULL CHECK (amount_minor > 0),
  status payment_status NOT NULL DEFAULT 'pending',
  provider TEXT,
  provider_payment_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at TIMESTAMPTZ,
  CONSTRAINT payment_paid_at_check CHECK (
    (status = 'paid' AND paid_at IS NOT NULL)
    OR (status <> 'paid')
  )
);

CREATE INDEX idx_payments_reservation_id ON payments (reservation_id);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_app_users_updated_at
BEFORE UPDATE ON app_users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_companies_updated_at
BEFORE UPDATE ON companies
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_trips_updated_at
BEFORE UPDATE ON trips
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_reservations_updated_at
BEFORE UPDATE ON reservations
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_payments_updated_at
BEFORE UPDATE ON payments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
