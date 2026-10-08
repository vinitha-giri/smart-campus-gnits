package com.gnits.smartcampusbackend.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name="user_device_tokens", indexes={@Index(name="idx_device_email", columnList="email")})
public class DeviceToken {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY)
    private Long id;
    @Column(nullable=false, length=150) private String email;
    @Column(nullable=false, unique=true, length=500) private String token;
    @Column(name="updated_at", nullable=false) private LocalDateTime updatedAt=LocalDateTime.now();
    public Long getId(){return id;}
    public String getEmail(){return email;} public void setEmail(String v){email=v;}
    public String getToken(){return token;} public void setToken(String v){token=v;}
    public LocalDateTime getUpdatedAt(){return updatedAt;} public void setUpdatedAt(LocalDateTime v){updatedAt=v;}
}
