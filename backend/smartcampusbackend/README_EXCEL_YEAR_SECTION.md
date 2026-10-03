# Timetable Excel: Year + Department + Section

A section name such as `CSE-A` is **not unique** because every year can have CSE-A.

Use this sheet naming convention:

`YEAR-DEPARTMENT-SECTION`

Examples:
- `1st-CSE-A`
- `2nd-CSE-A`
- `3rd-CSE-A`
- `4th-CSE-A`

The backend stores this complete class key in `section_name`, together with the selected `academic_year` and `semester_no`.

Therefore:

- `1st-CSE-A` and `4th-CSE-A` are different timetables.
- Deleting `3rd-CSE-B` does not delete `2nd-CSE-B`.
- Re-uploading `4th-CSE-A` replaces only `4th-CSE-A` for the selected academic year and semester.
- Admin can delete any starter sheet that does not exist at GNITS.
- Admin can add/rename sheets for the actual sections/classes available that year.

Recommended workflow:
1. Select Academic Year and Semester.
2. Download the multi-sheet starter workbook.
3. Delete sheets for classes that do not exist.
4. Rename/add sheets using `1st-CSE-A` style names.
5. Fill the Day/time/LH-No timetable.
6. Upload the workbook.
