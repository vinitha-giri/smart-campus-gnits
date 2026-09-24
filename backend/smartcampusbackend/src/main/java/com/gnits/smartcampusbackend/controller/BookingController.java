package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.Booking;
import com.gnits.smartcampusbackend.entity.Room;
import com.gnits.smartcampusbackend.entity.TimetableEntry;
import com.gnits.smartcampusbackend.repository.BookingRepository;
import com.gnits.smartcampusbackend.repository.RoomRepository;
import com.gnits.smartcampusbackend.repository.TimetableEntryRepository;
import com.gnits.smartcampusbackend.realtime.RealtimeHub;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;

@RestController
@RequestMapping("/api/bookings")
@CrossOrigin(origins = "*")
public class BookingController {
    private final BookingRepository bookingRepository;
    private final RoomRepository roomRepository;
    private final TimetableEntryRepository timetableRepository;
    private final RealtimeHub realtimeHub;

    public BookingController(BookingRepository bookingRepository, RoomRepository roomRepository, TimetableEntryRepository timetableRepository, RealtimeHub realtimeHub) {
        this.bookingRepository = bookingRepository;
        this.roomRepository = roomRepository;
        this.timetableRepository = timetableRepository;
        this.realtimeHub = realtimeHub;
    }

    @GetMapping("/available")
    public ResponseEntity<?> available(@RequestParam String date, @RequestParam String startTime, @RequestParam String endTime,
                                       @RequestParam(required=false) Integer capacity, @RequestParam(required=false) String roomType) {
        try {
            LocalDate d = LocalDate.parse(date); LocalTime start = LocalTime.parse(startTime); LocalTime end = LocalTime.parse(endTime);
            if (!start.isBefore(end)) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Start time must be before end time."));
            if (d.isBefore(LocalDate.now()) || (d.equals(LocalDate.now()) && !start.isAfter(LocalTime.now()))) {
                return ResponseEntity.badRequest().body(Map.of("success",false,"error","The selected start time has already passed."));
            }
            String day = d.getDayOfWeek().name();
            List<Map<String,Object>> out = new ArrayList<>();
            for (Room room : roomRepository.findAll()) {
                if ("MAINTENANCE".equalsIgnoreCase(room.getStatus()) || "RESERVED".equalsIgnoreCase(room.getStatus())) continue;
                if (capacity != null && room.getCapacity() != null && room.getCapacity() < capacity) continue;
                if (roomType != null && !roomType.isBlank() && !roomTypeMatches(room.getRoomType(), roomType)) continue;
                List<TimetableEntry> tt = timetableRepository.findAll().stream()
                        .filter(e -> roomMatches(e, room))
                        .filter(e -> dayMatches(e.getDayOfWeek(), day))
                        .toList();
                boolean timetableConflict = tt.stream().anyMatch(e -> e.getStartTime() != null && e.getEndTime() != null && start.isBefore(e.getEndTime()) && end.isAfter(e.getStartTime()));
                boolean bookingConflict = bookingRepository.hasOverlap(d, room.getRoomId(), start, end);
                if (!timetableConflict && !bookingConflict) {
                    out.add(Map.of("roomId",room.getRoomId(),"roomNo",room.getRoomNo(),"roomType",String.valueOf(room.getRoomType()),"capacity",room.getCapacity()==null?0:room.getCapacity(),"status","AVAILABLE"));
                }
            }
            return ResponseEntity.ok(Map.of("success",true,"date",date,"startTime",startTime,"endTime",endTime,"rooms",out));
        } catch (Exception e) { return ResponseEntity.badRequest().body(Map.of("success",false,"error","Invalid booking date/time.")); }
    }

    @GetMapping("/check")
    public ResponseEntity<?> check(@RequestParam Integer roomId, @RequestParam String date, @RequestParam String startTime, @RequestParam String endTime) {
        try {
            Room room = roomRepository.findById(roomId).orElse(null);
            if (room == null) return ResponseEntity.notFound().build();
            LocalDate d=LocalDate.parse(date); LocalTime start=LocalTime.parse(startTime); LocalTime end=LocalTime.parse(endTime);
            if (!start.isBefore(end)) return ResponseEntity.badRequest().body(Map.of("available",false,"reason","Start time must be before end time."));
            if (d.isBefore(LocalDate.now()) || (d.equals(LocalDate.now()) && !start.isAfter(LocalTime.now()))) return ResponseEntity.ok(Map.of("available",false,"reason","The selected start time has already passed."));
            if ("MAINTENANCE".equalsIgnoreCase(room.getStatus()) || "RESERVED".equalsIgnoreCase(room.getStatus())) return ResponseEntity.ok(Map.of("available",false,"reason","Room is not bookable."));
            String day=d.getDayOfWeek().name();
            boolean tt=timetableRepository.findAll().stream().filter(e->roomMatches(e,room)).filter(e->dayMatches(e.getDayOfWeek(),day)).anyMatch(e->e.getStartTime()!=null&&e.getEndTime()!=null&&start.isBefore(e.getEndTime())&&end.isAfter(e.getStartTime()));
            boolean bk=bookingRepository.hasOverlap(d,roomId,start,end);
            return ResponseEntity.ok(Map.of("available",!tt&&!bk,"timetableConflict",tt,"bookingConflict",bk,"reason",tt?"Timetable class is scheduled in this slot.":bk?"Another confirmed booking overlaps this slot.":"Room is available."));
        } catch(Exception e) { return ResponseEntity.badRequest().body(Map.of("available",false,"reason","Invalid date or time.")); }
    }

    @GetMapping
    public ResponseEntity<?> list(@RequestParam String role, @RequestParam String username) {
        if ("ADMIN".equalsIgnoreCase(role)) return ResponseEntity.ok(bookingRepository.findByStatusIgnoreCaseOrderByBookingDateDescStartTimeDesc("CONFIRMED"));
        if ("FACULTY".equalsIgnoreCase(role) || "STUDENT".equalsIgnoreCase(role)) return ResponseEntity.ok(bookingRepository.findByBookedByIgnoreCaseAndStatusIgnoreCaseOrderByBookingDateDescStartTimeDesc(username,"CONFIRMED"));
        return ResponseEntity.status(403).body(Map.of("success",false,"error","Unsupported role."));
    }

    @PostMapping
    @Transactional
    public ResponseEntity<?> create(@RequestBody Map<String,Object> body) {
        String role = Objects.toString(body.get("role"), "").toUpperCase(Locale.ROOT);
        if (!Set.of("ADMIN","FACULTY").contains(role)) return ResponseEntity.status(403).body(Map.of("success",false,"error","Booking authority is limited to Admin and Faculty."));
        try {
            Integer roomId = Integer.valueOf(Objects.toString(body.get("roomId")));
            Room room = roomRepository.findById(roomId).orElseThrow(() -> new IllegalArgumentException("Room not found."));
            LocalDate date = LocalDate.parse(Objects.toString(body.get("date")));
            LocalTime start = LocalTime.parse(Objects.toString(body.get("startTime")));
            LocalTime end = LocalTime.parse(Objects.toString(body.get("endTime")));
            String purpose = Objects.toString(body.get("purpose"), "").trim();
            String username = Objects.toString(body.get("username"), "").trim();
            if (username.isBlank() || purpose.isBlank()) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Purpose and user are required."));
            if (!start.isBefore(end)) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Start time must be before end time."));
            if (date.isBefore(LocalDate.now()) || (date.equals(LocalDate.now()) && !start.isAfter(LocalTime.now()))) return ResponseEntity.badRequest().body(Map.of("success",false,"error","The selected start time has already passed."));
            if ("MAINTENANCE".equalsIgnoreCase(room.getStatus()) || "RESERVED".equalsIgnoreCase(room.getStatus())) return ResponseEntity.badRequest().body(Map.of("success",false,"error","This room is not bookable."));
            String day = date.getDayOfWeek().name();
            boolean ttConflict = timetableRepository.findAll().stream()
                    .filter(e -> roomMatches(e, room))
                    .filter(e -> dayMatches(e.getDayOfWeek(), day))
                    .filter(e -> e.getStartTime() != null && e.getEndTime() != null)
                    .anyMatch(e -> start.isBefore(e.getEndTime()) && end.isAfter(e.getStartTime()));
            if (ttConflict || bookingRepository.hasOverlap(date,roomId,start,end)) return ResponseEntity.status(409).body(Map.of("success",false,"error","Room is already occupied or booked for the selected time."));
            Booking b = new Booking(); b.setRoomId(roomId); b.setRoomNo(room.getRoomNo()); b.setBookingDate(date); b.setStartTime(start); b.setEndTime(end); b.setPurpose(purpose); b.setBookedBy(username); b.setBookedByRole(role); b.setStatus("CONFIRMED");
            Booking saved = bookingRepository.save(b);
            realtimeHub.publish("BOOKING_CHANGED", "Room " + room.getRoomNo() + " was booked for " + date + " " + start + "-" + end + ".", Map.of("roomId", room.getRoomId(), "roomNo", room.getRoomNo(), "date", date.toString(), "startTime", start.toString(), "endTime", end.toString(), "status", "CONFIRMED"));
            return ResponseEntity.ok(Map.of("success",true,"message","Room booked successfully.","booking",saved));
        } catch (Exception e) { return ResponseEntity.badRequest().body(Map.of("success",false,"error",e.getMessage()==null?"Invalid booking request.":e.getMessage())); }
    }

    private static boolean roomTypeMatches(String stored, String requested) {
        if (stored == null || requested == null) return false;
        String a = stored.trim().toUpperCase(Locale.ROOT).replace('-', '_').replace(' ', '_');
        String b = requested.trim().toUpperCase(Locale.ROOT).replace('-', '_').replace(' ', '_');
        if (b.equals("CLASSROOM")) return a.equals("CLASSROOM") || a.equals("CLASS_ROOM");
        if (b.equals("LAB")) return a.equals("LAB") || a.equals("LABORATORY");
        if (b.equals("SEMINAR_HALL")) return a.equals("SEMINAR_HALL") || a.equals("SEMINAR");
        return a.equals(b);
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

    @DeleteMapping("/{id}")
    @Transactional
    public ResponseEntity<?> cancel(@PathVariable Integer id, @RequestParam String role, @RequestParam String username) {
        Booking b = bookingRepository.findById(id).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        if (!"ADMIN".equalsIgnoreCase(role) && !("FACULTY".equalsIgnoreCase(role) && b.getBookedBy().equalsIgnoreCase(username))) return ResponseEntity.status(403).body(Map.of("success",false,"error","You are not allowed to cancel this booking."));
        b.setStatus("CANCELLED"); bookingRepository.save(b);
        realtimeHub.publish("BOOKING_CHANGED", "Booking for room " + b.getRoomNo() + " was cancelled.", Map.of("roomId", b.getRoomId(), "roomNo", b.getRoomNo(), "date", b.getBookingDate().toString(), "startTime", b.getStartTime().toString(), "endTime", b.getEndTime().toString(), "status", "CANCELLED"));
        return ResponseEntity.ok(Map.of("success",true,"message","Booking cancelled."));
    }
}
