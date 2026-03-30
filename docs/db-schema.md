# SubNano — Database Schema

## Enums

| Enum | Values |
|---|---|
| `user_role` | customer, manager, admin |
| `scooter_status` | available, rented, maintenance, retired |
| `booking_status` | draft, confirmed, active, completed, cancelled |
| `payment_status` | pending, succeeded, failed, refunded |
| `deposit_status` | pending, held, released, forfeited |

## Tables

### profiles
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | references auth.users |
| email | TEXT | |
| full_name | TEXT | |
| phone | TEXT | |
| avatar_url | TEXT | |
| role | user_role | default: customer |

### pickup_points
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| name | TEXT | |
| address | TEXT | |
| lat / lng | DOUBLE | GPS coords |
| active | BOOL | |

### scooters
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| name | TEXT | |
| price_per_day | NUMERIC | |
| status | scooter_status | |
| max_depth_m | NUMERIC | spec |
| max_speed_knots | NUMERIC | spec |
| battery_hours | NUMERIC | spec |
| weight_kg | NUMERIC | spec |
| pickup_point_id | UUID FK → pickup_points | |

### bookings
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| user_id | UUID FK → profiles | |
| scooter_id | UUID FK → scooters | |
| pickup_point_id | UUID FK → pickup_points | |
| start_date | DATE | |
| end_date | DATE | end_date > start_date |
| total_amount | NUMERIC | rental only, not deposit |
| status | booking_status | starts as draft |

### payments
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| booking_id | UUID FK → bookings | |
| type | TEXT | rental \| deposit |
| amount | NUMERIC | |
| status | payment_status | |
| stripe_payment_intent_id | TEXT UNIQUE | |

### deposit_holds
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| booking_id | UUID FK UNIQUE | one deposit per booking |
| amount | NUMERIC | |
| status | deposit_status | |
| stripe_payment_intent_id | TEXT UNIQUE | |
| returned | BOOL | true after manager confirms return |
| returned_at | TIMESTAMPTZ | |

### documents
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| user_id | UUID FK → profiles | |
| type | TEXT | diving_license, passport, id_card, other |
| file_url | TEXT | |
| verified | BOOL | set by manager |
| expires_at | DATE | |

### damage_reports
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| booking_id | UUID FK | |
| reported_by | UUID FK → profiles | |
| description | TEXT | |
| severity | TEXT | minor, major, total_loss |
| photo_urls | TEXT[] | |
| resolved | BOOL | |

### support_tickets
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| user_id | UUID FK → profiles | |
| booking_id | UUID FK optional | |
| category | TEXT | |
| subject | TEXT | |
| message | TEXT | |
| status | TEXT | open, in_progress, resolved, closed |

## Key Functions

- `handle_new_user()` — trigger: auto-creates profile on sign-up
- `set_updated_at()` — trigger: keeps updated_at fresh on all tables
- `check_scooter_availability(scooter_id, start_date, end_date)` — returns BOOL

## Business Logic Notes

- Bookings start as `draft`. Rental payment → `confirmed`. Manager activates → `active`. Manager confirms return → `completed`.
- Double-booking prevented by partial unique index on `(scooter_id, start_date, end_date)` WHERE status IN ('confirmed', 'active').
- Deposit is a separate PaymentIntent tracked in `deposit_holds`. It's released when `returned = true`.
