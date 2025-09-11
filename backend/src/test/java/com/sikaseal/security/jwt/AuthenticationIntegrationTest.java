package com.sikaseal.security.jwt;

import com.sikaseal.config.SecurityConfiguration;
import com.sikaseal.config.SecurityJwtConfiguration;
import com.sikaseal.config.WebConfigurer;
import com.sikaseal.management.SecurityMetersService;
import com.sikaseal.web.rest.AuthenticateController;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.springframework.boot.test.autoconfigure.web.reactive.WebFluxTest;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import tech.jhipster.config.JHipsterProperties;

@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Import(
    {
        JHipsterProperties.class,
        WebConfigurer.class,
        SecurityConfiguration.class,
        SecurityJwtConfiguration.class,
        SecurityMetersService.class,
        JwtAuthenticationTestUtils.class,
    }
)
@WebFluxTest(
    controllers = { AuthenticateController.class }
)
@ActiveProfiles("test") //
@ComponentScan()
public @interface AuthenticationIntegrationTest {
}
