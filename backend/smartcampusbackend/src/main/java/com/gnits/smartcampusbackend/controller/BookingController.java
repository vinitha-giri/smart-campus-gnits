package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.Booking;
import com.gnits.smartcampusbackend.entity.Room;
import com.gnits.smartcampusbackend.entity.TimetableEntry;
import com.gnits.smartcampusbackend.entity.User;
import com.gnits.smartcampusbackend.entity.Notification;
import com.gnits.smartcampusbackend.repository.UserRepository;
import com.gnits.smartcampusbackend.repository.NotificationRepository;
import com.gnits.smartcampusbackend.repository.BookingRepository;
import com.gnits.smartcampusbackend.repository.RoomRepository;
import com.gnits.smartcampusbackend.repository.TimetableEntryRepository;
import com.gnits.smartcampusbackend.realtime.RealtimeHub;
import com.gnits.smartcampusbackend.service.PushNotificationService;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.*;
import java.time.LocalDateTime;

@RestController
@RequestMapping("/api/bookings")
@CrossOrigin(origins = "*")
public class BookingController {
    private static final ZoneId CAMPUS_ZONE = ZoneId.of("Asia/Kolkata");
    private final BookingRepository bookingRepository;
    private final RoomRepository roomRepository;
    private final TimetableEntryRepository timetableRepository;
    private final RealtimeHub realtimeHub;
    private final UserRepository userRepository;
    private final NotificationRepository notificationRepository;
    private final PushNotificationService pushNotifications;

    public BookingController(BookingRepository bookingRepository, RoomRepository roomRepository, TimetableEntryRepository timetableRepository, RealtimeHub realtimeHub, UserRepository userRepository, NotificationRepository notificationRepository, PushNotificationService pushNotifications) {
        this.bookingRepository = bookingRepository;
        this.roomRepository = roomRepository;
        this.timetableRepository = timetableRepository;
        this.realtimeHub = realtimeHub;
        this.userRepository = userRepository;
        this.notificationRepository = notificationRepository;
        this.pushNotifications = pushNotifications;
    }

    @GetMapping("/available")
    public ResponseEntity<?> available(@RequestParam String date, @RequestParam String startTime, @RequestParam String endTime,
                                       @RequestParam(required=false) Integer capacity, @RequestParam(required=false) String roomType) {
        try {
            LocalDate d = LocalDate.parse(date); LocalTime start = LocalTime.parse(startTime); LocalTime end = LocalTime.parse(endTime);
            if (!start.isBefore(end)) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Start time must be before end time."));
            LocalDate campusToday = LocalDate.now(CAMPUS_ZONE);
            LocalTime campusNow = LocalTime.now(CAMPUS_ZONE);
            if (d.isBefore(campusToday) || (d.equals(campusToday) && !start.isAfter(campusNow))) {
                return ResponseEntity.badRequest().body(Map.of("success",false,"error","The selected start time has already passed."));
            }
            String day = d.getDayOfWeek().name();
            List<Room> allRooms = roomRepository.findAll().stream()
                    .filter(BookingController::isUserVisibleRoom)
                    .toList();
            // Only the selected weekday is relevant to this availability check.
            List<TimetableEntry> allTimetable = timetableRepository.findByDayOfWeekIgnoreCase(day);
            List<Booking> confirmedBookings = new ArrayList<>();
            confirmedBookings.addAll(bookingRepository.findByBookingDateAndStatusIgnoreCase(d, "CONFIRMED"));
            confirmedBookings.addAll(bookingRepository.findByBookingDateAndStatusIgnoreCase(d, "PENDING_APPROVAL"));
            Map<Integer, List<Booking>> bookingsByRoom = new HashMap<>();
            for (Booking b : confirmedBookings) {
                if (b.getRoomId() != null) {
                    bookingsByRoom.computeIfAbsent(b.getRoomId(), k -> new ArrayList<>()).add(b);
                }
            }
            List<Map<String,Object>> out = new ArrayList<>();
            for (Room room : allRooms) {
                if ("MAINTENANCE".equalsIgnoreCase(room.getStatus()) || "RESERVED".equalsIgnoreCase(room.getStatus())) continue;
                Integer roomCapacity = room.getCapacity();
                if (capacity != null && (roomCapacity == null || roomCapacity < capacity)) continue;
                if (roomType != null && !roomType.isBlank() && !roomTypeMatches(room.getRoomType(), roomType)) continue;
                List<TimetableEntry> tt = allTimetable.stream()
                        .filter(e -> roomMatches(e, room))
                        .filter(e -> dayMatches(e.getDayOfWeek(), day))
                        .toList();
                boolean timetableConflict = tt.stream().anyMatch(e -> e.getStartTime() != null && e.getEndTime() != null && start.isBefore(e.getEndTime()) && end.isAfter(e.getStartTime()));
                boolean bookingConflict = bookingsByRoom.getOrDefault(room.getRoomId(), List.of()).stream()
                        .anyMatch(b -> b.getStartTime() != null && b.getEndTime() != null && start.isBefore(b.getEndTime()) && end.isAfter(b.getStartTime()));
                if (!timetableConflict && !bookingConflict) {
                    Map<String,Object> item = new LinkedHashMap<>();
                    item.put("roomId", room.getRoomId());
                    item.put("roomNo", room.getRoomNo());
                    item.put("roomType", String.valueOf(room.getRoomType()));
                    item.put("capacity", roomCapacity);
                    item.put("status", "AVAILABLE");
                    out.add(item);
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
            LocalDate campusToday = LocalDate.now(CAMPUS_ZONE);
            LocalTime campusNow = LocalTime.now(CAMPUS_ZONE);
            if (d.isBefore(campusToday) || (d.equals(campusToday) && !start.isAfter(campusNow))) return ResponseEntity.ok(Map.of("available",false,"reason","The selected start time has already passed."));
            if ("MAINTENANCE".equalsIgnoreCase(room.getStatus()) || "RESERVED".equalsIgnoreCase(room.getStatus())) return ResponseEntity.ok(Map.of("available",false,"reason","Room is not bookable."));
            String day=d.getDayOfWeek().name();
            boolean tt=timetableRepository.findByDayOfWeekIgnoreCase(day).stream().filter(e->roomMatches(e,room)).anyMatch(e->e.getStartTime()!=null&&e.getEndTime()!=null&&start.isBefore(e.getEndTime())&&end.isAfter(e.getStartTime()));
            boolean bk=bookingRepository.hasOverlap(d,roomId,start,end);
            return ResponseEntity.ok(Map.of("available",!tt&&!bk,"timetableConflict",tt,"bookingConflict",bk,"reason",tt?"Timetable class is scheduled in this slot.":bk?"Another confirmed or pending booking overlaps this slot.":"Room is available."));
        } catch(Exception e) { return ResponseEntity.badRequest().body(Map.of("available",false,"reason","Invalid date or time.")); }
    }

    @GetMapping
    public ResponseEntity<?> list(@RequestParam String role, @RequestParam String username) {
        if ("ADMIN".equalsIgnoreCase(role)) {
            List<Booking> all = new ArrayList<>();
            all.addAll(bookingRepository.findByStatusIgnoreCaseOrderByBookingDateDescStartTimeDesc("PENDING_APPROVAL"));
            all.addAll(bookingRepository.findByStatusIgnoreCaseOrderByBookingDateDescStartTimeDesc("CONFIRMED"));
            return ResponseEntity.ok(all);
        }
        if ("FACULTY".equalsIgnoreCase(role)) return ResponseEntity.ok(bookingRepository.findByBookedByIgnoreCaseOrderByBookingDateDescStartTimeDesc(username));
        if ("HEAD_STAFF".equalsIgnoreCase(role)) return ResponseEntity.ok(bookingRepository.findByStatusIgnoreCaseOrderByBookingDateAscStartTimeAsc("PENDING_APPROVAL"));
        if ("STUDENT".equalsIgnoreCase(role)) return ResponseEntity.ok(List.of());
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
            LocalDate campusToday = LocalDate.now(CAMPUS_ZONE);
            LocalTime campusNow = LocalTime.now(CAMPUS_ZONE);
            if (date.isBefore(campusToday) || (date.equals(campusToday) && !start.isAfter(campusNow))) return ResponseEntity.badRequest().body(Map.of("success",false,"error","The selected start time has already passed."));
            if ("MAINTENANCE".equalsIgnoreCase(room.getStatus()) || "RESERVED".equalsIgnoreCase(room.getStatus())) return ResponseEntity.badRequest().body(Map.of("success",false,"error","This room is not bookable."));
            String day = date.getDayOfWeek().name();
            boolean ttConflict = timetableRepository.findByDayOfWeekIgnoreCase(day).stream()
                    .filter(e -> roomMatches(e, room))
                    .filter(e -> e.getStartTime() != null && e.getEndTime() != null)
                    .anyMatch(e -> start.isBefore(e.getEndTime()) && end.isAfter(e.getStartTime()));
            if (ttConflict || bookingRepository.hasOverlap(date,roomId,start,end)) return ResponseEntity.status(409).body(Map.of("success",false,"error","Room is already occupied or booked for the selected time."));
            User faculty = userRepository.findByEmail(username).orElseGet(() -> userRepository.findByUsername(username).orElse(null));
            if (faculty == null) return ResponseEntity.status(401).body(Map.of("success",false,"error","Faculty account was not found."));

            // Faculty bookings must have a valid department Head Staff before a booking row is created.
            // Never create a REJECTED booking merely because the department setup is incomplete.
            if ("FACULTY".equalsIgnoreCase(role)) {
                String department = normalizeDepartment(faculty.getDepartment());
                if (department.isBlank()) {
                    return ResponseEntity.status(409).body(Map.of(
                            "success", false,
                            "error", "Your department is not configured for booking approval. Please contact Admin to update your department."));
                }
                List<User> heads = userRepository.findByRoleIgnoreCase("HEAD_STAFF").stream()
                        .filter(h -> normalizeDepartment(h.getDepartment()).equals(department))
                        .toList();
                if (heads.isEmpty()) {
                    return ResponseEntity.status(409).body(Map.of(
                            "success", false,
                            "error", "No Head Staff is configured for your department yet. Please contact Admin to assign a Head Staff before booking."));
                }

                Booking b = new Booking();
                b.setRoomId(roomId); b.setRoomNo(room.getRoomNo()); b.setBookingDate(date); b.setStartTime(start); b.setEndTime(end);
                b.setPurpose(purpose); b.setBookedBy(username); b.setBookedByRole(role); b.setStatus("PENDING_APPROVAL"); b.setApprovalDepartment(department);
                Booking saved = bookingRepository.save(b);

                String message = faculty.getName() + " requested " + room.getRoomNo() + " on " + date + " from " + start + " to " + end + ".";
                // Notify every configured Head Staff in the department. The first one to approve/reject completes the request.
                for (User head : heads) {
                    String recipient = head.getEmail() == null || head.getEmail().isBlank() ? head.getUsername() : head.getEmail();
                    Notification n = new Notification();
                    n.setRecipientEmail(recipient); n.setType("BOOKING_APPROVAL_REQUEST"); n.setTitle("New classroom booking request");
                    n.setMessage(message); n.setBookingId(saved.getBookingId()); notificationRepository.save(n);
                    realtimeHub.publish("BOOKING_APPROVAL_REQUEST", message, Map.of("bookingId", saved.getBookingId(), "recipient", recipient, "status", "PENDING_APPROVAL"));
                }
                return ResponseEntity.ok(Map.of("success",true,"message","Booking request sent to the concerned Head Staff for approval.","status","PENDING_APPROVAL","booking",saved));
            }

            Booking b = new Booking();
            b.setRoomId(roomId); b.setRoomNo(room.getRoomNo()); b.setBookingDate(date); b.setStartTime(start); b.setEndTime(end);
            b.setPurpose(purpose); b.setBookedBy(username); b.setBookedByRole(role); b.setStatus("CONFIRMED");
            Booking saved = bookingRepository.save(b);

            realtimeHub.publish("BOOKING_CHANGED", "Room " + room.getRoomNo() + " was booked for " + date + " " + start + "-" + end + ".", Map.of("roomId", room.getRoomId(), "roomNo", room.getRoomNo(), "date", date.toString(), "startTime", start.toString(), "endTime", end.toString(), "status", "CONFIRMED"));
            return ResponseEntity.ok(Map.of("success",true,"message","Room booked successfully.","booking",saved));
        } catch (Exception e) { return ResponseEntity.badRequest().body(Map.of("success",false,"error",e.getMessage()==null?"Invalid booking request.":e.getMessage())); }
    }

    @GetMapping("/pending-approvals")
    public ResponseEntity<?> pendingApprovals(@RequestParam String email) {
        User head = userRepository.findByEmail(email).orElseGet(() -> userRepository.findByUsername(email).orElse(null));
        if (head == null || !"HEAD_STAFF".equalsIgnoreCase(head.getRole())) return ResponseEntity.status(403).body(Map.of("success",false,"error","Head Staff account required."));
        String headDepartment = normalizeDepartment(head.getDepartment());
        if (headDepartment.isBlank()) {
            return ResponseEntity.status(409).body(Map.of(
                    "success", false,
                    "error", "Your Head Staff account has no department assigned. Please contact Admin to assign your department."));
        }
        List<Booking> pending = bookingRepository.findByStatusIgnoreCaseOrderByBookingDateAscStartTimeAsc("PENDING_APPROVAL");
        List<Booking> mine = pending.stream().filter(b -> {
            String approvalDept = normalizeDepartment(b.getApprovalDepartment());
            if (!approvalDept.isBlank()) return approvalDept.equals(headDepartment);
            User f=userRepository.findByEmail(b.getBookedBy()).orElseGet(() -> userRepository.findByUsername(b.getBookedBy()).orElse(null));
            return f != null && normalizeDepartment(f.getDepartment()).equals(headDepartment);
        }).toList();
        return ResponseEntity.ok(Map.of("success", true, "department", headDepartment, "count", mine.size(), "bookings", mine));
    }

    @PostMapping("/{id}/approve") @Transactional
    public ResponseEntity<?> approve(@PathVariable Integer id, @RequestParam String email) {
        User head = userRepository.findByEmail(email).orElseGet(() -> userRepository.findByUsername(email).orElse(null));
        Booking b = bookingRepository.findById(id).orElse(null);
        if (head == null || !"HEAD_STAFF".equalsIgnoreCase(head.getRole())) return ResponseEntity.status(403).body(Map.of("success",false,"error","Head Staff account required."));
        if (b == null) return ResponseEntity.notFound().build();
        User faculty=userRepository.findByEmail(b.getBookedBy()).orElseGet(() -> userRepository.findByUsername(b.getBookedBy()).orElse(null));
        if (faculty==null || !normalizeDepartment(faculty.getDepartment()).equals(normalizeDepartment(head.getDepartment()))) return ResponseEntity.status(403).body(Map.of("success",false,"error","This booking belongs to another department."));
        if (!"PENDING_APPROVAL".equalsIgnoreCase(b.getStatus())) return ResponseEntity.status(409).body(Map.of("success",false,"error","This booking is no longer pending."));
        if (bookingRepository.hasOverlapExcept(b.getBookingDate(), b.getRoomId(), b.getStartTime(), b.getEndTime(), b.getBookingId())) return ResponseEntity.status(409).body(Map.of("success",false,"error","The room is no longer available for this time."));
        b.setStatus("CONFIRMED"); b.setApprovedBy(head.getEmail()==null?head.getUsername():head.getEmail()); b.setApprovedAt(LocalDateTime.now()); b.setRejectionReason(null); bookingRepository.save(b);
        Notification n=new Notification(); n.setRecipientEmail(b.getBookedBy()); n.setType("BOOKING_APPROVED"); n.setTitle("Booking approved"); n.setMessage("Your booking for " + b.getRoomNo() + " on " + b.getBookingDate() + " from " + b.getStartTime() + " to " + b.getEndTime() + " has been approved."); n.setBookingId(b.getBookingId()); notificationRepository.save(n);
        pushNotifications.send(b.getBookedBy(), n.getTitle(), n.getMessage(), Map.of("type", n.getType(), "bookingId", String.valueOf(b.getBookingId())));
        realtimeHub.publish("BOOKING_CHANGED", n.getMessage(), Map.of("bookingId",b.getBookingId(),"roomId",b.getRoomId(),"roomNo",b.getRoomNo(),"status","CONFIRMED"));
        return ResponseEntity.ok(Map.of("success",true,"message","Booking approved.","booking",b));
    }

    @PostMapping("/{id}/reject") @Transactional
    public ResponseEntity<?> reject(@PathVariable Integer id, @RequestParam String email, @RequestParam(required=false, defaultValue="") String reason) {
        User head = userRepository.findByEmail(email).orElseGet(() -> userRepository.findByUsername(email).orElse(null));
        Booking b=bookingRepository.findById(id).orElse(null);
        if(head==null || !"HEAD_STAFF".equalsIgnoreCase(head.getRole())) return ResponseEntity.status(403).body(Map.of("success",false,"error","Head Staff account required."));
        if(b==null) return ResponseEntity.notFound().build();
        User faculty=userRepository.findByEmail(b.getBookedBy()).orElseGet(() -> userRepository.findByUsername(b.getBookedBy()).orElse(null));
        if(faculty==null || !normalizeDepartment(faculty.getDepartment()).equals(normalizeDepartment(head.getDepartment()))) return ResponseEntity.status(403).body(Map.of("success",false,"error","This booking belongs to another department."));
        if(!"PENDING_APPROVAL".equalsIgnoreCase(b.getStatus())) return ResponseEntity.status(409).body(Map.of("success",false,"error","This booking is no longer pending."));
        String why=reason==null?"":reason.trim(); b.setStatus("REJECTED"); b.setRejectionReason(why.isBlank()?"Rejected by Head Staff.":why); b.setApprovedBy(head.getEmail()==null?head.getUsername():head.getEmail()); b.setApprovedAt(LocalDateTime.now()); bookingRepository.save(b);
        Notification n=new Notification(); n.setRecipientEmail(b.getBookedBy()); n.setType("BOOKING_REJECTED"); n.setTitle("Booking rejected"); n.setMessage("Your booking for " + b.getRoomNo() + " on " + b.getBookingDate() + " was rejected. " + b.getRejectionReason()); n.setBookingId(b.getBookingId()); notificationRepository.save(n);
        pushNotifications.send(b.getBookedBy(), n.getTitle(), n.getMessage(), Map.of("type", n.getType(), "bookingId", String.valueOf(b.getBookingId())));
        realtimeHub.publish("BOOKING_CHANGED", n.getMessage(), Map.of("bookingId",b.getBookingId(),"roomId",b.getRoomId(),"roomNo",b.getRoomNo(),"status","REJECTED"));
        return ResponseEntity.ok(Map.of("success",true,"message","Booking rejected.","booking",b));
    }

    private static String normalizeDepartment(String value) {
        if (value == null) return "";
        String v = value.trim().toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]", "");
        return switch (v) {
            case "COMPUTERSCIENCEANDENGINEERING", "COMPUTERSCIENCEENGINEERING", "CSE" -> "CSE";
            case "ELECTRONICSANDCOMMUNICATIONENGINEERING", "ELECTRONICSCOMMUNICATIONENGINEERING", "ECE" -> "ECE";
            case "ELECTRICALANDELECTRONICSENGINEERING", "ELECTRICALENGINEERING", "EEE" -> "EEE";
            case "INFORMATIONTECHNOLOGY", "IT" -> "IT";
            case "MECHANICALENGINEERING", "MECH" -> "MECH";
            case "CIVILENGINEERING", "CIVIL" -> "CIVIL";
            default -> v;
        };
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

    private static boolean isUserVisibleRoom(Room room) {
        if (room == null) return false;
        String type = room.getRoomType() == null
                ? ""
                : room.getRoomType().trim().toUpperCase(Locale.ROOT);
        String normalizedNo = normalizeRoom(room.getRoomNo());
        if ("LIBRARY_SPACE".equals(type) || normalizedNo.startsWith("LIB")) return false;
        return !normalizedNo.equals("MAINCONF") && !normalizedNo.equals("MINICONF");
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
