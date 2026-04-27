# Supabase Auth Setup

TF.ai uses Supabase Auth for accounts and Supabase PostgREST for the public
character catalog.

## Required

1. Open Supabase Dashboard -> Authentication -> Providers.
2. Enable Email provider.
3. Run `docs/supabase-schema.sql` in Supabase SQL Editor.
4. Open Authentication -> URL Configuration.
5. Set Site URL to your published docs callback page:
   `https://YOUR_GITHUB_NAME.github.io/YOUR_REPO/auth-callback.html`
6. Add the same URL to Redirect URLs.

After that, users can create an account in TF.ai from Account, then publish
public characters. Public catalog browsing still works without an account.

If GitHub Pages is not published yet, either ignore the browser error after
clicking the email confirmation link and return to TF.ai to sign in, or disable
email confirmations in Authentication -> Providers -> Email while developing.

## Google OAuth Later

Google sign-in can use the same Supabase Auth project. Enable Google in
Authentication -> Providers, add the Google client ID/secret, then configure app
redirect links for desktop and mobile builds.
