package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.*;
import com.gnits.smartcampusbackend.repository.*;
import com.gnits.smartcampusbackend.realtime.RealtimeHub;
import com.gnits.smartcampusbackend.service.PushNotificationService;
import com.gnits.smartcampusbackend.service.TransactionalEmailService;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.time.*;
import java.util.*;

/** Priority conflict review is deliberately isolated from normal room bookings. */
@RestController
@RequestMapping("/api/booking-conflicts")
@CrossOrigin(origins="*")
public class BookingConflictController {
    private final BookingConflictRequestRepository conflicts;
    private final BookingRepository bookings;
    private final UserRepository users;
    private final NotificationRepository notifications;
    private final PushNotificationService push;
    private final TransactionalEmailService email;
    private final RealtimeHub realtime;
    private final RoomRepository rooms;
    private final BookingConflictAuditRepository audit;
    public BookingConflictController(BookingConflictRequestRepository conflicts, BookingRepository bookings, UserRepository users,
            NotificationRepository notifications, PushNotificationService push, TransactionalEmailService email, RealtimeHub realtime, RoomRepository rooms, BookingConflictAuditRepository audit) {
        this.conflicts=conflicts; this.bookings=bookings; this.users=users; this.notifications=notifications; this.push=push; this.email=email; this.realtime=realtime; this.rooms=rooms; this.audit=audit;
    }

    @PostMapping @Transactional
    public ResponseEntity<?> submit(@RequestBody Map<String,Object> body) {
        try {
            String actor=val(body,"username");
            User requester=findUser(actor);
            if(requester==null || !("FACULTY".equalsIgnoreCase(requester.getRole()) || "HEAD_STAFF".equalsIgnoreCase(requester.getRole()))) return error(403,"A Faculty or Head Staff account is required.");
            Integer bookingId=Integer.valueOf(val(body,"existingBookingId"));
            Booking original=bookings.findById(bookingId).orElse(null);
            if(original==null || !("CONFIRMED".equalsIgnoreCase(original.getStatus()) || "PENDING_APPROVAL".equalsIgnoreCase(original.getStatus()))) return error(409,"Only a pending or approved booking can be sent for conflict review.");
            String ownerKey=original.getBookedBy(); User owner=findUser(ownerKey);
            if(owner==null) return error(409,"The original booking owner could not be identified. Please contact Admin.");
            String requesterMail=identity(requester), ownerMail=identity(owner);
            if(requesterMail.equalsIgnoreCase(ownerMail)) return error(400,"You cannot request a priority review against your own booking.");
            String requesterDept=normalizeDepartment(requester.getDepartment()), ownerDept=roomApprovalDepartment(original.getRoomNo());
            if(requesterDept.isBlank() || ownerDept.isBlank()) return error(409,"Both faculty departments must be configured before a conflict review can be submitted.");
            String priority=val(body,"priority").toUpperCase(Locale.ROOT);
            if(!Set.of("P1","P2","P3","P4").contains(priority)) return error(400,"Priority must be P1, P2, P3 or P4.");
            String justification=val(body,"justification");
            if(justification.length()<12 || justification.length()>1000) return error(400,"Please provide a clear justification (12–1000 characters).");
            List<User> requesterHeads=heads(requesterDept), ownerHeads=heads(ownerDept);
            if(requesterHeads.isEmpty() || ownerHeads.isEmpty()) return error(409,"A Head Staff account is missing for one or both departments. Please contact Admin.");
            if(!conflicts.findByExistingBookingIdAndRequesterEmailIgnoreCaseAndStatusIn(original.getBookingId(),requesterMail,List.of("PENDING_HEAD_REVIEW","PENDING_ADMIN_RESOLUTION","ESCALATED_TO_ADMIN")).isEmpty()) return error(409,"You already have an open conflict review for this booking.");
            BookingConflictRequest c=new BookingConflictRequest(); c.setExistingBookingId(original.getBookingId()); c.setRoomId(original.getRoomId()); c.setRoomNo(original.getRoomNo());
            c.setBookingDate(original.getBookingDate()); c.setStartTime(original.getStartTime()); c.setEndTime(original.getEndTime()); c.setRequesterEmail(requesterMail); c.setExistingFacultyEmail(ownerMail);
            c.setRequesterDepartment(requesterDept); c.setExistingDepartment(ownerDept); c.setRequestedPriority(priority); c.setJustification(justification); c.setStatus("PENDING_HEAD_REVIEW");
            if(body.containsKey("targetRoomId")) c.setTargetRoomId(Integer.valueOf(val(body,"targetRoomId")));
            if(body.containsKey("targetRoomNo")) c.setTargetRoomNo(val(body,"targetRoomNo"));
            if(body.containsKey("targetDate")) c.setTargetDate(LocalDate.parse(val(body,"targetDate")));
            if(body.containsKey("targetStartTime")) c.setTargetStartTime(LocalTime.parse(val(body,"targetStartTime")));
            if(body.containsKey("targetEndTime")) c.setTargetEndTime(LocalTime.parse(val(body,"targetEndTime")));
            BookingConflictRequest saved=conflicts.save(c);
            record(saved, requesterMail, "SUBMITTED", "Priority "+priority+"; original booking status="+original.getStatus());
            notifyHeads(requesterHeads,saved,"Priority conflict review requested",requester.getName()+" requests review of "+original.getRoomNo()+" for "+original.getBookingDate()+". Priority: "+priority+". Original booking remains unchanged.");
            if(!requesterDept.equals(ownerDept)) notifyHeads(ownerHeads,saved,"Existing booking needs conflict review", "A priority conflict review was requested against "+owner.getName()+"'s approved booking for "+original.getRoomNo()+" on "+original.getBookingDate()+". Your department's decision is required.");
            notifyPerson(requesterMail,saved,"Conflict review submitted","Your priority conflict review was submitted. The existing booking remains unchanged while the concerned Head Staff review it.");
            notifyPerson(ownerMail,saved,"Booking conflict review requested","Another faculty member requested a priority review of this time slot. Your approved booking is still active.");
            return ResponseEntity.ok(Map.of("success",true,"message","Conflict review submitted to the Head Staff responsible for the relevant departments. The existing booking has not been changed.","request",saved));
        } catch(Exception ex) { return error(400,"Invalid conflict review request: "+(ex.getMessage()==null?"check the submitted details":ex.getMessage())); }
    }

    @GetMapping("/candidates")
    public ResponseEntity<?> candidates(@RequestParam String username) {
        User faculty=findUser(username); if(faculty==null || !("FACULTY".equalsIgnoreCase(faculty.getRole()) || "HEAD_STAFF".equalsIgnoreCase(faculty.getRole()))) return error(403,"Faculty or Head Staff account required.");
        List<Booking> eligible = new ArrayList<>(bookings.findByStatusIgnoreCaseOrderByBookingDateDescStartTimeDesc("CONFIRMED"));
        eligible.addAll(bookings.findByStatusIgnoreCaseOrderByBookingDateDescStartTimeDesc("PENDING_APPROVAL"));
        return ResponseEntity.ok(eligible.stream()
                .filter(b->!identity(faculty).equalsIgnoreCase(b.getBookedBy()))
                .filter(b->b.getBookingDate()!=null && !b.getBookingDate().isBefore(LocalDate.now(ZoneId.of("Asia/Kolkata"))))
                .toList());
    }

    @GetMapping
    public ResponseEntity<?> list(@RequestParam String role,@RequestParam String emailAddress) {
        User actor=findUser(emailAddress); if(actor==null) return error(401,"Account not found.");
        if("ADMIN".equalsIgnoreCase(role) && "ADMIN".equalsIgnoreCase(actor.getRole())) return ResponseEntity.ok(conflicts.findAll());
        if("FACULTY".equalsIgnoreCase(role) && "FACULTY".equalsIgnoreCase(actor.getRole())) {
            List<BookingConflictRequest> all=new ArrayList<>(conflicts.findByRequesterEmailIgnoreCaseOrderByCreatedAtDesc(identity(actor)));
            all.addAll(conflicts.findByExistingFacultyEmailIgnoreCaseOrderByCreatedAtDesc(identity(actor))); return ResponseEntity.ok(all);
        }
        if("HEAD_STAFF".equalsIgnoreCase(role) && "HEAD_STAFF".equalsIgnoreCase(actor.getRole())) {
            String dept=normalizeDepartment(actor.getDepartment()); if(dept.isBlank()) return error(409,"Your department is not configured.");
            Map<Long,BookingConflictRequest> visible=new LinkedHashMap<>();
            for(BookingConflictRequest c:conflicts.findByRequesterEmailIgnoreCaseOrderByCreatedAtDesc(identity(actor))) visible.put(c.getId(),c);
            for(BookingConflictRequest c:conflicts.findByExistingFacultyEmailIgnoreCaseOrderByCreatedAtDesc(identity(actor))) visible.put(c.getId(),c);
            for(BookingConflictRequest c:conflicts.findByStatusInOrderByCreatedAtAsc(List.of("PENDING_HEAD_REVIEW","PENDING_ADMIN_RESOLUTION")))
                if(dept.equals(c.getRequesterDepartment())||dept.equals(c.getExistingDepartment())) visible.put(c.getId(),c);
            return ResponseEntity.ok(new ArrayList<>(visible.values()));
        }
        return error(403,"You are not allowed to view these conflict requests.");
    }

    @PostMapping("/{id}/head-decision") @Transactional
    public ResponseEntity<?> headDecision(@PathVariable Long id,@RequestParam String emailAddress,@RequestBody Map<String,String> body) {
        User head=findUser(emailAddress); BookingConflictRequest c=conflicts.findById(id).orElse(null);
        if(head==null||!"HEAD_STAFF".equalsIgnoreCase(head.getRole())) return error(403,"Head Staff account required."); if(c==null) return ResponseEntity.notFound().build();
        String dept=normalizeDepartment(head.getDepartment()); boolean requesterSide=dept.equals(c.getRequesterDepartment()), ownerSide=dept.equals(c.getExistingDepartment());
        if(!requesterSide&&!ownerSide) return error(403,"This request is outside your department.");
        if(!"PENDING_HEAD_REVIEW".equals(c.getStatus())) return error(409,"Head Staff review is already complete.");
        String decision=Objects.toString(body.get("decision"),"").toUpperCase(Locale.ROOT);
        if("AGREE".equals(decision)) decision="KEEP_EXISTING"; // backward compatibility with V5.1 clients
        if(!Set.of("KEEP_EXISTING","DECLINE","ESCALATE").contains(decision)) return error(400,"Decision must be KEEP_EXISTING, DECLINE or ESCALATE.");
        if("ESCALATE".equals(decision)) {
            c.setStatus("ESCALATED_TO_ADMIN"); c.setEscalatedAt(LocalDateTime.now());
            conflicts.save(c); record(c,identity(head),"HEAD_ESCALATION","Head Staff escalated an unresolved conflict review.");
            String msg="Conflict review #"+c.getId()+" was escalated to general Admin by "+head.getName()+". The original booking remains unchanged.";
            for(User admin:users.findByRoleIgnoreCase("ADMIN")) notifyPerson(identity(admin),c,"Conflict review escalated to Admin",msg);
            notifyPerson(c.getRequesterEmail(),c,"Conflict review escalated",msg); notifyPerson(c.getExistingFacultyEmail(),c,"Conflict review escalated",msg);
            return ResponseEntity.ok(Map.of("success",true,"message",msg,"request",c));
        }
        if(requesterSide){c.setRequesterHeadDecision(decision);c.setRequesterHeadEmail(identity(head));}
        if(ownerSide){c.setExistingHeadDecision(decision);c.setExistingHeadEmail(identity(head));}
        if("DECLINE".equals(decision)) c.setStatus("DECLINED_BY_HEAD");
        else if("KEEP_EXISTING".equals(c.getRequesterHeadDecision()) && "KEEP_EXISTING".equals(c.getExistingHeadDecision())) {
            c.setStatus("RESOLUTION_RECORDED"); c.setAdminResolution("KEEP_EXISTING"); c.setAdminNote("Final decision recorded by the concerned Head Staff. Existing booking retained; no booking was changed."); c.setResolvedBy(identity(head));
        }
        conflicts.save(c); record(c, identity(head), "HEAD_DECISION", dept+" decision="+decision);
        String msg="Head Staff decision recorded: "+decision+". Status: "+c.getStatus()+". The original booking remains unchanged.";
        notifyPerson(c.getRequesterEmail(),c,"Conflict review updated",msg); notifyPerson(c.getExistingFacultyEmail(),c,"Conflict review updated",msg);
        return ResponseEntity.ok(Map.of("success",true,"message",msg,"request",c));
    }

    @PostMapping("/{id}/priority-verification") @Transactional
    public ResponseEntity<?> verifyPriority(@PathVariable Long id, @RequestParam String emailAddress, @RequestBody Map<String,String> body) {
        User head=findUser(emailAddress); BookingConflictRequest c=conflicts.findById(id).orElse(null);
        if(head==null || !"HEAD_STAFF".equalsIgnoreCase(head.getRole())) return error(403,"Head Staff account required.");
        if(c==null) return ResponseEntity.notFound().build();
        String dept=normalizeDepartment(head.getDepartment());
        if(!dept.equals(c.getRequesterDepartment()) && !dept.equals(c.getExistingDepartment())) return error(403,"This request is outside your department.");
        String priority=Objects.toString(body.get("priority"),"").toUpperCase(Locale.ROOT);
        if(!Set.of("P1","P2","P3","P4").contains(priority)) return error(400,"Priority must be P1, P2, P3 or P4.");
        c.setVerifiedPriority(priority); c.setPriorityVerifiedBy(identity(head)); c.setPriorityVerifiedAt(LocalDateTime.now());
        conflicts.save(c); record(c,identity(head),"PRIORITY_VERIFIED","Priority changed from "+c.getRequestedPriority()+" to "+priority);
        notifyPerson(c.getRequesterEmail(),c,"Conflict priority verified","Head Staff verified the conflict priority as "+priority+".");
        return ResponseEntity.ok(Map.of("success",true,"request",c,"message","Priority verified."));
    }

    @PostMapping("/{id}/consent") @Transactional
    public ResponseEntity<?> consent(@PathVariable Long id,@RequestParam String emailAddress,@RequestBody Map<String,Object> body) {
        User actor=findUser(emailAddress); BookingConflictRequest c=conflicts.findById(id).orElse(null);
        if(actor==null || !("FACULTY".equalsIgnoreCase(actor.getRole()) || "HEAD_STAFF".equalsIgnoreCase(actor.getRole()))) return error(403,"Faculty or Head Staff account required.");
        if(c==null) return ResponseEntity.notFound().build();
        String who=identity(actor); boolean agree="true".equalsIgnoreCase(Objects.toString(body.get("agree"),"false"));
        if(who.equalsIgnoreCase(c.getRequesterEmail())) c.setRequesterConsent(agree);
        else if(who.equalsIgnoreCase(c.getExistingFacultyEmail())) c.setExistingOwnerConsent(agree);
        else return error(403,"You are not a participant in this conflict request.");
        conflicts.save(c); record(c,who,"CONSENT",agree?"Agreed to proposed rescheduling":"Declined proposed rescheduling");
        return ResponseEntity.ok(Map.of("success",true,"requesterConsent",Boolean.TRUE.equals(c.getRequesterConsent()),"existingOwnerConsent",Boolean.TRUE.equals(c.getExistingOwnerConsent())));
    }

    @GetMapping("/{id}/history")
    public ResponseEntity<?> history(@PathVariable Long id,@RequestParam String emailAddress) {
        User actor=findUser(emailAddress); BookingConflictRequest c=conflicts.findById(id).orElse(null);
        if(actor==null || c==null) return ResponseEntity.notFound().build();
        String who=identity(actor); String dept=normalizeDepartment(actor.getDepartment());
        boolean allowed="ADMIN".equalsIgnoreCase(actor.getRole()) || who.equalsIgnoreCase(c.getRequesterEmail()) || who.equalsIgnoreCase(c.getExistingFacultyEmail()) || ("HEAD_STAFF".equalsIgnoreCase(actor.getRole()) && (dept.equals(c.getRequesterDepartment())||dept.equals(c.getExistingDepartment())));
        if(!allowed) return error(403,"You cannot view this history.");
        return ResponseEntity.ok(audit.findByConflictRequestIdOrderByCreatedAtAsc(id));
    }

    @PostMapping("/{id}/admin-resolution") @Transactional
    public ResponseEntity<?> resolve(@PathVariable Long id,@RequestParam String emailAddress,@RequestBody Map<String,Object> body) {
        User admin=findUser(emailAddress); BookingConflictRequest c=conflicts.findById(id).orElse(null);
        if(admin==null||!"ADMIN".equalsIgnoreCase(admin.getRole())) return error(403,"Admin account required."); if(c==null) return ResponseEntity.notFound().build();
        if(!Set.of("PENDING_ADMIN_RESOLUTION","ESCALATED_TO_ADMIN").contains(c.getStatus())) return error(409,"Both required Head Staff approvals must be recorded before Admin resolution.");
        String resolution=Objects.toString(body.get("resolution"),"").toUpperCase(Locale.ROOT);
        if(!Set.of("KEEP_EXISTING","ALTERNATE_ROOM","ALTERNATE_TIME","MUTUAL_RESCHEDULE","ESCALATE").contains(resolution)) return error(400,"Unsupported resolution option.");
        String note=Objects.toString(body.get("note"),"").trim(); if(note.length()<5||note.length()>1000) return error(400,"Add an Admin note (5–1000 characters).");
        if("ESCALATE".equals(resolution)) { c.setStatus("ESCALATED_TO_ADMIN"); c.setEscalatedAt(LocalDateTime.now()); }
        else if("ALTERNATE_ROOM".equals(resolution) || "ALTERNATE_TIME".equals(resolution) || "MUTUAL_RESCHEDULE".equals(resolution)) {
            if("MUTUAL_RESCHEDULE".equals(resolution) && !(Boolean.TRUE.equals(c.getRequesterConsent()) && Boolean.TRUE.equals(c.getExistingOwnerConsent()))) return error(409,"Both faculty members must consent before mutual rescheduling.");
            Booking booking=bookings.findById(c.getExistingBookingId()).orElse(null);
            if(booking==null || !"CONFIRMED".equalsIgnoreCase(booking.getStatus())) return error(409,"Only a confirmed booking can be moved. Pending bookings must first be approved or rejected by their approver.");
            Integer roomId=c.getTargetRoomId(); String roomNo=c.getTargetRoomNo(); LocalDate date=c.getTargetDate(); LocalTime start=c.getTargetStartTime(); LocalTime finish=c.getTargetEndTime();
            if(body.containsKey("targetRoomId")) roomId=Integer.valueOf(Objects.toString(body.get("targetRoomId")));
            if(body.containsKey("targetRoomNo")) roomNo=Objects.toString(body.get("targetRoomNo"));
            if(body.containsKey("targetDate")) date=LocalDate.parse(Objects.toString(body.get("targetDate")));
            if(body.containsKey("targetStartTime")) start=LocalTime.parse(Objects.toString(body.get("targetStartTime")));
            if(body.containsKey("targetEndTime")) finish=LocalTime.parse(Objects.toString(body.get("targetEndTime")));
            if("ALTERNATE_ROOM".equals(resolution) || "MUTUAL_RESCHEDULE".equals(resolution)) {
                if(roomId==null) return error(400,"Provide targetRoomId for room rescheduling.");
                Room room=rooms.findById(roomId).orElse(null); if(room==null) return error(404,"Target room not found.");
                if(room.getStatus()!=null && ("MAINTENANCE".equalsIgnoreCase(room.getStatus()) || "UNAVAILABLE".equalsIgnoreCase(room.getStatus()))) return error(409,"Target room is not available for booking.");
                roomNo=room.getRoomNo();
            }
            if("ALTERNATE_TIME".equals(resolution)) {
                if(date==null||start==null||finish==null) return error(400,"Provide targetDate, targetStartTime and targetEndTime.");
            }
            if("MUTUAL_RESCHEDULE".equals(resolution) && (roomId==null||date==null||start==null||finish==null)) return error(400,"Mutual rescheduling requires target room, date and time.");
            if(start!=null && finish!=null && !start.isBefore(finish)) return error(400,"Target start time must be before end time.");
            Integer checkRoom=roomId==null?booking.getRoomId():roomId; LocalDate checkDate=date==null?booking.getBookingDate():date;
            LocalTime checkStart=start==null?booking.getStartTime():start; LocalTime checkEnd=finish==null?booking.getEndTime():finish;
            if(bookings.hasOverlapExcept(checkDate,checkRoom,checkStart,checkEnd,booking.getBookingId())) return error(409,"The proposed room/time is no longer available. No booking was changed.");
            booking.setRoomId(checkRoom); booking.setRoomNo(roomNo==null?booking.getRoomNo():roomNo); booking.setBookingDate(checkDate); booking.setStartTime(checkStart); booking.setEndTime(checkEnd); bookings.save(booking);
            String moved="Booking #"+booking.getBookingId()+" moved to "+booking.getRoomNo()+" on "+checkDate+" "+checkStart+"-"+checkEnd;
            note=note+" "+moved;
            record(c,identity(admin),"BOOKING_RESCHEDULED",moved);
        }
        c.setAdminResolution(resolution); c.setAdminNote(note); c.setResolvedBy(identity(admin)); if(!"ESCALATE".equals(resolution)) c.setStatus("RESOLUTION_RECORDED"); conflicts.save(c);
        record(c,identity(admin),"ADMIN_RESOLUTION",resolution+": "+note);
        String msg="Admin recorded conflict resolution: "+resolution+". "+note;
        notifyPerson(c.getRequesterEmail(),c,"Conflict review resolved",msg); notifyPerson(c.getExistingFacultyEmail(),c,"Conflict review resolved",msg);
        return ResponseEntity.ok(Map.of("success",true,"message",msg,"request",c));
    }

    private void record(BookingConflictRequest c,String actor,String action,String details){audit.save(new BookingConflictAudit(c.getId(),actor,action,details));}

    private void notifyHeads(List<User> heads,BookingConflictRequest c,String title,String message){ for(User h:heads) notifyPerson(identity(h),c,title,message); }
    private void notifyPerson(String recipient,BookingConflictRequest c,String title,String message){
        if(recipient==null||recipient.isBlank()) return; Notification n=new Notification(); n.setRecipientEmail(recipient); n.setType("BOOKING_CONFLICT"); n.setTitle(title); n.setMessage(message); n.setBookingId(c.getExistingBookingId()); notifications.save(n);
        try{push.send(recipient,title,message,Map.of("type","BOOKING_CONFLICT","conflictRequestId",String.valueOf(c.getId()),"bookingId",String.valueOf(c.getExistingBookingId())));}catch(Exception ignored){}
        realtime.publish("BOOKING_CONFLICT",message,Map.of("conflictRequestId",c.getId(),"recipient",recipient,"status",c.getStatus()));
        email.send(recipient,"GNITS Smart Campus",title,"<p>"+escape(message)+"</p>",message);
    }
    private List<User> heads(String dept){return users.findByRoleIgnoreCase("HEAD_STAFF").stream().filter(h->dept.equals(normalizeDepartment(h.getDepartment()))).toList();}
    private String roomApprovalDepartment(String roomNo){if(roomNo==null||roomNo.isBlank())return "";return switch(roomNo.trim().toUpperCase(Locale.ROOT).charAt(0)){case 'A'->"ADMIN_BLOCK";case 'B'->"EEE";case 'C'->"CSE";case 'D'->"ECE";case 'F'->"IT";case 'S'->"SILVER_JUBILEE_BLOCK";default->"";};}
    private String normalizeDepartment(String value){String v=value==null?"":value.trim().toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]","");return switch(v){case "A","ABLOCK","ADMIN","ADMINBLOCK","ADMINISTRATION","ADMINISTRATIONBLOCK"->"ADMIN_BLOCK";case "S","SBLOCK","SILVERJUBILEE","SILVERJUBILEEBLOCK"->"SILVER_JUBILEE_BLOCK";case "C","CBLOCK","COMPUTERSCIENCEANDENGINEERING","COMPUTERSCIENCEENGINEERING","CSE","CSEBLOCK"->"CSE";case "D","DBLOCK","ELECTRONICSANDCOMMUNICATIONENGINEERING","ELECTRONICSCOMMUNICATIONENGINEERING","ECE","ECEBLOCK"->"ECE";case "B","BBLOCK","ELECTRICALANDELECTRONICSENGINEERING","ELECTRICALENGINEERING","EEE","EEEBLOCK"->"EEE";case "F","FBLOCK","INFORMATIONTECHNOLOGY","IT","ITBLOCK"->"IT";default->v;};}
    private User findUser(String key){if(key==null||key.isBlank())return null;return users.findByEmail(key).orElseGet(()->users.findByUsername(key).orElse(null));}
    private String identity(User u){return u.getEmail()==null||u.getEmail().isBlank()?u.getUsername():u.getEmail();}
    private String val(Map<String,?> m,String k){return Objects.toString(m.get(k),"").trim();}
    private String norm(String s){return s==null?"":s.trim().replaceAll("\\s+"," ").toUpperCase(Locale.ROOT);}
    private String escape(String s){return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;");}
    private ResponseEntity<Map<String,Object>> error(int status,String message){return ResponseEntity.status(status).body(Map.of("success",false,"error",message));}
}
