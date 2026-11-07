package com.gnits.smartcampusbackend.service;

import com.gnits.smartcampusbackend.entity.*;
import com.gnits.smartcampusbackend.repository.*;
import com.gnits.smartcampusbackend.realtime.RealtimeHub;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;

@Service
public class ConflictReviewReminderService {
    private final BookingConflictRequestRepository conflicts;
    private final BookingConflictAuditRepository audit;
    private final BookingRepository bookings;
    private final UserRepository users;
    private final NotificationRepository notifications;
    private final PushNotificationService push;
    private final TransactionalEmailService email;
    private final RealtimeHub realtime;
    public ConflictReviewReminderService(BookingConflictRequestRepository conflicts, BookingConflictAuditRepository audit,
            BookingRepository bookings, UserRepository users, NotificationRepository notifications, PushNotificationService push,
            TransactionalEmailService email, RealtimeHub realtime) {
        this.conflicts=conflicts; this.audit=audit; this.bookings=bookings; this.users=users; this.notifications=notifications;
        this.push=push; this.email=email; this.realtime=realtime;
    }

    @Scheduled(fixedDelay=300000)
    @Transactional
    public void remindAndEscalate() {
        LocalDateTime now=LocalDateTime.now();
        for(BookingConflictRequest c:conflicts.findByStatusInOrderByCreatedAtAsc(List.of("PENDING_HEAD_REVIEW","PENDING_ADMIN_RESOLUTION","ESCALATED_TO_ADMIN"))) {
            Booking booking=bookings.findById(c.getExistingBookingId()).orElse(null);
            if(booking==null || "REJECTED".equalsIgnoreCase(booking.getStatus()) || "CANCELLED".equalsIgnoreCase(booking.getStatus())) {
                c.setStatus("CLOSED_BOOKING_CANCELLED"); conflicts.save(c);
                audit.save(new BookingConflictAudit(c.getId(),"SYSTEM","CLOSED","Original booking was rejected, cancelled or deleted; conflict review closed."));
                notify(c.getRequesterEmail(),c,"Conflict review closed","The original booking is no longer active. This conflict review has been closed.");
                notify(c.getExistingFacultyEmail(),c,"Conflict review closed","The original booking is no longer active. This conflict review has been closed.");
                continue;
            }
            if("ESCALATED_TO_ADMIN".equals(c.getStatus())) continue;
            long age=Duration.between(c.getCreatedAt(),now).toMinutes();
            int sent=c.getReminderCount()==null?0:c.getReminderCount();
            if(age>=120) {
                c.setStatus("ESCALATED_TO_ADMIN"); c.setEscalatedAt(now); conflicts.save(c);
                audit.save(new BookingConflictAudit(c.getId(),"SYSTEM","AUTO_ESCALATED","Conflict review unresolved after two hours."));
                for(User admin:users.findByRoleIgnoreCase("ADMIN")) notify(identity(admin),c,"Conflict review escalated to Admin","Conflict review #"+c.getId()+" has remained unresolved for two hours and needs Admin attention.");
                notify(c.getRequesterEmail(),c,"Conflict review escalated","Your conflict review was automatically escalated to Admin after two hours.");
                notify(c.getExistingFacultyEmail(),c,"Conflict review escalated","A conflict review concerning your booking was automatically escalated to Admin.");
            } else if(age>=30 && sent==0) {
                String msg="Conflict review #"+c.getId()+" is still awaiting a decision. Please review it.";
                if("PENDING_HEAD_REVIEW".equals(c.getStatus())) {
                    for(User h:users.findByRoleIgnoreCase("HEAD_STAFF")) if(normalizeDepartment(h.getDepartment()).equals(normalizeDepartment(c.getRequesterDepartment())) || normalizeDepartment(h.getDepartment()).equals(normalizeDepartment(c.getExistingDepartment()))) notify(identity(h),c,"Reminder: conflict review pending",msg);
                } else {
                    for(User a:users.findByRoleIgnoreCase("ADMIN")) notify(identity(a),c,"Reminder: conflict review awaiting Admin",msg);
                }
                notify(c.getRequesterEmail(),c,"Conflict review reminder",msg);
                notify(c.getExistingFacultyEmail(),c,"Conflict review reminder",msg);
                c.setReminderCount(sent+1); c.setLastReminderAt(now); conflicts.save(c);
                audit.save(new BookingConflictAudit(c.getId(),"SYSTEM","REMINDER_SENT","30-minute unresolved review reminder sent."));
            }
        }
    }
    private void notify(String to,BookingConflictRequest c,String title,String message) {
        if(to==null||to.isBlank()) return;
        Notification n=new Notification(); n.setRecipientEmail(to); n.setType("BOOKING_CONFLICT_REMINDER"); n.setTitle(title); n.setMessage(message); n.setBookingId(c.getExistingBookingId()); notifications.save(n);
        try { push.send(to,title,message,Map.of("type","BOOKING_CONFLICT_REMINDER","conflictRequestId",String.valueOf(c.getId()))); } catch(Exception ignored) {}
        try { email.send(to,"GNITS Smart Campus",title,"<p>"+escape(message)+"</p>",message); } catch(Exception ignored) {}
        try { realtime.publish("BOOKING_CONFLICT_REMINDER",message,Map.of("conflictRequestId",c.getId(),"recipient",to,"status",c.getStatus())); } catch(Exception ignored) {}
    }
    private String identity(User u){return u.getEmail()==null||u.getEmail().isBlank()?u.getUsername():u.getEmail();}
    private String norm(String s){return s==null?"":s.trim().replaceAll("\\s+"," ").toUpperCase(Locale.ROOT);}
    private String normalizeDepartment(String value){
        String v=value==null?"":value.trim().toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]","");
        return switch(v){
            case "ADMIN","ADMINBLOCK","ADMINISTRATION","ADMINISTRATIONBLOCK" -> "ADMIN_BLOCK";
            case "S","SILVERJUBILEE","SILVERJUBILEEBLOCK" -> "SILVER_JUBILEE_BLOCK";
            case "COMPUTERSCIENCEANDENGINEERING","COMPUTERSCIENCEENGINEERING","CSE","CSEBLOCK" -> "CSE";
            case "ELECTRONICSANDCOMMUNICATIONENGINEERING","ELECTRONICSCOMMUNICATIONENGINEERING","ECE","ECEBLOCK" -> "ECE";
            case "ELECTRICALANDELECTRONICSENGINEERING","ELECTRICALENGINEERING","EEE","EEEBLOCK" -> "EEE";
            case "INFORMATIONTECHNOLOGY","IT","ITBLOCK" -> "IT";
            default -> v;
        };
    }
    private String escape(String s){return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;");}
}
