package com.mesatech.bff.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {

    @Value("${cors.allowed-origins:http://localhost:3000}")
    private String allowedOrigins;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                // Pre-flight requests de navegadores
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()

                // Endpoints públicos de salud / monitoreo
                .requestMatchers("/actuator/**", "/error", "/api/public/**").permitAll()

                // Reglas para Catálogo:
                // Lectura permitida para todos los roles autenticados (Cliente, Operador, Administrador)
                .requestMatchers(HttpMethod.GET, "/v1/catalogo/**").hasAnyRole("Cliente", "Operador", "Administrador")
                // Creación, Edición y Borrado de catálogo ESTRICTAMENTE RESERVADO para Administrador
                .requestMatchers(HttpMethod.POST, "/v1/catalogo/**").hasRole("Administrador")
                .requestMatchers(HttpMethod.PUT, "/v1/catalogo/**").hasRole("Administrador")
                .requestMatchers(HttpMethod.DELETE, "/v1/catalogo/**").hasRole("Administrador")

                // Reglas para Solicitudes:
                // Creación de solicitudes: permitida para Cliente y Administrador
                .requestMatchers(HttpMethod.POST, "/v1/solicitudes/**").hasAnyRole("Cliente", "Administrador")
                // Cambio de estado de solicitudes: permitido para Operador y Administrador (Cliente NO puede)
                .requestMatchers(HttpMethod.PUT, "/v1/solicitudes/{id}/estado").hasAnyRole("Operador", "Administrador")
                .requestMatchers(HttpMethod.PUT, "/v1/solicitudes/{id}/asignar").hasAnyRole("Operador", "Administrador")
                .requestMatchers(HttpMethod.PUT, "/v1/solicitudes/*/estado").hasAnyRole("Operador", "Administrador")
                .requestMatchers(HttpMethod.PUT, "/v1/solicitudes/*/asignar").hasAnyRole("Operador", "Administrador")
                // Lectura de solicitudes (/v1 y /v2): disponible para todos los roles autenticados
                .requestMatchers(HttpMethod.GET, "/v1/solicitudes/**").hasAnyRole("Cliente", "Operador", "Administrador")
                .requestMatchers(HttpMethod.GET, "/v2/solicitudes/**").hasAnyRole("Cliente", "Operador", "Administrador")

                // Endpoint de inspección de usuario/token actual
                .requestMatchers("/api/auth/me").authenticated()

                // Cualquier otra solicitud requiere autenticación
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter()))
            );

        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(new JwtRoleConverter());
        return converter;
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        List<String> origins = Arrays.asList(allowedOrigins.split(","));
        configuration.setAllowedOrigins(origins);
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD"));
        configuration.setAllowedHeaders(Arrays.asList("Authorization", "Content-Type", "Accept", "X-Requested-With", "Origin"));
        configuration.setExposedHeaders(List.of("Authorization"));
        configuration.setAllowCredentials(true);
        configuration.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
