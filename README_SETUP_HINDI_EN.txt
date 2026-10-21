KRBL MATERIAL ISSUE MANAGEMENT — ONLINE PACKAGE
================================================

FILES
- index.html: your supplied original HTML layout, styling and sections, with a Supabase login/cloud integration layer.
- supabase-config.js: add your Project URL and Publishable key here.
- ADMIN_SETUP.sql: promote your own existing account to Admin after account creation.

SETUP
1. Open supabase-config.js in a text editor.
2. Replace the URL placeholder with your Supabase Project URL.
3. Replace the Publishable key placeholder with the key beginning sb_publishable_.
4. Save both files in the same folder.
5. Host both files over HTTPS.
6. Open the website, create an account, confirm the email if prompted, then sign in.
7. In Supabase SQL Editor run ADMIN_SETUP.sql after replacing EMAIL_HERE with your account email.
8. Test Admin and Viewer accounts in separate browsers before using real stock records.

SECURITY
- Never place a Supabase Secret key or service_role key in browser code.
- Keep Row Level Security (RLS) enabled.
- Do not put sensitive operational data into production until you test sign-in, role permissions, create/edit/delete, and two-user viewing.
- Existing localStorage records are not automatically migrated to the shared database. Export a JSON backup from the old dashboard first.
- A static HTML file is not live until deployed to an HTTPS host.

IMPORTANT
The dashboard design is based on your original HTML. The online integration still needs configuration, deployment, and testing. Treat this as a setup package, not a confirmed live app.
