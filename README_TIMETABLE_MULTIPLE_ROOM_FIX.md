# Timetable upload fix — comma-separated rooms in subject parentheses

The Excel importer now supports subject cells such as:

`OOPJ/OS/DBMS(CL-5,F006,F103)`

The values inside the final parentheses are treated as three physical room labels:
- `CL-5`
- `F006`
- `F103`

Each room must resolve through `rooms.room_no`, `room_aliases`, or `lecture_hall_mapping`. When all resolve, the importer creates one timetable/occupancy event per physical room.

This keeps the original behavior unchanged for normal values such as:
- `DSUR(C401)`
- `CNS(LH-3)`
- `FM(S4)`

If any one of the comma-separated room labels is not present in the database (or an alias/mapping), the upload is rejected and the error names the specific missing room.

## What to do after replacing the project

1. Stop the currently running Spring Boot backend.
2. Replace the project with this updated version.
3. Start the backend again.
4. Upload the same `.xlsx` workbook.
5. If the database contains all three physical rooms, the previous combined-room error will no longer occur.

If the next error names a single room such as `F006` or `F103`, that means the parser fix is working and that particular room still needs to be added to `rooms` or mapped through `room_aliases` / `lecture_hall_mapping`.

## Alternative without changing the backend

For a single-room-only importer, the workbook can instead represent multiple rooms as separate rows for the same day/time, with one LH-No per row. The updated importer supports both formats.
