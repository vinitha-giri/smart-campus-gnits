package com.gnits.smartcampusbackend.realtime;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class RealtimeHub {
    private final Set<WebSocketSession> sessions = ConcurrentHashMap.newKeySet();
    private final ObjectMapper mapper = new ObjectMapper();

    public void add(WebSocketSession session) { sessions.add(session); }
    public void remove(WebSocketSession session) { sessions.remove(session); }

    public void publish(String type, String message) {
        publish(type, message, Map.of());
    }

    /** Broadcast a typed event with optional structured data. Existing clients that
     * only read type/message continue to work, while newer clients can immediately
     * refresh the affected room without waiting for polling. */
    public void publish(String type, String message, Map<String, Object> data) {
        String payload;
        try {
            Map<String, Object> event = new LinkedHashMap<>();
            event.put("type", type);
            event.put("message", message);
            event.put("timestamp", System.currentTimeMillis());
            event.put("data", data == null ? Map.of() : data);
            payload = mapper.writeValueAsString(event);
        } catch (Exception e) {
            return;
        }
        TextMessage event = new TextMessage(payload);
        for (WebSocketSession session : sessions) {
            if (!session.isOpen()) { sessions.remove(session); continue; }
            try { session.sendMessage(event); } catch (IOException e) { sessions.remove(session); }
        }
    }

    public int connectedUsers() { return sessions.size(); }
}
