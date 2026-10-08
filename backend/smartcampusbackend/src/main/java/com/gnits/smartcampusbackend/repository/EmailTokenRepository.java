package com.gnits.smartcampusbackend.repository;

import com.gnits.smartcampusbackend.entity.EmailToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface EmailTokenRepository extends JpaRepository<EmailToken, Long> {
    Optional<EmailToken> findByTokenHashAndPurpose(String tokenHash, String purpose);
}
