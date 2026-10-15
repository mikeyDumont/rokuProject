-- PMC logo uploads in Supabase Storage. Run after supabase_company_branding.sql.
-- Logos are public brand assets; database uploads remain restricted by Storage RLS.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('pmc-logos', 'pmc-logos', TRUE, 3145728, ARRAY['image/png', 'image/jpeg'])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

ALTER TABLE public.host_info
    ADD COLUMN IF NOT EXISTS brand_logo_path TEXT;

DROP FUNCTION IF EXISTS public.get_active_property_display(TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.get_active_property_display(p_device_id TEXT, p_device_token TEXT, p_staff_token TEXT DEFAULT NULL)
RETURNS TABLE (id TEXT, name TEXT, tagline TEXT, location TEXT, address TEXT, guest_name TEXT, stay_dates TEXT, wifi_network TEXT, wifi_password TEXT, check_in_time TEXT, check_out_time TEXT, trash_day TEXT, quiet_hours TEXT, max_occupancy INT, host_name TEXT, host_phone TEXT, emergency_contact TEXT, brand_logo_url TEXT, brand_logo_path TEXT)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    WITH authorized_device AS (
        SELECT d.property_id, EXISTS (
            SELECT 1 FROM staff_authorizations a
            WHERE a.device_id = d.device_id AND a.property_id = d.property_id
              AND a.token_hash = extensions.crypt(COALESCE(p_staff_token, ''), a.token_hash)
              AND a.expires_at > NOW() AND a.used_at IS NULL
        ) AS staff_preload
        FROM roku_devices d
        WHERE d.device_id = p_device_id AND d.revoked_at IS NULL
          AND extensions.crypt(p_device_token, d.credential_hash) = d.credential_hash
    )
    SELECT p.id, p.name, p.tagline, p.location, p.address,
        COALESCE(r.guest_display_name, '') AS guest_name,
        CASE WHEN r.id IS NULL THEN '' ELSE to_char(r.check_in_at AT TIME ZONE 'America/Chicago', 'FMMonth FMDD') || ' - ' || to_char(r.check_out_at AT TIME ZONE 'America/Chicago', 'FMMonth FMDD') END,
        p.wifi_network, p.wifi_password,
        hi.check_in_time, hi.check_out_time, hi.trash_day, hi.quiet_hours,
        p.max_occupancy,
        hi.host_name, hi.host_phone, hi.emergency_contact,
        COALESCE(hi.brand_logo_url, ''), COALESCE(hi.brand_logo_path, '')
    FROM authorized_device d JOIN properties p ON p.id = d.property_id
    LEFT JOIN host_info hi ON hi.org_id = p.org_id
    LEFT JOIN LATERAL (
        SELECT reservation.* FROM reservations reservation
        WHERE reservation.property_id = p.id AND reservation.cancelled_at IS NULL
          AND ((reservation.check_in_at <= NOW() AND NOW() < reservation.check_out_at)
               OR (d.staff_preload AND reservation.check_in_at > NOW() AND reservation.check_in_at < (date_trunc('day', NOW() AT TIME ZONE 'America/Chicago') + INTERVAL '1 day') AT TIME ZONE 'America/Chicago'))
        ORDER BY CASE WHEN reservation.check_in_at <= NOW() AND NOW() < reservation.check_out_at THEN 0 ELSE 1 END, reservation.check_in_at
        LIMIT 1
    ) r ON TRUE;
$$;

REVOKE ALL ON FUNCTION public.get_active_property_display(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_active_property_display(TEXT, TEXT, TEXT) TO anon;

NOTIFY pgrst, 'reload schema';