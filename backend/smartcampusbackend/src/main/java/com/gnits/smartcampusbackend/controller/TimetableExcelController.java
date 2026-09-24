package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.Room;
import com.gnits.smartcampusbackend.entity.TimetableEntry;
import com.gnits.smartcampusbackend.repository.RoomRepository;
import com.gnits.smartcampusbackend.repository.LectureHallMappingRepository;
import com.gnits.smartcampusbackend.repository.TimetableEntryRepository;
import com.gnits.smartcampusbackend.realtime.RealtimeHub;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.time.LocalTime;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@RestController
@RequestMapping("/api/timetable/excel")
@CrossOrigin(origins = "*")
public class TimetableExcelController {

    private static final String XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    private static final String[] DAYS = {"MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"};

    // Central catalogue used only when the Admin downloads the multi-section
    // template. The upload API remains fully backward compatible and still
    // accepts any valid section name from an Excel sheet.
    // IMPORTANT: Section alone is not unique. CSE-A exists in 1st/2nd/3rd/4th year.
    // The sheet/class key therefore carries Year + Department + Section.
    private static final String[] DEFAULT_SECTIONS = {
            "1st-CSE-A", "1st-CSE-B", "1st-CSE-C", "1st-CSE-D",
            "2nd-CSE-A", "2nd-CSE-B", "2nd-CSE-C", "2nd-CSE-D",
            "3rd-CSE-A", "3rd-CSE-B", "3rd-CSE-C", "3rd-CSE-D",
            "4th-CSE-A", "4th-CSE-B", "4th-CSE-C", "4th-CSE-D",
            "1st-ECE-A", "1st-ECE-B", "1st-ECE-C",
            "2nd-ECE-A", "2nd-ECE-B", "2nd-ECE-C",
            "3rd-ECE-A", "3rd-ECE-B", "3rd-ECE-C",
            "4th-ECE-A", "4th-ECE-B", "4th-ECE-C",
            "1st-EEE-A", "1st-EEE-B", "1st-EEE-C",
            "2nd-EEE-A", "2nd-EEE-B", "2nd-EEE-C",
            "3rd-EEE-A", "3rd-EEE-B", "3rd-EEE-C",
            "4th-EEE-A", "4th-EEE-B", "4th-EEE-C",
            "1st-IT-A", "1st-IT-B", "2nd-IT-A", "2nd-IT-B",
            "3rd-IT-A", "3rd-IT-B", "4th-IT-A", "4th-IT-B",
            "1st-CSM-A", "1st-CSM-B", "2nd-CSM-A", "2nd-CSM-B",
            "3rd-CSM-A", "3rd-CSM-B", "4th-CSM-A", "4th-CSM-B",
            "1st-CSD-A", "1st-CSD-B", "2nd-CSD-A", "2nd-CSD-B",
            "3rd-CSD-A", "3rd-CSD-B", "4th-CSD-A", "4th-CSD-B"
    };

    private final RoomRepository roomRepository;
    private final TimetableEntryRepository timetableEntryRepository;
    private final LectureHallMappingRepository lectureHallMappingRepository;
    private final RealtimeHub realtimeHub;

    public TimetableExcelController(RoomRepository roomRepository, TimetableEntryRepository timetableEntryRepository, LectureHallMappingRepository lectureHallMappingRepository, RealtimeHub realtimeHub) {
        this.realtimeHub = realtimeHub;
        this.roomRepository = roomRepository;
        this.timetableEntryRepository = timetableEntryRepository;
        this.lectureHallMappingRepository = lectureHallMappingRepository;
    }

    @GetMapping("/template")
    public ResponseEntity<byte[]> downloadTemplate(
            @RequestParam(defaultValue = "4th-CSE-D") String sectionName,
            @RequestParam(defaultValue = "2026-2027") String academicYear,
            @RequestParam(defaultValue = "1") int semesterNo) throws IOException {

        try (Workbook workbook = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            // Backward compatible: a single section still produces a single
            // timetable sheet. Passing ALL (used by the Admin UI) produces a
            // workbook containing one template sheet per supported section.
            List<String> requestedSections = resolveTemplateSections(sectionName);
            for (String section : requestedSections) {
                createTimetableSheet(workbook, section, academicYear, semesterNo);
            }

            Sheet instructions = workbook.createSheet("Instructions");
            String[] lines = {
                    "GNITS Smart Campus - Enterprise Timetable Upload",
                    "One Excel workbook can contain MULTIPLE timetable sheets.",
                    "IMPORTANT: Section names repeat across years. Use the sheet name format YEAR-DEPARTMENT-SECTION, for example 1st-CSE-A, 2nd-CSE-A, 3rd-CSE-A, 4th-CSE-A.",
                    "Delete any sheet you do not need before uploading. The sheet name is stored as the unique class key, so 1st-CSE-A and 4th-CSE-A are different timetables.",
                    "Starter sheets: " + String.join(", ", DEFAULT_SECTIONS),
                    "You can add, rename, or delete sheets. Recommended format: 1st-CSE-A / 2nd-CSE-A / 3rd-CSE-A / 4th-CSE-A. Do not use only CSE-A when the same section exists in multiple years.",
                    "GNITS timing rule: 1st Year normally starts at 09:20; 2nd, 3rd and 4th Year normally start at 09:00. The downloaded template applies this automatically based on the class sheet name.",
                    "TIME COLUMNS ARE FLEXIBLE: edit the generated time headers when the actual college timetable has different periods, breaks or special timings.",
                    "Keep the first column as Day and one column as LH-No/Room. Every column between them must contain a valid start-end time range.",
                    "For a 3-hour lab, MERGE the subject cell across the relevant time columns. The importer stores it as ONE event from the first column start to the last column end.",
                    "If a day uses multiple rooms, add another row for the same day with the other LH-No.",
                    "Blank subject cells are treated as free time.",
                    "Sheets named Instructions, Read Me or Notes are ignored during upload.",
                    "Upload is transactional: if any timetable sheet has an error, no sheet is changed.",
                    "Example: MONDAY | 09:20-10:20 | 10:20-11:20 | 11:20-12:20 | 1:20-2:20 | 2:20-3:20 | LH-No; a merged 09:20-12:20 cell represents one 3-hour lab."
            };
            for (int i = 0; i < lines.length; i++) instructions.createRow(i).createCell(0).setCellValue(lines[i]);
            instructions.setColumnWidth(0, 120 * 256);
            workbook.write(out);
            return ResponseEntity.ok().header("Content-Disposition", "attachment; filename=\"GNITS_Timetable_MultiSheet.xlsx\"")
                    .header("Content-Type", XLSX).body(out.toByteArray());
        }
    }

    private List<String> resolveTemplateSections(String sectionName) {
        String value = sectionName == null ? "" : sectionName.trim();
        if (value.isBlank() || value.equalsIgnoreCase("ALL") || value.equalsIgnoreCase("MULTI")) {
            return Arrays.asList(DEFAULT_SECTIONS);
        }

        // Also support comma-separated section names for future Admin UI
        // selection without changing this endpoint again.
        LinkedHashSet<String> sections = new LinkedHashSet<>();
        for (String raw : value.split(",")) {
            String section = raw.trim();
            if (!section.isBlank()) sections.add(section);
        }
        return sections.isEmpty() ? List.of(DEFAULT_SECTIONS[0]) : new ArrayList<>(sections);
    }

    private void createTimetableSheet(Workbook workbook, String sectionName, String academicYear, int semesterNo) {
        Sheet sheet = workbook.createSheet(safeSheetName(sectionName));
        CellStyle titleStyle = workbook.createCellStyle();
        Font titleFont = workbook.createFont(); titleFont.setBold(true); titleFont.setFontHeightInPoints((short) 16); titleStyle.setFont(titleFont);
        CellStyle headerStyle = workbook.createCellStyle();
        Font headerFont = workbook.createFont(); headerFont.setBold(true); headerStyle.setFont(headerFont); headerStyle.setAlignment(HorizontalAlignment.CENTER); headerStyle.setVerticalAlignment(VerticalAlignment.CENTER); headerStyle.setWrapText(true);
        CellStyle dayStyle = workbook.createCellStyle(); dayStyle.setAlignment(HorizontalAlignment.CENTER); dayStyle.setVerticalAlignment(VerticalAlignment.CENTER);

        Row title = sheet.createRow(0); title.createCell(0).setCellValue(sectionName.toUpperCase(Locale.ROOT) + " TIMETABLE"); title.getCell(0).setCellStyle(titleStyle); sheet.addMergedRegion(new org.apache.poi.ss.util.CellRangeAddress(0, 0, 0, 7));
        Row meta = sheet.createRow(1); meta.createCell(0).setCellValue("Academic Year: " + academicYear + "    Semester: " + semesterNo + "    EDIT TIME HEADERS TO MATCH THIS CLASS"); sheet.addMergedRegion(new org.apache.poi.ss.util.CellRangeAddress(1, 1, 0, 7));
        Row header = sheet.createRow(3);
        // GNITS timing rule: 1st Year normally starts at 09:20; 2nd/3rd/4th Year normally starts at 09:00.
        // Keep the generated template year-aware while allowing the Admin to edit headers for special schedules.
        String[] headers = defaultTimeHeadersForYear(sectionName);
        for (int i = 0; i < headers.length; i++) { Cell c = header.createCell(i); c.setCellValue(headers[i]); c.setCellStyle(headerStyle); }
        for (int i = 0; i < DAYS.length; i++) { Row row = sheet.createRow(4 + i); Cell day = row.createCell(0); day.setCellValue(DAYS[i]); day.setCellStyle(dayStyle); for (int c = 1; c <= 7; c++) row.createCell(c); row.setHeightInPoints(28); }
        sheet.createFreezePane(1, 4); sheet.setAutoFilter(new org.apache.poi.ss.util.CellRangeAddress(3, 9, 0, 7));
        sheet.setColumnWidth(0, 18 * 256); for (int c = 1; c <= 6; c++) sheet.setColumnWidth(c, 18 * 256); sheet.setColumnWidth(7, 16 * 256);
    }


    private String[] defaultTimeHeadersForYear(String sectionName) {
        String value = sectionName == null ? "" : sectionName.trim().toLowerCase(Locale.ROOT);
        boolean firstYear = value.startsWith("1st-") || value.startsWith("1st ") || value.startsWith("1 ");
        if (firstYear) {
            return new String[]{"Day", "09:20-10:20", "10:20-11:20", "11:20-12:20", "01:20-02:20", "02:20-03:20", "03:20-04:20", "LH-No"};
        }
        return new String[]{"Day", "09:00-10:00", "10:00-11:00", "11:10-12:10", "01:00-02:00", "02:00-03:00", "03:00-04:00", "LH-No"};
    }


    /**
     * Returns only timetable sections that actually exist for the selected
     * academic year and semester. The Flutter admin UI uses this instead of
     * hard-coded section names.
     */
    @GetMapping("/entries")
    public ResponseEntity<?> listEntries(@RequestParam String academicYear, @RequestParam Integer semesterNo, @RequestParam(required=false) String sectionName, @RequestParam(required=false) String day) {
        List<TimetableEntry> entries = timetableEntryRepository.findByAcademicYearAndSemesterNo(academicYear.trim(), semesterNo);
        if (sectionName != null && !sectionName.isBlank()) entries = entries.stream().filter(e -> sectionName.equalsIgnoreCase(e.getSectionName())).toList();
        if (day != null && !day.isBlank()) entries = entries.stream().filter(e -> e.getDayOfWeek()!=null && e.getDayOfWeek().toUpperCase(Locale.ROOT).startsWith(day.trim().toUpperCase(Locale.ROOT).substring(0, Math.min(3, day.trim().length())))).toList();
        entries = entries.stream().sorted(Comparator.comparing(TimetableEntry::getDayOfWeek, Comparator.nullsLast(String::compareToIgnoreCase)).thenComparing(TimetableEntry::getStartTime, Comparator.nullsLast(LocalTime::compareTo))).toList();
        List<Map<String,Object>> out = new ArrayList<>();
        for (TimetableEntry e: entries) out.add(Map.of("entryId",e.getEntryId(),"roomId",e.getRoomId(),"roomNo",Objects.toString(e.getLhNo(),""),"day",Objects.toString(e.getDayOfWeek(),""),"startTime",e.getStartTime().toString(),"endTime",e.getEndTime().toString(),"section",Objects.toString(e.getSectionName(),""),"subject",Objects.toString(e.getSubjectName(),"")));
        return ResponseEntity.ok(Map.of("success",true,"entries",out,"count",out.size()));
    }

    @GetMapping("/sections")
    public ResponseEntity<?> listSections(
            @RequestParam String academicYear,
            @RequestParam Integer semesterNo) {
        List<TimetableEntry> entries = timetableEntryRepository.findByAcademicYearAndSemesterNo(
                academicYear.trim(), semesterNo);

        Map<String, List<TimetableEntry>> grouped = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        for (TimetableEntry entry : entries) {
            grouped.computeIfAbsent(entry.getSectionName(), k -> new ArrayList<>()).add(entry);
        }

        List<Map<String, Object>> sections = new ArrayList<>();
        for (Map.Entry<String, List<TimetableEntry>> group : grouped.entrySet()) {
            Set<String> subjects = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
            Set<String> rooms = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
            for (TimetableEntry e : group.getValue()) {
                if (e.getSubjectName() != null && !e.getSubjectName().isBlank()) subjects.add(e.getSubjectName());
                if (e.getLhNo() != null && !e.getLhNo().isBlank()) rooms.add(e.getLhNo());
            }
            sections.add(Map.of(
                    "sectionName", group.getKey(),
                    "entries", group.getValue().size(),
                    "subjects", subjects.size(),
                    "rooms", rooms.size(),
                    "roomNames", rooms
            ));
        }

        return ResponseEntity.ok(Map.of(
                "success", true,
                "academicYear", academicYear.trim(),
                "semesterNo", semesterNo,
                "count", sections.size(),
                "sections", sections
        ));
    }

    /**
     * Deletes one uploaded section for only the selected academic year and
     * semester. Older/current data in other semesters is untouched.
     */
    @DeleteMapping("/section")
    @Transactional
    public ResponseEntity<?> deleteSection(
            @RequestParam String sectionName,
            @RequestParam String academicYear,
            @RequestParam Integer semesterNo) {
        String section = sectionName.trim();
        if (section.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Section name is required."));
        }

        List<TimetableEntry> before = timetableEntryRepository.findByAcademicYearAndSemesterNo(
                academicYear.trim(), semesterNo);
        long count = before.stream()
                .filter(e -> section.equalsIgnoreCase(e.getSectionName()))
                .count();

        timetableEntryRepository.deleteBySectionNameAndAcademicYearAndSemesterNo(
                section, academicYear.trim(), semesterNo);

        realtimeHub.publish("TIMETABLE_CHANGED", "Timetable for " + section + " was deleted.", Map.of("section", section, "action", "DELETED"));
        return ResponseEntity.ok(Map.of(
                "success", true,
                "sectionName", section,
                "academicYear", academicYear.trim(),
                "semesterNo", semesterNo,
                "deletedEntries", count,
                "message", count == 0
                        ? "No timetable was stored for this section."
                        : "Timetable deleted successfully."
        ));
    }

    @PostMapping("/upload")
    @Transactional
    public ResponseEntity<?> uploadExcel(
            @RequestParam("file") MultipartFile file,
            @RequestParam(defaultValue = "MULTI") String sectionName,
            @RequestParam String academicYear,
            @RequestParam Integer semesterNo) {

        if (file.isEmpty() || file.getOriginalFilename() == null || !file.getOriginalFilename().toLowerCase(Locale.ROOT).endsWith(".xlsx")) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Please upload a valid .xlsx Excel file."));
        }

        List<TimetableEntry> parsed = new ArrayList<>();
        List<String> errors = new ArrayList<>();
        Set<String> duplicateKeys = new HashSet<>();
        Set<String> sectionsInWorkbook = new LinkedHashSet<>();
        int timetableSheets = 0;

        try (InputStream in = file.getInputStream(); Workbook workbook = WorkbookFactory.create(in)) {
            DataFormatter formatter = new DataFormatter();

            for (int s = 0; s < workbook.getNumberOfSheets(); s++) {
                Sheet sheet = workbook.getSheetAt(s);
                String sheetName = sheet.getSheetName();
                if (isIgnoredSheet(sheetName) || sheet.getLastRowNum() < 1) continue;
                timetableSheets++;

                Row header = findHeaderRow(sheet, formatter);
                List<TimeColumn> timeColumns = header == null ? List.of() : parseTimeColumns(header, formatter);
                int dayColumn = header == null ? -1 : findDayColumn(header, formatter);
                int roomColumn = header == null ? -1 : findRoomColumn(header, formatter);
                if (header == null || dayColumn < 0 || timeColumns.isEmpty() || roomColumn < 0) {
                    errors.add("Sheet '" + sheetName + "': invalid timetable layout. Use a Day column, actual start-end time headers for the timetable columns, and one LH-No/Room column.");
                    continue;
                }

                String sheetSection = resolveSection(sheetName, sectionName);
                if (!isYearDepartmentSectionKey(sheetSection)) {
                    errors.add("Sheet '" + sheetName + "': ambiguous class name '" + sheetSection + "'. Use YEAR-DEPARTMENT-SECTION, for example 1st-CSE-A or 4th-CSE-D.");
                    continue;
                }
                sectionsInWorkbook.add(sheetSection);
                int headerRowNum = header.getRowNum();
                Map<String, MergedTimeRange> mergedSubjectRanges = buildMergedSubjectRanges(sheet, timeColumns, formatter);
                String currentDay = "";

                for (int r = headerRowNum + 1; r <= sheet.getLastRowNum(); r++) {
                    Row row = sheet.getRow(r);
                    if (row == null) continue;

                    String rawDay = mergedOrCellValue(sheet, row, dayColumn, formatter).trim().toUpperCase(Locale.ROOT);
                    if (!rawDay.isBlank()) currentDay = rawDay;
                    String day = currentDay;
                    String lhNo = mergedOrCellValue(sheet, row, roomColumn, formatter).trim();
                    boolean hasSubject = false;
                    for (TimeColumn tc : timeColumns) {
                        if (!mergedOrCellValue(sheet, row, tc.column, formatter).trim().isBlank()) { hasSubject = true; break; }
                    }
                    if (day.isBlank() && lhNo.isBlank() && !hasSubject) continue;

                    if (day.isBlank()) { errors.add("Sheet '" + sheetName + "', row " + (r + 1) + ": Day is required."); continue; }
                    if (!Set.of(DAYS).contains(day)) { errors.add("Sheet '" + sheetName + "', row " + (r + 1) + ": invalid day '" + day + "'."); continue; }
                    // Room selection is PER SUBJECT/TIME CELL, not per row.
                    // If a subject contains a room/class in parentheses, e.g.
                    // DSUR(C401), CNS(LH-3) or FM(S4), that bracketed value wins.
                    // Otherwise the row-level LH-No/Room value is used.
                    // This matches the real GNITS timetable format where one day
                    // can use different rooms in different periods.
                    if (!hasSubject) continue;

                    for (int i = 0; i < timeColumns.size(); i++) {
                        TimeColumn tc = timeColumns.get(i);
                        Cell subjectCell = cellForMergedRegion(sheet, row.getRowNum(), tc.column);
                        String subject = subjectCell == null ? "" : formatter.formatCellValue(subjectCell).trim();
                        if (subject.isBlank()) continue;

                        // Prefer a room/class explicitly written in parentheses in
                        // the subject cell; otherwise fall back to LH-No for the row.
                        String effectiveRoomName = extractBracketRoom(subject);
                        if (effectiveRoomName.isBlank()) effectiveRoomName = lhNo;
                        if (effectiveRoomName.isBlank()) {
                            errors.add("Sheet '" + sheetName + "', row " + (r + 1)
                                    + ": LH-No/Room is required when subject '" + subject + "' has no room in parentheses.");
                            continue;
                        }

                        Optional<Room> roomOpt = resolveRoom(effectiveRoomName);
                        if (roomOpt.isEmpty()) {
                            errors.add("Sheet '" + sheetName + "', row " + (r + 1)
                                    + ": Room '" + effectiveRoomName + "' for subject '" + subject
                                    + "' could not be mapped to a physical room. Checked rooms, room_aliases and lecture_hall_mapping.");
                            continue;
                        }
                        Room room = roomOpt.get();

                        MergedTimeRange merged = mergedSubjectRanges.get(row.getRowNum() + ":" + tc.column);
                        int lastColumn = merged == null ? tc.column : merged.lastColumn;
                        TimeColumn lastTc = timeColumnByColumn(timeColumns, lastColumn);
                        if (lastTc == null) {
                            errors.add("Sheet '" + sheetName + "', row " + (r + 1) + ": merged subject cell extends outside the timetable time columns.");
                            break;
                        }
                        // Only create one event for a merged subject cell. The event spans
                        // the first time header through the last time header covered by the merge.
                        if (merged != null && tc.column != merged.firstColumn) continue;

                        LocalTime startTime = tc.start;
                        LocalTime endTime = lastTc.end;
                        if (!startTime.isBefore(endTime)) {
                            errors.add("Sheet '" + sheetName + "', row " + (r + 1) + ": invalid time range for subject '" + subject + "'.");
                            continue;
                        }
                        String key = sheetSection.toUpperCase(Locale.ROOT) + "|" + room.getRoomId() + "|" + day + "|" + startTime + "|" + endTime;
                        if (!duplicateKeys.add(key)) {
                            errors.add("Sheet '" + sheetName + "', row " + (r + 1) + ": duplicate room/time interval for " + effectiveRoomName + " on " + day + " " + formatTime(startTime) + "-" + formatTime(endTime) + ".");
                            continue;
                        }

                        TimetableEntry entry = new TimetableEntry();
                        entry.setRoomId(room.getRoomId()); entry.setLhNo(room.getRoomNo()); entry.setDayOfWeek(day); entry.setStartTime(startTime); entry.setEndTime(endTime);
                        entry.setAcademicYear(academicYear.trim()); entry.setSemesterNo(semesterNo); entry.setSectionName(sheetSection); entry.setSubjectName(subject);
                        parsed.add(entry);
                    }
                }
            }

            if (timetableSheets == 0) return ResponseEntity.badRequest().body(Map.of("success", false, "error", "No timetable sheets found. Add one or more sheets with the required Day/time/LH-No columns."));
            if (!errors.isEmpty()) return ResponseEntity.badRequest().body(Map.of("success", false, "errors", errors, "sheetsRead", timetableSheets));

            for (TimetableEntry entry : parsed) {
                List<TimetableEntry> existingEntries = timetableEntryRepository.findByRoomIdAndDayOfWeek(entry.getRoomId(), entry.getDayOfWeek());
                for (TimetableEntry existing : existingEntries) {
                    boolean sameUpload = entry.getSectionName().equalsIgnoreCase(existing.getSectionName())
                            && academicYear.trim().equalsIgnoreCase(existing.getAcademicYear()) && Objects.equals(semesterNo, existing.getSemesterNo());
                    boolean overlaps = entry.getStartTime().isBefore(existing.getEndTime())
                            && existing.getStartTime().isBefore(entry.getEndTime());
                    boolean sameSection = entry.getSectionName().equalsIgnoreCase(existing.getSectionName());
                    if (!sameUpload && sameSection && overlaps) return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Room conflict: " + entry.getLhNo() + " is already assigned in section " + existing.getSectionName() + " on " + entry.getDayOfWeek() + " " + formatTime(existing.getStartTime()) + "-" + formatTime(existing.getEndTime()) + "."));
                }
            }
            // Also detect overlaps between rows/events inside the workbook itself.
            for (int i = 0; i < parsed.size(); i++) {
                TimetableEntry a = parsed.get(i);
                for (int j = i + 1; j < parsed.size(); j++) {
                    TimetableEntry b = parsed.get(j);
                    if (a.getSectionName().equalsIgnoreCase(b.getSectionName())
                            && Objects.equals(a.getRoomId(), b.getRoomId()) && a.getDayOfWeek().equalsIgnoreCase(b.getDayOfWeek())
                            && a.getStartTime().isBefore(b.getEndTime()) && b.getStartTime().isBefore(a.getEndTime())) {
                        return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Room conflict inside uploaded workbook: " + a.getLhNo() + " on " + a.getDayOfWeek() + " has overlapping events " + formatTime(a.getStartTime()) + "-" + formatTime(a.getEndTime()) + " and " + formatTime(b.getStartTime()) + "-" + formatTime(b.getEndTime()) + "."));
                    }
                }
            }

            for (String sec : sectionsInWorkbook) timetableEntryRepository.deleteBySectionNameAndAcademicYearAndSemesterNo(sec, academicYear.trim(), semesterNo);
            if (!parsed.isEmpty()) timetableEntryRepository.saveAllAndFlush(parsed);

            realtimeHub.publish("TIMETABLE_CHANGED", "Timetable uploaded for " + sectionsInWorkbook.size() + " section(s).", Map.of("sections", sectionsInWorkbook.size(), "action", "UPLOADED"));
            return ResponseEntity.ok(Map.of("success", true, "message", "Timetable workbook uploaded successfully.", "sheetsRead", timetableSheets, "sections", sectionsInWorkbook, "entriesCreated", parsed.size()));
        } catch (Exception ex) {
            // IMPORTANT: this method is transactional. Once JPA/JDBC throws an
            // exception, Spring marks the transaction rollback-only. Returning
            // a normal ResponseEntity from this catch block used to make Spring
            // try to COMMIT that rollback-only transaction, producing the
            // misleading UnexpectedRollbackException seen by the user.
            // Re-throw a runtime exception instead so Spring rolls back first,
            // and the exception handler below formats the real cause cleanly.
            throw new ExcelUploadException("Could not process Excel: " + rootCauseMessage(ex), ex);
        }
    }

    @ExceptionHandler(ExcelUploadException.class)
    public ResponseEntity<?> handleExcelUploadException(ExcelUploadException ex) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                "success", false,
                "error", ex.getMessage(),
                "cause", rootCauseMessage(ex.getCause())
        ));
    }

    private static String rootCauseMessage(Throwable ex) {
        Throwable t = ex;
        Throwable last = ex;
        while (t != null) {
            last = t;
            t = t.getCause();
        }
        String msg = last == null ? null : last.getMessage();
        if (msg == null || msg.isBlank()) msg = last == null ? "Unknown error" : last.getClass().getSimpleName();
        return msg;
    }

    private static final class ExcelUploadException extends RuntimeException {
        ExcelUploadException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    private static boolean isIgnoredSheet(String name) {
        String n = normalizeHeader(name);
        return n.equals("INSTRUCTIONS") || n.equals("README") || n.equals("NOTES") || n.equals("SUMMARY");
    }

    private static String resolveSection(String sheetName, String requestedSection) {
        String n = sheetName == null ? "" : sheetName.trim();
        if (n.equalsIgnoreCase("Timetable") || n.equalsIgnoreCase("Sheet1") || n.isBlank()) {
            return requestedSection == null || requestedSection.isBlank() || requestedSection.equalsIgnoreCase("MULTI")
                    ? "GENERAL" : normalizeClassKey(requestedSection.trim());
        }
        n = n.replaceAll("(?i)\\s*TIMETABLE\\s*$", "").trim();
        return n.isBlank() ? "GENERAL" : normalizeClassKey(n);
    }

    private static boolean isYearDepartmentSectionKey(String value) {
        return Pattern.compile("(?i)^(?:(?:1st|2nd|3rd|4th)-[A-Z0-9]{2,8}-[A-Z0-9]{1,4}|(?:1st|2nd|3rd|4th)-ETM)$").matcher(value == null ? "" : value.trim()).matches();
    }

    /** Keeps Year + Department + Section together so repeated section names do not collide. */
    private static String normalizeClassKey(String raw) {
        String n = raw.trim().replace('_', '-').replaceAll("\\s+", "-");
        // Convert common forms such as "1 CSE A" / "1st CSE A" to 1st-CSE-A.
        Matcher m = Pattern.compile("(?i)^(1(?:st)?|2(?:nd)?|3(?:rd)?|4(?:th)?)\\W*([A-Z]{2,5})\\W*([A-Z])$").matcher(n);
        if (m.matches()) {
            String year = switch (m.group(1).toLowerCase(Locale.ROOT)) {
                case "1", "1st" -> "1st"; case "2", "2nd" -> "2nd"; case "3", "3rd" -> "3rd"; default -> "4th";
            };
            return year + "-" + m.group(2).toUpperCase(Locale.ROOT) + "-" + m.group(3).toUpperCase(Locale.ROOT);
        }
        return n;
    }

    /**
     * Extracts the room/class written in the final parenthesized part of a
     * subject cell. Examples: DSUR(C401) -> C401, CNS(LH-3) -> LH-3,
     * FM (S4) -> S4. Parentheses are treated as room overrides only when the
     * content is non-blank. The original subject text is preserved in the
     * TimetableEntry; only room resolution uses this value.
     */
    private static String extractBracketRoom(String subject) {
        if (subject == null || subject.isBlank()) return "";
        Matcher matcher = Pattern.compile("\\(([^()]*)\\)\\s*$").matcher(subject.trim());
        if (!matcher.find()) return "";
        return matcher.group(1) == null ? "" : matcher.group(1).trim();
    }

    private Optional<Room> resolveRoom(String rawRoom) {
        String value = rawRoom == null ? "" : rawRoom.trim();
        if (value.isBlank()) return Optional.empty();

        Optional<Room> exact = roomRepository.findByRoomNoIgnoreCase(value);
        if (exact.isPresent()) return exact;

        String normalized = normalizeRoom(value);
        Optional<Room> normalizedMatch = roomRepository.findAll().stream()
                .filter(r -> normalizeRoom(r.getRoomNo()).equals(normalized))
                .findFirst();
        if (normalizedMatch.isPresent()) return normalizedMatch;

        // The college timetable often uses labels such as F3/F-3/F413 that
        // are maintained as aliases rather than as the physical rooms'
        // canonical room_no. Resolve those aliases before falling back to
        // lecture_hall_mapping. This keeps the database as the source of
        // truth and avoids creating duplicate physical rooms just for an
        // alternate timetable label.
        Optional<Room> aliasMatch = roomRepository.findByRoomAlias(value);
        if (aliasMatch.isPresent()) return aliasMatch;

        Optional<Room> normalizedAliasMatch = roomRepository.findByNormalizedRoomAlias(value);
        if (normalizedAliasMatch.isPresent()) return normalizedAliasMatch;

        return lectureHallMappingRepository.findByLhNoIgnoreCase(value)
                .flatMap(m -> m.getRoomId() == null ? Optional.empty() : roomRepository.findById(m.getRoomId()));
    }

    private static String normalizeRoom(String value) {
        if (value == null) return "";
        return value.toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]", "");
    }

    private static Row findHeaderRow(Sheet sheet, DataFormatter formatter) {
        for (int r = 0; r <= Math.min(sheet.getLastRowNum(), 15); r++) {
            Row row = sheet.getRow(r);
            if (row == null) continue;
            boolean hasDay = false, hasRoom = false, hasTime = false;
            for (int c = 0; c <= row.getLastCellNum(); c++) {
                String h = normalizeHeader(value(row, c, formatter));
                if (h.equals("DAY")) hasDay = true;
                if (h.equals("LH-NO") || h.equals("LHNO") || h.equals("ROOM") || h.equals("ROOMNO") || h.equals("ROOM-NO")) hasRoom = true;
                if (parseTimeRange(value(row, c, formatter)).isPresent()) hasTime = true;
            }
            if (hasDay && hasRoom && hasTime) return row;
        }
        return null;
    }

    private static int findDayColumn(Row row, DataFormatter formatter) {
        for (int c = 0; c <= row.getLastCellNum(); c++) {
            if (normalizeHeader(value(row, c, formatter)).equals("DAY")) return c;
        }
        return -1;
    }

    private static int findRoomColumn(Row row, DataFormatter formatter) {
        for (int c = 0; c <= row.getLastCellNum(); c++) {
            String h = normalizeHeader(value(row, c, formatter));
            if (h.equals("LH-NO") || h.equals("LHNO") || h.equals("ROOM") || h.equals("ROOMNO") || h.equals("ROOM-NO")) return c;
        }
        return -1;
    }

    private List<TimeColumn> parseTimeColumns(Row row, DataFormatter formatter) {
        List<TimeColumn> result = new ArrayList<>();
        int dayColumn = findDayColumn(row, formatter);
        int roomColumn = findRoomColumn(row, formatter);
        for (int c = 0; c <= row.getLastCellNum(); c++) {
            if (c == dayColumn || c == roomColumn) continue;
            String raw = value(row, c, formatter);
            Optional<TimeRange> range = parseTimeRange(raw);
            final int column = c;
            range.ifPresent(r -> result.add(new TimeColumn(column, r.start, r.end, hasExplicitMeridiem(raw))));
        }
        result.sort(Comparator.comparingInt(tc -> tc.column));

        // GNITS spreadsheets commonly write afternoon periods as 01:00-02:00
        // instead of 13:00-14:00.  Treat an ambiguous 1-6 PM header as PM when
        // it follows the morning sequence. This is crucial for live occupancy.
        LocalTime previousEnd = null;
        for (TimeColumn tc : result) {
            if (!tc.explicitMeridiem && previousEnd != null && tc.start.isBefore(previousEnd) && tc.start.getHour() >= 1 && tc.start.getHour() <= 6) {
                tc.start = tc.start.plusHours(12);
                tc.end = tc.end.plusHours(12);
            }
            // If a sheet starts directly with an ambiguous 1-6 period, prefer PM
            // when there is no earlier morning period in the row.
            previousEnd = tc.end;
        }
        return result;
    }

    private static Optional<TimeRange> parseTimeRange(String raw) {
        if (raw == null || raw.isBlank()) return Optional.empty();
        String s = raw.trim().toUpperCase(Locale.ROOT)
                .replace('–', '-').replace('—', '-')
                .replace('.', ':');
        s = s.replaceAll("\\s+", " ");
        String[] parts = s.split("\\s*-\\s*");
        if (parts.length != 2) return Optional.empty();
        String startRaw = parts[0].trim();
        String endRaw = parts[1].trim();
        Optional<LocalTime> start = parseTime(startRaw);
        Optional<LocalTime> end = parseTime(endRaw);
        if (start.isEmpty() || end.isEmpty()) return Optional.empty();

        LocalTime startTime = start.get();
        LocalTime endTime = end.get();
        // Handle common 12-hour spreadsheet notation such as 12:10-1:10.
        // Without AM/PM, the end value can look numerically smaller even
        // though it is the next period in the afternoon.
        if (!hasExplicitMeridiem(startRaw) && !hasExplicitMeridiem(endRaw)
                && !startTime.isBefore(endTime) && startTime.getHour() >= 10) {
            endTime = endTime.plusHours(12);
        }
        if (!startTime.isBefore(endTime)) return Optional.empty();
        return Optional.of(new TimeRange(startTime, endTime));
    }

    private static boolean hasExplicitMeridiem(String raw) {
        if (raw == null) return false;
        String s = raw.toUpperCase(Locale.ROOT);
        return s.contains("AM") || s.contains("PM");
    }

    private static Optional<LocalTime> parseTime(String raw) {
        String s = raw.trim().toUpperCase(Locale.ROOT).replaceAll("\\s+", " ");
        boolean pm = s.endsWith("PM"), am = s.endsWith("AM");
        s = s.replace("AM", "").replace("PM", "").trim();
        try {
            String[] hm = s.split(":");
            int hour = Integer.parseInt(hm[0]);
            int minute = hm.length > 1 ? Integer.parseInt(hm[1]) : 0;
            if (am || pm) {
                if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return Optional.empty();
                if (pm && hour < 12) hour += 12;
                if (am && hour == 12) hour = 0;
            } else if (hour > 23 || minute < 0 || minute > 59) return Optional.empty();
            return Optional.of(LocalTime.of(hour, minute));
        } catch (Exception e) { return Optional.empty(); }
    }

    private static Map<String, MergedTimeRange> buildMergedSubjectRanges(Sheet sheet, List<TimeColumn> timeColumns, DataFormatter formatter) {
        Map<String, MergedTimeRange> map = new HashMap<>();
        Set<Integer> timeColumnSet = new HashSet<>();
        for (TimeColumn tc : timeColumns) timeColumnSet.add(tc.column);
        for (org.apache.poi.ss.util.CellRangeAddress region : sheet.getMergedRegions()) {
            if (region.getFirstRow() <= 3 && region.getLastRow() <= 3) continue; // title/header merges are not subject cells
            int first = region.getFirstColumn(), last = region.getLastColumn();
            boolean spansTime = false;
            for (int c : timeColumnSet) if (c >= first && c <= last) { spansTime = true; break; }
            if (!spansTime || first == last) continue;
            for (int r = region.getFirstRow(); r <= region.getLastRow(); r++) {
                for (int c : timeColumns.stream().map(tc -> tc.column).filter(x -> x >= first && x <= last).toList()) {
                    map.put(r + ":" + c, new MergedTimeRange(first, last));
                }
            }
        }
        return map;
    }

    private static Cell cellForMergedRegion(Sheet sheet, int row, int column) {
        for (org.apache.poi.ss.util.CellRangeAddress region : sheet.getMergedRegions()) {
            if (region.isInRange(row, column)) {
                Row firstRow = sheet.getRow(region.getFirstRow());
                return firstRow == null ? null : firstRow.getCell(region.getFirstColumn());
            }
        }
        Row current = sheet.getRow(row);
        return current == null ? null : current.getCell(column);
    }

    private static String mergedOrCellValue(Sheet sheet, Row row, int column, DataFormatter formatter) {
        Cell cell = cellForMergedRegion(sheet, row.getRowNum(), column);
        return cell == null ? "" : formatter.formatCellValue(cell);
    }

    private static TimeColumn timeColumnByColumn(List<TimeColumn> columns, int column) {
        for (TimeColumn tc : columns) if (tc.column == column) return tc;
        return null;
    }

    private static String formatTime(LocalTime t) { return t == null ? "" : t.toString(); }
    private static String normalizeHeader(String s) { return s == null ? "" : s.replace("–", "-").replace("—", "-").replace("_", "-").replaceAll("[^A-Za-z0-9-]", "").toUpperCase(Locale.ROOT); }
    private static String value(Row row, int col, DataFormatter formatter) { return row.getCell(col) == null ? "" : formatter.formatCellValue(row.getCell(col)); }
    private static String safe(String s) { return s.replaceAll("[^A-Za-z0-9_-]", "_"); }

    private static final class TimeRange {
        final LocalTime start, end;
        TimeRange(LocalTime start, LocalTime end) { this.start = start; this.end = end; }
    }

    private static final class TimeColumn {
        final int column; LocalTime start, end; final boolean explicitMeridiem;
        TimeColumn(int column, LocalTime start, LocalTime end, boolean explicitMeridiem) { this.column = column; this.start = start; this.end = end; this.explicitMeridiem = explicitMeridiem; }
    }

    private static final class MergedTimeRange {
        final int firstColumn, lastColumn;
        MergedTimeRange(int firstColumn, int lastColumn) { this.firstColumn = firstColumn; this.lastColumn = lastColumn; }
    }
    private static String safeSheetName(String s) { String n = safe(s); return n.isBlank() ? "Timetable" : n.substring(0, Math.min(n.length(), 31)); }
}
