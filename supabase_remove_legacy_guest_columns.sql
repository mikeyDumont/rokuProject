-- Optional cleanup migration.
-- Run only after all active reservations have been entered in public.reservations
-- and the Roku app has been verified against get_active_property_display.

ALTER TABLE public.properties
    DROP COLUMN IF EXISTS guest_name,
    DROP COLUMN IF EXISTS stay_dates;