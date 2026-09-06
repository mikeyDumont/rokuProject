-- Cabin Concierge TV - live database alignment migration
-- Run once in the Supabase SQL Editor for project rbuyznszkwdyafiujhas.
-- This migration is additive and preserves existing data.

-- The live properties table is missing the fields consumed by
-- MapSupabasePropertyToProfile in source/api.brs.
ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS tagline TEXT,
    ADD COLUMN IF NOT EXISTS wifi_speed TEXT,
    ADD COLUMN IF NOT EXISTS check_in_time TEXT DEFAULT '4:00 PM',
    ADD COLUMN IF NOT EXISTS check_out_time TEXT DEFAULT '11:00 AM',
    ADD COLUMN IF NOT EXISTS trash_day TEXT,
    ADD COLUMN IF NOT EXISTS quiet_hours TEXT DEFAULT '10:00 PM - 8:00 AM',
    ADD COLUMN IF NOT EXISTS host_name TEXT,
    ADD COLUMN IF NOT EXISTS host_phone TEXT,
    ADD COLUMN IF NOT EXISTS emergency_contact TEXT DEFAULT 'Dial 911';

-- Global rows use NULL property_id; non-NULL values override or supplement
-- them for a specific properties.id.
ALTER TABLE public.house_rules
    ADD COLUMN IF NOT EXISTS property_id TEXT REFERENCES public.properties(id) ON DELETE CASCADE;

ALTER TABLE public.recommendations
    ADD COLUMN IF NOT EXISTS property_id TEXT REFERENCES public.properties(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS distance TEXT,
    ADD COLUMN IF NOT EXISTS rating TEXT,
    ADD COLUMN IF NOT EXISTS price TEXT,
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS host_tip TEXT,
    ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;

-- Preserve the live required column while copying it into the app contract.
ALTER TABLE public.checkout_tasks
    ADD COLUMN IF NOT EXISTS property_id TEXT REFERENCES public.properties(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS task_key TEXT,
    ADD COLUMN IF NOT EXISTS is_required BOOLEAN,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

UPDATE public.checkout_tasks
SET is_required = required
WHERE is_required IS NULL AND required IS NOT NULL;

UPDATE public.checkout_tasks
SET is_required = TRUE
WHERE is_required IS NULL;

UPDATE public.checkout_tasks
SET task_key = 'task_' || id::TEXT
WHERE task_key IS NULL OR task_key = '';

ALTER TABLE public.checkout_tasks
    ALTER COLUMN is_required SET DEFAULT TRUE,
    ALTER COLUMN is_required SET NOT NULL,
    ALTER COLUMN task_key SET NOT NULL;

-- All content tables must be readable by the Roku app's configured API role.
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.house_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkout_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access on properties" ON public.properties;
CREATE POLICY "Allow public read access on properties"
    ON public.properties FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public read access on house_rules" ON public.house_rules;
CREATE POLICY "Allow public read access on house_rules"
    ON public.house_rules FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public read access on recommendations" ON public.recommendations;
CREATE POLICY "Allow public read access on recommendations"
    ON public.recommendations FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public read access on checkout_tasks" ON public.checkout_tasks;
CREATE POLICY "Allow public read access on checkout_tasks"
    ON public.checkout_tasks FOR SELECT USING (true);
