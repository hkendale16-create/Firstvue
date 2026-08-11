import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const planPrices: Record<string, number> = {
  verified: 999,
  pro: 2999,
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecret) {
      throw new Error("STRIPE_SECRET_KEY is not configured.");
    }

    const stripe = new Stripe(stripeSecret, {
      apiVersion: "2023-10-16",
      httpClient: Stripe.createFetchHttpClient(),
    });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization header." }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return json({ error: "Unauthorized." }, 401);
    }

    const body = await req.json();
    const businessId = body.business_id as string | undefined;
    const plan = body.plan as string | undefined;

    if (!businessId || !plan || !["verified", "pro"].includes(plan)) {
      return json({ error: "business_id and plan (verified|pro) are required." }, 400);
    }

    const { data: business, error: businessError } = await supabase
      .from("businesses")
      .select("id, name, created_by, status")
      .eq("id", businessId)
      .maybeSingle();

    if (businessError || !business) {
      return json({ error: "Business not found." }, 404);
    }

    if (business.created_by !== user.id) {
      return json({ error: "You do not own this business." }, 403);
    }

    const priceEnv = plan === "verified"
      ? "STRIPE_PRICE_VERIFIED"
      : "STRIPE_PRICE_PRO";
    const priceId = Deno.env.get(priceEnv);
    if (!priceId) {
      return json({ error: `${priceEnv} is not configured in Supabase secrets.` }, 500);
    }

    const webUrl = (Deno.env.get("FIRSTVUE_WEB_URL") ?? "https://firstvue.app")
      .replace(/\/$/, "");

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer_email: user.email ?? undefined,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${webUrl}/?billing=success&business=${businessId}&plan=${plan}`,
      cancel_url: `${webUrl}/?billing=cancel`,
      client_reference_id: businessId,
      metadata: {
        business_id: businessId,
        plan,
        user_id: user.id,
      },
      subscription_data: {
        metadata: {
          business_id: businessId,
          plan,
          user_id: user.id,
        },
      },
    });

    if (!session.url) {
      return json({ error: "Stripe did not return a checkout URL." }, 500);
    }

    return json({ url: session.url });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Checkout failed.";
    return json({ error: message }, 400);
  }
});

function json(payload: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
