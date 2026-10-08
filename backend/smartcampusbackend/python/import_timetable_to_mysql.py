import json
import mysql.connector
from pathlib import Path


# ============================================================
# CONFIGURATION
# ============================================================

JSON_FILE = Path("python/cse_timetable.json")

DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "password",
    "database": "smart_campus_db"
}


# ============================================================
# ROOM MAPPING
# ============================================================

# LH rooms are aliases used in timetables.
# Physical room is the actual room stored in rooms table.

LH_TO_ROOM = {
    "LH-1": "C-201",
    "LH-3": "C-205",
    "LH-4": "C-301",
    "LH-5": "C-302",
    "LH-6": "C-401",
    "LH-7": "C-402",
    "LH-8": "C-405",
    "LH-9": "C-406"
}


# ============================================================
# DAY MAPPING
# ============================================================

DAY_MAP = {
    "MON": "MONDAY",
    "TUE": "TUESDAY",
    "WED": "WEDNESDAY",
    "THU": "THURSDAY",
    "FRI": "FRIDAY",
    "SAT": "SATURDAY"
}


# ============================================================
# LOAD JSON
# ============================================================

if not JSON_FILE.exists():

    print("=" * 70)
    print("ERROR")
    print("=" * 70)
    print(f"JSON file not found: {JSON_FILE}")
    print("Run parse_cse_timetable.py first.")
    exit(1)


with open(JSON_FILE, "r", encoding="utf-8") as f:

    timetable_data = json.load(f)


print("=" * 70)
print("TIMETABLE → MYSQL IMPORT")
print("=" * 70)

print(f"Branches found: {len(timetable_data)}")


# ============================================================
# CONNECT TO MYSQL
# ============================================================

try:

    connection = mysql.connector.connect(
        host=DB_CONFIG["host"],
        user=DB_CONFIG["user"],
        password=DB_CONFIG["password"],
        database=DB_CONFIG["database"]
    )

    cursor = connection.cursor(dictionary=True)

    print("MySQL connection successful.")

except mysql.connector.Error as e:

    print()
    print("MYSQL CONNECTION ERROR")
    print(e)
    exit(1)


# ============================================================
# VERIFY timetable_entries TABLE
# ============================================================

cursor.execute("""
    SHOW TABLES LIKE 'timetable_entries'
""")

table_exists = cursor.fetchone()

if not table_exists:

    print()
    print("ERROR: timetable_entries table does not exist.")
    print("Create the table first.")
    connection.close()
    exit(1)


# ============================================================
# PREPARE INSERT STATEMENT
# ============================================================

insert_sql = """
INSERT INTO timetable_entries
(
    room_id,
    day_of_week,
    start_time,
    end_time,
    academic_year,
    semester_no,
    section_name,
    is_active
)
VALUES
(
    %s,
    %s,
    %s,
    %s,
    %s,
    %s,
    %s,
    TRUE
)
"""


# ============================================================
# CLEAR OLD CSE TIMETABLE
# ============================================================

print()
print("Removing previous CSE timetable entries...")

cursor.execute("""
    DELETE FROM timetable_entries
    WHERE section_name LIKE 'CSE-%'
""")

connection.commit()


# ============================================================
# PROCESS BRANCHES
# ============================================================

total_inserted = 0
total_skipped = 0


for branch_data in timetable_data:

    branch = branch_data["branch"]

    print()
    print("-" * 70)
    print(branch)
    print("-" * 70)


    # --------------------------------------------------------
    # Academic year
    # --------------------------------------------------------

    academic_year = branch_data.get(
        "academic_year",
        "2026-2027"
    )


    # --------------------------------------------------------
    # Semester
    # --------------------------------------------------------

    semester_no = 1


    # --------------------------------------------------------
    # Find physical room
    # --------------------------------------------------------

    rooms = branch_data.get("rooms", {})

    lh_numbers = rooms.get(
        "lh_numbers",
        []
    )

    physical_rooms = rooms.get(
        "physical_rooms",
        []
    )


    # ========================================================
    # Determine primary room
    # ========================================================

    primary_room = None


    # First preference:
    # LH mapping

    for lh in lh_numbers:

        if lh in LH_TO_ROOM:

            primary_room = LH_TO_ROOM[lh]
            break


    # Second preference:
    # Direct physical room

    if primary_room is None and physical_rooms:

        primary_room = physical_rooms[0]


    print("LH rooms:", lh_numbers)
    print("Physical rooms:", physical_rooms)
    print("Primary room:", primary_room)


    # ========================================================
    # S7 / S4 handling
    # ========================================================

    if primary_room is None:

        print()
        print(
            f"WARNING: {branch} has no mapped physical room."
        )

        print(
            "Timetable entries will NOT be inserted "
            "until the room is mapped."
        )

        total_skipped += len(
            branch_data.get("entries", [])
        )

        continue


    # ========================================================
    # FIND ROOM ID
    # ========================================================

    cursor.execute("""
        SELECT room_id, room_no
        FROM rooms
        WHERE room_no = %s
        LIMIT 1
    """, (primary_room,))

    room = cursor.fetchone()


    if room is None:

        print(
            f"WARNING: Room {primary_room} "
            f"not found in rooms table."
        )

        total_skipped += len(
            branch_data.get("entries", [])
        )

        continue


    room_id = room["room_id"]

    print(
        f"Room ID: {room_id} "
        f"({primary_room})"
    )


    # ========================================================
    # INSERT ENTRIES
    # ========================================================

    branch_inserted = 0


    for entry in branch_data.get(
        "entries",
        []
    ):

        day_short = entry.get(
            "day"
        )

        day = DAY_MAP.get(
            day_short
        )


        if day is None:

            print(
                f"Skipping unknown day: "
                f"{day_short}"
            )

            total_skipped += 1
            continue


        start_time = entry.get(
            "start_time"
        )

        end_time = entry.get(
            "end_time"
        )


        if not start_time or not end_time:

            print(
                f"Skipping entry with "
                f"missing time: {entry}"
            )

            total_skipped += 1
            continue


        # ----------------------------------------------------
        # IMPORTANT
        # ----------------------------------------------------
        # We DO NOT store raw_subject in timetable_entries.
        #
        # Subject/course information will later come from
        # the courses master table.
        #
        # For now this table represents:
        #
        # branch + room + day + time
        # ----------------------------------------------------


        cursor.execute(
            insert_sql,
            (
                room_id,
                day,
                start_time,
                end_time,
                academic_year,
                semester_no,
                branch
            )
        )


        branch_inserted += 1
        total_inserted += 1


    connection.commit()


    print(
        f"Inserted: {branch_inserted} entries"
    )


# ============================================================
# CLOSE CONNECTION
# ============================================================

cursor.close()
connection.close()


# ============================================================
# SUMMARY
# ============================================================

print()
print("=" * 70)
print("IMPORT COMPLETE")
print("=" * 70)

print(
    f"Total inserted : {total_inserted}"
)

print(
    f"Total skipped  : {total_skipped}"
)

print()

print("Next verification query:")
print()

print("""
SELECT
    timetable_id,
    room_id,
    day_of_week,
    start_time,
    end_time,
    academic_year,
    semester_no,
    section_name
FROM timetable_entries
ORDER BY
    section_name,
    FIELD(
        day_of_week,
        'MONDAY',
        'TUESDAY',
        'WEDNESDAY',
        'THURSDAY',
        'FRIDAY',
        'SATURDAY'
    ),
    start_time;
""")