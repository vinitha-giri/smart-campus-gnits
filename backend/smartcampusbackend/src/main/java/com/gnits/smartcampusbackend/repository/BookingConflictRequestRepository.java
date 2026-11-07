package com.gnits.smartcampusbackend.repository;
import com.gnits.smartcampusbackend.entity.BookingConflictRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface BookingConflictRequestRepository extends JpaRepository<BookingConflictRequest, Long> {
    List<BookingConflictRequest> findByRequesterEmailIgnoreCaseOrderByCreatedAtDesc(String email);
    List<BookingConflictRequest> findByExistingFacultyEmailIgnoreCaseOrderByCreatedAtDesc(String email);
    List<BookingConflictRequest> findByStatusInOrderByCreatedAtAsc(List<String> statuses);
    List<BookingConflictRequest> findByExistingBookingIdAndRequesterEmailIgnoreCaseAndStatusIn(Integer bookingId, String requesterEmail, List<String> statuses);
}
