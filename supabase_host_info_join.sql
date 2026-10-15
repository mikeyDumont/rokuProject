-- Cabin Concierge TV - pull host/schedule fields from org-scoped host_info
-- Run after supabase_org_scoped_access.sql.
--
-- Problem: get_active_property_display only ever read host_name, host_phone,
-- emergency_contact, check_in_time, check_out_time, quiet_hours, and trash_day
-- from the properties row. Those columns have since been dropped from
-- properties entirely (host_info is now the sole source), so the Welcome
-- screen rendered "Host: " and "Call/Text: " with nothing after them and the
-- old query would now fail outright on the missing columns. This rewrites
-- the query to pull those fields, plus check_in_time/check_out_time/
-- quiet_hours/trash_day, from host_info by org_id. wifi_speed has also been
-- dropped from properties with no host_info replacement, so it is removed
-- from the return table.

-- The live return type no longer matches this definition, and CREATE OR
-- REPLACE can't change OUT-parameter row types.
DROP FUNCTION IF EXISTS public.get_active_property_display(TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.get_active_property_display(p_device_id TEXT, p_device_token TEXT, p_staff_token TEXT DEFAULT NULL)
RETURNS TABLE (id TEXT, name TEXT, tagline TEXT, location TEXT, address TEXT, guest_name TEXT, stay_dates TEXT, wifi_network TEXT, wifi_password TEXT, check_in_time TEXT, check_out_time TEXT, trash_day TEXT, quiet_hours TEXT, max_occupancy INT, host_name TEXT, host_phone TEXT, emergency_contact TEXT)
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
        hi.host_name, hi.host_phone, hi.emergency_contact
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

-- DROP FUNCTION above also dropped its prior grant; anon needs it restored.
REVOKE ALL ON FUNCTION public.get_active_property_display(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_active_property_display(TEXT, TEXT, TEXT) TO anon;

NOTIFY pgrst, 'reload schema';
