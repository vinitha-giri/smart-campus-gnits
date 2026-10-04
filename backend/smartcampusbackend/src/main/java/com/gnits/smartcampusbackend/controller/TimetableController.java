package com.gnits.smartcampusbackend.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.gnits.smartcampusbackend.entity.Room;
import com.gnits.smartcampusbackend.entity.TimetableEntry;
import com.gnits.smartcampusbackend.repository.RoomRepository;
import com.gnits.smartcampusbackend.repository.TimetableEntryRepository;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.*;
import java.time.LocalTime;
import java.util.*;

/**
 * Timetable upload pipeline.
 *
 * PDF -> Python parser (parse_cse_timetable.py, unchanged logic, just
 * called with explicit file paths) -> structured JSON preview returned
 * to the admin -> admin resolves any rooms flagged "requires_review"
 * and confirms -> only THEN is anything written to timetable_entries.
 *
 * Nothing is inserted into the database during /upload. Insertion only
 * happens in /confirm, inside a transaction, and only for entries whose
 * room has been resolved to a real rooms.room_id.
 */
@RestController
@RequestMapping("/api/timetable")
@CrossOrigin(origins = "*")
public class TimetableController {

    private static final String UPLOAD_DIR = "uploads";
    private static final String PARSED_DIR = "uploads/parsed";

    private final RoomRepository roomRepository;
    private final TimetableEntryRepository timetableEntryRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public TimetableController(RoomRepository roomRepository,
                                TimetableEntryRepository timetableEntryRepository) {
        this.roomRepository = roomRepository;
        this.timetableEntryRepository = timetableEntryRepository;
    }

    // ================================================================
    // STEP 1: UPLOAD + PARSE (no DB writes)
    // ================================================================

    @PostMapping("/upload")
    public ResponseEntity<?> uploadTimetable(@RequestParam("file") MultipartFile file) {

        try {
            String fileName = file.getOriginalFilename();

            if (fileName == null || fileName.isBlank()) {
                return ResponseEntity.badRequest()
                        .body(Map.of("success", false, "error", "Invalid file name"));
            }

            if (!fileName.toLowerCase().endsWith(".pdf")) {
                return ResponseEntity.badRequest()
                        .body(Map.of("success", false, "error", "Only PDF files are accepted"));
            }

            Path uploadPath = Paths.get(UPLOAD_DIR);
            Path parsedPath = Paths.get(PARSED_DIR);
            Files.createDirectories(uploadPath);
            Files.createDirectories(parsedPath);

            Path filePath = uploadPath.resolve(fileName);
            Files.copy(file.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);

            // Unique output JSON per upload so concurrent admin uploads
            // never clobber each other's preview data.
            String batchId = UUID.randomUUID().toString();
            Path jsonOutPath = parsedPath.resolve(batchId + ".json");

            int exitCode = runParser(filePath, jsonOutPath);

            if (exitCode != 0 || !Files.exists(jsonOutPath)) {
                return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(Map.of(
                        "success", false,
                        "error", "Timetable parser failed to produce output (exit code " + exitCode + ")"
                ));
            }

            String json = Files.readString(jsonOutPath);
            List<Map<String, Object>> branches = objectMapper.readValue(json, List.class);

            List<String> warnings = new ArrayList<>();
            for (Map<String, Object> branch : branches) {
                if (Boolean.TRUE.equals(branch.get("requires_review"))) {
                    warnings.add(branch.get("branch") + " has unresolved room(s): "
                            + ((Map<?, ?>) branch.get("rooms")).get("unresolved_rooms"));
                }
            }

            Map<String, Object> response = new LinkedHashMap<>();
            response.put("success", true);
            response.put("batchId", batchId);
            response.put("requiresReview", !warnings.isEmpty());
            response.put("warnings", warnings);
            response.put("branches", branches);

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("success", false, "error", "Upload failed: " + e.getMessage()));
        }
    }

    private int runParser(Path pdfPath, Path jsonOutPath) throws Exception {

        ProcessBuilder pb = new ProcessBuilder(
                "python",
                "python/parse_cse_timetable.py",
                pdfPath.toString(),
                jsonOutPath.toString()
        );
        pb.redirectErrorStream(true);

        Process process = pb.start();

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println("[PARSER] " + line);
            }
        }

        return process.waitFor();
    }

    // ================================================================
    // STEP 2: CONFIRM (writes to DB, only after admin review)
    // ================================================================

    /**
     * Request body shape:
     * {
     *   "batchId": "...",
     *   "roomMappings": { "CSE-A": 23, "CSE-B": 29 },   // branch -> rooms.room_id, admin-supplied
     *   "academicYear": "2026-2027",
     *   "semesterNo": 1
     * }
     *
     * Any branch NOT present in roomMappings AND not already resolvable
     * from the parser output is skipped (not inserted, not guessed).
     */
    @PostMapping("/confirm")
    @Transactional
    public ResponseEntity<?> confirmImport(@RequestBody Map<String, Object> request) {
System.out.println("========== CONFIRM ENDPOINT HIT ==========");
System.out.println("REQUEST = " + request);
        try {
            String batchId = (String) request.get("batchId");
            if (batchId == null) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "error", "batchId is required"));
            }

            Map<String, Object> roomMappingsRaw =
                    (Map<String, Object>) request.getOrDefault("roomMappings", Map.of());

            Path jsonPath = Paths.get(PARSED_DIR, batchId + ".json");
            if (!Files.exists(jsonPath)) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(Map.of("success", false, "error", "No parsed data found for this batchId. Re-upload the PDF."));
            }

            String json = Files.readString(jsonPath);
            List<Map<String, Object>> branches = objectMapper.readValue(json, List.class);

            int totalInserted = 0;
            int totalSkipped = 0;
            List<String> skippedBranches = new ArrayList<>();

            for (Map<String, Object> branchData : branches) {

                String branch = (String) branchData.get("branch");
                String academicYear = (String) branchData.getOrDefault("academic_year", "2026-2027");

                Integer roomId = resolveRoomIdForBranch(branchData, roomMappingsRaw, branch);

                if (roomId == null) {
                    skippedBranches.add(branch);
                    totalSkipped += ((List<?>) branchData.get("entries")).size();
                    continue;
                }

                // Replace any previous entries for this branch/section
                // rather than blindly appending duplicates on re-import.
                timetableEntryRepository.deleteBySectionName(branch);

                List<Map<String, Object>> entries = (List<Map<String, Object>>) branchData.get("entries");

                for (Map<String, Object> e : entries) {

                    String day = (String) e.get("day");
                    String startStr = (String) e.get("start_time");
                    String endStr = (String) e.get("end_time");
                    String subjectCode = (String) e.get("subject_code");
                    Boolean needsReview = (Boolean) e.get("needs_review");

                    if (Boolean.TRUE.equals(needsReview) || day == null
                            || startStr == null || endStr == null) {
                        totalSkipped++;
                        continue;
                    }

                    LocalTime start = LocalTime.parse(pad(startStr));
                    LocalTime end = LocalTime.parse(pad(endStr));

                    if (!start.isBefore(end)) {
                        totalSkipped++;
                        continue;
                    }

                    TimetableEntry entry = new TimetableEntry();
                    entry.setRoomId(roomId);
                    entry.setDayOfWeek(dayToFull(day));
                    entry.setStartTime(start);
                    entry.setEndTime(end);
                    entry.setAcademicYear(academicYear);
                    entry.setSemesterNo(1);
                    entry.setSectionName(branch);
                    entry.setSubjectName(subjectCode);

                    timetableEntryRepository.save(entry);
                    totalInserted++;
                }
            }

            Map<String, Object> response = new LinkedHashMap<>();
            response.put("success", true);
            response.put("totalInserted", totalInserted);
            response.put("totalSkipped", totalSkipped);
            response.put("skippedBranches", skippedBranches);

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("success", false, "error", "Import failed: " + e.getMessage()));
        }
    }

    private Integer resolveRoomIdForBranch(Map<String, Object> branchData,
                                            Map<String, Object> roomMappingsRaw,
                                            String branch) {

        // 1. Admin-supplied mapping always wins.
        if (roomMappingsRaw.containsKey(branch)) {
            Object v = roomMappingsRaw.get(branch);
            return v instanceof Number ? ((Number) v).intValue() : Integer.parseInt(v.toString());
        }

        // 2. Otherwise use the parser's own resolved room, if any and unambiguous.
        Map<String, Object> rooms = (Map<String, Object>) branchData.get("rooms");
        List<Map<String, Object>> resolved = (List<Map<String, Object>>) rooms.get("resolved_rooms");

        if (resolved == null || resolved.isEmpty()) {
            return null;
        }

        String physicalRoomNo = (String) resolved.get(0).get("physical_room");

        List<Room> matches = roomRepository.findAll();
        for (Room r : matches) {
            if (r.getRoomNo().equalsIgnoreCase(physicalRoomNo)) {
                return r.getRoomId();
            }
        }

        return null;
    }

    private static String pad(String time) {
        // "1:00" -> "01:00"
        if (time.indexOf(':') == 1) {
            return "0" + time;
        }
        return time;
    }

    private static String dayToFull(String shortDay) {
        return switch (shortDay.toUpperCase()) {
            case "MON" -> "MONDAY";
            case "TUE" -> "TUESDAY";
            case "WED" -> "WEDNESDAY";
            case "THU" -> "THURSDAY";
            case "FRI" -> "FRIDAY";
            case "SAT" -> "SATURDAY";
            default -> shortDay.toUpperCase();
        };
    }
}
