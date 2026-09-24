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
    @Column(nullable=false, length=20) private String status = "CONFIRMED";

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
}
