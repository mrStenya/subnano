# SubNano — API Contract

## Edge Functions

All Edge Functions receive a Bearer token in `Authorization` header (Supabase JWT).

---

### POST /functions/v1/create-payment-intent

Creates a Stripe PaymentIntent for the rental charge.

**Request**
```json
{
  "booking_id": "uuid",
  "amount": 15000,
  "currency": "usd"
}
```

**Response 200**
```json
{
  "client_secret": "pi_xxx_secret_yyy",
  "customer_id": "cus_xxx",
  "ephemeral_key": "ek_test_xxx",
  "payment_intent_id": "pi_xxx"
}
```

**Errors**
| Status | Reason |
|---|---|
| 400 | Missing or invalid fields |
| 404 | Booking not found |
| 409 | Booking not in draft status |
| 500 | Stripe or DB error |

---

### POST /functions/v1/create-deposit-intent

Creates a Stripe PaymentIntent for the security deposit.

**Request**
```json
{
  "booking_id": "uuid"
}
```

**Response 200**
```json
{
  "client_secret": "pi_xxx_secret_yyy",
  "customer_id": "cus_xxx",
  "ephemeral_key": "ek_test_xxx",
  "payment_intent_id": "pi_xxx",
  "deposit_amount_cents": 50000
}
```

**Errors**
| Status | Reason |
|---|---|
| 400 | Missing booking_id |
| 404 | Booking not found |
| 409 | Booking not confirmed OR deposit already exists |

---

### POST /functions/v1/stripe-webhook

Stripe sends events here. No client calls this directly.

**Handled events**
| Event | Action |
|---|---|
| `payment_intent.succeeded` | If type=rental → set booking.status=confirmed, payment.status=succeeded. If type=deposit → deposit_holds.status=held |
| `payment_intent.payment_failed` | Set payment or deposit_hold status=failed/pending |
| `charge.refunded` | Set deposit_holds.returned=true, status=released |

---

## Supabase PostgREST

Standard CRUD via `supabase_flutter` client. Key queries:

| Operation | Table | Filter |
|---|---|---|
| List scooters | scooters | none (public) |
| Get scooter | scooters | id = :id |
| Check availability | RPC `check_scooter_availability` | scooter_id, start_date, end_date |
| My bookings | bookings | user_id = auth.uid() |
| Booking detail | bookings + joins | id = :id |
| Create ticket | support_tickets | user_id = auth.uid() |
