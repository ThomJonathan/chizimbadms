# Chizimba App Auth Addition

This update adds:
- Login screen (custom auth using `public.users`)
- Monitor Signup with constituency/ward/station selection and enforcement that a station can only be assigned to one monitor
- Monitor Home page (shows assigned station details)
- Admin Home page (shows `vote_summary`)

Navigation:
- App starts at LoginPage.
- From Login, admins go to AdminHomePage; monitors go to MonitorHomePage.
- Original public browsing screen remains available in `ElectionHomeScreen` (you can add a route/button to access it if needed).

Backend assumptions:
- RLS allows:
  - select on `users` for login lookup (phone, role, is_active, password)
  - insert into `users` for signup
  - select on `constituency`, `ward`, `polling_station`
  - execute `assign_monitor_to_station` and `get_monitor_station` RPCs
- `assign_monitor_to_station(station_name text, monitor_phone varchar)` returns boolean true on success (your SQL provided matches this).

Security note:
- Passwords are stored and compared as plain text per your schema. For production, switch to hashed passwords and use Supabase Auth or PostgreSQL `crypt()`.

Files added/changed:
- lib/auth/login_page.dart — LoginPage
- lib/auth/signup_page.dart — SignupPage
- lib/home/monitor_home_page.dart — MonitorHomePage
- lib/home/admin_home_page.dart — AdminHomePage
- lib/main.dart — imports auth/login_page.dart and sets `home: LoginPage()`

Configure Supabase keys in main.dart as already present.
