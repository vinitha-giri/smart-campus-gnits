package com.gnits.smartcampusbackend.repository;

import com.gnits.smartcampusbackend.entity.DeviceToken;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {
    List<DeviceToken> findByEmailIgnoreCase(String email);
    Optional<DeviceToken> findByToken(String token);
    void deleteByToken(String token);
}
