package com.gnits.smartcampusbackend.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "rooms")
public class Room {

    @Id
    @Column(name = "room_id")
    private Integer roomId;

    @Column(name = "building_id")
    private Integer buildingId;

    @Column(name = "department_id")
    private Integer departmentId;

    @Column(name = "room_no")
    private String roomNo;

    @Column(name = "floor_no")
    private Integer floorNo;

    @Column(name = "room_type")
    private String roomType;

    @Column(name = "area_sqm")
    private BigDecimal areaSqm;

    @Column(name = "capacity")
    private Integer capacity;

    @Column(name = "smart_enabled")
    private Boolean smartEnabled;

    // AVAILABLE / OCCUPIED / MAINTENANCE / RESERVED
    // This is the room's administratively-set status (e.g. taken out
    // of service for maintenance). It is NOT the same as "currently
    // has a class in session" - that is derived dynamically from the
    // timetable, see RoomController#getAvailability.
    @Column(name = "status")
    private String status;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    public Integer getRoomId() { return roomId; }
    public void setRoomId(Integer roomId) { this.roomId = roomId; }

    public Integer getBuildingId() { return buildingId; }
    public void setBuildingId(Integer buildingId) { this.buildingId = buildingId; }

    public Integer getDepartmentId() { return departmentId; }
    public void setDepartmentId(Integer departmentId) { this.departmentId = departmentId; }

    public String getRoomNo() { return roomNo; }
    public void setRoomNo(String roomNo) { this.roomNo = roomNo; }

    public Integer getFloorNo() { return floorNo; }
    public void setFloorNo(Integer floorNo) { this.floorNo = floorNo; }

    public String getRoomType() { return roomType; }
    public void setRoomType(String roomType) { this.roomType = roomType; }

    public BigDecimal getAreaSqm() { return areaSqm; }
    public void setAreaSqm(BigDecimal areaSqm) { this.areaSqm = areaSqm; }

    public Integer getCapacity() { return capacity; }
    public void setCapacity(Integer capacity) { this.capacity = capacity; }

    public Boolean getSmartEnabled() { return smartEnabled; }
    public void setSmartEnabled(Boolean smartEnabled) { this.smartEnabled = smartEnabled; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDateTime getCreatedAt() { return createdAt; }
}
