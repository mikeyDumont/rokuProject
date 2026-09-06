-- Cabin Concierge TV - guest display lifecycle migration
-- Run the ENTIRE file in the Supabase SQL Editor after supabase_live_alignment.sql.
-- This script creates public.reservations. It intentionally does not delete
-- legacy properties.guest_name or properties.stay_dates; remove those only
-- after active stays have been entered into public.reservations and verified.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pms_reservation_id TEXT,
    property_id TEXT NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    guest_display_name TEXT NOT NULL,
    check_in_at TIMESTAMPTZ NOT NULL,
    check_out_at TIMESTAMPTZ NOT NULL,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (check_out_at > check_in_at)
);

ALTER TABLE public.reservations
    ADD COLUMN IF NOT EXISTS pms_reservation_id TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'reservations_pms_reservation_id_key'
          AND conrelid = 'public.reservations'::regclass
    ) THEN
        ALTER TABLE public.reservations
            ADD CONSTRAINT reservations_pms_reservation_id_key UNIQUE (pms_reservation_id);
    END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS reservations_active_stay_idx
    ON public.reservations (property_id, check_in_at, check_out_at)
    WHERE cancelled_at IS NULL;

ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;

-- The Roku app resolves a property through this narrow RPC instead of reading
-- properties or reservations directly. Guest fields are present only while the
-- reservation is active: check_in_at <= now() < check_out_at.
CREATE OR REPLACE FUNCTION public.get_active_property_display(
    p_property_pin TEXT,
    p_include_arriving_guest BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    id TEXT,
    name TEXT,
    tagline TEXT,
    location TEXT,
    address TEXT,
    guest_name TEXT,
    stay_dates TEXT,
    wifi_network TEXT,
    wifi_password TEXT,
    wifi_speed TEXT,
    check_in_time TEXT,
    check_out_time TEXT,
    trash_day TEXT,
    quiet_hours TEXT,
    max_occupancy INT,
    host_name TEXT,
    host_phone TEXT,
    emergency_contact TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        p.id,
        p.name,
        p.tagline,
        p.location,
        p.address,
        COALESCE(r.guest_display_name, '') AS guest_name,
        CASE
            WHEN r.id IS NULL THEN ''
            ELSE to_char(r.check_in_at AT TIME ZONE 'America/Chicago', 'FMMonth FMDD')
                || ' - ' || to_char(r.check_out_at AT TIME ZONE 'America/Chicago', 'FMMonth FMDD')
        END AS stay_dates,
        p.wifi_network,
        p.wifi_password,
        p.wifi_speed,
        p.check_in_time,
        p.check_out_time,
        p.trash_day,
        p.quiet_hours,
        p.max_occupancy,
        p.host_name,
        p.host_phone,
        p.emergency_contact
    FROM public.properties AS p
    LEFT JOIN LATERAL (
                SELECT reservation.*
        FROM public.reservations AS reservation
        WHERE reservation.property_id = p.id
          AND reservation.cancelled_at IS NULL
                    AND (
                            (reservation.check_in_at <= NOW() AND NOW() < reservation.check_out_at)
                            OR (
                                    p_include_arriving_guest
                                    AND reservation.check_in_at > NOW()
                                    AND reservation.check_in_at < (
                                            date_trunc('day', NOW() AT TIME ZONE 'America/Chicago')
                                            + INTERVAL '1 day'
                                    ) AT TIME ZONE 'America/Chicago'
                            )
                    )
                ORDER BY
                        CASE WHEN reservation.check_in_at <= NOW() AND NOW() < reservation.check_out_at THEN 0 ELSE 1 END,
                        reservation.check_in_at ASC
        LIMIT 1
    ) AS r ON TRUE
    WHERE p.pin = p_property_pin
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_active_property_display(TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_active_property_display(TEXT, BOOLEAN) TO anon;

-- Direct table reads would expose future and prior guest stays. The Roku app
-- should use get_active_property_display instead.
DROP POLICY IF EXISTS "Allow public read access on properties" ON public.properties;
DROP POLICY IF EXISTS "Allow public read access on reservations" ON public.reservations;

-- Feedback is optional. If present, it is submitted anonymously but not publicly listed.
DO $$
BEGIN
    IF to_regclass('public.guest_feedback') IS NOT NULL THEN
        DROP POLICY IF EXISTS "Allow public read access on guest_feedback" ON public.guest_feedback;
    END IF;
END;
$$;

-- Expected verification result: one row with table_name = reservations.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'reservations';