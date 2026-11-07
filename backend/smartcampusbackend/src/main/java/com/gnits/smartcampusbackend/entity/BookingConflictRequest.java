package com.gnits.smartcampusbackend.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

/** Separate review record: it never reserves a room or edits the original booking. */
@Entity
@Table(name = "booking_conflict_requests")
public class BookingConflictRequest {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable=false) private Integer existingBookingId;
    @Column(nullable=false) private Integer roomId;
    @Column(nullable=false, length=80) private String roomNo;
    @Column(nullable=false) private LocalDate bookingDate;
    @Column(nullable=false) private LocalTime startTime;
    @Column(nullable=false) private LocalTime endTime;
    @Column(nullable=false, length=150) private String requesterEmail;
    @Column(nullable=false, length=150) private String existingFacultyEmail;
    @Column(nullable=false, length=100) private String requesterDepartment;
    @Column(nullable=false, length=100) private String existingDepartment;
    @Column(nullable=false, length=2) private String requestedPriority;
    @Column(nullable=false, length=1000) private String justification;
    @Column(nullable=false, length=40) private String status = "PENDING_HEAD_REVIEW";
    @Column(length=20) private String requesterHeadDecision;
    @Column(length=150) private String requesterHeadEmail;
    @Column(length=20) private String existingHeadDecision;
    @Column(length=150) private String existingHeadEmail;
    @Column(length=40) private String adminResolution;
    @Column(length=1000) private String adminNote;
    @Column(length=150) private String resolvedBy;
    @Column(length=2) private String verifiedPriority;
    @Column(length=150) private String priorityVerifiedBy;
    private LocalDateTime priorityVerifiedAt;
    private LocalDateTime lastReminderAt;
    private Integer reminderCount = 0;
    private LocalDateTime escalatedAt;
    private Boolean requesterConsent = false;
    private Boolean existingOwnerConsent = false;
    private Integer targetRoomId;
    @Column(length=80) private String targetRoomNo;
    private LocalDate targetDate;
    private LocalTime targetStartTime;
    private LocalTime targetEndTime;
    @Column(nullable=false) private LocalDateTime createdAt = LocalDateTime.now();
    private LocalDateTime updatedAt = LocalDateTime.now();

    @PreUpdate public void touch(){ updatedAt=LocalDateTime.now(); }
    public Long getId(){return id;} public Integer getExistingBookingId(){return existingBookingId;} public void setExistingBookingId(Integer v){existingBookingId=v;}
    public Integer getRoomId(){return roomId;} public void setRoomId(Integer v){roomId=v;} public String getRoomNo(){return roomNo;} public void setRoomNo(String v){roomNo=v;}
    public LocalDate getBookingDate(){return bookingDate;} public void setBookingDate(LocalDate v){bookingDate=v;} public LocalTime getStartTime(){return startTime;} public void setStartTime(LocalTime v){startTime=v;} public LocalTime getEndTime(){return endTime;} public void setEndTime(LocalTime v){endTime=v;}
    public String getRequesterEmail(){return requesterEmail;} public void setRequesterEmail(String v){requesterEmail=v;} public String getExistingFacultyEmail(){return existingFacultyEmail;} public void setExistingFacultyEmail(String v){existingFacultyEmail=v;}
    public String getRequesterDepartment(){return requesterDepartment;} public void setRequesterDepartment(String v){requesterDepartment=v;} public String getExistingDepartment(){return existingDepartment;} public void setExistingDepartment(String v){existingDepartment=v;}
    public String getRequestedPriority(){return requestedPriority;} public void setRequestedPriority(String v){requestedPriority=v;} public String getJustification(){return justification;} public void setJustification(String v){justification=v;}
    public String getStatus(){return status;} public void setStatus(String v){status=v;} public String getRequesterHeadDecision(){return requesterHeadDecision;} public void setRequesterHeadDecision(String v){requesterHeadDecision=v;} public String getRequesterHeadEmail(){return requesterHeadEmail;} public void setRequesterHeadEmail(String v){requesterHeadEmail=v;}
    public String getExistingHeadDecision(){return existingHeadDecision;} public void setExistingHeadDecision(String v){existingHeadDecision=v;} public String getExistingHeadEmail(){return existingHeadEmail;} public void setExistingHeadEmail(String v){existingHeadEmail=v;}
    public String getAdminResolution(){return adminResolution;} public void setAdminResolution(String v){adminResolution=v;} public String getAdminNote(){return adminNote;} public void setAdminNote(String v){adminNote=v;} public String getResolvedBy(){return resolvedBy;} public void setResolvedBy(String v){resolvedBy=v;}
    public String getVerifiedPriority(){return verifiedPriority;} public void setVerifiedPriority(String v){verifiedPriority=v;}
    public String getPriorityVerifiedBy(){return priorityVerifiedBy;} public void setPriorityVerifiedBy(String v){priorityVerifiedBy=v;}
    public LocalDateTime getPriorityVerifiedAt(){return priorityVerifiedAt;} public void setPriorityVerifiedAt(LocalDateTime v){priorityVerifiedAt=v;}
    public LocalDateTime getLastReminderAt(){return lastReminderAt;} public void setLastReminderAt(LocalDateTime v){lastReminderAt=v;}
    public Integer getReminderCount(){return reminderCount;} public void setReminderCount(Integer v){reminderCount=v;}
    public LocalDateTime getEscalatedAt(){return escalatedAt;} public void setEscalatedAt(LocalDateTime v){escalatedAt=v;}
    public Boolean getRequesterConsent(){return requesterConsent;} public void setRequesterConsent(Boolean v){requesterConsent=v;}
    public Boolean getExistingOwnerConsent(){return existingOwnerConsent;} public void setExistingOwnerConsent(Boolean v){existingOwnerConsent=v;}
    public Integer getTargetRoomId(){return targetRoomId;} public void setTargetRoomId(Integer v){targetRoomId=v;}
    public String getTargetRoomNo(){return targetRoomNo;} public void setTargetRoomNo(String v){targetRoomNo=v;}
    public LocalDate getTargetDate(){return targetDate;} public void setTargetDate(LocalDate v){targetDate=v;}
    public LocalTime getTargetStartTime(){return targetStartTime;} public void setTargetStartTime(LocalTime v){targetStartTime=v;}
    public LocalTime getTargetEndTime(){return targetEndTime;} public void setTargetEndTime(LocalTime v){targetEndTime=v;}
    public LocalDateTime getCreatedAt(){return createdAt;} public LocalDateTime getUpdatedAt(){return updatedAt;}
}
