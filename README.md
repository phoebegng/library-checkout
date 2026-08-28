# Corporate Learning Library

A browser-based library checkout tool for managing your corporate learning library. No server or Node.js required — runs directly in any web browser.

## Features

- Browse the full book catalog with availability badges (Available / Checked Out)
- Check out books by entering your name and email (30-day loan period)
- Return books with one click
- Admin panel: add, edit, delete books and manage all checkouts
- Overdue tracking with automated email reminders via Outlook SMTP
- History log of all past checkouts

---

## Setup (5–10 minutes)

### Step 1 — Create a Supabase Project

1. Go to [https://supabase.com](https://supabase.com) and sign up for a free account
2. Click **New Project**, fill in the name, and wait for it to provision (~1 minute)
3. Go to **Settings → API** and copy:
   - **Project URL** (looks like `https://abcdefg.supabase.co`)
   - **anon / public** key (a long JWT string)

### Step 2 — Set Up the Database

1. In your Supabase project, click **SQL Editor → New Query**
2. Open `supabase-schema.sql` from this folder, paste all the contents, and click **Run**
3. This creates the tables, indexes, and sample books

### Step 3 — Configure the App

1. Open `config.js` in any text editor
2. Replace the placeholder values:

```js
window.SUPABASE_URL = 'https://your-project.supabase.co';
window.SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5...';
```

### Step 4 — Open the App

Double-click `index.html` to open it in your browser. That's it!

- **Catalog**: `index.html` — browse and check out books
- **Admin**: `admin.html` — manage books, view checkouts, send overdue emails
- **Settings**: `settings.html` — change loan period

---

## Setting Up Overdue Email Reminders

Overdue emails are sent via a **Supabase Edge Function** (runs in Supabase's cloud).

### Deploy the Edge Function

You need the [Supabase CLI](https://supabase.com/docs/guides/cli). If you have a colleague with Node.js available, ask them to run:

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase functions deploy send-overdue-emails
```

Alternatively, you can paste the contents of `supabase/functions/send-overdue-emails/index.ts` directly into the **Supabase Dashboard → Edge Functions → Create new function**.

### Add SMTP Secrets

In **Supabase Dashboard → Edge Functions → Manage Secrets**, add:

| Secret | Value |
|---|---|
| `OUTLOOK_SMTP_HOST` | `smtp.office365.com` |
| `OUTLOOK_SMTP_PORT` | `587` |
| `OUTLOOK_SMTP_USER` | `your@company.com` |
| `OUTLOOK_SMTP_PASS` | `yourpassword` |
| `FROM_EMAIL` | `library@company.com` |

### Send Reminder Emails

Go to **Admin → Overdue tab** and click **Send Reminder Emails**. This manually triggers the function. You can also schedule it to run daily using [cron-job.org](https://cron-job.org) — set it to call `POST https://your-project.supabase.co/functions/v1/send-overdue-emails` with your anon key as a Bearer token.

---

## File Structure

```
library-checkout/
├── index.html          ← Main book catalog
├── admin.html          ← Admin panel
├── settings.html       ← Settings
├── config.js           ← ⚠️ Edit this with your Supabase credentials
├── supabase-schema.sql ← Run this in Supabase SQL editor
└── supabase/
    └── functions/
        └── send-overdue-emails/
            └── index.ts  ← Overdue email Edge Function
```

---

## Sharing with Your Team

To share with coworkers, you have a few options:

1. **Host on Netlify** (free): Drag the folder to [netlify.com/drop](https://app.netlify.com/drop)
2. **SharePoint**: Upload the folder to a SharePoint document library and share the link to `index.html`
3. **Local network**: Place the folder on a shared network drive; anyone can open `index.html` directly

> **Note:** Some browsers block direct `file://` Supabase API calls. If the catalog doesn't load when opened directly, host it via Netlify Drop instead.
