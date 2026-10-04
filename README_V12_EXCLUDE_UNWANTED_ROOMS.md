# V12 – Exclude unwanted non-classroom spaces

Based on the V11 working project.

Excluded from normal user-facing room lists and availability/occupancy/booking results:
- MAIN-CONF
- MINI-CONF
- all rooms with room number beginning with LIB
- all rooms with room_type = LIBRARY_SPACE

These database rows are not deleted, so historical records and mappings remain intact.
Seminar halls such as A002, F105 and F306 remain available.
Room capacity remains database-driven from rooms.capacity.
