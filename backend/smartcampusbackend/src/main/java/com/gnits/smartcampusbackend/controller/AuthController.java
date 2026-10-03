package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.User;
import com.gnits.smartcampusbackend.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {
    private static final String COLLEGE_EMAIL_DOMAIN = "@gnits.ac.in";
    private final UserRepository userRepository;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public AuthController(UserRepository userRepository) {
        this.userRepository = userRepository;
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
        // Keep username equal to email for compatibility with existing booking APIs.
        user.setUsername(email);
        user.setEmail(email);
        user.setDepartment(department.isBlank() ? null : department);
        user.setPasswordHash(passwordEncoder.encode(password));
        user.setRole(role);
        userRepository.save(user);

        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Account created successfully.",
                "email", email,
                "username", email,
                "role", role
        ));
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, Object> body) {
        String email = text(body.get("email")).toLowerCase(Locale.ROOT);
        // Backward-compatible request key for older Flutter builds; the value must still be an email.
        if (email.isBlank()) email = text(body.get("username")).toLowerCase(Locale.ROOT);
        String password = text(body.get("password"));
        String requestedRole = text(body.get("role")).toUpperCase(Locale.ROOT);

        if (email.isBlank() || password.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "College email and password are required."));
        }
        if (!isCollegeEmail(email)) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Please enter your GNITS college email address ending with @gnits.ac.in."));
        }

        Optional<User> found = userRepository.findByEmail(email);
        if (found.isEmpty()) {
            // Compatibility with accounts whose username was already an email before
            // the email column was introduced.
            found = userRepository.findByUsername(email);
        }
        if (found.isEmpty() || !passwordEncoder.matches(password, found.get().getPasswordHash())) {
            return ResponseEntity.status(401).body(Map.of("success", false, "error", "Invalid college email or password."));
        }

        User user = found.get();
        // The server is authoritative for role. The old role selector remains backward-compatible,
        // but a missing role is accepted so email alone can determine the account type.
        if (!requestedRole.isBlank() && !requestedRole.equals(user.getRole().toUpperCase(Locale.ROOT))) {
            return ResponseEntity.status(403).body(Map.of("success", false, "error", "This account is registered as " + user.getRole() + ". Please select the correct role."));
        }

        // Issue a fresh session token after every successful login. It is used to bind
        // a phone's FCM token to the authenticated college account.
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
                "sessionToken", user.getSessionToken()
        ));
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@RequestBody Map<String, Object> body) {
        String email = text(body.get("email")).toLowerCase(Locale.ROOT);
        if (email.isBlank()) email = text(body.get("username")).toLowerCase(Locale.ROOT);
        String name = text(body.get("name"));
        String newPassword = text(body.get("newPassword"));

        if (email.isBlank() || name.isBlank() || newPassword.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "College email, registered full name and new password are required."));
        }
        if (!isCollegeEmail(email)) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Please use your GNITS college email address."));
        }
        if (newPassword.length() < 6) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "New password must contain at least 6 characters."));
        }

        Optional<User> found = userRepository.findByEmail(email);
        if (found.isEmpty()) found = userRepository.findByUsername(email);
        if (found.isEmpty() || !name.equalsIgnoreCase(found.get().getName())) {
            return ResponseEntity.status(404).body(Map.of("success", false, "error", "We could not verify that account. Check the college email and registered full name."));
        }

        User user = found.get();
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        return ResponseEntity.ok(Map.of("success", true, "message", "Password reset successfully. You can now sign in with your college email."));
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
        User u=new User(); u.setName(name); u.setEmail(email); u.setUsername(email); u.setDepartment(department.isBlank()?null:department); u.setPasswordHash(passwordEncoder.encode(password)); u.setRole(role); userRepository.save(u);
        return ResponseEntity.ok(Map.of("success",true,"message","User account created.","email",email,"role",role));
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

    private boolean isCollegeEmail(String email) {
        return email.matches("^[A-Za-z0-9._%+-]+@gnits\\.ac\\.in$");
    }

    private String text(Object value) {
        return value == null ? "" : String.valueOf(value).trim();
    }
}
