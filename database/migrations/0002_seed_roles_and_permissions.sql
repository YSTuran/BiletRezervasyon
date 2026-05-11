INSERT INTO roles (code, name, description)
VALUES
  ('normal_user', 'Normal Kullanici', 'Son kullanici roludur.'),
  ('company_officer', 'Firma Gorevlisi', 'Sirket adina sefer ve rezervasyon yonetir.'),
  ('admin', 'Admin', 'Tum onay ve sistem akislarini yonetir.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO permissions (code, name, description)
VALUES
  ('view_trips', 'Seferleri Goruntule', 'Sefer listesi ve detaylarini gorur.'),
  ('manage_company_profile', 'Firma Profili Yonet', 'Firma kaydi olusturur ve gunceller.'),
  ('manage_company_trips', 'Firma Seferlerini Yonet', 'Kendi seferlerini olusturur ve izler.'),
  ('review_reservations', 'Rezervasyon Incele', 'Rezervasyon taleplerini onaylar veya reddeder.'),
  ('review_companies', 'Firma Incele', 'Firma basvurularini onaylar veya reddeder.'),
  ('review_trips', 'Sefer Incele', 'Seferleri onaylar veya reddeder.'),
  ('view_admin_dashboard', 'Admin Dashboard', 'Admin dashboard verilerini gorur.'),
  ('view_company_operations', 'Firma Operasyon Paneli', 'Firma operasyon panelini gorur.')
ON CONFLICT (code) DO NOTHING;

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
