# Cabin Concierge TV - 100% Native Roku SceneGraph Channel Package

This is a complete, standalone Roku channel written in native BrightScript and Roku SceneGraph (RSG).

## Structure:
- `manifest`: Channel metadata, icon paths, and 1080p FHD resolution declarations.
- `source/main.brs`: Native application loop and roSGScreen display initialization.
- `source/api.brs`: Local registry persistence (roRegistrySection), PIN gate resolution, and data models.
- `components/MainScene.xml & .brs`: Root SceneGraph coordinator, left navigation rail, and subview switcher.
- `components/PinGateScreen.xml & .brs`: 10-foot numeric keypad PIN protection.
- `components/HouseRulesView.xml & .brs`: Interactive House & Hot Tub rules browser with instant details panel.
- `components/RecommendationsView.xml & .brs`: Curated local dining, hiking, and attractions with host tips.
- `components/WeatherView.xml & .brs`: Live mountain conditions & 4-day Hochatown forecast.
- `components/CheckoutView.xml & .brs`: Interactive departure checklist with toggleable checkboxes.
- `components/FeedbackView.xml & .brs`: 5-star guest feedback rating, category review & direct booking VIP promo code.
- `components/ScreensaverView.xml & .brs`: Anti-burn-in floating OLED ambient clock & screensaver.

## Supabase Setup

1. In the Supabase SQL Editor, run [supabase_live_alignment.sql](supabase_live_alignment.sql), then run the entire [supabase_guest_display.sql](supabase_guest_display.sql). The second migration creates `public.reservations`, limits guest data to an active reservation, and removes anonymous reads of `properties`, `reservations`, and `guest_feedback`. It intentionally retains the legacy guest columns until the optional [supabase_remove_legacy_guest_columns.sql](supabase_remove_legacy_guest_columns.sql) cleanup is run after verification.
2. In Supabase Dashboard, create or copy the project `anon`/publishable key. Do not use a `service_role` key in the Roku package.
3. Set `supabase_anon_key` in `manifest` to that publishable key before packaging the channel.

Global house rules, recommendations, and checkout tasks use `property_id = NULL`. Use a matching `properties.id` in `property_id` for unit-specific content.

Create reservations with UTC timestamps. A normal property load shows guest data only when `check_in_at <= now() < check_out_at`; during checkout-to-check-in turnover, the welcome screen omits guest identity and dates. A staff-authorized Refresh action may preload the next non-cancelled arrival scheduled later that same Central Time day.

Before production rollout, run [supabase_staff_pin_security.sql](supabase_staff_pin_security.sql), set the company PIN only through its documented SQL Editor update, then run [supabase_device_access_security.sql](supabase_device_access_security.sql). The second security migration binds every installed Roku to a random server-issued device credential, rate-limits property-PIN enrollment, and requires a short-lived staff authorization for pre-arrival guest preload. The Roku package contains neither the company PIN nor a persistent property PIN.

For Track PMS imports, [tools/apps_script_reservation_sync.js](tools/apps_script_reservation_sync.js) upserts confirmed arrivals and currently checked-in reservations by PMS reservation ID, then marks missing upcoming records cancelled. The existing Roku sheet sync uses Track `unitId` as `properties.id`, so the reservation importer writes that same unit ID directly as `reservations.property_id`. Run `syncPropertiesToSupabase()` first; the reservation import skips unmatched Track units and logs them instead of failing the entire batch. Track's reservation status is not a property occupancy state; the existing operations script remains responsible for deriving states such as `TURN`. Set the script's required values in Google Apps Script Script Properties; keep the Supabase service-role key there, never in the Roku package.

## Secure Weather Setup

The Roku client calls the authenticated Supabase Edge Function in [supabase/functions/weather/index.ts](supabase/functions/weather/index.ts). The OpenWeather credential must exist only as a Supabase secret; do not add it to `manifest` or any BrightScript file.

1. Rotate the OpenWeather key that was previously placed in the Roku package.
2. Install and authenticate the Supabase CLI, then set the replacement credential and deploy the function:

    ```powershell
    supabase secrets set OPENWEATHER_API_KEY="<replacement-key>"
    supabase functions deploy weather
    ```

3. Keep JWT verification enabled for the function. The Roku app sends its Supabase anonymous token with the request.

After applying the SQL migrations, verify in Supabase SQL Editor that there are no anonymous `SELECT` policies for the sensitive tables:

```sql
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
   and tablename in ('properties', 'reservations', 'guest_feedback')
   and cmd in ('SELECT', 'ALL');
```

If `supabase_live_alignment.sql` is run again later, rerun `supabase_guest_display.sql` afterward to restore the restricted policies.

## Release Package

### Ambient Audio Delivery

`forest_ambience.mp3` is intentionally streamed by the Roku `Audio` node and is excluded from the release ZIP. Keep the source master in [audio/forest_ambience.mp3](audio/forest_ambience.mp3), but do not serve production media from the mutable GitHub `main` branch.

Run [supabase_device_access_security.sql](supabase_device_access_security.sql) to create the media authorization RPC and private `channel-media` Storage bucket. Upload the approved full-length MP3 at `ambient/forest_ambience-v1.mp3`. Deploy the `ambient-audio` function without platform JWT verification because Roku's `Audio` node cannot send authorization headers; the function instead verifies the server-issued device credential before issuing a one-hour signed URL:

```powershell
supabase functions deploy ambient-audio --no-verify-jwt
```

The app uses this function automatically once deployed. Keep the bucket private, retain the MP3 format for Roku compatibility, and use a new versioned object path when replacing the track. Do not place a Supabase service-role key or Storage secret in the Roku package.

The full-length local master is retained for upload and revision control but is not part of the packaged channel.

Set a new `build_version` in `manifest` for every uploaded build. Create a clean package from the project root with:

```powershell
.\tools\build_release.ps1
```

The script writes `release/BrokenBowVacationCabins-build<build_version>.zip`, verifies the required package entries, and rejects a manifest containing an OpenWeather credential. Sideload this freshly generated ZIP for device acceptance testing and use the same artifact for Roku submission.

## How to Sideload:
1. Enable Developer Mode on your Roku TV remote:
   Home(3x) ➔ Up(2x) ➔ Right ➔ Left ➔ Right ➔ Left ➔ Right
2. Open http://<roku-tv-ip> in a web browser on your PC.
3. Upload this .ZIP package and click Install.
