package com.gnits.smartcampusbackend.repository;

import com.gnits.smartcampusbackend.entity.Booking;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Objects;

public interface BookingRepository extends JpaRepository<Booking, Integer> {
    List<Booking> findByBookingDateAndStatusIgnoreCase(LocalDate bookingDate, String status);
    List<Booking> findByBookingDateAndRoomIdAndStatusIgnoreCase(LocalDate bookingDate, Integer roomId, String status);
    List<Booking> findByBookedByIgnoreCaseAndStatusIgnoreCaseOrderByBookingDateDescStartTimeDesc(String bookedBy, String status);
    List<Booking> findByStatusIgnoreCaseOrderByBookingDateDescStartTimeDesc(String status);

    default boolean hasOverlap(LocalDate date, Integer roomId, LocalTime start, LocalTime end) {
        return findByBookingDateAndRoomIdAndStatusIgnoreCase(date, roomId, "CONFIRMED").stream()
                .anyMatch(b -> start.isBefore(b.getEndTime()) && end.isAfter(b.getStartTime()))
            || findByBookingDateAndRoomIdAndStatusIgnoreCase(date, roomId, "PENDING_APPROVAL").stream()
                .anyMatch(b -> start.isBefore(b.getEndTime()) && end.isAfter(b.getStartTime()));
    }

    List<Booking> findByStatusIgnoreCaseOrderByBookingDateAscStartTimeAsc(String status);
    default boolean hasOverlapExcept(LocalDate date, Integer roomId, LocalTime start, LocalTime end, Integer excludedId) {
        return findByBookingDateAndRoomIdAndStatusIgnoreCase(date, roomId, "CONFIRMED").stream()
                .filter(b -> !Objects.equals(b.getBookingId(), excludedId))
                .anyMatch(b -> start.isBefore(b.getEndTime()) && end.isAfter(b.getStartTime()))
            || findByBookingDateAndRoomIdAndStatusIgnoreCase(date, roomId, "PENDING_APPROVAL").stream()
                .filter(b -> !Objects.equals(b.getBookingId(), excludedId))
                .anyMatch(b -> start.isBefore(b.getEndTime()) && end.isAfter(b.getStartTime()));
    }
    List<Booking> findByBookedByIgnoreCaseOrderByBookingDateDescStartTimeDesc(String bookedBy);
}

