-- ============================================================
-- SubNano — Initial Schema
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE user_role AS ENUM ('customer', 'manager', 'admin');

CREATE TYPE scooter_status AS ENUM (
  'available',
  'rented',
  'maintenance',
  'retired'
);

CREATE TYPE booking_status AS ENUM (
  'draft',
  'confirmed',
  'active',
  'completed',
  'cancelled'
);

CREATE TYPE payment_status AS ENUM (
  'pending',
  'succeeded',
  'failed',
  'refunded'
);

CREATE TYPE deposit_status AS ENUM (
  'pending',
  'held',
  'released',
  'forfeited'
);

-- ============================================================
-- PROFILES
-- ============================================================
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  full_name   TEXT,
  phone       TEXT,
  avatar_url  TEXT,
  role        user_role NOT NULL DEFAULT 'customer',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-create profile on sign-up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- PICKUP POINTS
-- ============================================================
CREATE TABLE pickup_points (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  address     TEXT,
  lat         DOUBLE PRECISION,
  lng         DOUBLE PRECISION,
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SCOOTERS
-- ============================================================
CREATE TABLE scooters (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name              TEXT NOT NULL,
  description       TEXT,
  image_url         TEXT,
  price_per_day     NUMERIC(10, 2) NOT NULL CHECK (price_per_day > 0),
  status            scooter_status NOT NULL DEFAULT 'available',
  max_depth_m       NUMERIC(6, 1),
  max_speed_knots   NUMERIC(5, 1),
  battery_hours     NUMERIC(5, 1),
  weight_kg         NUMERIC(6, 1),
  pickup_point_id   UUID REFERENCES pickup_points(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- BOOKINGS
-- ============================================================
CREATE TABLE bookings (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  scooter_id       UUID NOT NULL REFERENCES scooters(id) ON DELETE RESTRICT,
  pickup_point_id  UUID REFERENCES pickup_points(id),
  start_date       DATE NOT NULL,
  end_date         DATE NOT NULL,
  total_amount     NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
  status           booking_status NOT NULL DEFAULT 'draft',
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_date_range CHECK (end_date > start_date)
);

-- Prevent double-booking: no two confirmed/active bookings for the same
-- scooter may overlap. Draft bookings are excluded intentionally.
CREATE UNIQUE INDEX unique_confirmed_booking_per_scooter
  ON bookings (scooter_id, start_date, end_date)
  WHERE status IN ('confirmed', 'active');

-- updated_at trigger
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookings_updated_at
  BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER scooters_updated_at
  BEFORE UPDATE ON scooters
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- PAYMENTS
-- ============================================================
CREATE TABLE payments (
  id                        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id                UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  type                      TEXT NOT NULL CHECK (type IN ('rental', 'deposit')),
  amount                    NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
  currency                  CHAR(3) NOT NULL DEFAULT 'usd',
  status                    payment_status NOT NULL DEFAULT 'pending',
  stripe_payment_intent_id  TEXT UNIQUE,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- DEPOSIT HOLDS
-- ============================================================
CREATE TABLE deposit_holds (
  id                        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id                UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  amount                    NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
  currency                  CHAR(3) NOT NULL DEFAULT 'usd',
  status                    deposit_status NOT NULL DEFAULT 'pending',
  stripe_payment_intent_id  TEXT UNIQUE,
  returned                  BOOLEAN NOT NULL DEFAULT FALSE,
  returned_at               TIMESTAMPTZ,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (booking_id)  -- one deposit hold per booking
);

CREATE TRIGGER deposit_holds_updated_at
  BEFORE UPDATE ON deposit_holds
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- DOCUMENTS
-- ============================================================
CREATE TABLE documents (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type         TEXT NOT NULL CHECK (type IN ('diving_license', 'passport', 'id_card', 'other')),
  file_url     TEXT NOT NULL,
  verified     BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at   DATE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DAMAGE REPORTS
-- ============================================================
CREATE TABLE damage_reports (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id   UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  reported_by  UUID NOT NULL REFERENCES profiles(id),
  description  TEXT NOT NULL,
  severity     TEXT NOT NULL CHECK (severity IN ('minor', 'major', 'total_loss')),
  photo_urls   TEXT[],
  resolved     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER damage_reports_updated_at
  BEFORE UPDATE ON damage_reports
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- SUPPORT TICKETS
-- ============================================================
CREATE TABLE support_tickets (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  booking_id   UUID REFERENCES bookings(id),
  category     TEXT NOT NULL DEFAULT 'general',
  subject      TEXT NOT NULL,
  message      TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER support_tickets_updated_at
  BEFORE UPDATE ON support_tickets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- AVAILABILITY FUNCTION
-- Returns TRUE if the scooter is available for the given date range.
-- Checks against confirmed and active bookings only.
-- ============================================================
CREATE OR REPLACE FUNCTION check_scooter_availability(
  p_scooter_id  UUID,
  p_start_date  DATE,
  p_end_date    DATE
)
RETURNS BOOLEAN AS $$
DECLARE
  overlap_count INT;
BEGIN
  SELECT COUNT(*)
  INTO overlap_count
  FROM bookings
  WHERE scooter_id = p_scooter_id
    AND status IN ('confirmed', 'active')
    AND start_date < p_end_date
    AND end_date   > p_start_date;

  RETURN overlap_count = 0;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- profiles: users can only read/update their own row
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- scooters: public read
ALTER TABLE scooters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "scooters_read_all" ON scooters
  FOR SELECT USING (TRUE);

-- pickup_points: public read
ALTER TABLE pickup_points ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pickup_points_read_all" ON pickup_points
  FOR SELECT USING (TRUE);

-- bookings: customers see only their own
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bookings_select_own" ON bookings
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "bookings_insert_own" ON bookings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- payments: customers see only their own (via booking)
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payments_select_own" ON payments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.id = payments.booking_id
        AND bookings.user_id = auth.uid()
    )
  );

-- deposit_holds: same as payments
ALTER TABLE deposit_holds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deposit_holds_select_own" ON deposit_holds
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.id = deposit_holds.booking_id
        AND bookings.user_id = auth.uid()
    )
  );

-- documents: own only
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "documents_select_own" ON documents
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "documents_insert_own" ON documents
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- support_tickets: own only
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "support_tickets_select_own" ON support_tickets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "support_tickets_insert_own" ON support_tickets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- damage_reports: customers can read their own (reporting done server-side)
ALTER TABLE damage_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "damage_reports_select_own" ON damage_reports
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.id = damage_reports.booking_id
        AND bookings.user_id = auth.uid()
    )
  );

-- ============================================================
-- SEED DATA (optional — remove before production)
-- ============================================================

INSERT INTO pickup_points (name, address) VALUES
  ('Marina Bay Dock A', '1 Marina Bay, Harbor Road'),
  ('Blue Lagoon Resort', '45 Reef Drive, Lagoon Bay'),
  ('Dive Center North', '12 Ocean Ave, North Beach');

INSERT INTO scooters (name, description, price_per_day, status, max_depth_m, max_speed_knots, battery_hours, weight_kg) VALUES
  ('SeaGlide Pro', 'Professional-grade scooter for experienced divers. Powerful and maneuverable.', 120.00, 'available', 40, 3.5, 2.5, 3.8),
  ('AquaJet Lite', 'Entry-level scooter perfect for beginners. Lightweight and easy to handle.', 75.00, 'available', 25, 2.0, 3.0, 2.5),
  ('DeepDiver 500', 'Built for technical dives. Maximum depth rating and extended battery life.', 180.00, 'available', 60, 3.0, 4.0, 4.5),
  ('CoralCruiser', 'Ideal for reef exploration. Quiet motor minimizes wildlife disturbance.', 95.00, 'maintenance', 30, 2.5, 3.5, 3.0);
