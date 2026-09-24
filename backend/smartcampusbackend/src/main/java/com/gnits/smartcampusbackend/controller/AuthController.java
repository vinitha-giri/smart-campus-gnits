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

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {
    private final UserRepository userRepository;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public AuthController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @PostMapping("/signup")
    public ResponseEntity<?> signup(@RequestBody Map<String, Object> body) {
        String name = text(body.get("name"));
        String username = text(body.get("username")).toLowerCase(Locale.ROOT);
        String password = text(body.get("password"));
        String role = text(body.get("role")).toUpperCase(Locale.ROOT);

        if (name.isBlank() || username.isBlank() || password.isBlank() || role.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "All fields are required."));
        }
        if (!Set.of("ADMIN", "FACULTY", "STUDENT").contains(role)) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Invalid role."));
        }
        if (!username.matches("[a-zA-Z0-9._-]{3,50}")) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Username must be 3-50 characters and use only letters, numbers, dot, underscore or hyphen."));
        }
        if (password.length() < 6) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Password must contain at least 6 characters."));
        }
        if (userRepository.existsByUsername(username)) {
            return ResponseEntity.status(409).body(Map.of("success", false, "error", "Username already exists. Please choose another username."));
        }

        User user = new User();
        user.setName(name);
        user.setUsername(username);
        user.setPasswordHash(passwordEncoder.encode(password));
        user.setRole(role);
        userRepository.save(user);

        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Account created successfully.",
                "username", username,
                "role", role
        ));
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, Object> body) {
        String username = text(body.get("username")).toLowerCase(Locale.ROOT);
        String password = text(body.get("password"));
        String requestedRole = text(body.get("role")).toUpperCase(Locale.ROOT);

        if (username.isBlank() || password.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Username and password are required."));
        }

        Optional<User> found = userRepository.findByUsername(username);
        if (found.isEmpty() || !passwordEncoder.matches(password, found.get().getPasswordHash())) {
            return ResponseEntity.status(401).body(Map.of("success", false, "error", "Invalid username or password."));
        }

        User user = found.get();
        if (!requestedRole.isBlank() && !requestedRole.equals(user.getRole().toUpperCase(Locale.ROOT))) {
            return ResponseEntity.status(403).body(Map.of("success", false, "error", "This account is registered as " + user.getRole() + ". Please select the correct role."));
        }

        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Login successful.",
                "username", user.getUsername(),
                "name", user.getName(),
                "role", user.getRole().toUpperCase(Locale.ROOT)
        ));
    }

    /**
     * Simple account-recovery flow for this academic/demo application.
     * The current users table has no email/OTP field, so the registered full
     * name is used as the second verification value. A production deployment
     * should replace this with an email/OTP or verified reset-token flow.
     */
    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@RequestBody Map<String, Object> body) {
        String username = text(body.get("username")).toLowerCase(Locale.ROOT);
        String name = text(body.get("name"));
        String newPassword = text(body.get("newPassword"));

        if (username.isBlank() || name.isBlank() || newPassword.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Username, registered full name and new password are required."));
        }
        if (newPassword.length() < 6) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "New password must contain at least 6 characters."));
        }

        Optional<User> found = userRepository.findByUsername(username);
        if (found.isEmpty() || !name.equalsIgnoreCase(found.get().getName())) {
            return ResponseEntity.status(404).body(Map.of("success", false, "error", "We could not verify that account. Check the username and registered full name."));
        }

        User user = found.get();
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        return ResponseEntity.ok(Map.of("success", true, "message", "Password reset successfully. You can now sign in with the new password."));
    }

    @GetMapping("/users")
    public ResponseEntity<?> users(@RequestParam String requesterUsername) {
        Optional<User> requester = userRepository.findByUsername(requesterUsername.toLowerCase(Locale.ROOT));
        if (requester.isEmpty() || !"ADMIN".equalsIgnoreCase(requester.get().getRole())) {
            return ResponseEntity.status(403).body(Map.of("success", false, "error", "Administrator access is required."));
        }

        List<Map<String, Object>> safeUsers = new ArrayList<>();
        for (User user : userRepository.findAll()) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", user.getId());
            item.put("name", user.getName());
            item.put("username", user.getUsername());
            item.put("role", user.getRole());
            item.put("createdAt", user.getCreatedAt() == null ? null : user.getCreatedAt().toString());
            safeUsers.add(item);
        }
        return ResponseEntity.ok(Map.of("success", true, "users", safeUsers));
    }

    @DeleteMapping("/users/{username}")
    public ResponseEntity<?> deleteUser(@PathVariable String username, @RequestParam String requesterUsername) {
        Optional<User> requester = userRepository.findByUsername(requesterUsername.toLowerCase(Locale.ROOT));
        if (requester.isEmpty() || !"ADMIN".equalsIgnoreCase(requester.get().getRole())) {
            return ResponseEntity.status(403).body(Map.of("success", false, "error", "Administrator access is required."));
        }

        String targetUsername = username.trim().toLowerCase(Locale.ROOT);
        if (targetUsername.equals(requester.get().getUsername().toLowerCase(Locale.ROOT))) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "You cannot delete the administrator account you are currently using."));
        }

        Optional<User> target = userRepository.findByUsername(targetUsername);
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

    private String text(Object value) {
        return value == null ? "" : String.valueOf(value).trim();
    }
}
