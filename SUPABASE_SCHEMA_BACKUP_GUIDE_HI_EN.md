# KRBL Digital Equipment — Supabase Schema Backup Guide

## Purpose
Keep a record of the database structure so the system can be rebuilt or migrated if the hosting provider changes. This is separate from the JSON transaction-data backup button in the dashboard.

## Safety
- The companion SQL file, `SUPABASE_SCHEMA_INSPECTION_READ_ONLY.sql`, contains SELECT queries only.
- It does not create, alter, update, or delete database objects or records.
- Do not run old setup or migration scripts as a backup procedure.
- Never put a Supabase service-role key, database password, access token, or private credentials in this GitHub repository.

## Steps
1. Open the existing KRBL Supabase project and go to SQL Editor.
2. Open `SUPABASE_SCHEMA_INSPECTION_READ_ONLY.sql` from this repository.
3. Copy the SQL into SQL Editor and run it.
4. For each result grid, use the result grid's download/export option to save CSV files.
5. Keep the CSV files alongside the dashboard's `KRBL_Equipment_Full_Backup_YYYY-MM-DD.json` export.
6. Store a copy in a company-approved secure location. Do not share user emails or role data outside authorized KRBL personnel.

## Important limitations
- This inventory documents public-schema structure, RLS policies, indexes, triggers, and selected custom functions. It does not export actual database rows, Auth user passwords, secrets, or Supabase project settings.
- The dashboard JSON export covers the equipment transactions and attempts the two Excel archive tables. It is not a full Supabase database backup.
- Auth users and role assignments need a separately authorized administrative backup/recreation process. Never export password hashes or credentials.
- Confirm that the export result sets are complete and that the project/table names match the live project before relying on them for migration.

## Known equipment module objects from repository migrations
- `krbl_equipment_transactions`
- `krbl_equipment_audit_log`
- `krbl_equipment_excel_import`
- `krbl_equipment_excel_balance_check` (referenced by the dashboard; confirm its live definition)
- `krbl_user_roles` (shared role table; do not overwrite it)

## Recovery rule
Do not run any setup/migration SQL against the live project merely to create a backup. Use the read-only inventory first, then plan restoration in a separate test project or approved migration window.
