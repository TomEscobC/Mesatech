package com.mesatech.catalogo.messaging;

public class EventoNoConfirmadoException extends RuntimeException {

    private final Long categoriaId;
    private final String eventId;

    public EventoNoConfirmadoException(String message, Long categoriaId, String eventId, Throwable cause) {
        super(message, cause);
        this.categoriaId = categoriaId;
        this.eventId = eventId;
    }

    public Long getCategoriaId() {
        return categoriaId;
    }

    public String getEventId() {
        return eventId;
    }
}
