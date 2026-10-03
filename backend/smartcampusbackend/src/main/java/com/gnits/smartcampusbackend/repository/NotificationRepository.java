package com.gnits.smartcampusbackend.repository;

import com.gnits.smartcampusbackend.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    List<Notification> findTop50ByRecipientEmailIgnoreCaseOrderByCreatedAtDesc(String recipientEmail);
    long countByRecipientEmailIgnoreCaseAndReadFalse(String recipientEmail);
}
