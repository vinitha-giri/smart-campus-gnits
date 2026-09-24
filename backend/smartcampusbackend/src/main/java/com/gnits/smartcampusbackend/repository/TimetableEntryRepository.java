package com.gnits.smartcampusbackend.repository;

import com.gnits.smartcampusbackend.entity.TimetableEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;
import java.util.List;

public interface TimetableEntryRepository
        extends JpaRepository<TimetableEntry, Integer> {

    boolean existsByRoomIdAndDayOfWeekAndStartTimeLessThanEqualAndEndTimeGreaterThan(
            Integer roomId,
            String dayOfWeek,
            LocalTime startTime,
            LocalTime endTime
    );

    List<TimetableEntry> findByRoomIdAndDayOfWeek(Integer roomId, String dayOfWeek);

    List<TimetableEntry> findByRoomIdAndDayOfWeekAndStartTimeLessThanEqualAndEndTimeGreaterThan(
            Integer roomId,
            String dayOfWeek,
            LocalTime startTime,
            LocalTime endTime
    );

    List<TimetableEntry> findByAcademicYearAndSemesterNo(
            String academicYear,
            Integer semesterNo
    );

    @Modifying
    @Transactional
    void deleteBySectionName(String sectionName);

    @Modifying
    @Transactional
    void deleteBySectionNameAndAcademicYearAndSemesterNo(String sectionName, String academicYear, Integer semesterNo);
}