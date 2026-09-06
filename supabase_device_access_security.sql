-- Cabin Concierge TV - device-bound access controls
-- Run after supabase_guest_display.sql and supabase_staff_pin_security.sql.

CREATE TABLE IF NOT EXISTS public.property_pin_attempts (
    device_id TEXT PRIMARY KEY,
    failed_attempts INT NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
    locked_until TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.roku_devices (
    device_id TEXT PRIMARY KEY,
    property_id TEXT NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    credential_hash TEXT NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.staff_authorizations (
    token_hash TEXT PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES public.roku_devices(device_id) ON DELETE CASCADE,
    property_id TEXT NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.property_pin_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roku_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_authorizations ENABLE ROW LEVEL SECURITY;

-- Remove the legacy anonymous endpoints before granting the device-bound APIs.
DROP FUNCTION IF EXISTS public.get_active_property_display(TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS public.verify_staff_company_pin(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.enroll_roku_device(p_device_id TEXT, p_property_pin TEXT)
RETURNS TABLE (approved BOOLEAN, device_token TEXT, retry_after_seconds INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
    v_property_id TEXT;
    v_attempt property_pin_attempts%ROWTYPE;
    v_token TEXT;
BEGIN
    IF length(p_device_id) < 16 OR length(p_property_pin) <> 4 THEN
        RETURN QUERY SELECT FALSE, '', 0;
        RETURN;
    END IF;
    SELECT * INTO v_attempt FROM property_pin_attempts WHERE device_id = p_device_id;
    IF FOUND AND v_attempt.locked_until > NOW() THEN
        RETURN QUERY SELECT FALSE, '', CEIL(EXTRACT(EPOCH FROM (v_attempt.locked_until - NOW())))::INT;
        RETURN;
    END IF;
    SELECT id INTO v_property_id FROM properties WHERE pin = p_property_pin;
    IF v_property_id IS NULL THEN
        INSERT INTO property_pin_attempts (device_id, failed_attempts, locked_until, updated_at)
        VALUES (p_device_id, 1, NULL, NOW())
        ON CONFLICT (device_id) DO UPDATE SET
            failed_attempts = CASE WHEN property_pin_attempts.failed_attempts + 1 >= 5 THEN 0 ELSE property_pin_attempts.failed_attempts + 1 END,
            locked_until = CASE WHEN property_pin_attempts.failed_attempts + 1 >= 5 THEN NOW() + INTERVAL '15 minutes' ELSE NULL END,
            updated_at = NOW();
        RETURN QUERY SELECT FALSE, '', 0;
        RETURN;
    END IF;
    v_token := encode(gen_random_bytes(32), 'hex');
    INSERT INTO roku_devices (device_id, property_id, credential_hash, revoked_at, updated_at)
    VALUES (p_device_id, v_property_id, extensions.crypt(v_token, extensions.gen_salt('bf')), NULL, NOW())
    ON CONFLICT (device_id) DO UPDATE SET property_id = EXCLUDED.property_id, credential_hash = EXCLUDED.credential_hash, revoked_at = NULL, updated_at = NOW();
    INSERT INTO property_pin_attempts (device_id, failed_attempts, locked_until, updated_at)
    VALUES (p_device_id, 0, NULL, NOW())
    ON CONFLICT (device_id) DO UPDATE SET failed_attempts = 0, locked_until = NULL, updated_at = NOW();
    RETURN QUERY SELECT TRUE, v_token, 0;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_active_property_display(p_device_id TEXT, p_device_token TEXT, p_staff_token TEXT DEFAULT NULL)
RETURNS TABLE (id TEXT, name TEXT, tagline TEXT, location TEXT, address TEXT, guest_name TEXT, stay_dates TEXT, wifi_network TEXT, wifi_password TEXT, wifi_speed TEXT, check_in_time TEXT, check_out_time TEXT, trash_day TEXT, quiet_hours TEXT, max_occupancy INT, host_name TEXT, host_phone TEXT, emergency_contact TEXT)
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
        p.wifi_network, p.wifi_password, p.wifi_speed, p.check_in_time, p.check_out_time, p.trash_day, p.quiet_hours, p.max_occupancy, p.host_name, p.host_phone, p.emergency_contact
    FROM authorized_device d JOIN properties p ON p.id = d.property_id
    LEFT JOIN LATERAL (
        SELECT reservation.* FROM reservations reservation
        WHERE reservation.property_id = p.id AND reservation.cancelled_at IS NULL
          AND ((reservation.check_in_at <= NOW() AND NOW() < reservation.check_out_at)
               OR (d.staff_preload AND reservation.check_in_at > NOW() AND reservation.check_in_at < (date_trunc('day', NOW() AT TIME ZONE 'America/Chicago') + INTERVAL '1 day') AT TIME ZONE 'America/Chicago'))
        ORDER BY CASE WHEN reservation.check_in_at <= NOW() AND NOW() < reservation.check_out_at THEN 0 ELSE 1 END, reservation.check_in_at
        LIMIT 1
    ) r ON TRUE;
$$;

CREATE OR REPLACE FUNCTION public.verify_staff_company_pin(p_device_id TEXT, p_device_token TEXT, p_company_pin TEXT)
RETURNS TABLE (approved BOOLEAN, staff_token TEXT, retry_after_seconds INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE v_device roku_devices%ROWTYPE; v_hash TEXT; v_attempt staff_pin_attempts%ROWTYPE; v_token TEXT;
BEGIN
    SELECT * INTO v_device FROM roku_devices WHERE device_id = p_device_id AND revoked_at IS NULL;
    IF NOT FOUND OR extensions.crypt(p_device_token, v_device.credential_hash) <> v_device.credential_hash THEN RETURN QUERY SELECT FALSE, '', 0; RETURN; END IF;
    SELECT pin_hash INTO v_hash FROM staff_pin_security WHERE id = TRUE AND configured_at IS NOT NULL;
    SELECT * INTO v_attempt FROM staff_pin_attempts WHERE property_id = v_device.property_id;
    IF FOUND AND v_attempt.locked_until > NOW() THEN RETURN QUERY SELECT FALSE, '', CEIL(EXTRACT(EPOCH FROM (v_attempt.locked_until - NOW())))::INT; RETURN; END IF;
    IF v_hash IS NOT NULL AND extensions.crypt(p_company_pin, v_hash) = v_hash THEN
        v_token := encode(gen_random_bytes(32), 'hex');
        INSERT INTO staff_authorizations (token_hash, device_id, property_id, expires_at) VALUES (extensions.crypt(v_token, extensions.gen_salt('bf')), v_device.device_id, v_device.property_id, NOW() + INTERVAL '10 minutes');
        INSERT INTO staff_pin_attempts (property_id, failed_attempts, locked_until, updated_at) VALUES (v_device.property_id, 0, NULL, NOW()) ON CONFLICT (property_id) DO UPDATE SET failed_attempts=0, locked_until=NULL, updated_at=NOW();
        RETURN QUERY SELECT TRUE, v_token, 0; RETURN;
    END IF;
    INSERT INTO staff_pin_attempts (property_id, failed_attempts, locked_until, updated_at) VALUES (v_device.property_id, 1, NULL, NOW()) ON CONFLICT (property_id) DO UPDATE SET failed_attempts=CASE WHEN staff_pin_attempts.failed_attempts+1>=5 THEN 0 ELSE staff_pin_attempts.failed_attempts+1 END, locked_until=CASE WHEN staff_pin_attempts.failed_attempts+1>=5 THEN NOW()+INTERVAL '15 minutes' ELSE NULL END, updated_at=NOW();
    RETURN QUERY SELECT FALSE, '', 0;
END;
$$;

REVOKE ALL ON TABLE public.property_pin_attempts, public.roku_devices, public.staff_authorizations FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enroll_roku_device(TEXT, TEXT), public.get_active_property_display(TEXT, TEXT, TEXT), public.verify_staff_company_pin(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enroll_roku_device(TEXT, TEXT), public.get_active_property_display(TEXT, TEXT, TEXT), public.verify_staff_company_pin(TEXT, TEXT, TEXT) TO anon;
NOTIFY pgrst, 'reload schema';