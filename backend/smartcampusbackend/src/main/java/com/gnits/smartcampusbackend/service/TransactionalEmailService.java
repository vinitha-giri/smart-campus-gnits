package com.gnits.smartcampusbackend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.scheduling.annotation.Async;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

/**
 * Production transactional-email bridge.
 *
 * The provider API key is server-side only. Email delivery never blocks a
 * successful booking: provider failures are logged and the in-app/FCM
 * notification path continues to work.
 */
@Service
public class TransactionalEmailService {
    private static final Logger log = LoggerFactory.getLogger(TransactionalEmailService.class);
    private final ObjectMapper mapper = new ObjectMapper();
    private final HttpClient http = HttpClient.newBuilder().build();

    public boolean enabled() {
        return value("BREVO_API_KEY") != null
                && value("MAIL_FROM_EMAIL") != null
                && value("MAIL_FROM_NAME") != null;
    }

    public boolean send(String to, String recipientName, String subject, String html, String text) {
        if (to == null || to.isBlank()) return false;
        String apiKey = value("BREVO_API_KEY");
        String fromEmail = value("MAIL_FROM_EMAIL");
        String fromName = value("MAIL_FROM_NAME");
        if (apiKey == null || fromEmail == null || fromName == null) {
            log.warn("Transactional email is not configured. Set BREVO_API_KEY, MAIL_FROM_EMAIL and MAIL_FROM_NAME.");
            return false;
        }

        try {
            Map<String, Object> payload = Map.of(
                    "sender", Map.of("name", fromName, "email", fromEmail),
                    "to", List.of(Map.of("email", to.trim(), "name", recipientName == null ? "" : recipientName.trim())),
                    "subject", subject,
                    "htmlContent", html,
                    "textContent", text
            );
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.brevo.com/v3/smtp/email"))
                    .header("accept", "application/json")
                    .header("api-key", apiKey)
                    .header("content-type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(payload), StandardCharsets.UTF_8))
                    .build();

            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() >= 200 && response.statusCode() < 300) return true;

            log.warn("Transactional email provider returned HTTP {}: {}", response.statusCode(), response.body());
        } catch (Exception e) {
            log.warn("Transactional email delivery failed: {}", e.getMessage());
        }
        return false;
    }

    @Async("emailExecutor")
    public void sendVerification(String email, String name, String link) {
        String safeName = esc(name);
        String html = page(
                "Verify your GNITS Smart Campus account",
                "<p>Hello " + safeName + ",</p>"
                        + "<p>Your GNITS Smart Campus account was created. Please verify that you own this college email address before signing in.</p>"
                        + button(link, "Verify my email")
                        + "<p>This verification link expires in 24 hours and can be used only once.</p>"
                        + "<p>If you did not create this account, you can safely ignore this email.</p>");
        send(email, name, "Verify your GNITS Smart Campus email", html,
                "Verify your GNITS Smart Campus email: " + link);
    }

    @Async("emailExecutor")
    public void sendPasswordReset(String email, String name, String link) {
        String html = page(
                "Reset your GNITS Smart Campus password",
                "<p>Hello " + esc(name) + ",</p>"
                        + "<p>We received a request to reset your Smart Campus password.</p>"
                        + button(link, "Reset password")
                        + "<p>This link expires in 30 minutes and can be used only once.</p>"
                        + "<p>If you did not request this, ignore this email.</p>");
        send(email, name, "Reset your GNITS Smart Campus password", html,
                "Reset your Smart Campus password: " + link);
    }

    @Async("emailExecutor")
    public void sendBookingRequest(String email, String name, String facultyName, String room,
                                   String date, String start, String end) {
        String body = "<p>A new classroom booking request requires your approval.</p>"
                + details(facultyName, room, date, start, end, null);
        send(email, name, "GNITS Smart Campus: booking approval required",
                page("Booking approval required", "<p>Hello " + esc(name) + ",</p>" + body
                        + "<p>Please open Smart Campus to approve or reject the request.</p>"),
                "A booking approval is pending from " + facultyName + " for " + room + " on " + date + " from " + start + " to " + end + ".");
    }

    @Async("emailExecutor")
    public void sendBookingSubmitted(String email, String name, String room, String date, String start, String end) {
        send(email, name, "GNITS Smart Campus: booking request submitted",
                page("Booking request submitted", "<p>Hello " + esc(name) + ",</p>"
                        + "<p>Your classroom booking request has been sent to the concerned Head Staff.</p>"
                        + details(null, room, date, start, end, null)),
                "Your booking request for " + room + " on " + date + " from " + start + " to " + end + " is pending Head Staff approval.");
    }

    @Async("emailExecutor")
    public void sendBookingDecision(String email, String name, boolean approved, String room,
                                    String date, String start, String end, String reason) {
        String title = approved ? "Booking approved" : "Booking rejected";
        String extra = approved
                ? "<p>Your classroom booking has been approved.</p>"
                : "<p>Your classroom booking was rejected.</p><p><b>Reason:</b> " + esc(reason) + "</p>";
        send(email, name, "GNITS Smart Campus: " + title,
                page(title, "<p>Hello " + esc(name) + ",</p>" + extra + details(null, room, date, start, end, null)),
                title + ": " + room + " on " + date + " from " + start + " to " + end + (approved ? "." : ". Reason: " + reason));
    }

    @Async("emailExecutor")
    public void sendBookingReminder(String email, String name, String facultyName, String room,
                                     String date, String start, String end) {
        send(email, name, "GNITS Smart Campus: booking approval reminder",
                page("Booking approval reminder", "<p>Hello " + esc(name) + ",</p>"
                        + "<p>The following faculty booking is still waiting for your approval:</p>"
                        + details(facultyName, room, date, start, end, null)),
                "Reminder: booking from " + facultyName + " for " + room + " on " + date + " from " + start + " to " + end + " is still pending.");
    }

    @Async("emailExecutor")
    public void sendAdminBookingConfirmation(String email, String name, String room,
                                              String date, String start, String end) {
        send(email, name, "GNITS Smart Campus: booking confirmed",
                page("Booking confirmed", "<p>Hello " + esc(name) + ",</p>"
                        + "<p>Your classroom booking has been confirmed.</p>"
                        + details(null, room, date, start, end, null)),
                "Your booking for " + room + " on " + date + " from " + start + " to " + end + " is confirmed.");
    }

    private String details(String person, String room, String date, String start, String end, String unused) {
        StringBuilder b = new StringBuilder("<div style='padding:14px;background:#f5f7fc;border-radius:10px'>");
        if (person != null && !person.isBlank()) b.append("<p><b>Faculty:</b> ").append(esc(person)).append("</p>");
        b.append("<p><b>Room:</b> ").append(esc(room)).append("</p>")
                .append("<p><b>Date:</b> ").append(esc(date)).append("</p>")
                .append("<p><b>Time:</b> ").append(esc(start)).append(" – ").append(esc(end)).append("</p></div>");
        return b.toString();
    }

    private String page(String title, String body) {
        return "<!doctype html><html><body style='font-family:Arial,sans-serif;color:#172033;line-height:1.6'>"
                + "<div style='max-width:620px;margin:24px auto;padding:28px;border:1px solid #e5e7eb;border-radius:18px'>"
                + "<h2 style='margin-top:0'>" + esc(title) + "</h2>" + body
                + "<p style='color:#6b7280;font-size:12px'>GNITS Smart Campus</p></div></body></html>";
    }

    private String button(String link, String label) {
        return "<p><a href='" + esc(link) + "' style='display:inline-block;padding:12px 18px;background:#4f46e5;color:#fff;text-decoration:none;border-radius:9px;font-weight:bold'>" + esc(label) + "</a></p>";
    }

    private String esc(String value) {
        if (value == null) return "";
        return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }

    private String value(String key) {
        String v = System.getenv(key);
        return v == null || v.isBlank() ? null : v.trim();
    }
}
