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

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Missing authorization header." }, 401, origin);
  }

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !anonKey || !serviceKey) {
    return json({ error: "Account deletion is temporarily unavailable." }, 503, origin);
  }

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return json({ error: "Unauthorized." }, 401, origin);
  }

  const service = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: blockers, error: blockersError } = await service.rpc(
    "get_account_deletion_blockers",
    { p_user_id: user.id },
  );

  if (blockersError) {
    return json({ error: "Unable to verify account deletion eligibility." }, 500, origin);
  }

  if (blockers && typeof blockers === "object" && (blockers as { blocked?: boolean }).blocked) {
    return json(
      {
        error: (blockers as { message?: string }).message ??
          "Transfer or delete your businesses and communities first.",
        blockers,
      },
      409,
      origin,
    );
  }

  const { error: cleanupError } = await service.rpc("delete_my_account_data", {
    p_user_id: user.id,
  });

  if (cleanupError) {
    const detail = cleanupError.details ?? cleanupError.message;
    if (cleanupError.code === "P0001") {
      return json(
        {
          error: cleanupError.message,
          blockers: detail ? tryParseJson(detail) : blockers,
        },
        409,
        origin,
      );
    }
    return json({ error: "Unable to delete account data." }, 500, origin);
  }

  const { error: deleteError } = await service.auth.admin.deleteUser(user.id);
  if (deleteError) {
    return json({ error: "Unable to delete authentication account." }, 500, origin);
  }

  return json({ success: true }, 200, origin);
});

function tryParseJson(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}
