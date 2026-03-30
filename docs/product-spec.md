# SubNano — Product Specification

## Overview
Cross-platform mobile rental booking app for underwater scooters.
One codebase for iOS and Android, built with Flutter + Supabase + Stripe.

## User Flow

```
Splash → Auth (Sign In / Sign Up)
  └─ Catalog
      └─ Scooter Details → Book Now
          └─ Booking Dates
              └─ Checkout
                  ├─ Step 1: Pay rental  (Stripe Payment Sheet)
                  └─ Step 2: Pay deposit (Stripe Payment Sheet)
                      └─ Confirmed → My Bookings
```

## Screens

| Screen | Route | Description |
|---|---|---|
| SplashPage | `/` | Auth check, redirect |
| SignInPage | `/sign-in` | Email + password |
| SignUpPage | `/sign-up` | Name, email, password |
| CatalogPage | `/catalog` | Scooter list cards |
| ScooterDetailsPage | `/catalog/:id` | Specs, price, book CTA |
| BookingDatesPage | `/catalog/:id/dates` | Date picker, rental summary |
| CheckoutPage | `/catalog/:id/checkout` | 2-step payment flow |
| MyBookingsPage | `/bookings` | User's booking list |
| BookingDetailsPage | `/bookings/:id` | Status, dates, payment info |
| ProfilePage | `/profile` | User info, logout |
| SupportPage | `/support` | FAQ + contact form |

## Business Rules

1. Rental is measured in full days (`end_date - start_date`).
2. Min 1 day, max 30 days per booking.
3. A scooter cannot be booked for overlapping dates (confirmed or active).
4. Booking starts as `draft` — not visible in availability checks.
5. After successful rental payment → booking becomes `confirmed`.
6. Security deposit ($500) is separate from rental, charged after rental.
7. Return is confirmed by a manager (back-office, not in this app).
8. Deposit is released by manager after return confirmed → Stripe refund → webhook updates DB.
9. Pickup and return happen at designated `pickup_point`.

## Roles
- `customer` — this app's users
- `manager` — back-office (separate admin app, not in scope here)
- `admin` — full access

## Out of Scope (MVP)
- GPS / map
- Bluetooth unlock
- Real-time availability calendar
- Manager admin panel
- Push notifications
- In-app chat
