# GNITS Smart Campus — Batch 1

Implemented in this build:

1. College-email login (`@gnits.ac.in`) instead of username login.
2. College-email signup for Faculty/Student accounts.
3. Department captured for new accounts; Faculty must provide a department.
4. `HEAD_STAFF` role supported by backend login and dashboard routing.
5. Head Staff is intentionally NOT self-registerable; an administrator must create/convert Head Staff accounts.
6. Admin Manage Users now displays email and department.
7. Password recovery now uses college email + registered name (same temporary recovery approach as before; OTP/email verification will be a later security batch).

## Database migration

Run `database/upgrade_email_head_staff.sql` once against the production/local Smart Campus MySQL database.

If an old user account has a username such as `admin` instead of a college email, assign the real institutional email before using that account with the new login screen. Example:

```sql
UPDATE users
SET email='admin@gnits.ac.in', username='admin@gnits.ac.in'
WHERE username='admin';
```

For a Head Staff account, use a real institutional account and department, for example:

```sql
UPDATE users
SET email='hod.cse@gnits.ac.in',
    username='hod.cse@gnits.ac.in',
    department='CSE',
    role='HEAD_STAFF'
WHERE username='existing-account';
```

Do not use example addresses above unless they are the real accounts. Replace them with actual GNITS college emails.

## Local test

1. Start the Spring Boot backend.
2. Start Flutter web with `flutter run -d chrome`.
3. Open Create Account and verify:
   - a non-`@gnits.ac.in` email is rejected;
   - Faculty requires Department;
   - Student can create an account with a college email;
   - Head Staff is available on the Login role selector but is not available in public signup.
4. Log in using the new college email.
5. Confirm Admin > Manage Users shows EMAIL and DEPARTMENT.

## Important

The full project build was not run in this packaging environment because the supplied Maven wrapper is missing `.mvn/wrapper/maven-wrapper.properties` and Flutter is not installed in the packaging environment. Please run `flutter analyze` and the normal Spring Boot build on your Windows development machine before replacing the currently working project.
