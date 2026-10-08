package com.gnits.smartcampusbackend.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalTime;

@Entity
@Table(name = "room_bookings")
public class Booking {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer bookingId;
    @Column(nullable=false) private Integer roomId;
    @Column(nullable=false, length=80) private String roomNo;
    @Column(nullable=false) private LocalDate bookingDate;
    @Column(nullable=false) private LocalTime startTime;
    @Column(nullable=false) private LocalTime endTime;
    @Column(nullable=false, length=200) private String purpose;
    @Column(nullable=false, length=100) private String bookedBy;
    @Column(nullable=false, length=20) private String bookedByRole;
    @Column(nullable=false, length=30) private String status = "CONFIRMED";
    @Column(name="approval_department", length=100) private String approvalDepartment;
    @Column(name="rejection_reason", length=500) private String rejectionReason;
    @Column(name="approved_by", length=150) private String approvedBy;
    @Column(name="approved_at") private java.time.LocalDateTime approvedAt;
    @Column(name="created_at") private java.time.LocalDateTime createdAt;
    @Column(name="last_reminder_at") private java.time.LocalDateTime lastReminderAt;
    @Column(name="reminder_count", nullable=false) private Integer reminderCount = 0;

    @PrePersist
    public void onCreate() {
        if (createdAt == null) createdAt = java.time.LocalDateTime.now();
        if (reminderCount == null) reminderCount = 0;
    }

    public Integer getBookingId(){return bookingId;} public void setBookingId(Integer v){bookingId=v;}
    public Integer getRoomId(){return roomId;} public void setRoomId(Integer v){roomId=v;}
    public String getRoomNo(){return roomNo;} public void setRoomNo(String v){roomNo=v;}
    public LocalDate getBookingDate(){return bookingDate;} public void setBookingDate(LocalDate v){bookingDate=v;}
    public LocalTime getStartTime(){return startTime;} public void setStartTime(LocalTime v){startTime=v;}
    public LocalTime getEndTime(){return endTime;} public void setEndTime(LocalTime v){endTime=v;}
    public String getPurpose(){return purpose;} public void setPurpose(String v){purpose=v;}
    public String getBookedBy(){return bookedBy;} public void setBookedBy(String v){bookedBy=v;}
    public String getBookedByRole(){return bookedByRole;} public void setBookedByRole(String v){bookedByRole=v;}
    public String getStatus(){return status;} public void setStatus(String v){status=v;}
    public String getApprovalDepartment(){return approvalDepartment;} public void setApprovalDepartment(String v){approvalDepartment=v;}
    public String getRejectionReason(){return rejectionReason;} public void setRejectionReason(String v){rejectionReason=v;}
    public String getApprovedBy(){return approvedBy;} public void setApprovedBy(String v){approvedBy=v;}
    public java.time.LocalDateTime getApprovedAt(){return approvedAt;} public void setApprovedAt(java.time.LocalDateTime v){approvedAt=v;}
    public java.time.LocalDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(java.time.LocalDateTime v){createdAt=v;}
    public java.time.LocalDateTime getLastReminderAt(){return lastReminderAt;} public void setLastReminderAt(java.time.LocalDateTime v){lastReminderAt=v;}
    public Integer getReminderCount(){return reminderCount;} public void setReminderCount(Integer v){reminderCount=v;}
}
