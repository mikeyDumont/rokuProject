-- Cabin Concierge TV - device-gated access for org/property-scoped content
-- Run after supabase_device_access_security.sql.
--
-- Problem: house_rules, recommendations, checkout_tasks, discounts, and host_info
-- all had "USING (true)" SELECT policies, so anyone holding the public anon key
-- could read every organization's data directly via REST with no PIN or device
-- auth. This migration removes those open policies and replaces direct table
-- reads with SECURITY DEFINER RPCs gated by the same device_id/device_token
-- pairing already used by get_active_property_display.
--
-- It also drops the legacy single-argument get_active_property_display(text)
-- RPC, which let anyone brute-force a 4-digit property PIN (no device binding,
-- no rate limiting) to read full guest display data including the WiFi password.

DROP FUNCTION IF EXISTS public.get_active_property_display(TEXT);

CREATE OR REPLACE FUNCTION public.get_house_rules(p_device_id TEXT, p_device_token TEXT)
RETURNS TABLE (title TEXT, category TEXT, summary TEXT, details TEXT, fine TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    WITH authorized_device AS (
        SELECT p.id AS property_id, p.org_id
        FROM roku_devices d
        JOIN properties p ON p.id = d.property_id
        WHERE d.device_id = p_device_id
          AND d.revoked_at IS NULL
          AND extensions.crypt(p_device_token, d.credential_hash) = d.credential_hash
    )
    SELECT hr.title, hr.category, hr.summary, hr.details, hr.fine
    FROM house_rules hr, authorized_device ad
    WHERE hr.property_id = ad.property_id
       OR (hr.property_id IS NULL AND hr.org_id = ad.org_id)
       OR (hr.property_id IS NULL AND hr.org_id IS NULL)
    ORDER BY hr.sort_order ASC;
$$;

CREATE OR REPLACE FUNCTION public.get_recommendations(p_device_id TEXT, p_device_token TEXT)
RETURNS TABLE (name TEXT, category TEXT, address TEXT, image_url TEXT, is_sponsored BOOLEAN, description TEXT, host_tip TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    WITH authorized_device AS (
        SELECT p.org_id
        FROM roku_devices d
        JOIN properties p ON p.id = d.property_id
        WHERE d.device_id = p_device_id
          AND d.revoked_at IS NULL
          AND extensions.crypt(p_device_token, d.credential_hash) = d.credential_hash
    )
    SELECT r.name, r.category, r.address, r.image_url, r.is_sponsored, r.description, r.host_tip
    FROM recommendations r, authorized_device ad
    WHERE (r.org_id = ad.org_id OR r.org_id IS NULL)
      AND r.is_active = true
    ORDER BY r.sort_order ASC;
$$;

CREATE OR REPLACE FUNCTION public.get_checkout_tasks(p_device_id TEXT, p_device_token TEXT)
RETURNS TABLE (id TEXT, task_key TEXT, title TEXT, time_estimate TEXT, is_required BOOLEAN)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    WITH authorized_device AS (
        SELECT p.id AS property_id, p.org_id
        FROM roku_devices d
        JOIN properties p ON p.id = d.property_id
        WHERE d.device_id = p_device_id
          AND d.revoked_at IS NULL
          AND extensions.crypt(p_device_token, d.credential_hash) = d.credential_hash
    )
    SELECT ct.id, ct.task_key, ct.title, ct.time_estimate, ct.is_required
    FROM checkout_tasks ct, authorized_device ad
    WHERE ct.property_id = ad.property_id
       OR (ct.property_id IS NULL AND ct.org_id = ad.org_id)
       OR (ct.property_id IS NULL AND ct.org_id IS NULL)
    ORDER BY ct.sort_order ASC;
$$;

CREATE OR REPLACE FUNCTION public.get_active_discount(p_device_id TEXT, p_device_token TEXT)
RETURNS TABLE (
    title TEXT, code TEXT, description TEXT, banner_text TEXT,
    nav_label TEXT, page_title TEXT, page_subtitle TEXT, code_label TEXT,
    website_label TEXT, website_url TEXT, footer_text TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    WITH authorized_device AS (
        SELECT p.id AS property_id, p.org_id
        FROM roku_devices d
        JOIN properties p ON p.id = d.property_id
        WHERE d.device_id = p_device_id
          AND d.revoked_at IS NULL
          AND extensions.crypt(p_device_token, d.credential_hash) = d.credential_hash
    )
    SELECT disc.title, disc.code, disc.description, disc.banner_text,
           disc.nav_label, disc.page_title, disc.page_subtitle, disc.code_label,
           disc.website_label, disc.website_url, disc.footer_text
    FROM discounts disc, authorized_device ad
    WHERE disc.is_active = true
      AND (
        disc.property_id = ad.property_id
        OR (disc.property_id IS NULL AND disc.org_id = ad.org_id)
        OR (disc.property_id IS NULL AND disc.org_id IS NULL)
      )
    ORDER BY disc.sort_order ASC
    LIMIT 1;
$$;

-- Direct table reads would expose every organization's data to any anon-key holder.
DROP POLICY IF EXISTS "Allow public read access on house_rules" ON public.house_rules;
DROP POLICY IF EXISTS "Allow public read access on recommendations" ON public.recommendations;
DROP POLICY IF EXISTS "Allow public read access on checkout_tasks" ON public.checkout_tasks;
DROP POLICY IF EXISTS "Allow public read access on discounts" ON public.discounts;
DROP POLICY IF EXISTS "Allow public read access on host_info" ON public.host_info;

REVOKE ALL ON FUNCTION public.get_house_rules(TEXT, TEXT), public.get_recommendations(TEXT, TEXT), public.get_checkout_tasks(TEXT, TEXT), public.get_active_discount(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_house_rules(TEXT, TEXT), public.get_recommendations(TEXT, TEXT), public.get_checkout_tasks(TEXT, TEXT), public.get_active_discount(TEXT, TEXT) TO anon;

NOTIFY pgrst, 'reload schema';
