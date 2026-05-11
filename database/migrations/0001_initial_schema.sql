CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'approval_status') THEN
    CREATE TYPE approval_status AS ENUM ('pending', 'approved', 'rejected');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
    CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'failed', 'refunded');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reservation_status') THEN
    CREATE TYPE reservation_status AS ENUM (
      'pending_approval',
      'approved',
      'rejected',
      'cancelled_by_user',
      'expired',
      'paid'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transport_type') THEN
    CREATE TYPE transport_type AS ENUM ('bus', 'flight');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trip_status') THEN
    CREATE TYPE trip_status AS ENUM (
      'pending_approval',
      'approved',
      'rejected',
      'cancelled'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('normal_user', 'company_officer', 'admin');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS app_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid text NOT NULL UNIQUE,
  email text NOT NULL,
  full_name text NOT NULL,
  role user_role NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  officer_user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE RESTRICT,
  status approval_status NOT NULL DEFAULT 'pending',
  rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  transport_type transport_type,
  CONSTRAINT company_review_state_check
    CHECK (
      (
        status = 'pending' AND rejection_reason IS NULL
      ) OR (
        status = 'approved' AND rejection_reason IS NULL
      ) OR (
        status = 'rejected' AND rejection_reason IS NOT NULL
      )
    )
);

CREATE TABLE IF NOT EXISTS trips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  created_by_officer_id uuid NOT NULL REFERENCES app_users(id) ON DELETE RESTRICT,
  transport_type transport_type NOT NULL,
  trip_code text NOT NULL UNIQUE,
  origin text NOT NULL,
  destination text NOT NULL,
  departure_at timestamptz NOT NULL,
  arrival_at timestamptz NOT NULL,
  seat_capacity integer NOT NULL,
  price_minor integer NOT NULL,
  status trip_status NOT NULL DEFAULT 'pending_approval',
  rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT trip_origin_destination_check CHECK (origin <> destination),
  CONSTRAINT trip_time_check CHECK (departure_at < arrival_at),
  CONSTRAINT trips_price_minor_check CHECK (price_minor >= 0),
  CONSTRAINT trips_seat_capacity_check CHECK (seat_capacity > 0),
  CONSTRAINT trip_review_state_check
    CHECK (
      (
        status = 'pending_approval' AND rejection_reason IS NULL
      ) OR (
        status = 'approved' AND rejection_reason IS NULL
      ) OR (
        status = 'rejected' AND rejection_reason IS NOT NULL
      ) OR (
        status = 'cancelled'
      )
    )
);

CREATE TABLE IF NOT EXISTS trip_seats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  seat_number text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_trip_seats_trip_seat_number UNIQUE (trip_id, seat_number)
);

CREATE TABLE IF NOT EXISTS reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  trip_seat_id uuid NOT NULL REFERENCES trip_seats(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE RESTRICT,
  status reservation_status NOT NULL DEFAULT 'pending_approval',
  requested_at timestamptz NOT NULL DEFAULT now(),
  payment_deadline_at timestamptz NOT NULL,
  rejection_reason text,
  paid_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reservation_payment_deadline_check
    CHECK (payment_deadline_at >= requested_at),
  CONSTRAINT reservation_state_check
    CHECK (
      (
        status = 'pending_approval' AND rejection_reason IS NULL
      ) OR (
        status = 'approved' AND rejection_reason IS NULL
      ) OR (
        status = 'rejected' AND rejection_reason IS NOT NULL
      ) OR (
        status = 'cancelled_by_user' AND cancelled_at IS NOT NULL
      ) OR (
        status = 'expired'
      ) OR (
        status = 'paid' AND paid_at IS NOT NULL
      )
    )
);

CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
  amount_minor integer NOT NULL,
  status payment_status NOT NULL DEFAULT 'pending',
  provider text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  paid_at timestamptz,
  CONSTRAINT payments_amount_minor_check CHECK (amount_minor > 0),
  CONSTRAINT payment_paid_at_check
    CHECK (
      (
        status = 'paid' AND paid_at IS NOT NULL
      ) OR (
        status <> 'paid'
      )
    )
);

CREATE TABLE IF NOT EXISTS roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  is_system boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  company_id uuid REFERENCES companies(id) ON DELETE CASCADE,
  assigned_by_user_id uuid REFERENCES app_users(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  revoke_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_roles_active_revoked_check
    CHECK (((is_active = true) AND revoked_at IS NULL) OR (is_active = false)),
  CONSTRAINT user_roles_expiry_check
    CHECK (expires_at IS NULL OR expires_at > assigned_at),
  CONSTRAINT user_roles_revoked_check
    CHECK (revoked_at IS NULL OR revoked_at >= assigned_at)
);
