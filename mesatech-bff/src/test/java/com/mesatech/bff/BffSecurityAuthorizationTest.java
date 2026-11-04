package com.mesatech.bff;

import com.mesatech.bff.client.CatalogoClient;
import com.mesatech.bff.client.SolicitudesClient;
import com.mesatech.bff.config.JwtRoleConverter;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class BffSecurityAuthorizationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private JwtDecoder jwtDecoder;

    @MockBean
    private SolicitudesClient solicitudesClient;

    @MockBean
    private CatalogoClient catalogoClient;

    @Test
    @DisplayName("JwtRoleConverter debe mapear claim 'roles' a 'ROLE_<Rol>'")
    void testJwtRoleConverter() {
        Jwt jwt = new Jwt(
                "token-value",
                Instant.now(),
                Instant.now().plusSeconds(3600),
                Map.of("alg", "RS256"),
                Map.of(
                        "roles", List.of("Administrador", "Operador"),
                        "scp", "access_as_user"
                )
        );

        JwtRoleConverter converter = new JwtRoleConverter();
        var authorities = converter.convert(jwt);
        assert authorities != null;
        assertTrue(authorities.contains(new SimpleGrantedAuthority("ROLE_Administrador")));
        assertTrue(authorities.contains(new SimpleGrantedAuthority("ROLE_Operador")));
        assertTrue(authorities.contains(new SimpleGrantedAuthority("SCOPE_access_as_user")));
    }

    @Test
    @DisplayName("Escenario 1: Petición sin token debe ser rechazada con 401 Unauthorized")
    void testAccesoSinTokenRechazado() throws Exception {
        mockMvc.perform(get("/v1/solicitudes"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/v1/catalogo/categorias")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"codigo\":\"TEST\",\"nombre\":\"Test\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Escenario 2: JWT con firma inválida o expirado debe ser rechazado con 401 (sin filtros que omitan la validación)")
    void testJwtInvalidoRechazado() throws Exception {
        when(jwtDecoder.decode(any())).thenThrow(new org.springframework.security.oauth2.jwt.BadJwtException("Firma inválida"));

        // Token con claims "convincentes" pero firma falsa: antes lo aceptaba DemoAuthFilter
        String forjado = "eyJhbGciOiJSUzI1NiJ9."
                + "eyJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vIiwicHJlZmVycmVkX3VzZXJuYW1lIjoiYWRtaW5AY3VyenVhMS5vbm1pY3Jvc29mdC5jb20ifQ."
                + "firma-falsa";

        mockMvc.perform(get("/v1/solicitudes").header("Authorization", "Bearer " + forjado))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Escenario 3: Usuario con rol Cliente intentando crear catálogo debe ser rechazado con 403 Forbidden")
    void testClienteRechazadoEnCatalogo() throws Exception {
        mockMvc.perform(post("/v1/catalogo/categorias")
                        .with(SecurityMockMvcRequestPostProcessors.jwt()
                                .authorities(new SimpleGrantedAuthority("ROLE_Cliente"))
                                .jwt(jwt -> jwt.claim("preferred_username", "cliente@mesatech.cloud")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"codigo\":\"TEST\",\"nombre\":\"Intento Ilegal\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Escenario 3b: Usuario con rol Cliente intentando cambiar estado de ticket debe ser rechazado con 403 Forbidden")
    void testClienteRechazadoCambioEstado() throws Exception {
        mockMvc.perform(put("/v1/solicitudes/1/estado")
                        .with(SecurityMockMvcRequestPostProcessors.jwt()
                                .authorities(new SimpleGrantedAuthority("ROLE_Cliente"))
                                .jwt(jwt -> jwt.claim("preferred_username", "cliente@mesatech.cloud")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nuevoEstado\":\"RESUELTA\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Rol Administrador tiene permiso para crear categorías en catálogo")
    void testAdminPermitidoEnCatalogo() throws Exception {
        when(catalogoClient.crearCategoria(any())).thenReturn(Map.of("id", 99, "nombre", "Nueva Categoria"));

        mockMvc.perform(post("/v1/catalogo/categorias")
                        .with(SecurityMockMvcRequestPostProcessors.jwt()
                                .authorities(new SimpleGrantedAuthority("ROLE_Administrador"))
                                .jwt(jwt -> jwt.claim("preferred_username", "admin@mesatech.cloud")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"codigo\":\"HW_NEW\",\"nombre\":\"Hardware Nuevo\"}"))
                .andExpect(status().isCreated());
    }

    @Test
    @DisplayName("Rol Operador tiene permiso para cambiar estado de solicitud")
    void testOperadorPermitidoCambioEstado() throws Exception {
        when(solicitudesClient.cambiarEstado(any(), any())).thenReturn(Map.of("id", 1, "estado", "EN_PROCESO"));

        mockMvc.perform(put("/v1/solicitudes/1/estado")
                        .with(SecurityMockMvcRequestPostProcessors.jwt()
                                .authorities(new SimpleGrantedAuthority("ROLE_Operador"))
                                .jwt(jwt -> jwt.claim("preferred_username", "operador@mesatech.cloud")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nuevoEstado\":\"EN_PROCESO\"}"))
                .andExpect(status().isOk());
    }
}
