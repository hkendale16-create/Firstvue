export const MEDIA_BUCKETS = [
  "business-media",
  "rental-media",
  "professional-media",
] as const;

export type MediaBucket = (typeof MEDIA_BUCKETS)[number];

export function isMediaBucket(value: string): value is MediaBucket {
  return MEDIA_BUCKETS.includes(value as MediaBucket);
}

export function objectKey(bucket: MediaBucket, path: string): string {
  return `${bucket}/${path}`.replace(/\/+/g, "/");
}

export function safeFileName(name: string): string {
  return name.replace(/[^A-Za-z0-9._-]/g, "_");
}

export function buildStoragePath(
  userId: string,
  index: number,
  fileName: string,
): string {
  return `${userId}/${Date.now()}_${index}_${safeFileName(fileName)}`;
}
