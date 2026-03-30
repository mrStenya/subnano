/**
 * Edge Function: create-payment-intent
 *
 * Creates a Stripe PaymentIntent for the rental amount.
 * Called from the Flutter client during checkout.
 *
 * Request body:
 *   {
 *     booking_id: string   // UUID of the booking (status=draft)
 *     amount:     number   // amount in cents (e.g. 15000 = $150.00)
 *     currency:   string   // ISO 4217 (default: "usd")
 *   }
 *
 * Response 200:
 *   {
 *     client_secret:   string   // pass to Stripe Payment Sheet
 *     customer_id:     string   // Stripe customer id (for saved cards)
 *     ephemeral_key:   string   // Stripe ephemeral key secret
 *     payment_intent_id: string
 *   }
 *
 * Response 4xx/5xx:
 *   { error: string }
 */

import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-04-10",
  httpClient: Stripe.createFetchHttpClient(),
});

Deno.serve(async (req: Request) => {
  // Handle CORS pre-flight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ---------------------------------------------------------------
    // 1. Parse & validate request
    // ---------------------------------------------------------------
    const { booking_id, amount, currency = "usd" } = await req.json();

    if (!booking_id || typeof amount !== "number" || amount <= 0) {
      return errorResponse("Invalid request body", 400);
    }

    // ---------------------------------------------------------------
    // 2. Verify booking exists and belongs to the calling user
    // ---------------------------------------------------------------
    const authHeader = req.headers.get("Authorization");
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader! } } }
    );

    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("id, user_id, status, total_amount")
      .eq("id", booking_id)
      .single();

    if (bookingError || !booking) {
      return errorResponse("Booking not found", 404);
    }
    if (booking.status !== "draft") {
      return errorResponse("Booking is not in draft status", 409);
    }

    // ---------------------------------------------------------------
    // 3. Get or create Stripe customer for this user
    // ---------------------------------------------------------------
    const { data: profile } = await supabase
      .from("profiles")
      .select("id, email, full_name")
      .eq("id", booking.user_id)
      .single();

    // TODO: persist stripe_customer_id in profiles table for re-use
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
    // 4. Create PaymentIntent
    // ---------------------------------------------------------------
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      customer: customer.id,
      automatic_payment_methods: { enabled: true },
      metadata: {
        booking_id,
        type: "rental",
        supabase_user_id: booking.user_id,
      },
    });

    // ---------------------------------------------------------------
    // 5. Record pending payment in DB (uses service_role via admin client)
    // ---------------------------------------------------------------
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    await adminClient.from("payments").insert({
      booking_id,
      type: "rental",
      amount: amount / 100, // back to dollars
      currency,
      status: "pending",
      stripe_payment_intent_id: paymentIntent.id,
    });

    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
        customer_id: customer.id,
        ephemeral_key: ephemeralKey.secret,
        payment_intent_id: paymentIntent.id,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    console.error("create-payment-intent error:", err);
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
