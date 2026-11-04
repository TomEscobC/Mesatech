package com.mesatech.bff.client;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Map;

@Component
public class SolicitudesClient {

    private final RestClient restClient;

    public SolicitudesClient(@Value("${services.solicitudes.url:http://localhost:8081}") String solicitudesUrl) {
        this.restClient = RestClient.builder()
                .baseUrl(solicitudesUrl)
                .build();
    }

    public Object listarSolicitudesV1(String usuarioSolicitante, String usuarioAsignado, String estado) {
        return restClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/v1/solicitudes")
                        .queryParam("usuarioSolicitante", usuarioSolicitante)
                        .queryParam("usuarioAsignado", usuarioAsignado)
                        .queryParam("estado", estado)
                        .build())
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .body(new ParameterizedTypeReference<Object>() {});
    }

    /** Categorías locales de Solicitudes (copia recibida por RabbitMQ). */
    public Object listarCategoriasLocales() {
        return restClient.get()
                .uri("/v1/solicitudes/categorias")
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .body(new ParameterizedTypeReference<Object>() {});
    }

    public Object obtenerPorIdV1(Long id) {
        return restClient.get()
                .uri("/v1/solicitudes/{id}", id)
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .body(new ParameterizedTypeReference<Object>() {});
    }

    public Object crearSolicitud(Map<String, Object> body) {
        return restClient.post()
                .uri("/v1/solicitudes")
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(new ParameterizedTypeReference<Object>() {});
    }

    public Object cambiarEstado(Long id, Map<String, Object> body) {
        return restClient.put()
                .uri("/v1/solicitudes/{id}/estado", id)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(new ParameterizedTypeReference<Object>() {});
    }

    public Object asignarOperador(Long id, Map<String, Object> body) {
        return restClient.put()
                .uri("/v1/solicitudes/{id}/asignar", id)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(new ParameterizedTypeReference<Object>() {});
    }

    public Object listarSolicitudesV2(String usuarioSolicitante, String usuarioAsignado, String estado) {
        return restClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/v2/solicitudes")
                        .queryParam("usuarioSolicitante", usuarioSolicitante)
                        .queryParam("usuarioAsignado", usuarioAsignado)
                        .queryParam("estado", estado)
                        .build())
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .body(new ParameterizedTypeReference<Object>() {});
    }

    public Object obtenerPorIdV2(Long id) {
        return restClient.get()
                .uri("/v2/solicitudes/{id}", id)
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .body(new ParameterizedTypeReference<Object>() {});
    }
}
