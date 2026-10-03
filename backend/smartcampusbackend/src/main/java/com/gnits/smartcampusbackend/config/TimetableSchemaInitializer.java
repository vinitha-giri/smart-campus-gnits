package com.gnits.smartcampusbackend.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Keeps timetable_entries.room_id nullable so future-proof ROOMLESS timetable
 * activities can be stored without inventing a physical classroom.
 *
 * Existing GNITS databases created with an older schema may still have
 * room_id declared NOT NULL. Hibernate's update mode does not reliably relax
 * an existing MySQL NOT NULL constraint, so this idempotent migration runs
 * after the application is ready.
 */
@Component
public class TimetableSchemaInitializer {
    private static final Logger log = LoggerFactory.getLogger(TimetableSchemaInitializer.class);
    private final JdbcTemplate jdbcTemplate;

    public TimetableSchemaInitializer(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void ensureRoomIdNullable() {
        try {
            Integer exists = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM information_schema.columns " +
                    "WHERE table_schema = DATABASE() AND table_name = 'timetable_entries' AND column_name = 'room_id'",
                    Integer.class);

            if (exists == null || exists == 0) {
                log.warn("timetable_entries.room_id does not exist; Hibernate schema update should create it.");
                return;
            }

            jdbcTemplate.execute("ALTER TABLE timetable_entries MODIFY COLUMN room_id INT NULL");
            log.info("Verified timetable_entries.room_id allows NULL for ROOMLESS timetable sessions.");
        } catch (Exception ex) {
            log.warn("Could not automatically relax timetable_entries.room_id to NULL. " +
                    "Run database/allow_roomless_timetable.sql manually if a ROOMLESS upload fails. Cause: {}",
                    ex.getMessage());
        }
    }
}
