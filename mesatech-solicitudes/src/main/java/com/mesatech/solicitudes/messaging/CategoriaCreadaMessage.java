package com.mesatech.solicitudes.messaging;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/** Contrato del evento publicado por Catálogo (ver mesatech-catalogo CategoriaCreadaEvent). */
@JsonIgnoreProperties(ignoreUnknown = true)
public record CategoriaCreadaMessage(
        String eventId,
        String tipoEvento,
        String fechaEvento,
        Long categoriaId,
        String nombre) {
}
