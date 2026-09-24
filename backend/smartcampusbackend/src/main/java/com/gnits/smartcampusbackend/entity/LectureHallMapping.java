package com.gnits.smartcampusbackend.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "lecture_hall_mapping")
public class LectureHallMapping {
    @Id
    @Column(name = "lh_no", length = 50)
    private String lhNo;

    @Column(name = "room_id", nullable = false)
    private Integer roomId;

    @Column(name = "notes")
    private String notes;

    public String getLhNo() { return lhNo; }
    public void setLhNo(String lhNo) { this.lhNo = lhNo; }
    public Integer getRoomId() { return roomId; }
    public void setRoomId(Integer roomId) { this.roomId = roomId; }
    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }
}
