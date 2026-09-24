package com.gnits.smartcampusbackend.repository;

import com.gnits.smartcampusbackend.entity.Booking;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public interface BookingRepository extends JpaRepository<Booking, Integer> {
    List<Booking> findByBookingDateAndStatusIgnoreCase(LocalDate bookingDate, String status);
    List<Booking> findByBookingDateAndRoomIdAndStatusIgnoreCase(LocalDate bookingDate, Integer roomId, String status);
    List<Booking> findByBookedByIgnoreCaseAndStatusIgnoreCaseOrderByBookingDateDescStartTimeDesc(String bookedBy, String status);
    List<Booking> findByStatusIgnoreCaseOrderByBookingDateDescStartTimeDesc(String status);

    default boolean hasOverlap(LocalDate date, Integer roomId, LocalTime start, LocalTime end) {
        return findByBookingDateAndRoomIdAndStatusIgnoreCase(date, roomId, "CONFIRMED").stream()
                .anyMatch(b -> start.isBefore(b.getEndTime()) && end.isAfter(b.getStartTime()));
    }
}
