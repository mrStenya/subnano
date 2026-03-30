-- ============================================================
-- SubNano — Test booking seed
-- Creates a test user profile + one confirmed booking to verify
-- that the availability check correctly blocks overlapping dates.
--
-- Run ONLY in development/staging — not in production.
-- ============================================================

-- Replace this UUID with an actual auth.users id from your Supabase project.
-- You can get it from: Dashboard → Authentication → Users
DO $$
DECLARE
  v_user_id   UUID := '00000000-0000-0000-0000-000000000099'; -- ← replace
  v_booking_id UUID := 'c0000000-0000-0000-0000-000000000001';
BEGIN

  -- Insert a profile if it doesn't exist
  INSERT INTO profiles (id, email, full_name, role)
  VALUES (v_user_id, 'testuser@example.com', 'Test User', 'customer')
  ON CONFLICT (id) DO NOTHING;

  -- Confirmed booking for SeaGlide Pro (b1000000-...-0002)
  -- Dates: next month for 5 days
  INSERT INTO bookings (
    id,
    user_id,
    scooter_id,
    pickup_point_id,
    start_date,
    end_date,
    total_amount,
    status
  )
  VALUES (
    v_booking_id,
    v_user_id,
    'b1000000-0000-0000-0000-000000000002', -- SeaGlide Pro
    'a1000000-0000-0000-0000-000000000001', -- Marina Bay
    CURRENT_DATE + INTERVAL '30 days',
    CURRENT_DATE + INTERVAL '35 days',
    600.00, -- 5 days × $120
    'confirmed'
  )
  ON CONFLICT (id) DO NOTHING;

  -- Matching payment record
  INSERT INTO payments (booking_id, type, amount, status)
  VALUES (v_booking_id, 'rental', 600.00, 'succeeded')
  ON CONFLICT DO NOTHING;

END $$;

-- ============================================================
-- Quick verification queries
-- ============================================================

-- 1. Should return TRUE (AquaJet Lite is free on those dates)
SELECT check_scooter_availability(
  'b1000000-0000-0000-0000-000000000001',   -- AquaJet Lite
  (CURRENT_DATE + INTERVAL '30 days')::DATE,
  (CURRENT_DATE + INTERVAL '35 days')::DATE
) AS aquajet_should_be_available;

-- 2. Should return FALSE (SeaGlide Pro is booked on those dates)
SELECT check_scooter_availability(
  'b1000000-0000-0000-0000-000000000002',   -- SeaGlide Pro
  (CURRENT_DATE + INTERVAL '30 days')::DATE,
  (CURRENT_DATE + INTERVAL '35 days')::DATE
) AS seaglide_should_be_unavailable;

-- 3. Should return TRUE (SeaGlide Pro is free before the blocked period)
SELECT check_scooter_availability(
  'b1000000-0000-0000-0000-000000000002',
  (CURRENT_DATE + INTERVAL '25 days')::DATE,
  (CURRENT_DATE + INTERVAL '29 days')::DATE
) AS seaglide_before_period_should_be_available;
