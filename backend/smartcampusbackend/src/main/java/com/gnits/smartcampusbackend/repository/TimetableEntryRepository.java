package com.gnits.smartcampusbackend.repository;

import com.gnits.smartcampusbackend.entity.TimetableEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
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

    /** Loads only one day instead of the full timetable for live/booking checks. */
    List<TimetableEntry> findByDayOfWeekIgnoreCase(String dayOfWeek);

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

    /**
     * Removes every class key belonging to one year level for exactly one
     * academic year and semester.  Example: 1st-% removes 1st-CSE-A,
     * 1st-ECE-B, 1st-ETM, etc., without touching 2nd/3rd/4th year data.
     */
    @Modifying
    @Transactional
    @Query("delete from TimetableEntry t where lower(t.academicYear) = lower(:academicYear) " +
           "and t.semesterNo = :semesterNo and lower(t.sectionName) like lower(concat(:yearPrefix, '-%'))")
    int deleteByAcademicYearAndSemesterNoAndYearLevel(
            @Param("academicYear") String academicYear,
            @Param("semesterNo") Integer semesterNo,
            @Param("yearPrefix") String yearPrefix);
}