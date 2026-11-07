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
import com.gnits.smartcampusbackend.service.TransactionalEmailService;
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
    private final TransactionalEmailService emailService;

    public BookingController(BookingRepository bookingRepository, RoomRepository roomRepository, TimetableEntryRepository timetableRepository, RealtimeHub realtimeHub, UserRepository userRepository, NotificationRepository notificationRepository, PushNotificationService pushNotifications, TransactionalEmailService emailService) {
        this.bookingRepository = bookingRepository;
        this.roomRepository = roomRepository;
        this.timetableRepository = timetableRepository;
        this.realtimeHub = realtimeHub;
        this.userRepository = userRepository;
        this.notificationRepository = notificationRepository;
        this.pushNotifications = pushNotifications;
        this.emailService = emailService;
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
            List<Map<String,Object>> unavailable = new ArrayList<>();
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
                List<Booking> overlapping = bookingsByRoom.getOrDefault(room.getRoomId(), List.of()).stream()
                        .filter(b -> b.getStartTime() != null && b.getEndTime() != null && start.isBefore(b.getEndTime()) && end.isAfter(b.getStartTime()))
                        .toList();
                boolean bookingConflict = !overlapping.isEmpty();
                if (!timetableConflict && !bookingConflict) {
                    Map<String,Object> item = new LinkedHashMap<>();
                    item.put("roomId", room.getRoomId()); item.put("roomNo", room.getRoomNo());
                    item.put("roomType", String.valueOf(room.getRoomType())); item.put("capacity", roomCapacity);
                    item.put("status", "AVAILABLE"); out.add(item);
                } else if (bookingConflict) {
                    for (Booking b : overlapping) {
                        Map<String,Object> item = new LinkedHashMap<>();
                        item.put("roomId", room.getRoomId()); item.put("roomNo", room.getRoomNo());
                        item.put("roomType", String.valueOf(room.getRoomType())); item.put("capacity", roomCapacity);
                        item.put("bookingId", b.getBookingId()); item.put("bookingDate", b.getBookingDate().toString());
                        item.put("startTime", b.getStartTime().toString()); item.put("endTime", b.getEndTime().toString());
                        item.put("status", b.getStatus()); item.put("purpose", b.getPurpose()); item.put("bookedBy", b.getBookedBy());
                        User owner = userRepository.findByEmail(b.getBookedBy()).orElseGet(() -> userRepository.findByUsername(b.getBookedBy()).orElse(null));
                        item.put("bookedByName", owner == null ? b.getBookedBy() : owner.getName());
                        item.put("department", owner == null ? Objects.toString(b.getApprovalDepartment(), "") : Objects.toString(owner.getDepartment(), ""));
                        unavailable.add(item);
                    }
                }
            }
            return ResponseEntity.ok(Map.of("success",true,"date",date,"startTime",startTime,"endTime",endTime,"rooms",out,"unavailableRooms",unavailable));
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
        if ("HEAD_STAFF".equalsIgnoreCase(role)) return ResponseEntity.ok(bookingRepository.findByBookedByIgnoreCaseOrderByBookingDateDescStartTimeDesc(username));
        if ("STUDENT".equalsIgnoreCase(role)) return ResponseEntity.ok(List.of());
        return ResponseEntity.status(403).body(Map.of("success",false,"error","Unsupported role."));
    }

    @PostMapping
    @Transactional
    public ResponseEntity<?> create(@RequestBody Map<String,Object> body) {
        String role = Objects.toString(body.get("role"), "").toUpperCase(Locale.ROOT);
        if (!Set.of("ADMIN","FACULTY","HEAD_STAFF").contains(role)) return ResponseEntity.status(403).body(Map.of("success",false,"error","Booking authority is limited to Admin, Faculty and Head Staff."));
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
            if ("FACULTY".equalsIgnoreCase(role) || "HEAD_STAFF".equalsIgnoreCase(role)) {
                if (!role.equalsIgnoreCase(faculty.getRole())) {
                    return ResponseEntity.status(403).body(Map.of("success",false,"error","The selected role does not match this account."));
                }
                // Approval authority follows the room's owning block, never the requester's home department.
                String approvalDepartment = roomApprovalDepartment(room.getRoomNo());
                if (approvalDepartment.isBlank()) {
                    return ResponseEntity.status(409).body(Map.of("success",false,"error","The classroom block could not be identified from its room number. Please contact Admin."));
                }
                List<User> approvers = userRepository.findByRoleIgnoreCase("HEAD_STAFF").stream()
                        .filter(h -> approvalDepartment.equals(normalizeDepartment(h.getDepartment())))
                        .toList();
                boolean headSelfApproval = "HEAD_STAFF".equalsIgnoreCase(role)
                        && approvalDepartment.equals(normalizeDepartment(faculty.getDepartment()));
                if (!headSelfApproval && approvers.isEmpty()) {
                    return ResponseEntity.status(409).body(Map.of("success",false,"error","No Head Staff account is configured for the owning block (" + approvalDepartment + "). Please contact Admin."));
                }

                Booking b = new Booking();
                b.setRoomId(roomId); b.setRoomNo(room.getRoomNo()); b.setBookingDate(date); b.setStartTime(start); b.setEndTime(end);
                b.setPurpose(purpose); b.setBookedBy(username); b.setBookedByRole(role); b.setApprovalDepartment(approvalDepartment);
                if (headSelfApproval) {
                    b.setStatus("CONFIRMED");
                    b.setApprovedBy(faculty.getEmail() == null ? faculty.getUsername() : faculty.getEmail());
                    b.setApprovedAt(LocalDateTime.now());
                    Booking saved = bookingRepository.save(b);
                    String recipient = faculty.getEmail() == null ? faculty.getUsername() : faculty.getEmail();
                    Notification n = new Notification(); n.setRecipientEmail(recipient); n.setType("BOOKING_APPROVED");
                    n.setTitle("Booking self-approved"); n.setMessage("Your booking for " + room.getRoomNo() + " on " + date + " from " + start + " to " + end + " was approved by you as the owning block's Head Staff.");
                    n.setBookingId(saved.getBookingId()); notificationRepository.save(n);
                    realtimeHub.publish("BOOKING_CHANGED", n.getMessage(), Map.of("bookingId",saved.getBookingId(),"roomId",roomId,"roomNo",room.getRoomNo(),"status","CONFIRMED"));
                    emailService.sendBookingDecision(recipient, faculty.getName(), true, room.getRoomNo(), date.toString(), start.toString(), end.toString(), "");
                    return ResponseEntity.ok(Map.of("success",true,"message","Booking approved by you as the Head Staff responsible for this block.","status","CONFIRMED","booking",saved));
                }

                b.setStatus("PENDING_APPROVAL");
                Booking saved = bookingRepository.save(b);
                String message = faculty.getName() + " requested " + room.getRoomNo() + " (" + approvalDepartment + ") on " + date + " from " + start + " to " + end + ".";
                for (User head : approvers) {
                    String recipient = head.getEmail() == null || head.getEmail().isBlank() ? head.getUsername() : head.getEmail();
                    Notification n = new Notification(); n.setRecipientEmail(recipient); n.setType("BOOKING_APPROVAL_REQUEST"); n.setTitle("New classroom booking request");
                    n.setMessage(message); n.setBookingId(saved.getBookingId()); notificationRepository.save(n);
                    realtimeHub.publish("BOOKING_APPROVAL_REQUEST", message, Map.of("bookingId", saved.getBookingId(), "recipient", recipient, "status", "PENDING_APPROVAL"));
                    emailService.sendBookingRequest(recipient, head.getName(), faculty.getName(), room.getRoomNo(), date.toString(), start.toString(), end.toString());
                }
                emailService.sendBookingSubmitted(faculty.getEmail() == null ? faculty.getUsername() : faculty.getEmail(), faculty.getName(), room.getRoomNo(), date.toString(), start.toString(), end.toString());
                return ResponseEntity.ok(Map.of("success",true,"message","Booking request sent to the Head Staff responsible for " + approvalDepartment + ".","status","PENDING_APPROVAL","booking",saved));
            }

            Booking b = new Booking();
            b.setRoomId(roomId); b.setRoomNo(room.getRoomNo()); b.setBookingDate(date); b.setStartTime(start); b.setEndTime(end);
            b.setPurpose(purpose); b.setBookedBy(username); b.setBookedByRole(role); b.setStatus("CONFIRMED");
            Booking saved = bookingRepository.save(b);

            realtimeHub.publish("BOOKING_CHANGED", "Room " + room.getRoomNo() + " was booked for " + date + " " + start + "-" + end + ".", Map.of("roomId", room.getRoomId(), "roomNo", room.getRoomNo(), "date", date.toString(), "startTime", start.toString(), "endTime", end.toString(), "status", "CONFIRMED"));
            emailService.sendAdminBookingConfirmation(faculty.getEmail() == null ? faculty.getUsername() : faculty.getEmail(),
                    faculty.getName(), room.getRoomNo(), date.toString(), start.toString(), end.toString());
            return ResponseEntity.ok(Map.of("success",true,"message","Room booked successfully.","booking",saved));
        } catch (Exception e) { return ResponseEntity.badRequest().body(Map.of("success",false,"error",e.getMessage()==null?"Invalid booking request.":e.getMessage())); }
    }

    @GetMapping("/pending-approvals")
    public ResponseEntity<?> pendingApprovals(@RequestParam String email) {
        User head = userRepository.findByEmail(email).orElseGet(() -> userRepository.findByUsername(email).orElse(null));
        if (head == null || !Set.of("HEAD_STAFF","ADMIN").contains(Objects.toString(head.getRole(),"").toUpperCase(Locale.ROOT))) return ResponseEntity.status(403).body(Map.of("success",false,"error","Head Staff or Admin account required."));
        List<Booking> pending = bookingRepository.findByStatusIgnoreCaseOrderByBookingDateAscStartTimeAsc("PENDING_APPROVAL");
        if ("ADMIN".equalsIgnoreCase(head.getRole())) {
            return ResponseEntity.ok(Map.of("success", true, "department", "ALL", "count", pending.size(), "bookings", pending));
        }
        String headDepartment = normalizeDepartment(head.getDepartment());
        if (headDepartment.isBlank()) {
            return ResponseEntity.status(409).body(Map.of(
                    "success", false,
                    "error", "Your Head Staff account has no department assigned. Please contact Admin to assign your department."));
        }
        List<Booking> mine = pending.stream().filter(b -> {
            String approvalDept = roomApprovalDepartment(b.getRoomNo());
            if (approvalDept.isBlank()) approvalDept = normalizeDepartment(b.getApprovalDepartment());
            return approvalDept.equals(headDepartment);
        }).toList();
        return ResponseEntity.ok(Map.of("success", true, "department", headDepartment, "count", mine.size(), "bookings", mine));
    }

    @PostMapping("/{id}/approve") @Transactional
    public ResponseEntity<?> approve(@PathVariable Integer id, @RequestParam String email) {
        User head = userRepository.findByEmail(email).orElseGet(() -> userRepository.findByUsername(email).orElse(null));
        Booking b = bookingRepository.findById(id).orElse(null);
        if (head == null || !Set.of("HEAD_STAFF","ADMIN").contains(Objects.toString(head.getRole(),"").toUpperCase(Locale.ROOT))) return ResponseEntity.status(403).body(Map.of("success",false,"error","Head Staff or Admin account required."));
        if (b == null) return ResponseEntity.notFound().build();
        User faculty=userRepository.findByEmail(b.getBookedBy()).orElseGet(() -> userRepository.findByUsername(b.getBookedBy()).orElse(null));
        if (faculty==null) return ResponseEntity.status(404).body(Map.of("success",false,"error","Booking owner account was not found."));
        if ("HEAD_STAFF".equalsIgnoreCase(head.getRole())
                && !roomApprovalDepartment(b.getRoomNo()).equals(normalizeDepartment(head.getDepartment())))
            return ResponseEntity.status(403).body(Map.of("success",false,"error","Only the Head Staff responsible for this classroom's block can approve it."));
        if (!"PENDING_APPROVAL".equalsIgnoreCase(b.getStatus())) return ResponseEntity.status(409).body(Map.of("success",false,"error","This booking is no longer pending."));
        if (bookingRepository.hasOverlapExcept(b.getBookingDate(), b.getRoomId(), b.getStartTime(), b.getEndTime(), b.getBookingId())) return ResponseEntity.status(409).body(Map.of("success",false,"error","The room is no longer available for this time."));
        b.setStatus("CONFIRMED"); b.setApprovedBy(head.getEmail()==null?head.getUsername():head.getEmail()); b.setApprovedAt(LocalDateTime.now()); b.setRejectionReason(null); bookingRepository.save(b);
        Notification n=new Notification(); n.setRecipientEmail(b.getBookedBy()); n.setType("BOOKING_APPROVED"); n.setTitle("Booking approved"); n.setMessage("Your booking for " + b.getRoomNo() + " on " + b.getBookingDate() + " from " + b.getStartTime() + " to " + b.getEndTime() + " has been approved."); n.setBookingId(b.getBookingId()); notificationRepository.save(n);
        pushNotifications.send(b.getBookedBy(), n.getTitle(), n.getMessage(), Map.of("type", n.getType(), "bookingId", String.valueOf(b.getBookingId())));
        emailService.sendBookingDecision(faculty.getEmail() == null ? faculty.getUsername() : faculty.getEmail(), faculty.getName(),
                true, b.getRoomNo(), b.getBookingDate().toString(), b.getStartTime().toString(), b.getEndTime().toString(), "");
        realtimeHub.publish("BOOKING_CHANGED", n.getMessage(), Map.of("bookingId",b.getBookingId(),"roomId",b.getRoomId(),"roomNo",b.getRoomNo(),"status","CONFIRMED"));
        return ResponseEntity.ok(Map.of("success",true,"message","Booking approved.","booking",b));
    }

    @PostMapping("/{id}/reject") @Transactional
    public ResponseEntity<?> reject(@PathVariable Integer id, @RequestParam String email, @RequestParam(required=false, defaultValue="") String reason) {
        User head = userRepository.findByEmail(email).orElseGet(() -> userRepository.findByUsername(email).orElse(null));
        Booking b=bookingRepository.findById(id).orElse(null);
        if(head==null || !Set.of("HEAD_STAFF","ADMIN").contains(Objects.toString(head.getRole(),"").toUpperCase(Locale.ROOT))) return ResponseEntity.status(403).body(Map.of("success",false,"error","Head Staff or Admin account required."));
        if(b==null) return ResponseEntity.notFound().build();
        User faculty=userRepository.findByEmail(b.getBookedBy()).orElseGet(() -> userRepository.findByUsername(b.getBookedBy()).orElse(null));
        if(faculty==null) return ResponseEntity.status(404).body(Map.of("success",false,"error","Booking owner account was not found."));
        if ("HEAD_STAFF".equalsIgnoreCase(head.getRole())
                && !roomApprovalDepartment(b.getRoomNo()).equals(normalizeDepartment(head.getDepartment())))
            return ResponseEntity.status(403).body(Map.of("success",false,"error","Only the Head Staff responsible for this classroom's block can reject it."));
        if(!"PENDING_APPROVAL".equalsIgnoreCase(b.getStatus())) return ResponseEntity.status(409).body(Map.of("success",false,"error","This booking is no longer pending."));
        String why=reason==null?"":reason.trim(); b.setStatus("REJECTED"); b.setRejectionReason(why.isBlank()?"Rejected by Head Staff.":why); b.setApprovedBy(head.getEmail()==null?head.getUsername():head.getEmail()); b.setApprovedAt(LocalDateTime.now()); bookingRepository.save(b);
        Notification n=new Notification(); n.setRecipientEmail(b.getBookedBy()); n.setType("BOOKING_REJECTED"); n.setTitle("Booking rejected"); n.setMessage("Your booking for " + b.getRoomNo() + " on " + b.getBookingDate() + " was rejected. " + b.getRejectionReason()); n.setBookingId(b.getBookingId()); notificationRepository.save(n);
        pushNotifications.send(b.getBookedBy(), n.getTitle(), n.getMessage(), Map.of("type", n.getType(), "bookingId", String.valueOf(b.getBookingId())));
        emailService.sendBookingDecision(faculty.getEmail() == null ? faculty.getUsername() : faculty.getEmail(), faculty.getName(),
                false, b.getRoomNo(), b.getBookingDate().toString(), b.getStartTime().toString(), b.getEndTime().toString(), b.getRejectionReason());
        realtimeHub.publish("BOOKING_CHANGED", n.getMessage(), Map.of("bookingId",b.getBookingId(),"roomId",b.getRoomId(),"roomNo",b.getRoomNo(),"status","REJECTED"));
        return ResponseEntity.ok(Map.of("success",true,"message","Booking rejected.","booking",b));
    }

    private static String normalizeDepartment(String value) {
        if (value == null) return "";
        String v = value.trim().toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]", "");
        return switch (v) {
            case "C", "CBLOCK", "COMPUTERSCIENCEANDENGINEERING", "COMPUTERSCIENCEENGINEERING", "CSE", "CSEBLOCK" -> "CSE";
            case "D", "DBLOCK", "ELECTRONICSANDCOMMUNICATIONENGINEERING", "ELECTRONICSCOMMUNICATIONENGINEERING", "ECE", "ECEBLOCK" -> "ECE";
            case "B", "BBLOCK", "ELECTRICALANDELECTRONICSENGINEERING", "ELECTRICALENGINEERING", "EEE", "EEEBLOCK" -> "EEE";
            case "F", "FBLOCK", "INFORMATIONTECHNOLOGY", "IT", "ITBLOCK" -> "IT";
            case "A", "ABLOCK", "ADMIN", "ADMINBLOCK", "ADMINISTRATION", "ADMINISTRATIONBLOCK" -> "ADMIN_BLOCK";
            case "S", "SBLOCK", "SILVERJUBILEE", "SILVERJUBILEEBLOCK" -> "SILVER_JUBILEE_BLOCK";
            case "MECHANICALENGINEERING", "MECH" -> "MECH";
            case "CIVILENGINEERING", "CIVIL" -> "CIVIL";
            default -> v;
        };
    }

    private static String roomApprovalDepartment(String roomNo) {
        if (roomNo == null || roomNo.isBlank()) return "";
        String value = roomNo.trim().toUpperCase(Locale.ROOT);
        char prefix = value.charAt(0);
        return switch (prefix) {
            case 'A' -> "ADMIN_BLOCK";
            case 'B' -> "EEE";
            case 'C' -> "CSE";
            case 'D' -> "ECE";
            case 'F' -> "IT";
            case 'S' -> "SILVER_JUBILEE_BLOCK";
            default -> "";
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
        if (!"ADMIN".equalsIgnoreCase(role) && !(("FACULTY".equalsIgnoreCase(role) || "HEAD_STAFF".equalsIgnoreCase(role)) && b.getBookedBy().equalsIgnoreCase(username))) return ResponseEntity.status(403).body(Map.of("success",false,"error","You are not allowed to cancel this booking."));
        if (!Set.of("PENDING_APPROVAL", "CONFIRMED").contains(Objects.toString(b.getStatus(), "").toUpperCase(Locale.ROOT))) return ResponseEntity.status(409).body(Map.of("success",false,"error","Only pending or approved bookings can be cancelled."));
        LocalDate today = LocalDate.now(CAMPUS_ZONE); LocalTime now = LocalTime.now(CAMPUS_ZONE);
        if (b.getBookingDate().isBefore(today) || (b.getBookingDate().equals(today) && !b.getStartTime().isAfter(now))) return ResponseEntity.status(409).body(Map.of("success",false,"error","A booking that has already started or passed cannot be cancelled. Contact Admin if a correction is required."));
        String previousStatus = b.getStatus();
        b.setStatus("CANCELLED"); bookingRepository.save(b);
        String message = "Booking for " + b.getRoomNo() + " on " + b.getBookingDate() + " " + b.getStartTime() + "-" + b.getEndTime() + " was cancelled by " + username + ". Previous status: " + previousStatus + ".";
        realtimeHub.publish("BOOKING_CHANGED", message, Map.of("roomId", b.getRoomId(), "roomNo", b.getRoomNo(), "date", b.getBookingDate().toString(), "startTime", b.getStartTime().toString(), "endTime", b.getEndTime().toString(), "status", "CANCELLED"));
        User owner = userRepository.findByEmail(b.getBookedBy()).orElseGet(() -> userRepository.findByUsername(b.getBookedBy()).orElse(null));
        String ownerEmail = owner == null ? b.getBookedBy() : Objects.toString(owner.getEmail(), owner.getUsername());
        if (ownerEmail != null && !ownerEmail.isBlank()) {
            Notification n = new Notification(); n.setRecipientEmail(ownerEmail); n.setType("BOOKING_CANCELLED"); n.setTitle("Booking cancelled"); n.setMessage(message); n.setBookingId(b.getBookingId()); notificationRepository.save(n);
            try { emailService.send(ownerEmail, owner == null ? "Faculty" : owner.getName(), "GNITS Smart Campus: booking cancelled", "<p>" + message + "</p>", message); } catch (Exception ignored) { }
            try { pushNotifications.send(ownerEmail, "Booking cancelled", message, Map.of("bookingId", String.valueOf(b.getBookingId()), "type", "BOOKING_CANCELLED")); } catch (Exception ignored) { }
        }
        {
            String cancellationAuthority = roomApprovalDepartment(b.getRoomNo());
            if (cancellationAuthority.isBlank()) cancellationAuthority = normalizeDepartment(b.getApprovalDepartment());
            for (User head : userRepository.findByRoleIgnoreCase("HEAD_STAFF")) {
                if (cancellationAuthority.equals(normalizeDepartment(head.getDepartment()))) {
                    String recipient = head.getEmail() == null || head.getEmail().isBlank() ? head.getUsername() : head.getEmail();
                    Notification n = new Notification(); n.setRecipientEmail(recipient); n.setType("BOOKING_CANCELLED"); n.setTitle("Booking cancellation notice"); n.setMessage(message); n.setBookingId(b.getBookingId()); notificationRepository.save(n);
                    try { emailService.send(recipient, "GNITS Smart Campus", "Booking cancellation notice", "<p>" + message + "</p>", message); } catch (Exception ignored) { }
                    try { pushNotifications.send(recipient, "Booking cancellation notice", message, Map.of("bookingId", String.valueOf(b.getBookingId()), "type", "BOOKING_CANCELLED")); } catch (Exception ignored) { }
                }
            }
        }
        return ResponseEntity.ok(Map.of("success",true,"message","Booking cancelled and the relevant approver has been notified."));
    }
}
