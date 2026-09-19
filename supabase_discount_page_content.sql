-- Migration: make the Returning Guest Perks page fully content-driven.
-- Run this on databases created before nav_label/page_title/etc. existed on public.discounts.

ALTER TABLE public.discounts
    ADD COLUMN IF NOT EXISTS nav_label TEXT DEFAULT 'Returning Guest Perks',
    ADD COLUMN IF NOT EXISTS page_title TEXT DEFAULT 'RETURNING GUEST PERK',
    ADD COLUMN IF NOT EXISTS page_subtitle TEXT,
    ADD COLUMN IF NOT EXISTS code_label TEXT DEFAULT 'Direct Booking Discount Code:',
    ADD COLUMN IF NOT EXISTS website_label TEXT DEFAULT 'Visit our website:',
    ADD COLUMN IF NOT EXISTS website_url TEXT,
    ADD COLUMN IF NOT EXISTS footer_text TEXT;

-- Backfill existing rows with the copy that used to be hard-coded on the Roku app,
-- so already-configured discounts keep displaying the same text after upgrading.
UPDATE public.discounts
SET
    page_subtitle = COALESCE(page_subtitle, 'Enjoy an exclusive direct-booking discount on your next getaway.'),
    website_url = COALESCE(website_url, 'https://brokenbowvacationcabins.com'),
    footer_text = COALESCE(footer_text, 'Thanks again for choosing Broken Bow Vacation Cabins!')
WHERE page_subtitle IS NULL OR website_url IS NULL OR footer_text IS NULL;
