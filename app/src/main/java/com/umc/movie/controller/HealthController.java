package com.umc.movie.controller;

import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

// [인프라 1주차] ALB 타겟 그룹이 10초마다 GET /health 를 호출해 이 서버가 살아 있는지 판단한다.
// 200 이면 healthy → 트래픽을 받고, 2번 연속 실패하면 unhealthy → 트래픽에서 빠진다.
@RestController
public class HealthController {

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "UP"));
    }
}
