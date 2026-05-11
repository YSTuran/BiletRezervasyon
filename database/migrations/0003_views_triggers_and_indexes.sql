CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_legacy_role_to_user_roles()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_role_id uuid;
BEGIN
  SELECT id INTO v_role_id
  FROM roles
  WHERE code = NEW.role::text
  LIMIT 1;

  IF v_role_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM user_roles ur
    WHERE ur.user_id = NEW.id
      AND ur.role_id = v_role_id
      AND ur.company_id IS NULL
      AND ur.revoked_at IS NULL
  ) THEN
    INSERT INTO user_roles (user_id, role_id, assigned_at, is_active)
    VALUES (NEW.id, v_role_id, now(), true);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_users_set_updated_at ON app_users;
CREATE TRIGGER trg_app_users_set_updated_at
BEFORE UPDATE ON app_users
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_companies_set_updated_at ON companies;
CREATE TRIGGER trg_companies_set_updated_at
BEFORE UPDATE ON companies
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_trips_set_updated_at ON trips;
CREATE TRIGGER trg_trips_set_updated_at
BEFORE UPDATE ON trips
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_reservations_set_updated_at ON reservations;
CREATE TRIGGER trg_reservations_set_updated_at
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_payments_set_updated_at ON payments;
CREATE TRIGGER trg_payments_set_updated_at
BEFORE UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_roles_set_updated_at ON roles;
CREATE TRIGGER trg_roles_set_updated_at
BEFORE UPDATE ON roles
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_permissions_set_updated_at ON permissions;
CREATE TRIGGER trg_permissions_set_updated_at
BEFORE UPDATE ON permissions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_user_roles_set_updated_at ON user_roles;
CREATE TRIGGER trg_user_roles_set_updated_at
BEFORE UPDATE ON user_roles
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_sync_legacy_role_to_user_roles ON app_users;
CREATE TRIGGER trg_sync_legacy_role_to_user_roles
AFTER INSERT OR UPDATE OF role ON app_users
FOR EACH ROW
EXECUTE FUNCTION public.sync_legacy_role_to_user_roles();

CREATE UNIQUE INDEX IF NOT EXISTS ux_companies_officer_user_id
ON companies (officer_user_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_payments_reservation_id
ON payments (reservation_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_reservations_active_trip_seat
ON reservations (trip_id, trip_seat_id)
WHERE status IN ('pending_approval', 'approved', 'paid');

CREATE UNIQUE INDEX IF NOT EXISTS ux_reservations_active_user_trip
ON reservations (trip_id, user_id)
WHERE status IN ('pending_approval', 'approved', 'paid');

CREATE INDEX IF NOT EXISTS ix_companies_status ON companies (status);
CREATE INDEX IF NOT EXISTS ix_trips_company_id ON trips (company_id);
CREATE INDEX IF NOT EXISTS ix_trips_status_departure_at ON trips (status, departure_at);
CREATE INDEX IF NOT EXISTS ix_reservations_trip_id_status ON reservations (trip_id, status);
CREATE INDEX IF NOT EXISTS ix_reservations_user_id_status ON reservations (user_id, status);
CREATE INDEX IF NOT EXISTS ix_payments_status ON payments (status);
CREATE INDEX IF NOT EXISTS ix_user_roles_user_id_active ON user_roles (user_id, is_active);

CREATE OR REPLACE VIEW public.v_app_user_primary_role AS
SELECT
  u.id AS user_id,
  COALESCE(
    (
      SELECT r.code
      FROM user_roles ur
      JOIN roles r ON r.id = ur.role_id
      WHERE ur.user_id = u.id
        AND ur.company_id IS NULL
        AND ur.is_active = true
        AND ur.revoked_at IS NULL
        AND (ur.expires_at IS NULL OR ur.expires_at > now())
      ORDER BY
        CASE r.code
          WHEN 'admin' THEN 1
          WHEN 'company_officer' THEN 2
          ELSE 3
        END,
        ur.assigned_at DESC
      LIMIT 1
    ),
    u.role::text
  ) AS role_code
FROM app_users u;

CREATE OR REPLACE VIEW public.v_user_effective_permissions AS
SELECT
  ur.user_id,
  ur.company_id,
  r.code AS role_code,
  p.code AS permission_code
FROM user_roles ur
JOIN roles r ON r.id = ur.role_id
JOIN role_permissions rp ON rp.role_id = ur.role_id
JOIN permissions p ON p.id = rp.permission_id
WHERE ur.is_active = true
  AND ur.revoked_at IS NULL
  AND (ur.expires_at IS NULL OR ur.expires_at > now());
