# Life Group Randomizer

A small web app for randomly placing church members into life groups of 4–5 people.

## Pages

- `/` — Sign-up form where members enter their first and last name
- `/admin` — List of all submissions (with remove buttons)
- `/groups` — Press "Create Life Groups" to randomly assign everyone into groups of 4–5 (ideally 5); press again to reshuffle
- `/qr` — QR code that links to the sign-up form (download as PNG or print)

## Stack

- Next.js (App Router) deployed on Vercel
- Supabase (`lifegroup-randomizer` project) for storage — table `public.lifegroup_members`

The Supabase publishable key in `lib/supabase.js` is public by design; data access is governed by row level security policies. Note: the admin pages are unauthenticated (anyone with the URL can view/manage the list), which is a deliberate simplicity trade-off for this use case.

## Development

```bash
npm install
npm run dev
```
