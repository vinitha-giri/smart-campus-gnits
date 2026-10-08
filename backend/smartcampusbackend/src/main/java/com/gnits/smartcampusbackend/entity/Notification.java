package com.gnits.smartcampusbackend.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "notifications")
public class Notification {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name="recipient_email", nullable=false, length=150) private String recipientEmail;
    @Column(nullable=false, length=40) private String type;
    @Column(nullable=false, length=160) private String title;
    @Column(nullable=false, length=1000) private String message;
    @Column(name="booking_id") private Integer bookingId;
    @Column(name="is_read", nullable=false) private boolean read = false;
    @Column(name="created_at", nullable=false) private LocalDateTime createdAt = LocalDateTime.now();
    @Column(name="read_at") private LocalDateTime readAt;
    public Long getId(){return id;}
    public String getRecipientEmail(){return recipientEmail;} public void setRecipientEmail(String v){recipientEmail=v;}
    public String getType(){return type;} public void setType(String v){type=v;}
    public String getTitle(){return title;} public void setTitle(String v){title=v;}
    public String getMessage(){return message;} public void setMessage(String v){message=v;}
    public Integer getBookingId(){return bookingId;} public void setBookingId(Integer v){bookingId=v;}
    public boolean isRead(){return read;} public void setRead(boolean v){read=v;}
    public LocalDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(LocalDateTime v){createdAt=v;}
    public LocalDateTime getReadAt(){return readAt;} public void setReadAt(LocalDateTime v){readAt=v;}
}
