INSERT INTO roles (code, name, description)
VALUES
  ('normal_user', 'Normal Kullanıcı', 'Son kullanıcı rolüdür.'),
  ('company_officer', 'Firma Görevlisi', 'Şirket adına sefer ve rezervasyon yönetir.'),
  ('admin', 'Admin', 'Tüm onay ve sistem akışlarını yönetir.')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = now();

INSERT INTO permissions (code, name, description)
VALUES
  ('view_trips', 'Seferleri Görüntüle', 'Sefer listesi ve detaylarını görür.'),
  ('manage_company_profile', 'Firma Profili Yönet', 'Firma kaydı oluşturur ve günceller.'),
  ('manage_company_trips', 'Firma Seferlerini Yönet', 'Kendi seferlerini oluşturur ve izler.'),
  ('review_reservations', 'Rezervasyon İncele', 'Rezervasyon taleplerini onaylar veya reddeder.'),
  ('review_companies', 'Firma İncele', 'Firma başvurularını onaylar veya reddeder.'),
  ('review_trips', 'Sefer İncele', 'Seferleri onaylar veya reddeder.'),
  ('view_admin_dashboard', 'Admin Paneli', 'Admin paneli verilerini görür.'),
  ('view_company_operations', 'Firma Operasyon Paneli', 'Firma operasyon panelini görür.')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = now();

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p
  ON (r.code, p.code) IN (
    ('normal_user', 'view_trips'),
    ('company_officer', 'view_trips'),
    ('company_officer', 'manage_company_profile'),
    ('company_officer', 'manage_company_trips'),
    ('company_officer', 'review_reservations'),
    ('company_officer', 'view_company_operations'),
    ('admin', 'view_trips'),
    ('admin', 'review_companies'),
    ('admin', 'review_trips'),
    ('admin', 'view_admin_dashboard')
  )
ON CONFLICT DO NOTHING;
