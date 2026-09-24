package com.gnits.smartcampusbackend.realtime;

import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.WebSocketMessage;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketSession;

@Component
public class RealtimeWebSocketHandler implements WebSocketHandler {
    private final RealtimeHub hub;
    public RealtimeWebSocketHandler(RealtimeHub hub) { this.hub = hub; }
    @Override public void afterConnectionEstablished(WebSocketSession session) { hub.add(session); }
    @Override public void handleMessage(WebSocketSession session, WebSocketMessage<?> message) { /* client is receive-only */ }
    @Override public void handleTransportError(WebSocketSession session, Throwable exception) { hub.remove(session); }
    @Override public void afterConnectionClosed(WebSocketSession session, CloseStatus closeStatus) { hub.remove(session); }
    @Override public boolean supportsPartialMessages() { return false; }
}
