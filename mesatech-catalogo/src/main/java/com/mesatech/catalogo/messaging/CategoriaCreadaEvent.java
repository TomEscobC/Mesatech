package com.mesatech.catalogo.messaging;

/**
 * Contrato del evento "categoria.creada".
 * fechaEvento: ISO-8601 con zona, p. ej. 2026-11-04T20:05:31.123Z
 * categoriaId: id original del Catálogo; el consumidor lo conserva como referencia de origen.
 */
public record CategoriaCreadaEvent(
        String eventId,
        String tipoEvento,
        String fechaEvento,
        Long categoriaId,
        String nombre) {

    public static final String TIPO = "CATEGORIA_CREADA";
}
