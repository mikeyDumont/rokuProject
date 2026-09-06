-- Cabin Concierge TV - staff PIN server-side verification
-- Run once in the Supabase SQL Editor. Then execute the UPDATE at the end
-- with the real company PIN directly in the SQL Editor; never add it to Roku.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.staff_pin_security (
    id BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),
    pin_hash TEXT NOT NULL,
    configured_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.staff_pin_attempts (
    property_id TEXT PRIMARY KEY REFERENCES public.properties(id) ON DELETE CASCADE,
    failed_attempts INT NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
    locked_until TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.staff_pin_security ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_pin_attempts ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.verify_staff_company_pin(
    p_property_pin TEXT,
    p_company_pin TEXT
)
RETURNS TABLE (approved BOOLEAN, retry_after_seconds INT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_property_id TEXT;
    v_pin_hash TEXT;
    v_configured_at TIMESTAMPTZ;
    v_attempt staff_pin_attempts%ROWTYPE;
    v_matches BOOLEAN;
BEGIN
    SELECT id INTO v_property_id
    FROM properties
    WHERE pin = p_property_pin;

    IF v_property_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 0;
        RETURN;
    END IF;

    SELECT pin_hash, configured_at INTO v_pin_hash, v_configured_at
    FROM staff_pin_security
    WHERE id = TRUE;

    IF v_pin_hash IS NULL OR v_configured_at IS NULL THEN
        RETURN QUERY SELECT FALSE, 0;
        RETURN;
    END IF;

    SELECT * INTO v_attempt
    FROM staff_pin_attempts
    WHERE property_id = v_property_id;

    IF FOUND AND v_attempt.locked_until IS NOT NULL AND v_attempt.locked_until > NOW() THEN
        RETURN QUERY SELECT FALSE, CEIL(EXTRACT(EPOCH FROM (v_attempt.locked_until - NOW())))::INT;
        RETURN;
    END IF;

    v_matches := extensions.crypt(p_company_pin, v_pin_hash) = v_pin_hash;
    IF v_matches THEN
        INSERT INTO staff_pin_attempts (property_id, failed_attempts, locked_until, updated_at)
        VALUES (v_property_id, 0, NULL, NOW())
        ON CONFLICT (property_id) DO UPDATE
        SET failed_attempts = 0, locked_until = NULL, updated_at = NOW();
        RETURN QUERY SELECT TRUE, 0;
        RETURN;
    END IF;

    INSERT INTO staff_pin_attempts (property_id, failed_attempts, locked_until, updated_at)
    VALUES (v_property_id, 1, NULL, NOW())
    ON CONFLICT (property_id) DO UPDATE
    SET failed_attempts = CASE
            WHEN staff_pin_attempts.failed_attempts + 1 >= 5 THEN 0
            ELSE staff_pin_attempts.failed_attempts + 1
        END,
        locked_until = CASE
            WHEN staff_pin_attempts.failed_attempts + 1 >= 5 THEN NOW() + INTERVAL '15 minutes'
            ELSE NULL
        END,
        updated_at = NOW();

    SELECT * INTO v_attempt
    FROM staff_pin_attempts
    WHERE property_id = v_property_id;
    IF v_attempt.locked_until IS NOT NULL THEN
        RETURN QUERY SELECT FALSE, 900;
    ELSE
        RETURN QUERY SELECT FALSE, 0;
    END IF;
END;
$$;

REVOKE ALL ON TABLE public.staff_pin_security, public.staff_pin_attempts FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_staff_company_pin(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_staff_company_pin(TEXT, TEXT) TO anon;

-- Ensure the REST API discovers the newly created RPC immediately.
NOTIFY pgrst, 'reload schema';

-- Replace the placeholder directly in the SQL Editor before using the staff menu.
INSERT INTO public.staff_pin_security (id, pin_hash, configured_at, updated_at)
VALUES (TRUE, extensions.crypt('REPLACE_WITH_YOUR_COMPANY_PIN', extensions.gen_salt('bf')), NULL, NOW())
ON CONFLICT (id) DO NOTHING;

-- After the script succeeds, run this separately with the real staff PIN:
-- UPDATE public.staff_pin_security
-- SET pin_hash = extensions.crypt('YOUR_REAL_COMPANY_PIN', extensions.gen_salt('bf')),
--     configured_at = NOW(), updated_at = NOW()
-- WHERE id = TRUE;

-- Verify deployment directly in the SQL Editor after setting the real PIN.
-- Replace both values and expect approved = true for a valid pair.
-- SELECT * FROM public.verify_staff_company_pin('PROPERTY_PIN', 'COMPANY_PIN');