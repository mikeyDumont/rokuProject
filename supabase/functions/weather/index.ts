const OPENWEATHER_BASE_URL = "https://api.openweathermap.org/data/2.5";
const HOCHATOWN_QUERY = "lat=34.1768&lon=-94.7391&units=imperial";

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=600",
    },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "GET") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const apiKey = Deno.env.get("OPENWEATHER_API_KEY");
  if (!apiKey) {
    console.error("OPENWEATHER_API_KEY is not configured");
    return jsonResponse({ error: "Weather service is unavailable" }, 503);
  }

  try {
    const weatherUrls = ["weather", "forecast"].map(
      (endpoint) => `${OPENWEATHER_BASE_URL}/${endpoint}?${HOCHATOWN_QUERY}&appid=${apiKey}`,
    );
    const responses = await Promise.all(weatherUrls.map((url) => fetch(url)));

    if (responses.some((response) => !response.ok)) {
      console.error("OpenWeather request failed", responses.map((response) => response.status));
      return jsonResponse({ error: "Weather service is unavailable" }, 502);
    }

    const [current, forecast] = await Promise.all(responses.map((response) => response.json()));
    return jsonResponse({ current, forecast });
  } catch (error) {
    console.error("Weather request failed", error);
    return jsonResponse({ error: "Weather service is unavailable" }, 502);
  }
});
