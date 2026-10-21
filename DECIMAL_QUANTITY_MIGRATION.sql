-- KRBL Material Management: enable decimal quantities in shared Supabase records.
-- Run this script in Supabase Dashboard > SQL Editor.
-- This changes only quantity column types; existing values and rows are preserved.

alter table public.krbl_material_receipts
  alter column white_roll_packs type numeric using white_roll_packs::numeric,
  alter column white_roll_pcs type numeric using white_roll_pcs::numeric,
  alter column black_ribbon_packs type numeric using black_ribbon_packs::numeric,
  alter column black_ribbon_pcs type numeric using black_ribbon_pcs::numeric;

alter table public.krbl_mandi_issues
  alter column white_roll_packs type numeric using white_roll_packs::numeric,
  alter column white_roll_pcs type numeric using white_roll_pcs::numeric,
  alter column black_ribbon_packs type numeric using black_ribbon_packs::numeric,
  alter column black_ribbon_pcs type numeric using black_ribbon_pcs::numeric;
