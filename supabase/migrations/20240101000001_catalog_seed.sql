-- ============================================================
-- SubNano — Catalog seed data
-- Run after initial_schema migration.
-- Safe to re-run (uses ON CONFLICT DO NOTHING).
-- ============================================================

-- ============================================================
-- PICKUP POINTS
-- ============================================================
INSERT INTO pickup_points (id, name, address, lat, lng, active) VALUES
  (
    'a1000000-0000-0000-0000-000000000001',
    'Marina Bay Dive Center',
    'Pier 3, Marina Bay Harbor, Dock A',
    1.2789, 103.8536,
    TRUE
  ),
  (
    'a1000000-0000-0000-0000-000000000002',
    'Blue Lagoon Resort',
    '45 Reef Drive, Lagoon Bay, Sentosa',
    1.2496, 103.8303,
    TRUE
  ),
  (
    'a1000000-0000-0000-0000-000000000003',
    'Coral Reef Club',
    '12 Ocean Avenue, North Shore',
    1.3048, 103.7726,
    TRUE
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- SCOOTERS
-- ============================================================
INSERT INTO scooters (
  id,
  name,
  description,
  image_url,
  price_per_day,
  status,
  max_depth_m,
  max_speed_knots,
  battery_hours,
  weight_kg,
  pickup_point_id
) VALUES
  -- 1. Entry-level, available
  (
    'b1000000-0000-0000-0000-000000000001',
    'AquaJet Lite',
    'Perfect for first-time divers. Lightweight, stable, and easy to handle. '
    'Great for shallow reef exploration down to 25 m.',
    NULL,
    75.00,
    'available',
    25.0,
    2.0,
    3.0,
    2.5,
    'a1000000-0000-0000-0000-000000000001'
  ),
  -- 2. Mid-range, available
  (
    'b1000000-0000-0000-0000-000000000002',
    'SeaGlide Pro',
    'Professional-grade scooter for experienced divers. Powerful dual motors '
    'give you speed and precision at depth. Foldable handles for compact transport.',
    NULL,
    120.00,
    'available',
    40.0,
    3.5,
    2.5,
    3.8,
    'a1000000-0000-0000-0000-000000000001'
  ),
  -- 3. Technical / deep, available
  (
    'b1000000-0000-0000-0000-000000000003',
    'DeepDiver 500',
    'Built for technical dives. Extended battery life and a depth-rated housing '
    'make it the go-to choice for underwater photographers and wreck divers.',
    NULL,
    180.00,
    'available',
    60.0,
    3.0,
    4.0,
    4.5,
    'a1000000-0000-0000-0000-000000000002'
  ),
  -- 4. Eco / reef, available
  (
    'b1000000-0000-0000-0000-000000000004',
    'CoralCruiser',
    'Low-noise brushless motor minimises disturbance to marine wildlife. '
    'Ideal for guided reef tours and marine research.',
    NULL,
    95.00,
    'available',
    30.0,
    2.5,
    3.5,
    3.0,
    'a1000000-0000-0000-0000-000000000002'
  ),
  -- 5. Premium, available
  (
    'b1000000-0000-0000-0000-000000000005',
    'Titan X700',
    'Top-of-the-line scooter with titanium housing, dual-battery system and '
    'electronic depth limiter. Favoured by commercial divers.',
    NULL,
    250.00,
    'available',
    80.0,
    4.0,
    5.5,
    5.2,
    'a1000000-0000-0000-0000-000000000003'
  ),
  -- 6. In maintenance — visible in catalog but not bookable
  (
    'b1000000-0000-0000-0000-000000000006',
    'WaveRunner 200',
    'Versatile scooter for snorkelling and shallow diving. Currently undergoing '
    'scheduled battery maintenance.',
    NULL,
    65.00,
    'maintenance',
    20.0,
    1.8,
    2.0,
    2.2,
    'a1000000-0000-0000-0000-000000000001'
  ),
  -- 7. Rented out right now
  (
    'b1000000-0000-0000-0000-000000000007',
    'NanoSub Classic',
    'The model that started it all. Reliable, simple, and loved by dive clubs '
    'worldwide. Currently out with a customer.',
    NULL,
    55.00,
    'rented',
    20.0,
    1.5,
    2.5,
    2.0,
    'a1000000-0000-0000-0000-000000000003'
  )
ON CONFLICT (id) DO NOTHING;
