/**
 * Edge Function: create-deposit-intent
 *
 * Creates a Stripe PaymentIntent to charge the security deposit.
 * Deposit is separate from rental and displayed to the user independently.
 *
 * Request body:
 *   {
 *     booking_id: string   // UUID of a confirmed booking
 *   }
 *
 * Response 200:
 *   {
 *     client_secret:        string
 *     customer_id:          string
 *     ephemeral_key:        string
 *     payment_intent_id:    string
 *     deposit_amount_cents: number
 *   }
 *
 * Response 4xx/5xx:
 *   { error: string }
 */

import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

// TODO: make deposit amount configurable per scooter or from env
const DEPOSIT_AMOUNT_CENTS = 50000; // $500.00

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-04-10",
  httpClient: Stripe.createFetchHttpClient(),
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { booking_id } = await req.json();

    if (!booking_id) {
      return errorResponse("booking_id is required", 400);
    }

    // ---------------------------------------------------------------
    // Verify booking is confirmed and belongs to calling user
    // ---------------------------------------------------------------
    const authHeader = req.headers.get("Authorization");
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader! } } }
    );

    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("id, user_id, status")
      .eq("id", booking_id)
      .single();

    if (bookingError || !booking) {
      return errorResponse("Booking not found", 404);
    }
    if (!["confirmed", "draft"].includes(booking.status)) {
      return errorResponse("Booking must be confirmed before paying deposit", 409);
    }

    // Check no deposit hold already exists
    const { data: existing } = await supabase
      .from("deposit_holds")
      .select("id")
      .eq("booking_id", booking_id)
      .maybeSingle();

    if (existing) {
      return errorResponse("Deposit already recorded for this booking", 409);
    }

    // ---------------------------------------------------------------
    // Get profile → customer
    // ---------------------------------------------------------------
    const { data: profile } = await supabase
      .from("profiles")
      .select("id, email, full_name")
      .eq("id", booking.user_id)
      .single();

    // TODO: reuse existing stripe customer id if stored on profile
    const customer = await stripe.customers.create({
      email: profile?.email,
      name: profile?.full_name ?? undefined,
      metadata: { supabase_user_id: booking.user_id },
    });

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customer.id },
      { apiVersion: "2024-04-10" }
    );

    // ---------------------------------------------------------------
    // Create deposit PaymentIntent
    // ---------------------------------------------------------------
    const paymentIntent = await stripe.paymentIntents.create({
      amount: DEPOSIT_AMOUNT_CENTS,
      currency: "usd",
      customer: customer.id,
      automatic_payment_methods: { enabled: true },
      // capture_method: 'manual' if you want to hold and release later
      metadata: {
        booking_id,
        type: "deposit",
        supabase_user_id: booking.user_id,
      },
    });

    // ---------------------------------------------------------------
    // Record deposit hold in DB
    // ---------------------------------------------------------------
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    await adminClient.from("deposit_holds").insert({
      booking_id,
      amount: DEPOSIT_AMOUNT_CENTS / 100,
      currency: "usd",
      status: "pending",
      stripe_payment_intent_id: paymentIntent.id,
    });

    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
        customer_id: customer.id,
        ephemeral_key: ephemeralKey.secret,
        payment_intent_id: paymentIntent.id,
        deposit_amount_cents: DEPOSIT_AMOUNT_CENTS,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    console.error("create-deposit-intent error:", err);
    return errorResponse(
      err instanceof Error ? err.message : "Internal server error",
      500
    );
  }
});

function errorResponse(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}
