DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'refund_request_status') THEN
    CREATE TYPE refund_request_status AS ENUM ('pending', 'approved', 'rejected');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'reservation_status'
      AND e.enumlabel = 'cancelled_by_company'
  ) THEN
    ALTER TYPE reservation_status ADD VALUE 'cancelled_by_company';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS user_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  related_trip_id uuid REFERENCES trips(id) ON DELETE SET NULL,
  related_reservation_id uuid REFERENCES reservations(id) ON DELETE SET NULL,
  related_payment_id uuid REFERENCES payments(id) ON DELETE SET NULL,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS refund_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
  payment_id uuid NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  requested_by_user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE RESTRICT,
  decided_by_officer_id uuid REFERENCES app_users(id) ON DELETE SET NULL,
  status refund_request_status NOT NULL DEFAULT 'pending',
  reason text,
  rejection_reason text,
  refund_amount_minor integer NOT NULL,
  refund_summary text NOT NULL,
  requested_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT refund_requests_amount_check CHECK (refund_amount_minor >= 0),
  CONSTRAINT refund_requests_decision_check
    CHECK (
      (
        status = 'pending'
        AND decided_by_officer_id IS NULL
        AND decided_at IS NULL
        AND rejection_reason IS NULL
      ) OR (
        status = 'approved'
        AND decided_by_officer_id IS NOT NULL
        AND decided_at IS NOT NULL
        AND rejection_reason IS NULL
      ) OR (
        status = 'rejected'
        AND decided_by_officer_id IS NOT NULL
        AND decided_at IS NOT NULL
        AND rejection_reason IS NOT NULL
      )
    )
);

ALTER TABLE reservations
DROP CONSTRAINT IF EXISTS reservation_state_check;

ALTER TABLE reservations
ADD CONSTRAINT reservation_state_check
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
    status::text = 'cancelled_by_company' AND cancelled_at IS NOT NULL
  ) OR (
    status = 'expired'
  ) OR (
    status = 'paid' AND paid_at IS NOT NULL
  )
);

DROP TRIGGER IF EXISTS trg_refund_requests_set_updated_at ON refund_requests;
CREATE TRIGGER trg_refund_requests_set_updated_at
BEFORE UPDATE ON refund_requests
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS ix_user_notifications_user_id_created_at
ON user_notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_user_notifications_user_id_read_at
ON user_notifications (user_id, read_at);

CREATE INDEX IF NOT EXISTS ix_refund_requests_status_requested_at
ON refund_requests (status, requested_at);

CREATE UNIQUE INDEX IF NOT EXISTS ux_refund_requests_active_payment
ON refund_requests (payment_id)
WHERE status = 'pending';

UPDATE roles
SET
  name = role_labels.name,
  description = role_labels.description,
  updated_at = now()
FROM (
  VALUES
    ('normal_user', 'Normal Kullanıcı', 'Son kullanıcı rolüdür.'),
    ('company_officer', 'Firma Görevlisi', 'Şirket adına sefer ve rezervasyon yönetir.'),
    ('admin', 'Admin', 'Tüm onay ve sistem akışlarını yönetir.')
) AS role_labels(code, name, description)
WHERE roles.code = role_labels.code;

UPDATE permissions
SET
  name = permission_labels.name,
  description = permission_labels.description,
  updated_at = now()
FROM (
  VALUES
    ('view_trips', 'Seferleri Görüntüle', 'Sefer listesi ve detaylarını görür.'),
    ('manage_company_profile', 'Firma Profili Yönet', 'Firma kaydı oluşturur ve günceller.'),
    ('manage_company_trips', 'Firma Seferlerini Yönet', 'Kendi seferlerini oluşturur ve izler.'),
    ('review_reservations', 'Rezervasyon İncele', 'Rezervasyon taleplerini onaylar veya reddeder.'),
    ('review_companies', 'Firma İncele', 'Firma başvurularını onaylar veya reddeder.'),
    ('review_trips', 'Sefer İncele', 'Seferleri onaylar veya reddeder.'),
    ('view_admin_dashboard', 'Admin Paneli', 'Admin paneli verilerini görür.'),
    ('view_company_operations', 'Firma Operasyon Paneli', 'Firma operasyon panelini görür.')
) AS permission_labels(code, name, description)
WHERE permissions.code = permission_labels.code;
