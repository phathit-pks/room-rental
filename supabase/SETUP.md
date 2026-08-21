# Supabase setup

1. Create a free project at https://supabase.com/dashboard.
2. Open **SQL Editor**, paste `schema.sql`, and run it once.
3. Copy **Project URL** and **Publishable key** from Project Settings → API.
4. Run Flutter with the values supplied as compile-time variables:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Clear old browser data after a deployment

Give every production build a new cache version. When this value changes, the
app removes the old location cache before downloading fresh Supabase data:

```powershell
flutter build web --dart-define=CACHE_VERSION=2026-08-05-2
```

Use a release number, date, commit hash, or CI build number as the value.

Do not put the `service_role` key in Flutter or any browser application.

## Gemini rental-post parser

Create a Gemini API key in Google AI Studio, then keep it only as a Supabase
secret. Never add the Gemini key to Flutter, source control, or a web build.

```powershell
supabase login
supabase link --project-ref oqrxmwoirhbmrewrjoco
supabase secrets set GEMINI_API_KEY=YOUR_GEMINI_API_KEY
supabase functions deploy parse-rental-post
```

The Flutter app can call the deployed function through `RentalPostParser`.
The function accepts `text`, optional `source_url`, and optional ISO-8601
`posted_at`. It returns structured rental data under the `data` key. Missing
information is returned as `null`; parsed results should be reviewed by an
admin before publishing. The function also verifies the signed-in user against
the `profiles` table and rejects non-admin callers to protect the AI quota.

## Make the first admin

Create a user in Authentication first. Then run this in SQL Editor, replacing the email:

```sql
update public.profiles
set role = 'admin'
where id = (select id from auth.users where email = 'admin@example.com');
```

The current app keeps its location cache locally until remote repository wiring is enabled. The schema, security policies, authentication profile trigger, and image bucket are ready for that connection.
