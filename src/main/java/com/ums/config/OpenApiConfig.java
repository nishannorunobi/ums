package com.ums.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI umsOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("User Management System API")
                        .description("REST API for managing users")
                        .version("v1")
                        .contact(new Contact()
                                .name("Nishan")
                                .email("norunnabinishan@gmail.com")));
    }
}
