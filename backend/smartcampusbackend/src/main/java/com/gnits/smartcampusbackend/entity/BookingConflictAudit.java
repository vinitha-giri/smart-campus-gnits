package com.gnits.smartcampusbackend.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "booking_conflict_audit")
public class BookingConflictAudit {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(nullable=false) private Long conflictRequestId;
    @Column(nullable=false, length=150) private String actor;
    @Column(nullable=false, length=40) private String action;
    @Column(length=2000) private String details;
    @Column(nullable=false) private LocalDateTime createdAt = LocalDateTime.now();
    protected BookingConflictAudit() {}
    public BookingConflictAudit(Long requestId, String actor, String action, String details) {
        this.conflictRequestId=requestId; this.actor=actor; this.action=action; this.details=details;
    }
    public Long getId(){return id;} public Long getConflictRequestId(){return conflictRequestId;}
    public String getActor(){return actor;} public String getAction(){return action;}
    public String getDetails(){return details;} public LocalDateTime getCreatedAt(){return createdAt;}
}
