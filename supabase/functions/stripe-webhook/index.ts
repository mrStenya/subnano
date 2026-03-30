/**
 * Edge Function: stripe-webhook
 *
 * Receives and processes Stripe webhook events.
 * Register this URL in your Stripe dashboard:
 *   https://<project>.supabase.co/functions/v1/stripe-webhook
 *
 * Required Stripe events to enable:
 *   - payment_intent.succeeded
 *   - payment_intent.payment_failed
 *   - charge.refunded
 *
 * Environment variables needed:
 *   STRIPE_WEBHOOK_SECRET   — from Stripe dashboard > Webhooks > signing secret
 *   STRIPE_SECRET_KEY       — Stripe secret key (server-side only)
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 */

import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-04-10",
  httpClient: Stripe.createFetchHttpClient(),
});

const adminClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // ---------------------------------------------------------------
  // Verify Stripe signature
  // ---------------------------------------------------------------
  const signature = req.headers.get("stripe-signature");
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");

  if (!signature || !webhookSecret) {
    return new Response("Webhook secret not configured", { status: 400 });
  }

  let event: Stripe.Event;
  const body = await req.text();

  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      webhookSecret
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return new Response("Invalid signature", { status: 400 });
  }

  // ---------------------------------------------------------------
  // Route events
  // ---------------------------------------------------------------
  try {
    switch (event.type) {
      case "payment_intent.succeeded":
        await handlePaymentSucceeded(event.data.object as Stripe.PaymentIntent);
        break;

      case "payment_intent.payment_failed":
        await handlePaymentFailed(event.data.object as Stripe.PaymentIntent);
        break;

      case "charge.refunded":
        await handleChargeRefunded(event.data.object as Stripe.Charge);
        break;

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }
  } catch (err) {
    console.error(`Error handling event ${event.type}:`, err);
    // Return 500 so Stripe retries
    return new Response("Handler error", { status: 500 });
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
    status: 200,
  });
});

// ---------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------

async function handlePaymentSucceeded(pi: Stripe.PaymentIntent) {
  const { booking_id, type } = pi.metadata;

  if (!booking_id) {
    console.warn("payment_intent.succeeded: no booking_id in metadata");
    return;
  }

  if (type === "rental") {
    // Update payment record
    await adminClient
      .from("payments")
      .update({ status: "succeeded" })
      .eq("stripe_payment_intent_id", pi.id);

    // Confirm booking
    await adminClient
      .from("bookings")
      .update({ status: "confirmed" })
      .eq("id", booking_id)
      .eq("status", "draft"); // guard: only transition from draft

    console.log(`Booking ${booking_id} confirmed after rental payment ${pi.id}`);
  } else if (type === "deposit") {
    await adminClient
      .from("deposit_holds")
      .update({ status: "held" })
      .eq("stripe_payment_intent_id", pi.id);

    console.log(`Deposit held for booking ${booking_id}, pi ${pi.id}`);
  }
}

async function handlePaymentFailed(pi: Stripe.PaymentIntent) {
  const { booking_id, type } = pi.metadata;
  if (!booking_id) return;

  if (type === "rental") {
    await adminClient
      .from("payments")
      .update({ status: "failed" })
      .eq("stripe_payment_intent_id", pi.id);

    console.warn(`Rental payment failed for booking ${booking_id}`);
  } else if (type === "deposit") {
    await adminClient
      .from("deposit_holds")
      .update({ status: "pending" }) // stays pending, user should retry
      .eq("stripe_payment_intent_id", pi.id);
  }
}

async function handleChargeRefunded(charge: Stripe.Charge) {
  // TODO: handle deposit release after successful return.
  // The manager confirms return → back-office triggers refund via Stripe →
  // this webhook marks deposit_holds.returned = true.
  const paymentIntentId = charge.payment_intent as string | undefined;
  if (!paymentIntentId) return;

  await adminClient
    .from("deposit_holds")
    .update({ status: "released", returned: true, returned_at: new Date().toISOString() })
    .eq("stripe_payment_intent_id", paymentIntentId);

  console.log(`Deposit released for payment_intent ${paymentIntentId}`);
}
