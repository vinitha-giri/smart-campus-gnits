import mysql.connector

# Connect to MySQL
conn = mysql.connector.connect(
    host='localhost',
    user='root',
    password='password',
    database='smart_campus_db'
)

cursor = conn.cursor()

# Extracted data from OCR
branch = 'CSE-A'
lh_no = 'LH-6'

# Find actual room using mapping table
cursor.execute(
    'SELECT room_no, room_id FROM lecture_hall_mapping WHERE lh_no=%s',
    (lh_no,)
)

result = cursor.fetchone()

if result:
    room_no, room_id = result

    # Insert into timetable_entries
    cursor.execute(
    '''
    INSERT INTO timetable_entries
    (room_id, lh_no, day_of_week, start_time, end_time,
     academic_year, semester_no, section_name, subject_name)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    ''',
    (
        room_id,
        lh_no,
        'MONDAY',
        '09:00:00',
        '10:00:00',
        '2026-2027',
        1,
        branch,
        'Demo Entry'
    )
)

    conn.commit()

    print(f'Inserted: {branch} -> {lh_no} -> {room_no} (room_id={room_id})')
else:
    print('LH mapping not found')

cursor.close()
conn.close()