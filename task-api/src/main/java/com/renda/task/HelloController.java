package com.renda.task;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    @GetMapping("/api/hello")
    public String hello(@RequestParam(name = "name", required = false, defaultValue = "World") String name) {
        return "hello " + name;
    }

    // 预留一个“业务探针”，后续可被 readiness probe 依赖
    @GetMapping("/api/ping")
    public String ping() {
        return "pong";
    }
}
