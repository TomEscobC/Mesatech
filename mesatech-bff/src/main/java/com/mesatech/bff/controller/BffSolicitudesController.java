package com.mesatech.bff.controller;

import com.mesatech.bff.client.SolicitudesClient;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
public class BffSolicitudesController {

    private final SolicitudesClient solicitudesClient;

    public BffSolicitudesController(SolicitudesClient solicitudesClient) {
        this.solicitudesClient = solicitudesClient;
    }

    // --- Endpoints Versión 1 (/v1/solicitudes) ---

    @GetMapping("/v1/solicitudes")
    public ResponseEntity<Object> listarSolicitudesV1(
            @RequestParam(required = false) String usuarioSolicitante,
            @RequestParam(required = false) String usuarioAsignado,
            @RequestParam(required = false) String estado,
            Authentication authentication) {

        String email = extraerEmailOUsuario(authentication);
        boolean esSoloCliente = esSoloCliente(authentication);

        // Si el usuario tiene exclusivamente rol Cliente, solo puede ver sus propias solicitudes
        String solicitanteEfectivo = esSoloCliente ? email : usuarioSolicitante;

        return ResponseEntity.ok(solicitudesClient.listarSolicitudesV1(solicitanteEfectivo, usuarioAsignado, estado));
    }

    @GetMapping("/v1/solicitudes/categorias")
    public ResponseEntity<Object> listarCategoriasLocales() {
        return ResponseEntity.ok(solicitudesClient.listarCategoriasLocales());
    }

    @GetMapping("/v1/solicitudes/{id}")
    public ResponseEntity<Object> obtenerPorIdV1(@PathVariable Long id) {
        return ResponseEntity.ok(solicitudesClient.obtenerPorIdV1(id));
    }

    @PostMapping("/v1/solicitudes")
    public ResponseEntity<Object> crearSolicitud(
            @RequestBody Map<String, Object> payload,
            Authentication authentication) {

        Map<String, Object> body = new HashMap<>(payload);
        String usuarioAutenticado = extraerEmailOUsuario(authentication);

        // Si es cliente, garantizamos que el solicitante sea el usuario del token autenticado
        if (esSoloCliente(authentication) || !body.containsKey("usuarioSolicitante")) {
            body.put("usuarioSolicitante", usuarioAutenticado);
        }

        return ResponseEntity.status(HttpStatus.CREATED).body(solicitudesClient.crearSolicitud(body));
    }

    @PutMapping("/v1/solicitudes/{id}/estado")
    public ResponseEntity<Object> cambiarEstado(
            @PathVariable Long id,
            @RequestBody Map<String, Object> payload,
            Authentication authentication) {

        Map<String, Object> body = new HashMap<>(payload);
        String usuario = extraerEmailOUsuario(authentication);
        if (!body.containsKey("usuario")) {
            body.put("usuario", usuario);
        }

        return ResponseEntity.ok(solicitudesClient.cambiarEstado(id, body));
    }

    @PutMapping("/v1/solicitudes/{id}/asignar")
    public ResponseEntity<Object> asignarOperador(
            @PathVariable Long id,
            @RequestBody Map<String, Object> payload,
            Authentication authentication) {

        Map<String, Object> body = new HashMap<>(payload);
        String usuario = extraerEmailOUsuario(authentication);
        if (!body.containsKey("asignadoPor")) {
            body.put("asignadoPor", usuario);
        }

        return ResponseEntity.ok(solicitudesClient.asignarOperador(id, body));
    }

    // --- Endpoints Versión 2 (/v2/solicitudes) ---

    @GetMapping("/v2/solicitudes")
    public ResponseEntity<Object> listarSolicitudesV2(
            @RequestParam(required = false) String usuarioSolicitante,
            @RequestParam(required = false) String usuarioAsignado,
            @RequestParam(required = false) String estado,
            Authentication authentication) {

        String email = extraerEmailOUsuario(authentication);
        boolean esSoloCliente = esSoloCliente(authentication);

        String solicitanteEfectivo = esSoloCliente ? email : usuarioSolicitante;
        return ResponseEntity.ok(solicitudesClient.listarSolicitudesV2(solicitanteEfectivo, usuarioAsignado, estado));
    }

    @GetMapping("/v2/solicitudes/{id}")
    public ResponseEntity<Object> obtenerPorIdV2(@PathVariable Long id) {
        return ResponseEntity.ok(solicitudesClient.obtenerPorIdV2(id));
    }

    private String extraerEmailOUsuario(Authentication auth) {
        if (auth == null) return "anonimo";
        if (auth.getPrincipal() instanceof Jwt jwt) {
            String preferred = jwt.getClaimAsString("preferred_username");
            if (preferred != null && !preferred.isBlank()) return preferred;
            String email = jwt.getClaimAsString("email");
            if (email != null && !email.isBlank()) return email;
            String upn = jwt.getClaimAsString("upn");
            if (upn != null && !upn.isBlank()) return upn;
        }
        return auth.getName();
    }

    private boolean esSoloCliente(Authentication auth) {
        if (auth == null) return false;
        boolean tieneCliente = false;
        for (GrantedAuthority ga : auth.getAuthorities()) {
            if ("ROLE_Administrador".equals(ga.getAuthority()) || "ROLE_Operador".equals(ga.getAuthority())) {
                return false;
            }
            if ("ROLE_Cliente".equals(ga.getAuthority())) {
                tieneCliente = true;
            }
        }
        return tieneCliente;
    }
}
