package com.gnits.smartcampusbackend.repository;

import com.gnits.smartcampusbackend.entity.Room;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface RoomRepository extends JpaRepository<Room, Integer> {
    Optional<Room> findByRoomNoIgnoreCase(String roomNo);

    /**
     * Resolves timetable room labels through the user-maintained room_aliases
     * table. This is intentionally a native query so the importer can use
     * aliases without requiring a separate JPA entity for the alias table.
     */
    @Query(value = "SELECT r.* FROM rooms r JOIN room_aliases ra ON ra.room_id = r.room_id " +
            "WHERE LOWER(TRIM(ra.alias_name)) = LOWER(TRIM(:alias)) ORDER BY " +
            "CASE WHEN UPPER(TRIM(COALESCE(ra.alias_type, ''))) = 'DATABASE' THEN 0 " +
            "WHEN UPPER(TRIM(COALESCE(ra.alias_type, ''))) = 'ALIAS' THEN 1 ELSE 2 END, ra.room_id LIMIT 1",
            nativeQuery = true)
    Optional<Room> findByRoomAlias(@Param("alias") String alias);

    /**
     * Fallback for timetable spellings such as F-3 vs F3. Only punctuation
     * and spaces are ignored; the underlying room_aliases row remains the
     * source of truth.
     */
    @Query(value = "SELECT r.* FROM rooms r JOIN room_aliases ra ON ra.room_id = r.room_id " +
            "WHERE REPLACE(REPLACE(REPLACE(UPPER(TRIM(ra.alias_name)), '-', ''), ' ', ''), '_', '') = " +
            "REPLACE(REPLACE(REPLACE(UPPER(TRIM(:alias)), '-', ''), ' ', ''), '_', '') " +
            "ORDER BY CASE WHEN UPPER(TRIM(COALESCE(ra.alias_type, ''))) = 'DATABASE' THEN 0 " +
            "WHEN UPPER(TRIM(COALESCE(ra.alias_type, ''))) = 'ALIAS' THEN 1 ELSE 2 END, ra.room_id LIMIT 1",
            nativeQuery = true)
    Optional<Room> findByNormalizedRoomAlias(@Param("alias") String alias);
}
