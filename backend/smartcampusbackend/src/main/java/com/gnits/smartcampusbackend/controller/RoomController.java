package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.Booking;
import com.gnits.smartcampusbackend.entity.Room;
import com.gnits.smartcampusbackend.entity.TimetableEntry;
import com.gnits.smartcampusbackend.repository.BookingRepository;
import com.gnits.smartcampusbackend.realtime.RealtimeHub;
import com.gnits.smartcampusbackend.repository.RoomRepository;
import com.gnits.smartcampusbackend.repository.TimetableEntryRepository;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/api/rooms")
@CrossOrigin(origins = "*")
public class RoomController {
    private static final ZoneId CAMPUS_ZONE = ZoneId.of("Asia/Kolkata");
    private final RoomRepository roomRepository;
    private final TimetableEntryRepository timetableEntryRepository;
    private final BookingRepository bookingRepository;
    private final RealtimeHub realtimeHub;

    // Live occupancy is the hottest endpoint in the app. A short server-side
    // cache lets hundreds of clients share the same snapshot instead of
    // repeatedly reading the timetable and bookings from MySQL.
    private final Map<String, CachedAvailability> availabilityCache = new ConcurrentHashMap<>();
    private static final long AVAILABILITY_CACHE_MS = 5000L;

    private static final class CachedAvailability {
        final long createdAt;
        final List<Map<String, Object>> data;
        CachedAvailability(long createdAt, List<Map<String, Object>> data) {
            this.createdAt = createdAt;
            this.data = data;
        }
    }

    public RoomController(RoomRepository roomRepository,
                          TimetableEntryRepository timetableEntryRepository,
                          BookingRepository bookingRepository,
                          RealtimeHub realtimeHub) {
        this.roomRepository = roomRepository;
        this.timetableEntryRepository = timetableEntryRepository;
        this.bookingRepository = bookingRepository;
        this.realtimeHub = realtimeHub;
    }

    @GetMapping
    public List<Room> getAllRooms() {
        // Database is the single source of truth for room capacity.
        // Hide non-user-facing library/general conference spaces from room lists.
        return roomRepository.findAll().stream()
                .filter(RoomController::isUserVisibleRoom)
                .toList();
    }

    @GetMapping("/live-status")
    public List<Map<String, Object>> getLiveStatus() {
        LocalDateTime campusNow = LocalDateTime.now(CAMPUS_ZONE);
        return getAvailability(null, campusNow.getDayOfWeek().name(), campusNow.toLocalTime().toString());
    }

    /**
     * Real-time room state. When day/time are omitted the server's current
     * campus-local date/time is used. Availability considers timetable,
     * confirmed bookings, maintenance and administrative reservations.
     */
    @GetMapping("/availability")
    public List<Map<String, Object>> getAvailability(
            @RequestParam(required = false) Integer roomId,
            @RequestParam(required = false) String day,
            @RequestParam(required = false) String time) {

        LocalDate campusToday = LocalDate.now(CAMPUS_ZONE);
        LocalDateTime campusNow = LocalDateTime.now(CAMPUS_ZONE);

        DayOfWeek dayOfWeek = (day == null || day.isBlank())
                ? campusToday.getDayOfWeek()
                : DayOfWeek.valueOf(day.toUpperCase(Locale.ROOT));

        LocalDate selectedDate = (day == null || day.isBlank())
                ? campusToday
                : nextOccurrence(dayOfWeek, campusToday);

        LocalTime checkTime = (time == null || time.isBlank())
                ? campusNow.toLocalTime()
                : LocalTime.parse(time);

        // Occupancy only needs minute-level precision. Sharing a five-second
        // snapshot dramatically reduces database work during busy periods.
        String cacheKey = (roomId == null ? "ALL" : roomId.toString()) + "|"
                + dayOfWeek.name() + "|" + checkTime.withSecond(0).withNano(0);
        CachedAvailability cached = availabilityCache.get(cacheKey);
        long nowMs = System.currentTimeMillis();
        if (cached != null && nowMs - cached.createdAt < AVAILABILITY_CACHE_MS) {
            return cached.data;
        }

        List<Room> rooms = roomId != null
                ? roomRepository.findById(roomId)
                        .filter(RoomController::isUserVisibleRoom)
                        .map(List::of)
                        .orElse(List.of())
                : roomRepository.findAll().stream()
                        .filter(RoomController::isUserVisibleRoom)
                        .toList();

        // Load timetable and bookings once per request. Never query the database
        // once per room; doing so exhausts the Hikari connection pool when the
        // live endpoint is polled frequently.
        // Only load the requested day. The full production timetable contains
        // thousands of rows and should never be scanned for every live request.
        List<TimetableEntry> allTimetable = timetableEntryRepository.findByDayOfWeekIgnoreCase(dayOfWeek.name());
        List<Booking> allBookings =
                bookingRepository.findByBookingDateAndStatusIgnoreCase(selectedDate, "CONFIRMED");

        Map<Integer, List<Booking>> bookingsByRoom = new HashMap<>();
        for (Booking booking : allBookings) {
            if (booking.getRoomId() != null) {
                bookingsByRoom
                        .computeIfAbsent(booking.getRoomId(), k -> new ArrayList<>())
                        .add(booking);
            }
        }

        // Build the timetable index once. A room can be matched either by the
        // explicit roomId or by the LH/alias label stored in the timetable.
        // This avoids scanning the entire timetable for every room.
        Map<Integer, List<TimetableEntry>> timetableByRoomId = new HashMap<>();
        Map<String, List<TimetableEntry>> timetableByRoomLabel = new HashMap<>();
        for (TimetableEntry entry : allTimetable) {
            if (!dayMatches(entry.getDayOfWeek(), dayOfWeek.name())
                    || entry.getStartTime() == null
                    || entry.getEndTime() == null) {
                continue;
            }
            if (entry.getRoomId() != null) {
                timetableByRoomId
                        .computeIfAbsent(entry.getRoomId(), k -> new ArrayList<>())
                        .add(entry);
            }
            String label = normalizeRoom(entry.getLhNo());
            if (!label.isBlank()) {
                timetableByRoomLabel
                        .computeIfAbsent(label, k -> new ArrayList<>())
                        .add(entry);
            }
        }

        List<Map<String, Object>> result = new ArrayList<>(rooms.size());

        for (Room room : rooms) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("roomId", room.getRoomId());
            item.put("roomNo", room.getRoomNo());
            item.put("floorNo", room.getFloorNo());
            item.put("roomType", room.getRoomType());
            item.put("capacity", room.getCapacity());
            item.put("checkedAt", campusNow.toString());
            item.put("checkedDay", dayOfWeek.name());
            item.put("checkedTime", checkTime.toString());

            if ("MAINTENANCE".equalsIgnoreCase(room.getStatus())) {
                item.put("status", "MAINTENANCE");
                item.put("statusReason", "Room is under maintenance");
                result.add(item);
                continue;
            }
            if ("RESERVED".equalsIgnoreCase(room.getStatus())) {
                item.put("status", "RESERVED");
                item.put("statusReason", "Room is administratively reserved");
                result.add(item);
                continue;
            }

            LinkedHashSet<TimetableEntry> matchedEntries = new LinkedHashSet<>();
            List<TimetableEntry> byId = timetableByRoomId.get(room.getRoomId());
            if (byId != null) matchedEntries.addAll(byId);
            List<TimetableEntry> byLabel = timetableByRoomLabel.get(normalizeRoom(room.getRoomNo()));
            if (byLabel != null) matchedEntries.addAll(byLabel);
            List<TimetableEntry> timetable = new ArrayList<>(matchedEntries);

            TimetableEntry activeClass = timetable.stream()
                    .filter(e -> overlaps(checkTime, e.getStartTime(), e.getEndTime()))
                    .findFirst()
                    .orElse(null);

            List<Booking> bookings = bookingsByRoom.getOrDefault(room.getRoomId(), List.of());
            Booking activeBooking = bookings.stream()
                    .filter(b -> b.getStartTime() != null && b.getEndTime() != null)
                    .filter(b -> overlaps(checkTime, b.getStartTime(), b.getEndTime()))
                    .findFirst()
                    .orElse(null);

            if (activeClass != null) {
                item.put("status", "OCCUPIED");
                item.put("statusReason", "Scheduled class");
                item.put("currentClass", activeClass.getSubjectName());
                item.put("section", activeClass.getSectionName());
                item.put("startTime", activeClass.getStartTime().toString());
                item.put("endTime", activeClass.getEndTime().toString());
                item.put("availableFrom", activeClass.getEndTime().toString());
            } else if (activeBooking != null) {
                item.put("status", "BOOKED");
                item.put("statusReason", "Confirmed room booking");
                item.put("currentClass", activeBooking.getPurpose());
                item.put("bookedBy", activeBooking.getBookedBy());
                item.put("startTime", activeBooking.getStartTime().toString());
                item.put("endTime", activeBooking.getEndTime().toString());
                item.put("availableFrom", activeBooking.getEndTime().toString());
            } else {
                item.put("status", "AVAILABLE");
                item.put("statusReason", "No active class or booking");
            }

            LocalTime nextStart = nextOccupiedStart(timetable, bookings, checkTime);
            if (nextStart != null) {
                item.put("nextOccupiedStart", nextStart.toString());
                if ("AVAILABLE".equalsIgnoreCase(String.valueOf(item.get("status")))) {
                    item.put("availableUntil", nextStart.toString());
                }
            }

            result.add(item);
        }

        availabilityCache.put(cacheKey, new CachedAvailability(System.currentTimeMillis(), result));
        return result;
    }


    /**
     * Future room schedule used by the student/faculty room-details view.
     * It combines recurring timetable classes with confirmed one-off bookings
     * for the next few calendar days.  The live /availability endpoint remains
     * unchanged and continues to represent "right now".
     */
    @GetMapping("/{roomId}/schedule")
    public ResponseEntity<?> getRoomSchedule(
            @PathVariable Integer roomId,
            @RequestParam(required = false) String fromDate,
            @RequestParam(required = false) Integer days) {
        Room room = roomRepository.findById(roomId).orElse(null);
        if (room == null) return ResponseEntity.notFound().build();

        LocalDate startDate;
        try {
            startDate = (fromDate == null || fromDate.isBlank()) ? LocalDate.now(CAMPUS_ZONE) : LocalDate.parse(fromDate);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Invalid fromDate. Use YYYY-MM-DD."));
        }
        int horizon = days == null ? 7 : Math.max(1, Math.min(days, 14));

        List<TimetableEntry> timetable = timetableEntryRepository.findAll().stream()
                .filter(e -> roomMatches(e, room))
                .filter(e -> e.getStartTime() != null && e.getEndTime() != null)
                .toList();

        List<Booking> bookings = bookingRepository.findAll().stream()
                .filter(b -> Objects.equals(b.getRoomId(), roomId))
                .filter(b -> "CONFIRMED".equalsIgnoreCase(b.getStatus()))
                .filter(b -> b.getBookingDate() != null && !b.getBookingDate().isBefore(startDate) && b.getBookingDate().isBefore(startDate.plusDays(horizon)))
                .toList();

        List<Map<String,Object>> events = new ArrayList<>();
        for (int offset = 0; offset < horizon; offset++) {
            LocalDate date = startDate.plusDays(offset);
            String day = date.getDayOfWeek().name();

            for (TimetableEntry e : timetable) {
                if (!dayMatches(e.getDayOfWeek(), day)) continue;
                Map<String,Object> event = new LinkedHashMap<>();
                event.put("date", date.toString());
                event.put("day", date.getDayOfWeek().toString());
                event.put("startTime", e.getStartTime().toString());
                event.put("endTime", e.getEndTime().toString());
                event.put("type", "TIMETABLE");
                event.put("status", "OCCUPIED");
                event.put("title", e.getSubjectName() == null || e.getSubjectName().isBlank() ? "Scheduled class" : e.getSubjectName());
                event.put("section", e.getSectionName());
                events.add(event);
            }

            for (Booking b : bookings) {
                if (!date.equals(b.getBookingDate())) continue;
                Map<String,Object> event = new LinkedHashMap<>();
                event.put("date", date.toString());
                event.put("day", date.getDayOfWeek().toString());
                event.put("startTime", b.getStartTime().toString());
                event.put("endTime", b.getEndTime().toString());
                event.put("type", "BOOKING");
                event.put("status", "BOOKED");
                event.put("title", b.getPurpose());
                event.put("section", null);
                events.add(event);
            }
        }

        events.sort(Comparator.comparing((Map<String,Object> e) -> String.valueOf(e.get("date")))
                .thenComparing(e -> String.valueOf(e.get("startTime")))
                .thenComparing(e -> String.valueOf(e.get("type"))));

        // Only expose a small, useful summary to normal users; no account name is returned.
        Map<String,Object> response = new LinkedHashMap<>();
        response.put("success", true);
        response.put("roomId", room.getRoomId());
        response.put("roomNo", room.getRoomNo());
        response.put("roomType", room.getRoomType());
        response.put("capacity", room.getCapacity());
        response.put("fromDate", startDate.toString());
        response.put("days", horizon);
        response.put("events", events);
        return ResponseEntity.ok(response);
    }

    @PostMapping
    public ResponseEntity<?> createRoom(@RequestBody Map<String,Object> body) {
        try {
            String roomNo = Objects.toString(body.get("roomNo"), "").trim();
            if (roomNo.isBlank()) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Room number is required."));
            if (roomRepository.findByRoomNoIgnoreCase(roomNo).isPresent()) return ResponseEntity.status(409).body(Map.of("success",false,"error","Room number already exists."));
            int nextId = roomRepository.findAll().stream().map(Room::getRoomId).filter(Objects::nonNull).max(Integer::compareTo).orElse(0) + 1;
            Room r = new Room();
            r.setRoomId(nextId);
            r.setRoomNo(roomNo);

            // building_id is mandatory in the rooms table. Resolve it from
            // the room-number block (A/B/C/D/F/S) using an existing room in
            // that block, so the client does not need to know numeric IDs.
            Integer buildingId = resolveBuildingId(roomNo);
            if (buildingId == null) {
                throw new IllegalArgumentException(
                        "Could not determine building for room " + roomNo +
                        ". Use a room number beginning with A, B, C, D, F or S.");
            }
            r.setBuildingId(buildingId);

            r.setFloorNo(toInt(body.get("floorNo")));
            r.setRoomType(Objects.toString(body.get("roomType"),"Classroom"));
            Integer capacity = toInt(body.get("capacity"));
            if (capacity == null || capacity <= 0) throw new IllegalArgumentException("Capacity must be greater than 0.");
            r.setCapacity(capacity);
            r.setStatus(normalizeAdminStatus(Objects.toString(body.get("status"),"AVAILABLE"))); r.setSmartEnabled(Boolean.TRUE.equals(body.get("smartEnabled")));
            Room saved = roomRepository.save(r);
            realtimeHub.publish("ROOM_CHANGED", "Room " + saved.getRoomNo() + " was created.", Map.of("roomId", saved.getRoomId(), "roomNo", saved.getRoomNo(), "action", "CREATED"));
            return ResponseEntity.ok(saved);
        } catch (Exception e) { return ResponseEntity.badRequest().body(Map.of("success",false,"error",e.getMessage()==null?"Invalid room":e.getMessage())); }
    }

    @PutMapping("/{roomId}")
    public ResponseEntity<?> updateRoom(@PathVariable Integer roomId, @RequestBody Map<String,Object> body) {
        Room r = roomRepository.findById(roomId).orElse(null);
        if (r == null) return ResponseEntity.notFound().build();
        try {
            if (body.containsKey("roomNo")) {
                String no = Objects.toString(body.get("roomNo"), "").trim();
                if (no.isBlank()) throw new IllegalArgumentException("Room number is required.");
                if (!no.equalsIgnoreCase(r.getRoomNo()) && roomRepository.findByRoomNoIgnoreCase(no).isPresent()) {
                    throw new IllegalArgumentException("Room number already exists.");
                }
                Integer buildingId = resolveBuildingId(no);
                if (buildingId == null) {
                    throw new IllegalArgumentException(
                            "Could not determine building for room " + no +
                            ". Use a room number beginning with A, B, C, D, F or S.");
                }
                r.setRoomNo(no);
                r.setBuildingId(buildingId);
            }
            if (body.containsKey("floorNo")) r.setFloorNo(toInt(body.get("floorNo")));
            if (body.containsKey("roomType")) r.setRoomType(Objects.toString(body.get("roomType"),"Classroom"));
            if (body.containsKey("capacity")) {
                Integer capacity = toInt(body.get("capacity"));
                if (capacity == null || capacity <= 0) throw new IllegalArgumentException("Capacity must be greater than 0.");
                r.setCapacity(capacity);
            }
            if (body.containsKey("status")) r.setStatus(normalizeAdminStatus(Objects.toString(body.get("status"),"AVAILABLE")));
            if (body.containsKey("smartEnabled")) r.setSmartEnabled(Boolean.TRUE.equals(body.get("smartEnabled")));
            Room saved = roomRepository.save(r);
            realtimeHub.publish("ROOM_CHANGED", "Room " + saved.getRoomNo() + " was updated.", Map.of("roomId", saved.getRoomId(), "roomNo", saved.getRoomNo(), "action", "UPDATED"));
            return ResponseEntity.ok(saved);
        } catch (Exception e) { return ResponseEntity.badRequest().body(Map.of("success",false,"error",e.getMessage()==null?"Invalid room":e.getMessage())); }
    }

    @DeleteMapping("/{roomId}")
    public ResponseEntity<?> deleteRoom(@PathVariable Integer roomId) {
        if (!roomRepository.existsById(roomId)) return ResponseEntity.notFound().build();
        if (bookingRepository.findAll().stream().anyMatch(b -> Objects.equals(b.getRoomId(), roomId) && "CONFIRMED".equalsIgnoreCase(b.getStatus())))
            return ResponseEntity.status(409).body(Map.of("success",false,"error","Room has confirmed bookings and cannot be deleted."));
        String deletedRoom = roomRepository.findById(roomId).map(Room::getRoomNo).orElse("room");
        roomRepository.deleteById(roomId);
        realtimeHub.publish("ROOM_CHANGED", "Room " + deletedRoom + " was deleted.", Map.of("roomId", roomId, "roomNo", deletedRoom, "action", "DELETED"));
        return ResponseEntity.ok(Map.of("success",true,"message","Room deleted."));
    }

    /**
     * Resolve the mandatory building_id from the room-number block. We reuse
     * an existing room in the same block, so the actual numeric building IDs
     * remain data-driven and can differ between databases.
     */
    private Integer resolveBuildingId(String roomNo) {
        String block = extractBlock(roomNo);
        if (block.isBlank()) return null;
        return roomRepository.findAll().stream()
                .filter(Objects::nonNull)
                .filter(r -> Objects.equals(extractBlock(r.getRoomNo()), block))
                .map(Room::getBuildingId)
                .filter(Objects::nonNull)
                .findFirst()
                .orElse(null);
    }

    private static String extractBlock(String roomNo) {
        if (roomNo == null) return "";
        String value = roomNo.trim().toUpperCase(Locale.ROOT);

        // CSE computer labs use the special CL-<number> naming convention,
        // e.g. CL-1, CL-5, CL-10. These are physical rooms in C Block.
        if (value.matches("^CL[-\\s]?\\d+$")) return "C";

        Matcher m = Pattern.compile("^(?:BLOCK\\s*)?([ABCDFS])(?:[-\\s]?\\d|$)", Pattern.CASE_INSENSITIVE)
                .matcher(value);
        return m.find() ? m.group(1).toUpperCase(Locale.ROOT) : "";
    }

    /** Rooms kept in MySQL but excluded from normal user-facing room lists. */
    private static boolean isUserVisibleRoom(Room room) {
        if (room == null) return false;
        String type = room.getRoomType() == null
                ? ""
                : room.getRoomType().trim().toUpperCase(Locale.ROOT);
        String normalizedNo = normalizeRoom(room.getRoomNo());

        // Exclude all library spaces and any room number beginning with LIB.
        if ("LIBRARY_SPACE".equals(type) || normalizedNo.startsWith("LIB")) return false;

        // Exclude only the two general conference rooms requested.
        return !normalizedNo.equals("MAINCONF") && !normalizedNo.equals("MINICONF");
    }

    private static Integer toInt(Object value) {
        if (value == null || Objects.toString(value,"").isBlank()) return null;
        return Integer.valueOf(Objects.toString(value));
    }
    private static String normalizeAdminStatus(String s) {
        String v=s==null?"AVAILABLE":s.trim().toUpperCase(Locale.ROOT);
        if (!Set.of("AVAILABLE","MAINTENANCE","RESERVED").contains(v)) return "AVAILABLE";
        return v;
    }

    private static boolean roomMatches(TimetableEntry entry, Room room) {
        if (entry.getRoomId() != null && Objects.equals(entry.getRoomId(), room.getRoomId())) return true;
        return normalizeRoom(entry.getLhNo()).equals(normalizeRoom(room.getRoomNo()));
    }

    private static String normalizeRoom(String value) {
        if (value == null) return "";
        return value.toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]", "");
    }

    private static boolean dayMatches(String stored, String requested) {
        if (stored == null || requested == null) return false;
        String a = stored.trim().toUpperCase(Locale.ROOT);
        String b = requested.trim().toUpperCase(Locale.ROOT);
        return a.equals(b) || (a.length() >= 3 && b.length() >= 3 && a.substring(0, 3).equals(b.substring(0, 3)));
    }

    private static boolean overlaps(LocalTime check, LocalTime start, LocalTime end) {
        return !check.isBefore(start) && check.isBefore(end);
    }

    private static LocalTime nextOccupiedStart(List<TimetableEntry> timetable, List<Booking> bookings, LocalTime now) {
        LocalTime result = null;
        for (TimetableEntry e : timetable) {
            if (e.getStartTime() != null && e.getStartTime().isAfter(now) && (result == null || e.getStartTime().isBefore(result))) result = e.getStartTime();
        }
        for (Booking b : bookings) {
            if (b.getStartTime() != null && b.getStartTime().isAfter(now) && (result == null || b.getStartTime().isBefore(result))) result = b.getStartTime();
        }
        return result;
    }

    private static LocalDate nextOccurrence(DayOfWeek target, LocalDate from) {
        int delta = (target.getValue() - from.getDayOfWeek().getValue() + 7) % 7;
        return from.plusDays(delta);
    }
}
