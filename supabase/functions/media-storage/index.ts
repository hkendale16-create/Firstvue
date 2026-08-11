import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from "https://esm.sh/@aws-sdk/client-s3@3.682.0";
import { getSignedUrl } from "https://esm.sh/@aws-sdk/s3-request-presigner@3.682.0";
import {
  buildStoragePath,
  isMediaBucket,
  objectKey,
  type MediaBucket,
} from "../_shared/media_buckets.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const bucketName = Deno.env.get("S3_MEDIA_BUCKET");
  const awsRegion = Deno.env.get("AWS_REGION") ?? "us-east-1";
  const awsAccessKeyId = Deno.env.get("AWS_ACCESS_KEY_ID");
  const awsSecretAccessKey = Deno.env.get("AWS_SECRET_ACCESS_KEY");
  const cloudfrontDomain = Deno.env.get("CLOUDFRONT_DOMAIN")?.replace(/\/$/, "");

  if (!bucketName || !awsAccessKeyId || !awsSecretAccessKey) {
    return json({
      error: "AWS media storage is not configured. Set S3_MEDIA_BUCKET and AWS credentials.",
      configured: false,
    }, 501);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Missing authorization header." }, 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  );

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const body = await req.json();
  const action = body.action as string | undefined;

  const s3 = new S3Client({
    region: awsRegion,
    credentials: {
      accessKeyId: awsAccessKeyId,
      secretAccessKey: awsSecretAccessKey,
    },
  });

  try {
    switch (action) {
      case "upload-url": {
        if (!user) return json({ error: "Sign in required." }, 401);
        const bucket = body.bucket as string;
        const contentType = body.content_type as string;
        const fileName = body.file_name as string;
        const index = Number(body.index ?? 0);
        const context = (body.context ?? {}) as Record<string, string>;

        if (!isMediaBucket(bucket) || !contentType || !fileName) {
          return json({ error: "bucket, content_type, and file_name are required." }, 400);
        }

        const authorized = await authorizeUpload(
          supabaseAdmin,
          user.id,
          bucket,
          context,
        );
        if (!authorized) {
          return json({ error: "You do not have permission to upload here." }, 403);
        }

        const path = buildStoragePath(user.id, index, fileName);
        const key = objectKey(bucket, path);
        const uploadUrl = await getSignedUrl(
          s3,
          new PutObjectCommand({
            Bucket: bucketName,
            Key: key,
            ContentType: contentType,
          }),
          { expiresIn: 3600 },
        );

        return json({
          configured: true,
          path,
          upload_url: uploadUrl,
          storage_provider: "s3",
          headers: { "Content-Type": contentType },
        });
      }

      case "read-url": {
        const bucket = body.bucket as string;
        const path = body.path as string;
        const context = (body.context ?? {}) as Record<string, string>;

        if (!isMediaBucket(bucket) || !path) {
          return json({ error: "bucket and path are required." }, 400);
        }

        const visibility = await authorizeRead(
          supabaseAdmin,
          user?.id ?? null,
          bucket,
          path,
          context,
        );
        if (!visibility) {
          return json({ error: "You do not have permission to view this media." }, 403);
        }

        const key = objectKey(bucket, path);
        if (cloudfrontDomain && visibility === "public") {
          return json({
            configured: true,
            read_url: `https://${cloudfrontDomain}/${key}`,
            storage_provider: "s3",
          });
        }

        const readUrl = await getSignedUrl(
          s3,
          new GetObjectCommand({
            Bucket: bucketName,
            Key: key,
          }),
          { expiresIn: 3600 },
        );

        return json({ configured: true, read_url: readUrl, storage_provider: "s3" });
      }

      case "delete": {
        if (!user) return json({ error: "Sign in required." }, 401);
        const bucket = body.bucket as string;
        const path = body.path as string;
        const context = (body.context ?? {}) as Record<string, string>;

        if (!isMediaBucket(bucket) || !path) {
          return json({ error: "bucket and path are required." }, 400);
        }

        const authorized = await authorizeDelete(
          supabaseAdmin,
          user.id,
          bucket,
          path,
          context,
        );
        if (!authorized) {
          return json({ error: "You do not have permission to delete this media." }, 403);
        }

        await s3.send(new DeleteObjectCommand({
          Bucket: bucketName,
          Key: objectKey(bucket, path),
        }));

        return json({ configured: true, deleted: true });
      }

      default:
        return json({ error: "Unsupported action." }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Media storage request failed.";
    return json({ error: message }, 400);
  }
});

async function authorizeUpload(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  bucket: MediaBucket,
  context: Record<string, string>,
): Promise<boolean> {
  switch (bucket) {
    case "business-media":
      return verifyBusinessOwner(supabaseAdmin, userId, context.business_id);
    case "rental-media":
      return context.rental_id
        ? verifyRentalOwner(supabaseAdmin, userId, context.rental_id)
        : true;
    case "professional-media":
      return verifyProfessionalOwner(
        supabaseAdmin,
        userId,
        context.professional_profile_id,
      );
    default:
      return false;
  }
}

async function authorizeRead(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string | null,
  bucket: MediaBucket,
  path: string,
  _context: Record<string, string>,
): Promise<"public" | "private" | false> {
  switch (bucket) {
    case "business-media": {
      const { data } = await supabaseAdmin
        .from("business_media")
        .select("business_id, businesses!inner(status, created_by)")
        .eq("storage_path", path)
        .maybeSingle();
      if (!data) return false;
      const business = data.businesses as { status: string; created_by: string };
      if (business.status === "approved") return "public";
      if (userId && business.created_by === userId) return "private";
      return (await isAdmin(supabaseAdmin, userId)) ? "private" : false;
    }
    case "rental-media": {
      const { data } = await supabaseAdmin
        .from("rental_media")
        .select("rental_id, rentals!inner(status, owner_id)")
        .eq("storage_path", path)
        .maybeSingle();
      if (!data) return false;
      const rental = data.rentals as { status: string; owner_id: string };
      if (rental.status === "approved") return "public";
      if (userId && rental.owner_id === userId) return "private";
      return (await isAdmin(supabaseAdmin, userId)) ? "private" : false;
    }
    case "professional-media": {
      const { data } = await supabaseAdmin
        .from("professional_media")
        .select(
          "professional_profile_id, professional_profiles!inner(status, profile_id)",
        )
        .eq("storage_path", path)
        .maybeSingle();
      if (!data) return false;
      const profile = data.professional_profiles as {
        status: string;
        profile_id: string;
      };
      if (profile.status === "approved") return "public";
      if (userId && profile.profile_id === userId) return "private";
      return (await isAdmin(supabaseAdmin, userId)) ? "private" : false;
    }
    default:
      return false;
  }
}

async function authorizeDelete(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  bucket: MediaBucket,
  path: string,
  context: Record<string, string>,
): Promise<boolean> {
  if (await isAdmin(supabaseAdmin, userId)) return true;

  switch (bucket) {
    case "business-media": {
      const { data } = await supabaseAdmin
        .from("business_media")
        .select("business_id, businesses!inner(created_by)")
        .eq("storage_path", path)
        .maybeSingle();
      if (!data) return false;
      const business = data.businesses as { created_by: string };
      return business.created_by === userId;
    }
    case "rental-media": {
      const { data } = await supabaseAdmin
        .from("rental_media")
        .select("rental_id, rentals!inner(owner_id)")
        .eq("storage_path", path)
        .maybeSingle();
      if (!data) return false;
      const rental = data.rentals as { owner_id: string };
      return rental.owner_id === userId;
    }
    case "professional-media": {
      const { data } = await supabaseAdmin
        .from("professional_media")
        .select(
          "professional_profile_id, professional_profiles!inner(profile_id)",
        )
        .eq("storage_path", path)
        .maybeSingle();
      if (!data) return false;
      const profile = data.professional_profiles as { profile_id: string };
      return profile.profile_id === userId;
    }
    default:
      return false;
  }
}

async function verifyBusinessOwner(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  businessId?: string,
): Promise<boolean> {
  if (!businessId) return false;
  const { data } = await supabaseAdmin
    .from("businesses")
    .select("id")
    .eq("id", businessId)
    .eq("created_by", userId)
    .maybeSingle();
  return data != null;
}

async function verifyRentalOwner(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  rentalId?: string,
): Promise<boolean> {
  if (!rentalId) return false;
  const { data } = await supabaseAdmin
    .from("rentals")
    .select("id")
    .eq("id", rentalId)
    .eq("owner_id", userId)
    .maybeSingle();
  return data != null;
}

async function verifyProfessionalOwner(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  professionalProfileId?: string,
): Promise<boolean> {
  if (!professionalProfileId) return false;
  const { data } = await supabaseAdmin
    .from("professional_profiles")
    .select("id")
    .eq("id", professionalProfileId)
    .eq("profile_id", userId)
    .maybeSingle();
  return data != null;
}

async function isAdmin(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string | null,
): Promise<boolean> {
  if (!userId) return false;
  const { data } = await supabaseAdmin
    .from("profiles")
    .select("account_type")
    .eq("id", userId)
    .maybeSingle();
  return data?.account_type === "admin";
}

function json(payload: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
