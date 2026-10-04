package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.DeviceToken;
import com.gnits.smartcampusbackend.entity.User;
import com.gnits.smartcampusbackend.repository.DeviceTokenRepository;
import com.gnits.smartcampusbackend.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

@RestController
@RequestMapping("/api/devices")
@CrossOrigin(origins="*")
public class DeviceTokenController {
    private final DeviceTokenRepository tokens;
    private final UserRepository users;
    public DeviceTokenController(DeviceTokenRepository tokens, UserRepository users){this.tokens=tokens;this.users=users;}

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Map<String,Object> body){
        String email=text(body.get("email")).toLowerCase();
        String session=text(body.get("sessionToken"));
        String token=text(body.get("token"));
        if(email.isBlank()||session.isBlank()||token.isBlank()) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Email, session and device token are required."));
        User user=users.findByEmail(email).orElseGet(()->users.findByUsername(email).orElse(null));
        if(user==null || user.getSessionToken()==null || !user.getSessionToken().equals(session)) return ResponseEntity.status(401).body(Map.of("success",false,"error","Your session has expired. Please sign in again."));
        DeviceToken device=tokens.findByToken(token).orElseGet(DeviceToken::new);
        device.setEmail(email); device.setToken(token); device.setUpdatedAt(LocalDateTime.now()); tokens.save(device);
        return ResponseEntity.ok(Map.of("success",true,"message","Device notifications enabled."));
    }

    @DeleteMapping("/register")
    public ResponseEntity<?> unregister(@RequestParam String email,@RequestParam String sessionToken,@RequestParam String token){
        User user=users.findByEmail(email.toLowerCase()).orElseGet(()->users.findByUsername(email.toLowerCase()).orElse(null));
        if(user==null || user.getSessionToken()==null || !user.getSessionToken().equals(sessionToken)) return ResponseEntity.status(401).body(Map.of("success",false,"error","Invalid session."));
        tokens.deleteByToken(token); return ResponseEntity.ok(Map.of("success",true));
    }
    private static String text(Object v){return v==null?"":String.valueOf(v).trim();}
}
