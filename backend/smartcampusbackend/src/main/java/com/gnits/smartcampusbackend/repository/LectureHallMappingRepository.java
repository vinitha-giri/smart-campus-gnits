package com.gnits.smartcampusbackend.repository;

import com.gnits.smartcampusbackend.entity.LectureHallMapping;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface LectureHallMappingRepository extends JpaRepository<LectureHallMapping, String> {
    Optional<LectureHallMapping> findByLhNoIgnoreCase(String lhNo);
}
