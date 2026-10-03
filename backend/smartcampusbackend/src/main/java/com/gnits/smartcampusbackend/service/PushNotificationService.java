package com.gnits.smartcampusbackend.service;

import com.gnits.smartcampusbackend.entity.DeviceToken;
import com.gnits.smartcampusbackend.repository.DeviceTokenRepository;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;

/** Optional FCM bridge. In-app notifications continue to work when FCM is not configured. */
@Service
public class PushNotificationService {
    private static final Logger log = LoggerFactory.getLogger(PushNotificationService.class);
    private final DeviceTokenRepository tokens;
    private volatile FirebaseApp app;
    private volatile boolean attempted;

    public PushNotificationService(DeviceTokenRepository tokens){this.tokens=tokens;}

    private FirebaseApp firebase(){
        if(attempted) return app;
        synchronized(this){
            if(attempted) return app;
            attempted=true;
            try{
                String encoded=System.getenv("FIREBASE_SERVICE_ACCOUNT_JSON_B64");
                if(encoded==null || encoded.isBlank()){
                    log.info("FCM disabled: FIREBASE_SERVICE_ACCOUNT_JSON_B64 is not configured.");
                    return null;
                }
                byte[] json=Base64.getDecoder().decode(encoded);
                FirebaseOptions options=FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(new ByteArrayInputStream(json)))
                    .build();
                app=FirebaseApp.getApps().isEmpty()?FirebaseApp.initializeApp(options):FirebaseApp.getInstance();
                log.info("Firebase Admin SDK initialized for push notifications.");
            }catch(Exception e){
                log.warn("FCM initialization failed; in-app notifications will continue: {}",e.getMessage());
            }
            return app;
        }
    }

    public void send(String email,String title,String body,Map<String,String> data){
        FirebaseApp firebase=firebase();
        if(firebase==null || email==null || email.isBlank()) return;
        for(DeviceToken device: tokens.findByEmailIgnoreCase(email.trim())){
            try{
                Message.Builder builder=Message.builder()
                    .setToken(device.getToken())
                    .setNotification(com.google.firebase.messaging.Notification.builder().setTitle(title).setBody(body).build());
                if(data!=null && !data.isEmpty()) builder.putAllData(data);
                FirebaseMessaging.getInstance(firebase).send(builder.build());
            }catch(Exception e){
                // A stale token should not prevent other devices from receiving the notification.
                log.debug("FCM send failed for token: {}",e.getMessage());
            }
        }
    }
}
