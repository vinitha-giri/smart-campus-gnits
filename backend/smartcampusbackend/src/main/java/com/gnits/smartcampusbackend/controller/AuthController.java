package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.EmailToken;
import com.gnits.smartcampusbackend.entity.User;
import com.gnits.smartcampusbackend.repository.EmailTokenRepository;
import com.gnits.smartcampusbackend.repository.UserRepository;
import com.gnits.smartcampusbackend.service.TransactionalEmailService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {
    private static final String COLLEGE_EMAIL_DOMAIN = "@gnits.ac.in";
    private static final String VERIFY = "VERIFY_EMAIL";
    private static final String RESET = "RESET_PASSWORD";
    private final UserRepository userRepository;
    private final EmailTokenRepository tokenRepository;
    private final TransactionalEmailService emailService;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    private final ConcurrentHashMap<String, Deque<Long>> rateWindow = new ConcurrentHashMap<>();

    public AuthController(UserRepository userRepository, EmailTokenRepository tokenRepository,
                          TransactionalEmailService emailService) {
        this.userRepository = userRepository;
        this.tokenRepository = tokenRepository;
        this.emailService = emailService;
    }

    @PostMapping("/signup")
    public ResponseEntity<?> signup(@RequestBody Map<String, Object> body) {
        String name = text(body.get("name"));
        String email = text(body.get("email")).toLowerCase(Locale.ROOT);
        String password = text(body.get("password"));
        String role = text(body.get("role")).toUpperCase(Locale.ROOT);
        String department = text(body.get("department"));

        if (name.isBlank() || email.isBlank() || password.isBlank() || role.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Full name, college email, password and role are required."));
        }
        if (!isCollegeEmail(email)) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Please use your GNITS college email address ending with @gnits.ac.in."));
        }
        if (!allow(email, "signup", 5, 15)) {
            return ResponseEntity.status(429).body(Map.of("success", false, "error", "Too many signup attempts. Please try again later."));
        }
        if (!Set.of("ADMIN", "FACULTY", "STUDENT").contains(role)) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "This role cannot be self-registered. Head Staff accounts are created by the administrator."));
        }
        if ("FACULTY".equals(role) && department.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Department is required for faculty accounts."));
        }
        if (password.length() < 6) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Password must contain at least 6 characters."));
        }
        if (userRepository.existsByEmail(email) || userRepository.existsByUsername(email)) {
            return ResponseEntity.status(409).body(Map.of("success", false, "error", "This college email is already registered. Please sign in instead."));
        }

        User user = new User();
        user.setName(name);
        user.setUsername(email);
        user.setEmail(email);
        user.setDepartment(department.isBlank() ? null : department);
        user.setPasswordHash(passwordEncoder.encode(password));
        user.setRole(role);
        user.setEmailVerified(false);
        userRepository.save(user);

        issueVerification(user);

        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Account created. Please verify your college email before signing in.",
                "email", email,
                "username", email,
                "role", role,
                "emailVerified", false
        ));
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, Object> body) {
        String email = text(body.get("email")).toLowerCase(Locale.ROOT);
        if (email.isBlank()) email = text(body.get("username")).toLowerCase(Locale.ROOT);
        String password = text(body.get("password"));
        String requestedRole = text(body.get("role")).toUpperCase(Locale.ROOT);

        if (email.isBlank() || password.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "College email and password are required."));
        }
        if (!isCollegeEmail(email)) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Please enter your GNITS college email address ending with @gnits.ac.in."));
        }
        if (!allow(email, "login", 10, 15)) {
            return ResponseEntity.status(429).body(Map.of("success", false, "error", "Too many login attempts. Please wait a few minutes and try again."));
        }

        Optional<User> found = userRepository.findByEmail(email);
        if (found.isEmpty()) found = userRepository.findByUsername(email);
        if (found.isEmpty() || !passwordEncoder.matches(password, found.get().getPasswordHash())) {
            return ResponseEntity.status(401).body(Map.of("success", false, "error", "Invalid college email or password."));
        }

        User user = found.get();
        if (Boolean.FALSE.equals(user.getEmailVerified())) {
            return ResponseEntity.status(403).body(Map.of(
                    "success", false,
                    "error", "Please verify your GNITS college email before signing in.",
                    "emailVerificationRequired", true,
                    "email", user.getEmail() == null ? user.getUsername() : user.getEmail()
            ));
        }

        if (!requestedRole.isBlank() && !requestedRole.equals(user.getRole().toUpperCase(Locale.ROOT))) {
            return ResponseEntity.status(403).body(Map.of("success", false, "error", "This account is registered as " + user.getRole() + ". Please select the correct role."));
        }

        user.setSessionToken(UUID.randomUUID().toString());
        userRepository.save(user);

        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Login successful.",
                "email", user.getEmail() == null ? user.getUsername() : user.getEmail(),
                "username", user.getUsername(),
                "name", user.getName(),
                "department", user.getDepartment() == null ? "" : user.getDepartment(),
                "role", user.getRole().toUpperCase(Locale.ROOT),
                "sessionToken", user.getSessionToken(),
                "emailVerified", true
        ));
    }

    @PostMapping("/resend-verification")
    public ResponseEntity<?> resendVerification(@RequestBody Map<String, Object> body) {
        String email = text(body.get("email")).toLowerCase(Locale.ROOT);
        if (!isCollegeEmail(email)) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Please enter your GNITS college email address."));
        }
        if (!allow(email, "verify", 3, 15)) {
            return ResponseEntity.status(429).body(Map.of("success", false, "error", "Too many verification emails requested. Please wait and try again."));
        }
        final String lookupEmail = email;
         User user = userRepository.findByEmail(lookupEmail).orElseGet(() -> userRepository.findByUsername(lookupEmail).orElse(null));
        // Do not reveal whether an email is registered.
        if (user == null || !Boolean.FALSE.equals(user.getEmailVerified())) {
            return ResponseEntity.ok(Map.of("success", true, "message", "If that college account exists and still needs verification, a verification email has been sent."));
        }
        issueVerification(user);
        return ResponseEntity.ok(Map.of("success", true, "message", "A new verification email has been sent."));
    }

    @GetMapping("/verify-email")
    public ResponseEntity<String> verifyEmail(@RequestParam String token) {
        EmailToken record = findToken(token, VERIFY);
        if (record == null || record.getExpiresAt().isBefore(LocalDateTime.now()) || record.getUsedAt() != null) {
            return ResponseEntity.ok(htmlPage("Verification link expired", "<p>This verification link is invalid, expired, or already used.</p><p>Please return to Smart Campus and request a new verification email.</p>"));
        }

        User user = userRepository.findById(record.getUserId()).orElse(null);
        if (user == null) {
            return ResponseEntity.ok(htmlPage("Account not found", "<p>The account associated with this verification link no longer exists.</p>"));
        }

        user.setEmailVerified(true);
        userRepository.save(user);
        record.setUsedAt(LocalDateTime.now());
        tokenRepository.save(record);
        return ResponseEntity.ok(htmlPage("Email verified successfully", "<p>Your GNITS Smart Campus college email is now verified.</p><p>You can return to the Smart Campus app and sign in.</p>"));
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@RequestBody Map<String, Object> body) {
        String email = text(body.get("email")).toLowerCase(Locale.ROOT);
        if (email.isBlank()) email = text(body.get("username")).toLowerCase(Locale.ROOT);
        if (!isCollegeEmail(email)) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Please use your GNITS college email address."));
        }
        if (!allow(email, "reset", 3, 30)) {
            return ResponseEntity.status(429).body(Map.of("success", false, "error", "Too many password-reset requests. Please try again later."));
        }

        final String lookupEmail = email;
         User user = userRepository.findByEmail(lookupEmail).orElseGet(() -> userRepository.findByUsername(lookupEmail).orElse(null));
        // Do not disclose whether the account exists.
        if (user != null) {
            issuePasswordReset(user);
        }
        return ResponseEntity.ok(Map.of("success", true, "message", "If a GNITS account exists for that email, a password-reset link has been sent."));
    }

    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@RequestBody Map<String, Object> body) {
        String token = text(body.get("token"));
        String newPassword = text(body.get("newPassword"));
        if (token.isBlank() || newPassword.length() < 6) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "A valid reset token and a password of at least 6 characters are required."));
        }

        EmailToken record = findToken(token, RESET);
        if (record == null || record.getExpiresAt().isBefore(LocalDateTime.now()) || record.getUsedAt() != null) {
            return ResponseEntity.status(400).body(Map.of("success", false, "error", "This password-reset link is invalid, expired, or already used."));
        }
        User user = userRepository.findById(record.getUserId()).orElse(null);
        if (user == null) return ResponseEntity.status(404).body(Map.of("success", false, "error", "Account not found."));

        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.setSessionToken(null);
        userRepository.save(user);
        record.setUsedAt(LocalDateTime.now());
        tokenRepository.save(record);
        return ResponseEntity.ok(Map.of("success", true, "message", "Password reset successfully. You can now sign in with your college email."));
    }

    @GetMapping("/reset-password")
    public ResponseEntity<String> resetPasswordPage(@RequestParam String token) {
        EmailToken record = findToken(token, RESET);
        if (record == null || record.getExpiresAt().isBefore(LocalDateTime.now()) || record.getUsedAt() != null) {
            return ResponseEntity.ok(htmlPage("Reset link expired", "<p>This password-reset link is invalid, expired, or already used.</p><p>Please request a new reset email from Smart Campus.</p>"));
        }
        String safe = escapeHtml(token);
        String form = "<form method='post' action='/api/auth/reset-password' style='display:grid;gap:12px'>"
                + "<input type='hidden' name='token' value='" + safe + "'/>"
                + "<input type='password' name='newPassword' minlength='6' required placeholder='New password' style='padding:12px;border:1px solid #ddd;border-radius:8px'/>"
                + "<button type='submit' style='padding:12px;border:0;border-radius:8px;background:#4f46e5;color:#fff;font-weight:700'>Reset password</button></form>";
        return ResponseEntity.ok(htmlPage("Reset your password", "<p>Choose a new Smart Campus password.</p>" + form));
    }

    @PostMapping(value = "/reset-password", consumes = "application/x-www-form-urlencoded")
    public ResponseEntity<String> resetPasswordForm(@RequestParam String token, @RequestParam String newPassword) {
        Map<String,Object> body = Map.of("token", token, "newPassword", newPassword);
        ResponseEntity<?> result = resetPassword(body);
        if (result.getStatusCode().is2xxSuccessful()) {
            return ResponseEntity.ok(htmlPage("Password reset successful", "<p>Your password has been changed successfully.</p><p>You can return to the Smart Campus app and sign in.</p>"));
        }
        Object value = result.getBody();
        String message = value instanceof Map<?,?> map && map.get("error") != null ? String.valueOf(map.get("error")) : "Password reset failed.";
        return ResponseEntity.ok(htmlPage("Password reset failed", "<p>" + escapeHtml(message) + "</p>"));
    }

    @GetMapping("/users")
    public ResponseEntity<?> users(@RequestParam String requesterUsername) {
        Optional<User> requester = userRepository.findByUsername(requesterUsername.toLowerCase(Locale.ROOT));
        if (requester.isEmpty()) requester = userRepository.findByEmail(requesterUsername.toLowerCase(Locale.ROOT));
        if (requester.isEmpty() || !"ADMIN".equalsIgnoreCase(requester.get().getRole())) {
            return ResponseEntity.status(403).body(Map.of("success", false, "error", "Administrator access is required."));
        }

        List<Map<String, Object>> safeUsers = new ArrayList<>();
        for (User user : userRepository.findAll()) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", user.getId());
            item.put("name", user.getName());
            item.put("email", user.getEmail() == null ? user.getUsername() : user.getEmail());
            item.put("username", user.getUsername());
            item.put("department", user.getDepartment() == null ? "" : user.getDepartment());
            item.put("role", user.getRole());
            item.put("emailVerified", !Boolean.FALSE.equals(user.getEmailVerified()));
            item.put("createdAt", user.getCreatedAt() == null ? null : user.getCreatedAt().toString());
            safeUsers.add(item);
        }
        return ResponseEntity.ok(Map.of("success", true, "users", safeUsers));
    }

    @PostMapping("/users")
    public ResponseEntity<?> createManagedUser(@RequestBody Map<String,Object> body) {
        String requester=text(body.get("requesterUsername")).toLowerCase(Locale.ROOT);
        Optional<User> admin=userRepository.findByUsername(requester); if(admin.isEmpty()) admin=userRepository.findByEmail(requester);
        if(admin.isEmpty() || !"ADMIN".equalsIgnoreCase(admin.get().getRole())) return ResponseEntity.status(403).body(Map.of("success",false,"error","Administrator access is required."));
        String name=text(body.get("name")), email=text(body.get("email")).toLowerCase(Locale.ROOT), password=text(body.get("password")), role=text(body.get("role")).toUpperCase(Locale.ROOT), department=text(body.get("department"));
        if(name.isBlank()||email.isBlank()||password.isBlank()||role.isBlank()) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Name, college email, password and role are required."));
        if(!isCollegeEmail(email)) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Use a @gnits.ac.in college email."));
        if(!Set.of("ADMIN","FACULTY","STUDENT","HEAD_STAFF").contains(role)) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Invalid role."));
        if("FACULTY".equals(role)||"HEAD_STAFF".equals(role)) { if(department.isBlank()) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Department is required.")); }
        if(password.length()<6) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Password must contain at least 6 characters."));
        if(userRepository.existsByEmail(email)||userRepository.existsByUsername(email)) return ResponseEntity.status(409).body(Map.of("success",false,"error","This college email is already registered."));
        User u=new User(); u.setName(name); u.setEmail(email); u.setUsername(email); u.setDepartment(department.isBlank()?null:department); u.setPasswordHash(passwordEncoder.encode(password)); u.setRole(role);
        // Accounts explicitly created by an authenticated administrator are trusted setup accounts.
        u.setEmailVerified(true);
        userRepository.save(u);
        return ResponseEntity.ok(Map.of("success",true,"message","User account created.","email",email,"role",role,"emailVerified",true));
    }

    @DeleteMapping("/users/{username}")
    public ResponseEntity<?> deleteUser(@PathVariable String username, @RequestParam String requesterUsername) {
        Optional<User> requester = userRepository.findByUsername(requesterUsername.toLowerCase(Locale.ROOT));
        if (requester.isEmpty()) requester = userRepository.findByEmail(requesterUsername.toLowerCase(Locale.ROOT));
        if (requester.isEmpty() || !"ADMIN".equalsIgnoreCase(requester.get().getRole())) {
            return ResponseEntity.status(403).body(Map.of("success", false, "error", "Administrator access is required."));
        }

        String targetUsername = username.trim().toLowerCase(Locale.ROOT);
        String requesterIdentity = requester.get().getUsername().toLowerCase(Locale.ROOT);
        if (targetUsername.equals(requesterIdentity)) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "You cannot delete the administrator account you are currently using."));
        }

        Optional<User> target = userRepository.findByUsername(targetUsername);
        if (target.isEmpty()) target = userRepository.findByEmail(targetUsername);
        if (target.isEmpty()) {
            return ResponseEntity.status(404).body(Map.of("success", false, "error", "User account not found."));
        }

        if ("ADMIN".equalsIgnoreCase(target.get().getRole())) {
            long adminCount = userRepository.findAll().stream().filter(u -> "ADMIN".equalsIgnoreCase(u.getRole())).count();
            if (adminCount <= 1) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "error", "The last administrator account cannot be deleted."));
            }
        }

        userRepository.delete(target.get());
        return ResponseEntity.ok(Map.of("success", true, "message", "User account deleted successfully.", "username", targetUsername));
    }

    private void issueVerification(User user) {
        String raw = UUID.randomUUID().toString() + UUID.randomUUID();
        EmailToken token = new EmailToken();
        token.setUserId(user.getId());
        token.setTokenHash(hash(raw));
        token.setPurpose(VERIFY);
        token.setExpiresAt(LocalDateTime.now().plusHours(24));
        tokenRepository.save(token);
        emailService.sendVerification(user.getEmail(), user.getName(), baseUrl() + "/api/auth/verify-email?token=" + URLEncoder.encode(raw, StandardCharsets.UTF_8));
    }

    private void issuePasswordReset(User user) {
        String raw = UUID.randomUUID().toString() + UUID.randomUUID();
        EmailToken token = new EmailToken();
        token.setUserId(user.getId());
        token.setTokenHash(hash(raw));
        token.setPurpose(RESET);
        token.setExpiresAt(LocalDateTime.now().plusMinutes(30));
        tokenRepository.save(token);
        emailService.sendPasswordReset(user.getEmail(), user.getName(), baseUrl() + "/api/auth/reset-password?token=" + URLEncoder.encode(raw, StandardCharsets.UTF_8));
    }

    private EmailToken findToken(String raw, String purpose) {
        if (raw == null || raw.isBlank()) return null;
        return tokenRepository.findByTokenHashAndPurpose(hash(raw), purpose).orElse(null);
    }

    private String baseUrl() {
        String configured = System.getenv("APP_BASE_URL");
        if (configured != null && !configured.isBlank()) return configured.trim().replaceAll("/+$", "");
        return "http://localhost:" + System.getenv().getOrDefault("PORT", "8080");
    }

    private boolean allow(String email, String action, int max, int minutes) {
        String key = action + ":" + email;
        long now = System.currentTimeMillis();
        long window = minutes * 60_000L;
        Deque<Long> q = rateWindow.computeIfAbsent(key, ignored -> new ArrayDeque<>());
        synchronized (q) {
            while (!q.isEmpty() && now - q.peekFirst() > window) q.removeFirst();
            if (q.size() >= max) return false;
            q.addLast(now);
            return true;
        }
    }

    private String hash(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder out = new StringBuilder(64);
            for (byte b : digest) out.append(String.format("%02x", b));
            return out.toString();
        } catch (Exception e) {
            throw new IllegalStateException("Unable to secure email token.", e);
        }
    }

    private String htmlPage(String title, String body) {
        return "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'></head>"
                + "<body style='font-family:Arial,sans-serif;background:#f5f7fc;color:#172033;padding:24px'>"
                + "<main style='max-width:620px;margin:8vh auto;background:#fff;padding:30px;border-radius:18px;box-shadow:0 12px 40px #0b153322'>"
                + "<h2>" + escapeHtml(title) + "</h2>" + body + "<p style='color:#6b7280;font-size:12px'>GNITS Smart Campus</p></main></body></html>";
    }

    private String escapeHtml(String value) {
        if (value == null) return "";
        return value.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;").replace("'","&#39;");
    }

    private boolean isCollegeEmail(String email) {
        return email.matches("^[A-Za-z0-9._%+-]+@gnits\\.ac\\.in$");
    }

    private String text(Object value) {
        return value == null ? "" : String.valueOf(value).trim();
    }
}
