import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const allowedOrigins = new Set([
  "https://firstvue.app",
  "https://www.firstvue.app",
  "https://firstvapp.netlify.app",
  "http://localhost",
  "http://127.0.0.1",
]);

function originAllowed(origin: string | null): boolean {
  if (origin === null) return true;
  if (allowedOrigins.has(origin)) return true;
  try {
    const url = new URL(origin);
    return (url.hostname === "localhost" || url.hostname === "127.0.0.1") &&
      (url.protocol === "http:" || url.protocol === "https:");
  } catch {
    return false;
  }
}

function corsHeaders(origin: string | null): HeadersInit {
  const allowOrigin = origin && originAllowed(origin)
    ? origin
    : "https://firstvue.app";
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Cache-Control": "no-store",
    "Vary": "Origin",
  };
}

function json(
  body: Record<string, unknown>,
  status: number,
  origin: string | null,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
    },
  });
}

async function genericFailure(origin: string | null): Promise<Response> {
  // Small uniform delay makes basic username-existence timing probes less useful.
  await new Promise((resolve) => setTimeout(resolve, 250));
  return json({ error: "Unable to sign in." }, 401, origin);
}

serve(async (req) => {
  const origin = req.headers.get("Origin");

  if (!originAllowed(origin)) {
    return json({ error: "Origin not allowed." }, 403, origin);
  }
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(origin) });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405, origin);
  }

  try {
    const body = await req.json();
    const username = typeof body?.username === "string"
      ? body.username.trim().toLowerCase().replace(/^@+/, "")
      : "";
    const password = typeof body?.password === "string" ? body.password : "";

    if (!/^[a-z0-9_]{3,30}$/.test(username) ||
      password.length < 1 ||
      password.length > 1024) {
      return await genericFailure(origin);
    }

    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!url || !anonKey || !serviceKey) {
      return json({ error: "Authentication is temporarily unavailable." }, 503, origin);
    }

    const service = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: email, error: lookupError } = await service.rpc(
      "auth_email_for_username",
      { candidate: username },
    );

    if (lookupError || typeof email !== "string" || email.length === 0) {
      return await genericFailure(origin);
    }

    const publicClient = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await publicClient.auth.signInWithPassword({
      email,
      password,
    });

    if (error || !data.session?.refresh_token) {
      return await genericFailure(origin);
    }

    return json(
      {
        refresh_token: data.session.refresh_token,
        expires_in: data.session.expires_in,
        token_type: data.session.token_type,
      },
      200,
      origin,
    );
  } catch {
    return await genericFailure(origin);
  }
});
