package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.realtime.RealtimeHub;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@RestController
public class HealthController {
    private final RealtimeHub hub;
    public HealthController(RealtimeHub hub) { this.hub = hub; }
    @GetMapping("/api/health")
    public Map<String, Object> health() {
        return Map.of("status", "UP", "service", "GNITS Smart Campus API", "timestamp", Instant.now().toString(), "connectedRealtimeUsers", hub.connectedUsers());
    }
}
