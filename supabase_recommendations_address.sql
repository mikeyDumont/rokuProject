-- Migration: replace the recommendations "distance" column with an "address"
-- column so the Roku app can generate a Google Maps directions QR code.
-- Run this once against the live database.

ALTER TABLE public.recommendations
    ADD COLUMN IF NOT EXISTS address TEXT;

-- Fill in each row's address with the real street address before relying on
-- the generated Google Maps QR codes in the Roku app, e.g.:
-- UPDATE public.recommendations SET address = '123 Main St, Broken Bow, OK 74728' WHERE name = 'Friends Trail Loop';

ALTER TABLE public.recommendations
    DROP COLUMN IF EXISTS distance;
