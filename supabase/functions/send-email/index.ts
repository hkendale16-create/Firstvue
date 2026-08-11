import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  SESClient,
  SendEmailCommand,
} from "https://esm.sh/@aws-sdk/client-ses@3.682.0";
import { renderEmailTemplate } from "./templates.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-email-webhook-secret",
};

interface OutboxRow {
  id: string;
  template: string;
  recipient_email: string;
  payload: Record<string, unknown>;
  status: string;
  idempotency_key?: string | null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!isAuthorized(req)) {
    return json({ error: "Unauthorized." }, 401);
  }

  const awsRegion = Deno.env.get("AWS_REGION") ?? "us-east-1";
  const awsAccessKeyId = Deno.env.get("AWS_ACCESS_KEY_ID");
  const awsSecretAccessKey = Deno.env.get("AWS_SECRET_ACCESS_KEY");
  const fromEmail = Deno.env.get("SES_FROM_EMAIL");
  const adminNotifyEmail = Deno.env.get("ADMIN_NOTIFY_EMAIL");

  if (!awsAccessKeyId || !awsSecretAccessKey || !fromEmail) {
    return json({
      error: "AWS SES is not configured. Set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, SES_FROM_EMAIL.",
    }, 500);
  }

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const ses = new SESClient({
    region: awsRegion,
    credentials: {
      accessKeyId: awsAccessKeyId,
      secretAccessKey: awsSecretAccessKey,
    },
  });

  try {
    const body = await req.json();
    const outboxRow = extractOutboxRow(body);

    if (!outboxRow) {
      return json({ error: "No email outbox row found in request body." }, 400);
    }

    if (outboxRow.status !== "pending") {
      return json({ received: true, skipped: true, reason: "not_pending" });
    }

    const recipient = resolveRecipient(outboxRow, adminNotifyEmail);
    if (!recipient) {
      await markOutbox(supabaseAdmin, outboxRow.id, "skipped", "Missing recipient.");
      return json({ received: true, skipped: true, reason: "missing_recipient" });
    }

    const rendered = renderEmailTemplate(outboxRow.template, outboxRow.payload);

    await ses.send(new SendEmailCommand({
      Source: fromEmail,
      Destination: { ToAddresses: [recipient] },
      Message: {
        Subject: { Data: rendered.subject, Charset: "UTF-8" },
        Body: {
          Html: { Data: rendered.html, Charset: "UTF-8" },
          Text: { Data: rendered.text, Charset: "UTF-8" },
        },
      },
    }));

    await markOutbox(supabaseAdmin, outboxRow.id, "sent");

    return json({ received: true, sent: true, to: recipient });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Email send failed.";
    console.error(message);
    return json({ error: message }, 500);
  }
});

function isAuthorized(req: Request): boolean {
  const webhookSecret = Deno.env.get("EMAIL_WEBHOOK_SECRET");
  if (webhookSecret) {
    const headerSecret = req.headers.get("x-email-webhook-secret");
    if (headerSecret === webhookSecret) return true;
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (authHeader === `Bearer ${serviceRoleKey}` && serviceRoleKey.length > 0) {
    return true;
  }

  return false;
}

function extractOutboxRow(body: unknown): OutboxRow | null {
  if (!body || typeof body !== "object") return null;

  const payload = body as Record<string, unknown>;

  if (payload.record && typeof payload.record === "object") {
    return normalizeOutboxRow(payload.record as Record<string, unknown>);
  }

  if (payload.id && payload.template) {
    return normalizeOutboxRow(payload);
  }

  return null;
}

function normalizeOutboxRow(row: Record<string, unknown>): OutboxRow {
  return {
    id: String(row.id),
    template: String(row.template),
    recipient_email: String(row.recipient_email ?? ""),
    payload: (row.payload as Record<string, unknown>) ?? {},
    status: String(row.status ?? "pending"),
    idempotency_key: row.idempotency_key as string | null | undefined,
  };
}

function resolveRecipient(row: OutboxRow, adminNotifyEmail?: string): string | null {
  if (row.template === "admin_new_business_submission") {
    return adminNotifyEmail?.trim() || null;
  }

  const email = row.recipient_email?.trim();
  if (!email || email.endsWith("@firstvue.internal")) {
    return adminNotifyEmail?.trim() || null;
  }

  return email;
}

async function markOutbox(
  supabaseAdmin: ReturnType<typeof createClient>,
  id: string,
  status: "sent" | "failed" | "skipped",
  errorMessage?: string,
) {
  await supabaseAdmin
    .from("email_outbox")
    .update({
      status,
      error_message: errorMessage ?? null,
      sent_at: status === "sent" ? new Date().toISOString() : null,
    })
    .eq("id", id);
}

function json(payload: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
