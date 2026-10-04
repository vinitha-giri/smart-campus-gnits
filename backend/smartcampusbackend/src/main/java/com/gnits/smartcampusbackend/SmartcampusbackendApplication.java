package com.gnits.smartcampusbackend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class SmartcampusbackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(SmartcampusbackendApplication.class, args);
    }
}