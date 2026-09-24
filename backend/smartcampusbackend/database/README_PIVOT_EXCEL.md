# Pivot Timetable Excel Flow

The admin downloads an Excel template with exactly this structure:

| Day | 9:00-10:00 | 10:00-11:00 | 11:10-12:10 | 1:00-2:00 | 2:00-3:00 | 3:00-4:00 | LH-No |
|---|---|---|---|---|---|---|---|
| MONDAY | DSUR | CNS | BDA | | | | C-301 |
| TUESDAY | FM | DSUR | | | | | C-301 |
| WEDNESDAY | BSPC | BDA | CNS | | | | C-301 |
| THURSDAY | DSUR | BSPC | | | | | C-301 |
| FRIDAY | CNS | FM | | | | | C-301 |
| SATURDAY | | | | | | | C-301 |

The LH-No is the physical `rooms.room_no`. If a day uses multiple rooms, add another row with the same day and a different LH-No.

Every non-empty subject cell is converted into one timetable entry and therefore drives `/api/occupancy`.
