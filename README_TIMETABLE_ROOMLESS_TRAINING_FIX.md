# Timetable room-less activity + CL-10 fix

This build includes two backend fixes while preserving the existing UI/features:

1. **Pre-Placement Training** may have a blank LH-No/Room. It is stored as a timetable event with no physical room and therefore does not mark any classroom occupied. It remains visible in timetable data.
2. **CL-1, CL-2, ... CL-10** are recognized as C Block (CSE Block) room names when creating/updating rooms.
3. Existing multi-room parsing such as `OOPJ/OS/DBMS(CL-5,F006,F103)` remains enabled.

After replacing the backend project, restart Spring Boot before uploading the workbook again.
