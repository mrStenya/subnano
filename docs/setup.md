# SubNano — Setup Guide

## Prerequisites

- Flutter 3.19+ (`flutter --version`)
- Supabase account + project
- Stripe account (test mode for development)
- Deno (for local Edge Function testing)

---

## 1. Clone & install Flutter deps

```bash
git clone <repo>
cd subnano
flutter pub get
```

---

## 2. Supabase setup

### 2a. Create project
1. Go to https://supabase.com/dashboard
2. New project → note your **Project URL** and **anon key**

### 2b. Run migration
In the Supabase SQL Editor, paste and run:
```
supabase/migrations/20240101000000_initial_schema.sql
```

Or with the Supabase CLI:
```bash
supabase db push
```

### 2c. Enable Email auth
Dashboard → Authentication → Providers → Email → Enable

### 2d. Deploy Edge Functions
```bash
supabase functions deploy create-payment-intent
supabase functions deploy create-deposit-intent
supabase functions deploy stripe-webhook
```

### 2e. Set Edge Function secrets
```bash
supabase secrets set STRIPE_SECRET_KEY=sk_test_...
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
```
> Never put these in client code or git.

---

## 3. Stripe setup

1. Create account at https://stripe.com
2. Dashboard → Developers → API keys
   - Copy **Publishable key** (starts with `pk_test_`)
   - Copy **Secret key** (starts with `sk_test_`) — only for Edge Functions
3. Dashboard → Developers → Webhooks → Add endpoint
   - URL: `https://<project-ref>.supabase.co/functions/v1/stripe-webhook`
   - Events: `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`
   - Copy the **Signing secret** → set as `STRIPE_WEBHOOK_SECRET`

---

## 4. Run the Flutter app

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_... \
  --dart-define=APP_ENV=development
```

### Optional: .env helper (not committed to git)
Create `run_dev.sh`:
```bash
#!/bin/bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_... \
  --dart-define=APP_ENV=development
```
```bash
chmod +x run_dev.sh && ./run_dev.sh
```

---

## 5. iOS additional setup

Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Used for document scanning</string>
```

Stripe requires adding to `ios/Podfile`:
```ruby
platform :ios, '13.0'
```

---

## 6. Android additional setup

`android/app/build.gradle` — ensure `minSdkVersion 21`.

---

## 7. Environment variables reference

| Variable | Where | Description |
|---|---|---|
| `SUPABASE_URL` | Flutter `--dart-define` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Flutter `--dart-define` | Supabase anon/public key |
| `STRIPE_PUBLISHABLE_KEY` | Flutter `--dart-define` | Stripe pk_test/pk_live |
| `STRIPE_SECRET_KEY` | Supabase secrets | Stripe secret — server only |
| `STRIPE_WEBHOOK_SECRET` | Supabase secrets | Stripe webhook signing secret |
| `SUPABASE_SERVICE_ROLE_KEY` | Auto-injected in Edge Functions | Do not expose to client |
