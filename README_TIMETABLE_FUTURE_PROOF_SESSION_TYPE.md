# Future-proof timetable upload

The timetable importer no longer hard-codes activity names such as Lunch Break,
Pre-Placement Training, Placement, or Guest Lecture.

## Session Type
The generated Excel starter template contains a `Session Type` column:
- `CLASS`: a physical room is required. The importer resolves the room from
  `LH-No/Room` or a room in parentheses in the subject, including multiple
  comma-separated rooms.
- `ROOMLESS`: no physical room is required. The timetable event is stored,
  but it never creates classroom occupancy.

Any future activity name can be used with `ROOMLESS`.

## Backward compatibility
Older workbooks without `Session Type` are accepted. A blank room is treated
as room-less for compatibility; new templates should use `CLASS` or `ROOMLESS`
explicitly so missing rooms on normal classes are caught.

## Database compatibility
`TimetableSchemaInitializer` automatically makes `timetable_entries.room_id`
nullable on application startup for existing MySQL databases. The manual
fallback is `database/allow_roomless_timetable.sql`.
