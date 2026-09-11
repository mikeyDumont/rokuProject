const BUCKET = "channel-media";
const OBJECT_PATH = "ambient/forest_ambience-v1.mp3";
const SIGNED_URL_TTL_SECONDS = 3600;

function response(status: number, body: string) {
  return new Response(body, {
    status,
    headers: {
      "Cache-Control": "no-store",
      "Content-Type": "text/plain; charset=utf-8",
    },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "GET") {
    return response(405, "Method not allowed");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const deviceId = new URL(request.url).searchParams.get("device_id") ?? "";
  const deviceToken = new URL(request.url).searchParams.get("device_token") ?? "";
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Supabase service configuration is unavailable");
    return response(503, "Media service is unavailable");
  }
  if (!deviceId || !deviceToken) {
    return response(401, "Unauthorized");
  }

  const headers = {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    "Content-Type": "application/json",
  };

  try {
    const authorizationResponse = await fetch(`${supabaseUrl}/rest/v1/rpc/authorize_roku_media`, {
      method: "POST",
      headers,
      body: JSON.stringify({ p_device_id: deviceId, p_device_token: deviceToken }),
    });
    if (!authorizationResponse.ok || (await authorizationResponse.json()) !== true) {
      return response(401, "Unauthorized");
    }

    const signedUrlResponse = await fetch(
      `${supabaseUrl}/storage/v1/object/sign/${BUCKET}/${OBJECT_PATH}`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({ expiresIn: SIGNED_URL_TTL_SECONDS }),
      },
    );
    if (!signedUrlResponse.ok) {
      console.error("Unable to sign ambient audio", signedUrlResponse.status);
      return response(503, "Media service is unavailable");
    }

    const signedUrl = (await signedUrlResponse.json()).signedURL;
    if (typeof signedUrl !== "string" || !signedUrl.startsWith("/object/sign/")) {
      console.error("Storage returned an invalid signed URL");
      return response(503, "Media service is unavailable");
    }
    return new Response(null, {
      status: 302,
      headers: {
        "Cache-Control": "no-store",
        Location: new URL(`/storage/v1${signedUrl}`, supabaseUrl).toString(),
      },
    });
  } catch (error) {
    console.error("Ambient audio request failed", error);
    return response(503, "Media service is unavailable");
  }
});