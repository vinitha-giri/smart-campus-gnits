package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.Notification;
import com.gnits.smartcampusbackend.repository.NotificationRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
@CrossOrigin(origins = "*")
public class NotificationController {
    private final NotificationRepository repository;
    public NotificationController(NotificationRepository repository){this.repository=repository;}

    @GetMapping
    public ResponseEntity<?> list(@RequestParam String email){
        return ResponseEntity.ok(Map.of("notifications", repository.findTop50ByRecipientEmailIgnoreCaseOrderByCreatedAtDesc(email.trim()), "unreadCount", repository.countByRecipientEmailIgnoreCaseAndReadFalse(email.trim())));
    }

    @PostMapping("/{id}/read") @Transactional
    public ResponseEntity<?> markRead(@PathVariable Long id, @RequestParam String email){
        Notification n=repository.findById(id).orElse(null);
        if(n==null) return ResponseEntity.notFound().build();
        if(!n.getRecipientEmail().equalsIgnoreCase(email.trim())) return ResponseEntity.status(403).body(Map.of("success",false,"error","Not allowed."));
        n.setRead(true); n.setReadAt(LocalDateTime.now()); repository.save(n);
        return ResponseEntity.ok(Map.of("success",true));
    }
}
