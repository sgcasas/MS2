package pe.utec.cs2032.ms2.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI openApi(@Value("${app.public-api-url}") String publicApiUrl) {
        return new OpenAPI()
                .info(new Info()
                        .title("MS2 - Menú y Platos")
                        .version("1.0")
                        .description("Microservicio de menú y platos (categorías y platos) del proyecto "
                                + "CS2032 Cloud Computing - UTEC 2026-2."))
                .servers(List.of(new Server().url(publicApiUrl)));
    }
}
