package com.gnits.smartcampusbackend.service;

import com.gnits.smartcampusbackend.entity.Booking;
import com.gnits.smartcampusbackend.entity.Notification;
import com.gnits.smartcampusbackend.entity.User;
import com.gnits.smartcampusbackend.repository.BookingRepository;
import com.gnits.smartcampusbackend.repository.NotificationRepository;
import com.gnits.smartcampusbackend.repository.UserRepository;
import com.gnits.smartcampusbackend.realtime.RealtimeHub;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;

@Service
public class BookingReminderService {
    private static final long REMINDER_MINUTES = 30;
    private final BookingRepository bookings;
    private final UserRepository users;
    private final NotificationRepository notifications;
    private final RealtimeHub realtimeHub;
    private final PushNotificationService pushNotifications;

    public BookingReminderService(BookingRepository bookings, UserRepository users, NotificationRepository notifications, RealtimeHub realtimeHub, PushNotificationService pushNotifications) {
        this.bookings = bookings; this.users = users; this.notifications = notifications; this.realtimeHub = realtimeHub; this.pushNotifications = pushNotifications;
    }

    @Scheduled(fixedDelay = 300000)
    @Transactional
    public void sendPendingApprovalReminders() {
        LocalDateTime now = LocalDateTime.now();
        List<Booking> pending = bookings.findByStatusIgnoreCaseOrderByBookingDateAscStartTimeAsc("PENDING_APPROVAL");
        for (Booking booking : pending) {
            if (booking.getCreatedAt() == null) { booking.setCreatedAt(now); bookings.save(booking); continue; }
            long age = Duration.between(booking.getCreatedAt(), now).toMinutes();
            if (age < REMINDER_MINUTES) continue;
            if (booking.getLastReminderAt() != null && Duration.between(booking.getLastReminderAt(), now).toMinutes() < REMINDER_MINUTES) continue;

            User faculty = users.findByEmail(booking.getBookedBy()).orElseGet(() -> users.findByUsername(booking.getBookedBy()).orElse(null));
            if (faculty == null || faculty.getDepartment() == null || faculty.getDepartment().isBlank()) continue;
            String dept = normalizeDepartment(faculty.getDepartment());
            for (User head : users.findByRoleIgnoreCase("HEAD_STAFF")) {
                if (!dept.equals(normalizeDepartment(head.getDepartment()))) continue;
                String recipient = head.getEmail() == null || head.getEmail().isBlank() ? head.getUsername() : head.getEmail();
                Notification n = new Notification();
                n.setRecipientEmail(recipient);
                n.setType("BOOKING_APPROVAL_REMINDER");
                n.setTitle("Reminder: booking approval pending");
                n.setMessage("A classroom booking from " + faculty.getName() + " is still waiting for your approval: " + booking.getRoomNo() + " on " + booking.getBookingDate() + " from " + booking.getStartTime() + " to " + booking.getEndTime() + ".");
                n.setBookingId(booking.getBookingId());
                notifications.save(n);
                pushNotifications.send(recipient, n.getTitle(), n.getMessage(), java.util.Map.of("type", n.getType(), "bookingId", String.valueOf(booking.getBookingId())));
                realtimeHub.publish("BOOKING_APPROVAL_REMINDER", n.getMessage(), java.util.Map.of("bookingId", booking.getBookingId(), "recipient", recipient, "status", "PENDING_APPROVAL"));
            }
            booking.setLastReminderAt(now);
            booking.setReminderCount((booking.getReminderCount() == null ? 0 : booking.getReminderCount()) + 1);
            bookings.save(booking);
        }
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
}
