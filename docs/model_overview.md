# Model Overview

## Firebase + PostgreSQL boundary
- Firebase Auth: kullanıcı kimliği (`firebase_uid`) için tek doğrulama noktası.
- PostgreSQL: şirket, sefer, koltuk, rezervasyon, ödeme ve onay süreçlerinin ana kaynağı.

## Core entities
- `app_users`: normal kullanıcı, firma yetkilisi, admin.
- `companies`: firma başvurusu ve admin onay durumu.
- `trips`: firma seferleri, admin onay durumu, fiyat ve kapasite.
- `trip_seats`: sefere ait tekil koltuklar.
- `reservations`: kullanıcı rezervasyon talebi/onayı/red/iptal/ödeme durumları.
- `payments`: onaylanan rezervasyonların ödeme kayıtları.

## Business rules covered
- 1 firma yetkilisi sadece 1 firmaya bağlı olabilir (`companies.officer_user_id UNIQUE`).
- Firma ve seferler admin onayı almadan aktif kullanıma açılmaz (`status` alanları).
- Koltuk çakışması engellenir: aktif rezervasyonlar için tek kayıt (`uq_reservations_active_seat`).
- Kullanıcı iptal etmediği sürece koltuk dolu görünür (aktif durumlarda koltuk bloke).
- Ödeme son tarihi rezervasyon üzerinde tutulur (`payment_deadline_at`).
