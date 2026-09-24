import re
import json
from pathlib import Path

import pdfplumber


# ============================================================
# CONFIG
# ============================================================

import sys

# PDF path and output JSON path can be overridden via CLI args so this
# script can be invoked by the backend for any uploaded PDF, not just
# the one file it was originally hardcoded to. Falls back to the
# original defaults for manual/interactive use.
PDF_FILE = Path(sys.argv[1]) if len(sys.argv) > 1 else \
    Path("IV CSE 2026-27 I sem TT (1).pdf")

OUTPUT_FILE = Path(sys.argv[2]) if len(sys.argv) > 2 else \
    Path("python") / "cse_timetable.json"

DAYS = ["MON", "TUE", "WED", "THU", "FRI", "SAT"]

# Only used to identify the timetable column header.
# These are NOT timetable values being hardcoded.
TIME_PATTERN = re.compile(
    r"\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}"
)


# ============================================================
# NORMALIZATION
# ============================================================

def normalize_text(text):
    if not text:
        return ""

    text = text.replace("\r", "\n")
    text = text.replace("–", "-")
    text = text.replace("—", "-")
    text = text.replace("â€“", "-")
    text = text.replace("â€”", "-")

    # Remove excessive whitespace
    text = re.sub(r"[ \t]+", " ", text)

    return text.strip()


def clean_cell(text):
    if not text:
        return ""

    text = normalize_text(text)

    # Remove strange OCR/extraction spacing
    text = re.sub(r"\s+", " ", text)

    return text.strip()


# ============================================================
# EXTRACT BRANCH
# ============================================================

def extract_branch(text):
    match = re.search(
        r"Branch\s*:\s*CSE[-\s]?([A-D])",
        text,
        re.IGNORECASE
    )

    if match:
        return f"CSE-{match.group(1).upper()}"

    return None


# ============================================================
# EXTRACT ACADEMIC YEAR
# ============================================================

def extract_academic_year(text):
    match = re.search(
        r"Academic\s*year\s*:\s*(20\d{2})\s*-\s*(20\d{2})",
        text,
        re.IGNORECASE
    )

    if match:
        return f"{match.group(1)}-{match.group(2)}"

    return None


# ============================================================
# EXTRACT EFFECTIVE DATE
# ============================================================

def extract_effective_date(text):
    match = re.search(
        r"w\.?e\.?f\.?\s*:?\s*(\d{2}-\d{2}-\d{4})",
        text,
        re.IGNORECASE
    )

    if match:
        return match.group(1)

    return None


# ============================================================
# EXTRACT ROOM INFORMATION
# ============================================================

def extract_room_header(text):
    match = re.search(
        r"Class\s*Room\s*No\.?\s*:\s*(.*?)(?:w\.?e\.?f\.?|$)",
        text,
        re.IGNORECASE
    )

    if not match:
        return ""

    return clean_cell(match.group(1))


def extract_rooms(room_text):
    if not room_text:
        return []

    rooms = []

    # LH-1, LH-4 etc.
    lh_matches = re.findall(
        r"\bLH[-\s]?\d+\b",
        room_text,
        re.IGNORECASE
    )

    for room in lh_matches:
        room = room.upper().replace(" ", "-")

        if room not in rooms:
            rooms.append(room)

    # Other short campus room codes such as S4, S7 (seminar/staff rooms,
    # or any other single-letter + number code that is NOT a LH-code and
    # NOT a full building-style code like C-205/D-403).
    # These are real room codes used on this campus but are not in our
    # LH_TO_ROOM mapping or the rooms table naming convention, so they
    # must be surfaced for admin review rather than silently dropped.
    other_code_matches = re.findall(
        r"\b(?<![A-Z])([A-Z]\d{1,2})\b",
        room_text
    )

    for code in other_code_matches:
        code = code.upper()

        # Skip if it's actually part of an LH-x or building-x match
        # already captured above (defensive de-dup only).
        if code in rooms:
            continue

        if code not in rooms:
            rooms.append(code)

    # D403, C205, etc.
    physical_matches = re.findall(
        r"\b([A-Z])[-\s]?(\d{3,4}[A-Z]?)\b",
        room_text,
        re.IGNORECASE
    )

    for building, number in physical_matches:

        room = f"{building.upper()}-{number.upper()}"

        if room not in rooms:
            rooms.append(room)

    return rooms


# ============================================================
# LH -> ACTUAL ROOM
# ============================================================

# This is NOT subject/timing hardcoding.
# This is the mapping you already supplied for your campus.

LH_TO_ROOM = {
    "LH-1": "C-201",
    "LH-3": "C-205",
    "LH-4": "C-301",
    "LH-5": "C-302",
    "LH-6": "C-401",
    "LH-7": "C-402",
    "LH-8": "C-405",
    "LH-9": "C-406",
}


def convert_lh_to_physical(rooms):
    physical_rooms = []

    for room in rooms:

        if room in LH_TO_ROOM:
            actual = LH_TO_ROOM[room]

            if actual not in physical_rooms:
                physical_rooms.append(actual)

        elif room.startswith(("A-", "B-", "C-", "D-", "F-")):

            if room not in physical_rooms:
                physical_rooms.append(room)

    return physical_rooms


def resolve_room_status(rooms):
    """
    Classify every detected room token as either resolvable to a
    physical room, or unresolved (requires admin review).

    We NEVER guess a physical room for a code we don't recognize -
    codes like 'S4'/'S7' are real campus room codes but are not in
    LH_TO_ROOM and don't follow the Building-Number convention, so
    they must be reviewed and mapped by an admin, not fabricated.
    """

    resolved = []
    unresolved = []

    for room in rooms:

        if room in LH_TO_ROOM:
            resolved.append(
                {"source": room, "physical_room": LH_TO_ROOM[room]}
            )

        elif room.startswith(("A-", "B-", "C-", "D-", "F-")):
            resolved.append(
                {"source": room, "physical_room": room}
            )

        else:
            unresolved.append(room)

    return resolved, unresolved


# ============================================================
# EXTRACT TIME SLOTS
# ============================================================

def extract_time_slots(text):
    """
    Extract the actual timetable header timings from the PDF.

    Nothing is hardcoded here.
    """

    # Locate Time/Day or TimeDay header
    header_match = re.search(
        r"Time\s*/?\s*Day(.*?)(?:MON|TUE|WED|THU|FRI|SAT)",
        text,
        re.IGNORECASE | re.DOTALL
    )

    if not header_match:
        return []

    header = header_match.group(1)

    matches = TIME_PATTERN.findall(header)

    slots = []

    for value in matches:

        value = clean_cell(value)

        parts = re.split(r"\s*-\s*", value)

        if len(parts) != 2:
            continue

        start = parts[0].strip()
        end = parts[1].strip()

        # Convert 1:00 -> 01:00
        if len(start.split(":")[0]) == 1:
            start = "0" + start

        if len(end.split(":")[0]) == 1:
            end = "0" + end

        slots.append(
            {
                "start_time": start,
                "end_time": end
            }
        )

    return slots


# ============================================================
# FIND TIMETABLE SECTION
# ============================================================

def get_timetable_text(text):
    """
    Get text between timetable header and Subject/Faculty section.
    """

    start_match = re.search(
        r"Time\s*/?\s*Day",
        text,
        re.IGNORECASE
    )

    if not start_match:
        return ""

    start = start_match.end()

    end_match = re.search(
        r"\bSubject\s+Faculty\b|\bName\s+of\s+the\s+Lab\b",
        text[start:],
        re.IGNORECASE
    )

    if end_match:
        end = start + end_match.start()
    else:
        end = len(text)

    return text[start:end]


# ============================================================
# EXTRACT DAY ROWS
# ============================================================

def extract_day_rows(text):
    """
    Extract complete timetable rows.

    Example:

    MON DSUR BSPC FM CNS Lab Library
    TUE BDA CNS BSPC PP-I Sports
    """

    timetable_text = get_timetable_text(text)

    if not timetable_text:
        return []

    lines = [
        clean_cell(line)
        for line in timetable_text.splitlines()
        if clean_cell(line)
    ]

    rows = []

    current_day = None
    current_text = ""

    for line in lines:

        # Detect day at beginning
        day_match = re.match(
            r"^(MON|TUE|WED|THU|FRI|SAT)\b(.*)",
            line,
            re.IGNORECASE
        )

        if day_match:

            # Save previous row
            if current_day is not None:

                rows.append(
                    {
                        "day": current_day,
                        "raw_text": current_text.strip()
                    }
                )

            current_day = day_match.group(1).upper()
            current_text = day_match.group(2).strip()

        else:

            # Continuation of current day
            if current_day is not None:
                current_text += " " + line

    # Save last row
    if current_day is not None:

        rows.append(
            {
                "day": current_day,
                "raw_text": current_text.strip()
            }
        )

    return rows


# ============================================================
# SPLIT TIMETABLE ROW INTO PERIODS
# ============================================================

def split_periods(row_text, number_of_periods):
    """
    IMPORTANT:

    We do NOT guess subject names.

    We use PDF character positions to determine columns.
    Therefore this function is only a fallback for text-only
    extraction.

    When PDF words contain x-coordinates, the main parser below
    is used.
    """

    if not row_text:
        return []

    # Remove room annotations such as:
    # (LH-3), (FN S4), (AN LH-4), etc.
    row_text = re.sub(
        r"\([^)]*\)",
        " ",
        row_text
    )

    row_text = clean_cell(row_text)

    if not row_text:
        return []

    return [row_text]


# ============================================================
# PDF WORD-BASED EXTRACTION
# ============================================================

def extract_using_words(page, time_slots):
    """
    Uses PDF word coordinates.

    This is the important part.

    The PDF itself contains x/y positions for each word.
    We use those positions to determine which timetable
    column a subject belongs to.
    """

    words = page.extract_words(
        x_tolerance=2,
        y_tolerance=3,
        keep_blank_chars=False
    )

    if not words:
        return []

    # --------------------------------------------------------
    # Find timetable header
    # --------------------------------------------------------

    header_words = []

    for word in words:

        text = clean_cell(word["text"])

        if text.lower() in ["time/day", "timeday"]:
            header_words.append(word)

    # Sometimes "Time/Day" is split.
    if not header_words:

        for word in words:

            if "time" in word["text"].lower():
                header_words.append(word)

    if not header_words:
        return []

    header_y = min(
        word["top"]
        for word in header_words
    )

    # --------------------------------------------------------
    # Find time column centers
    # --------------------------------------------------------

    time_words = []

    for word in words:

        value = clean_cell(word["text"])

        if TIME_PATTERN.fullmatch(value):

            # Only take words near timetable header
            if abs(word["top"] - header_y) < 35:
                time_words.append(word)

    # Sometimes PDF splits the time into multiple words.
    # Try searching around header area.
    if len(time_words) < len(time_slots):

        time_words = []

        for word in words:

            value = clean_cell(word["text"])

            if re.search(r"\d{1,2}:\d{2}", value):

                if abs(word["top"] - header_y) < 45:
                    time_words.append(word)

    # --------------------------------------------------------
    # If we cannot get coordinates, stop.
    # --------------------------------------------------------

    if len(time_words) < 2:
        return []

    # Sort by x position
    time_words.sort(
        key=lambda x: x["x0"]
    )

    # --------------------------------------------------------
    # Determine timetable column boundaries
    # --------------------------------------------------------

    centers = []

    for word in time_words:

        center = (
            float(word["x0"]) +
            float(word["x1"])
        ) / 2

        centers.append(center)

    # Remove duplicate / almost duplicate x positions
    unique_centers = []

    for center in centers:

        if not unique_centers:
            unique_centers.append(center)
            continue

        if abs(center - unique_centers[-1]) > 10:
            unique_centers.append(center)

    # Need at least several columns
    if len(unique_centers) < 2:
        return []

    # --------------------------------------------------------
    # Find day rows
    # --------------------------------------------------------

    day_words = []

    for word in words:

        value = clean_cell(word["text"]).upper()

        if value in DAYS:

            day_words.append(word)

    results = []

    for day_word in day_words:

        day = clean_cell(day_word["text"]).upper()

        row_y = float(day_word["top"])

        # Get words on same horizontal row
        row_words = []

        for word in words:

            top = float(word["top"])

            if abs(top - row_y) <= 6:

                if float(word["x0"]) > float(day_word["x1"]):

                    row_words.append(word)

        # Sort left -> right
        row_words.sort(
            key=lambda x: x["x0"]
        )

        # ----------------------------------------------------
        # Assign words to nearest timetable column
        # ----------------------------------------------------

        columns = [
            []
            for _ in range(len(unique_centers))
        ]

        for word in row_words:

            x_center = (
                float(word["x0"]) +
                float(word["x1"])
            ) / 2

            nearest = min(
                range(len(unique_centers)),
                key=lambda i: abs(
                    unique_centers[i] - x_center
                )
            )

            columns[nearest].append(
                clean_cell(word["text"])
            )

        # ----------------------------------------------------
        # Create entries
        # ----------------------------------------------------

        for index, words_in_column in enumerate(columns):

            if index >= len(time_slots):
                break

            subject = clean_cell(
                " ".join(words_in_column)
            )

            if not subject:
                continue

            # Ignore obvious header/footnote material
            if subject.upper() in DAYS:
                continue

            # Ignore stray single-letter fragments of the vertical
            # "LUNCH BREAK" column label. That column sits between
            # periods 3 and 4 and its letters occasionally get
            # nearest-column-assigned into an adjacent period. A
            # single uppercase letter that is itself a substring of
            # "LUNCHBREAK" is treated as noise, not a real subject,
            # and the entry is dropped (not inserted as fake data).
            if len(subject) == 1 and subject.upper() in "LUNCHBREAK":
                continue

            # Separate any inline room override annotation, e.g.
            # "CNS - Lab (LH-6)" or "(FN S4)". We do NOT discard this
            # information - the header's declared room is only the
            # DEFAULT room, and specific periods can genuinely be
            # held elsewhere. We keep both the cleaned subject code
            # and the raw override hint for downstream review.
            room_override = None
            override_match = re.search(r"\(([^)]*)\)", subject)

            if override_match:
                room_override = clean_cell(override_match.group(1))
                subject = clean_cell(
                    re.sub(r"\([^)]*\)", " ", subject)
                )

            if not subject:
                continue

            entry = {
                "day": day,
                "period": index + 1,
                "start_time": time_slots[index]["start_time"],
                "end_time": time_slots[index]["end_time"],
                "subject_code": subject
            }

            if room_override:
                entry["room_override_raw"] = room_override

            results.append(entry)

    return results


# ============================================================
# FALLBACK TEXT PARSER
# ============================================================

def fallback_extract(text, time_slots):

    rows = extract_day_rows(text)

    results = []

    for row in rows:

        day = row["day"]
        raw = row["raw_text"]

        if not raw:
            continue

        # Remove room information
        raw = re.sub(
            r"\([^)]*\)",
            " ",
            raw
        )

        raw = clean_cell(raw)

        # We intentionally DO NOT split subjects incorrectly.
        # If column coordinates are unavailable, mark the row
        # for review instead of creating false timetable data.

        results.append(
            {
                "day": day,
                "period": None,
                "start_time": None,
                "end_time": None,
                "subject_code": raw,
                "needs_review": True
            }
        )

    return results


# ============================================================
# SUBJECT / FACULTY LEGEND
# ============================================================
#
# The legend at the bottom of each page maps subject codes to full
# subject names and faculty, in a 4-column layout:
#   [Subject/code]  [Faculty Name]  [Name of the Lab]  [Faculty Name]
#
# page.extract_text() interleaves these columns unreadably (columns
# get merged character-by-character), so we MUST use word x/y
# coordinates - the same technique used for the timetable grid -
# rather than regex over extract_text() output, which would produce
# silently wrong subject/faculty pairings.

def extract_legend(page):

    words = page.extract_words(x_tolerance=2, y_tolerance=3)

    if not words:
        return {"courses": [], "labs": []}

    header_words = [
        w for w in words
        if clean_cell(w["text"]).lower() in ("subject", "faculty", "name")
    ]

    if not header_words:
        return {"courses": [], "labs": []}

    header_top = min(w["top"] for w in header_words)
    header_bottom = max(w["bottom"] for w in header_words)

    # Column start x-positions, taken from the header row itself so
    # this adapts to each page rather than being hardcoded.
    subject_x = min(
        (w["x0"] for w in words
         if clean_cell(w["text"]).lower() == "subject"),
        default=None
    )

    faculty_xs = sorted(
        w["x0"] for w in words
        if clean_cell(w["text"]).lower() == "faculty"
        and abs(w["top"] - header_top) < 5
    )

    if subject_x is None or len(faculty_xs) < 2:
        return {"courses": [], "labs": []}

    # "Name of the Lab" column starts at the "Name" word that is NOT
    # part of "Faculty Name" (i.e. sits between the two Faculty cols).
    lab_x_candidates = [
        w["x0"] for w in words
        if clean_cell(w["text"]).lower() == "name"
        and abs(w["top"] - header_top) < 5
        and faculty_xs[0] < w["x0"] < faculty_xs[1]
    ]
    lab_x = min(lab_x_candidates) if lab_x_candidates else (
        (faculty_xs[0] + faculty_xs[1]) / 2
    )

    col_starts = [subject_x, faculty_xs[0], lab_x, faculty_xs[1]]

    body_words = [w for w in words if w["top"] > header_bottom + 2]

    if not body_words:
        return {"courses": [], "labs": []}

    # Group words into rows by y-proximity.
    body_words.sort(key=lambda w: w["top"])

    rows = []
    current_row = [body_words[0]]

    for w in body_words[1:]:
        if abs(w["top"] - current_row[-1]["top"]) <= 6:
            current_row.append(w)
        else:
            rows.append(current_row)
            current_row = [w]
    rows.append(current_row)

    def assign_column(x0):
        best = 0
        for i, start in enumerate(col_starts):
            if x0 + 3 >= start:
                best = i
        return best

    courses = []
    labs = []

    for row in rows:
        row.sort(key=lambda w: w["x0"])

        cells = ["", "", "", ""]

        for w in row:
            col = assign_column(w["x0"])
            cells[col] = clean_cell(cells[col] + " " + w["text"])

        subject_cell, faculty1_cell, lab_cell, faculty2_cell = (
            c.strip() for c in cells
        )

        if subject_cell and subject_cell.lower() != "subject":
            code_match = re.search(r"\(([0-9A-Za-z]+)\)", subject_cell)

            courses.append({
                "raw_text": subject_cell,
                "course_code": code_match.group(1) if code_match else None,
                "faculty_raw": faculty1_cell or None
            })

        if lab_cell and "name of the lab" not in lab_cell.lower():
            code_match = re.search(r"\(([0-9A-Za-z]+)\)", lab_cell)

            labs.append({
                "raw_text": lab_cell,
                "lab_code": code_match.group(1) if code_match else None,
                "faculty_raw": faculty2_cell or None
            })

    return {"courses": courses, "labs": labs}


# ============================================================
# PROCESS ONE PDF PAGE
# ============================================================

def process_page(page):

    text = page.extract_text(
        x_tolerance=2,
        y_tolerance=3
    ) or ""

    text = normalize_text(text)

    branch = extract_branch(text)

    if not branch:
        return None

    academic_year = extract_academic_year(text)

    effective_date = extract_effective_date(text)

    room_header = extract_room_header(text)

    rooms = extract_rooms(room_header)

    resolved_rooms, unresolved_rooms = resolve_room_status(rooms)

    time_slots = extract_time_slots(text)

    # --------------------------------------------------------
    # Extract using actual PDF coordinates
    # --------------------------------------------------------

    entries = extract_using_words(
        page,
        time_slots
    )

    # --------------------------------------------------------
    # Fallback only if coordinate extraction failed
    # --------------------------------------------------------

    if not entries:

        entries = fallback_extract(
            text,
            time_slots
        )

    legend = extract_legend(page)

    # Collect any inline per-period room overrides (e.g. "(FN S4)")
    # that individual entries carried, distinct from the header's
    # declared default room. Deduplicated for the branch-level report.
    inline_room_hints = sorted(set(
        e["room_override_raw"]
        for e in entries
        if e.get("room_override_raw")
    ))

    return {
        "branch": branch,
        "academic_year": academic_year,
        "effective_date": effective_date,
        "rooms": {
            "header_rooms": rooms,
            "resolved_rooms": resolved_rooms,
            "unresolved_rooms": unresolved_rooms,
            "inline_room_hints": inline_room_hints
        },
        "requires_review": bool(unresolved_rooms),
        "time_slots": time_slots,
        "entries": entries,
        "legend": legend
    }


# ============================================================
# MAIN
# ============================================================

def main():

    print("=" * 70)
    print("CSE TIMETABLE PDF PARSER")
    print("=" * 70)

    if not PDF_FILE.exists():

        print()
        print("ERROR: PDF not found:")
        print(PDF_FILE)
        print()

        print(
            "Put the PDF in the project root directory "
            "with the filename:"
        )

        print(
            "IV CSE 2026-27 I sem TT (1)(1).pdf"
        )

        return

    OUTPUT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    results = []

    with pdfplumber.open(PDF_FILE) as pdf:

        print(
            f"Pages detected: {len(pdf.pages)}"
        )

        print()

        for page_number, page in enumerate(
            pdf.pages,
            start=1
        ):

            print("=" * 70)
            print(f"PAGE {page_number}")
            print("=" * 70)

            data = process_page(page)

            if data is None:

                print("No CSE branch detected.")
                continue

            results.append(data)

            print(
                f"Branch: {data['branch']}"
            )

            print(
                f"Academic year: "
                f"{data['academic_year']}"
            )

            print(
                f"Effective date: "
                f"{data['effective_date']}"
            )

            print()

            print("ROOMS")
            print("-" * 70)

            print(
                "Header rooms:",
                ", ".join(
                    data["rooms"]["header_rooms"]
                )
                if data["rooms"]["header_rooms"]
                else "None"
            )

            resolved = data["rooms"]["resolved_rooms"]
            unresolved = data["rooms"]["unresolved_rooms"]

            print(
                "Resolved rooms:",
                ", ".join(
                    f"{r['source']}->{r['physical_room']}"
                    for r in resolved
                )
                if resolved else "None"
            )

            print(
                "UNRESOLVED rooms (needs admin review):",
                ", ".join(unresolved) if unresolved else "None"
            )

            if data["rooms"]["inline_room_hints"]:
                print(
                    "Inline per-period room hints found:",
                    ", ".join(data["rooms"]["inline_room_hints"])
                )

            print()

            print("TIME SLOTS")
            print("-" * 70)

            for i, slot in enumerate(
                data["time_slots"],
                start=1
            ):

                print(
                    f"Period {i}: "
                    f"{slot['start_time']} - "
                    f"{slot['end_time']}"
                )

            print()

            print("TIMETABLE ENTRIES")
            print("-" * 70)

            for entry in data["entries"]:

                print(
                    f"{entry['day']:3} | "
                    f"P{entry['period']} | "
                    f"{entry['start_time']} - "
                    f"{entry['end_time']} | "
                    f"{entry['subject_code']}"
                    + (
                        f" [room override: {entry['room_override_raw']}]"
                        if entry.get("room_override_raw") else ""
                    )
                )

            print()

            if data["legend"]["courses"] or data["legend"]["labs"]:

                print("SUBJECT / FACULTY LEGEND")
                print("-" * 70)

                for c in data["legend"]["courses"]:
                    print(
                        f"  Course: {c['raw_text']}"
                        f"  | code={c['course_code']}"
                        f"  | faculty={c['faculty_raw']}"
                    )

                for lab in data["legend"]["labs"]:
                    print(
                        f"  Lab:    {lab['raw_text']}"
                        f"  | code={lab['lab_code']}"
                        f"  | faculty={lab['faculty_raw']}"
                    )

                print()

    # ========================================================
    # SAVE
    # ========================================================

    with open(
        OUTPUT_FILE,
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            results,
            f,
            indent=4,
            ensure_ascii=False
        )

    # ========================================================
    # SUMMARY
    # ========================================================

    print("=" * 70)
    print("EXTRACTION COMPLETE")
    print("=" * 70)

    print(
        f"Branches detected: {len(results)}"
    )

    for data in results:

        review_count = sum(
            1
            for entry in data["entries"]
            if entry.get("needs_review", False)
        )

        print(
            f"{data['branch']}: "
            f"{len(data['entries'])} entries"
            f" | {review_count} need review"
        )

    print()
    print(
        f"Output saved to: {OUTPUT_FILE}"
    )


if __name__ == "__main__":
    main()