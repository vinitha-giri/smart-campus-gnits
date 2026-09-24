package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.Booking;
import com.gnits.smartcampusbackend.entity.Room;
import com.gnits.smartcampusbackend.entity.TimetableEntry;
import com.gnits.smartcampusbackend.repository.BookingRepository;
import com.gnits.smartcampusbackend.repository.RoomRepository;
import com.gnits.smartcampusbackend.repository.TimetableEntryRepository;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;

@RestController
@RequestMapping("/api/occupancy")
@CrossOrigin(origins = "*")
public class OccupancyController {
    private final RoomRepository roomRepository;
    private final TimetableEntryRepository timetableEntryRepository;
    private final BookingRepository bookingRepository;

    public OccupancyController(RoomRepository roomRepository, TimetableEntryRepository timetableEntryRepository, BookingRepository bookingRepository) {
        this.roomRepository = roomRepository;
        this.timetableEntryRepository = timetableEntryRepository;
        this.bookingRepository = bookingRepository;
    }

    /** Authoritative live snapshot used by all role dashboards. */
    @GetMapping("/live")
    public Map<String, Object> getLiveSnapshot() {
        LocalDate today = LocalDate.now();
        LocalTime now = LocalTime.now();
        List<Map<String, Object>> rooms = getOccupancy(today.getDayOfWeek().name(), now.toString(), null, null);
        long available = rooms.stream().filter(r -> "AVAILABLE".equalsIgnoreCase(String.valueOf(r.get("status")))).count();
        long occupied = rooms.stream().filter(r -> "OCCUPIED".equalsIgnoreCase(String.valueOf(r.get("status")))).count();
        long booked = rooms.stream().filter(r -> "BOOKED".equalsIgnoreCase(String.valueOf(r.get("status")))).count();
        long maintenance = rooms.stream().filter(r -> "MAINTENANCE".equalsIgnoreCase(String.valueOf(r.get("status")))).count();
        long reserved = rooms.stream().filter(r -> "RESERVED".equalsIgnoreCase(String.valueOf(r.get("status")))).count();
        Map<String,Object> out = new LinkedHashMap<>();
        out.put("checkedAt", java.time.LocalDateTime.now().toString());
        out.put("day", today.getDayOfWeek().name());
        out.put("time", now.toString());
        out.put("totalRooms", rooms.size());
        out.put("available", available); out.put("occupied", occupied); out.put("booked", booked);
        out.put("maintenance", maintenance); out.put("reserved", reserved);
        out.put("rooms", rooms);
        return out;
    }

    @GetMapping
    public List<Map<String, Object>> getOccupancy(
            @RequestParam String day,
            @RequestParam String time,
            @RequestParam(required = false) String academicYear,
            @RequestParam(required = false) Integer semesterNo) {
        LocalTime checkTime = LocalTime.parse(time);
        String normalizedDay = day.toUpperCase(Locale.ROOT);
        LocalDate selectedDate = nextOccurrence(normalizedDay);
        List<Map<String, Object>> result = new ArrayList<>();

        for (Room room : roomRepository.findAll()) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("roomId", room.getRoomId()); item.put("roomNo", room.getRoomNo());
            item.put("floorNo", room.getFloorNo()); item.put("roomType", room.getRoomType()); item.put("capacity", room.getCapacity());
            if ("MAINTENANCE".equalsIgnoreCase(room.getStatus())) { item.put("status", "MAINTENANCE"); result.add(item); continue; }
            if ("RESERVED".equalsIgnoreCase(room.getStatus())) { item.put("status", "RESERVED"); result.add(item); continue; }

            // Read the actual timetable rows for this room.  Older imported
            // data can contain either the numeric room_id or only LH-No/room_no,
            // so match on both and normalize short day names (MON/TUE/...).
            TimetableEntry match = timetableEntryRepository.findAll().stream()
                    .filter(e -> roomMatches(e, room))
                    .filter(e -> dayMatches(e.getDayOfWeek(), normalizedDay))
                    .filter(e -> e.getStartTime() != null && e.getEndTime() != null)
                    .filter(e -> !checkTime.isBefore(e.getStartTime()) && checkTime.isBefore(e.getEndTime()))
                    .filter(e -> academicYear == null || academicYear.isBlank() || academicYear.equalsIgnoreCase(e.getAcademicYear()))
                    .filter(e -> semesterNo == null || Objects.equals(semesterNo, e.getSemesterNo()))
                    .findFirst().orElse(null);
            Booking booking = bookingRepository.findByBookingDateAndRoomIdAndStatusIgnoreCase(selectedDate, room.getRoomId(), "CONFIRMED").stream()
                    .filter(b -> !checkTime.isBefore(b.getStartTime()) && checkTime.isBefore(b.getEndTime())).findFirst().orElse(null);
            if (match != null) {
                item.put("status", "OCCUPIED"); item.put("subject", match.getSubjectName()); item.put("section", match.getSectionName()); item.put("lhNo", match.getLhNo()); item.put("startTime", match.getStartTime().toString()); item.put("endTime", match.getEndTime().toString());
            } else if (booking != null) {
                item.put("status", "BOOKED"); item.put("subject", booking.getPurpose()); item.put("section", booking.getBookedBy()); item.put("startTime", booking.getStartTime().toString()); item.put("endTime", booking.getEndTime().toString());
            } else item.put("status", "AVAILABLE");
            result.add(item);
        }
        return result;
    }

    @GetMapping("/slots")
    public List<Map<String, String>> getSlots(@RequestParam(required = false) String day, @RequestParam(required = false) String academicYear, @RequestParam(required = false) Integer semesterNo) {
        Map<String, Map<String, String>> unique = new TreeMap<>();
        for (TimetableEntry e : timetableEntryRepository.findAll()) {
            if (day != null && !day.isBlank() && !dayMatches(e.getDayOfWeek(), day)) continue;
            if (academicYear != null && !academicYear.isBlank() && !academicYear.equalsIgnoreCase(e.getAcademicYear())) continue;
            if (semesterNo != null && !Objects.equals(semesterNo, e.getSemesterNo())) continue;
            String start = e.getStartTime().toString(); String end = e.getEndTime().toString();
            unique.putIfAbsent(start + "|" + end, Map.of("startTime", start, "endTime", end, "label", start + "–" + end));
        }
        return new ArrayList<>(unique.values());
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
        if (a.equals(b)) return true;
        return a.length() >= 3 && b.length() >= 3 && a.substring(0, 3).equals(b.substring(0, 3));
    }

    private LocalDate nextOccurrence(String day) {
        java.time.DayOfWeek target = java.time.DayOfWeek.valueOf(day);
        LocalDate now = LocalDate.now();
        int delta = (target.getValue() - now.getDayOfWeek().getValue() + 7) % 7;
        return now.plusDays(delta);
    }
}
