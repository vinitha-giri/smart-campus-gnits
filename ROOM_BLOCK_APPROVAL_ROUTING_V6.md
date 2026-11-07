# Room-block approval and conflict-review routing (V6)

## Room ownership

The first character of the room number determines its owning block and the Head Staff department that receives booking requests:

- `A` -> Admin Block (`ADMIN_BLOCK`)
- `B` -> EEE (`EEE`)
- `C` -> CSE (`CSE`)
- `D` -> ECE (`ECE`)
- `F` -> IT (`IT`)
- `S` -> Silver Jubilee Block (`SILVER_JUBILEE_BLOCK`)

Department normalization accepts common department names and block labels (for example, `Admin`, `Admin Block`, `A Block`; `S`, `S Block`, `Silver Jubilee Block`). The general `ADMIN` role remains separate from the Admin Block `HEAD_STAFF` account.

## Booking approval

- Faculty requests route to the Head Staff assigned to the room's owning block, regardless of the faculty member's department.
- A Head Staff member booking a room in her own block is immediately self-approved and recorded as `CONFIRMED` with approver identity and timestamp.
- A Head Staff member booking a room in another block routes to that block's Head Staff.
- General Admin retains global approval access.
- Pending approval records retain the canonical owning-block value in `approval_department`.

## Conflict review

- Faculty and Head Staff can submit conflict reviews.
- The requester's department Head Staff and the existing room's owning-block Head Staff are notified. If both are the same department, the Head Staff sees one request.
- A Head Staff can make the final `KEEP_EXISTING` decision for their department. For a cross-department review, both concerned Heads must record that decision.
- A Head Staff can decline or explicitly escalate an unresolved review to the separate general Admin account.
- Original bookings are not changed by these decisions. Admin-only alternate-room/time resolution remains available for escalated cases.
- Head Staff reminder routing uses the same normalized department identities.

## Compatibility

The existing V5.1 tables and columns are reused; this patch does not require a database migration. Older `AGREE` conflict-review clients are accepted as `KEEP_EXISTING` for compatibility.
