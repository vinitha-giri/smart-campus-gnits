package com.gnits.smartcampusbackend.repository;
import com.gnits.smartcampusbackend.entity.BookingConflictAudit;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface BookingConflictAuditRepository extends JpaRepository<BookingConflictAudit,Long> {
    List<BookingConflictAudit> findByConflictRequestIdOrderByCreatedAtAsc(Long conflictRequestId);
}
