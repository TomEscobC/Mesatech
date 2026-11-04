package com.mesatech.solicitudes.messaging;

import com.mesatech.solicitudes.model.CategoriaCopia;
import com.mesatech.solicitudes.repository.CategoriaCopiaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/**
 * Guarda la categoría recibida en el RDS propio. Con ack AUTO, el mensaje se confirma solo si el método
 * termina sin excepción, es decir, después de guardar. Si falla, la excepción se propaga y el mensaje se reencola.
 * save() sobre un id asignado hace upsert: reentregas del mismo categoriaId no duplican filas.
 */
@Component
public class CategoriaListener {

    private static final Logger log = LoggerFactory.getLogger(CategoriaListener.class);

    private final CategoriaCopiaRepository repository;

    public CategoriaListener(CategoriaCopiaRepository repository) {
        this.repository = repository;
    }

    @RabbitListener(queues = "${app.rabbitmq.queue}")
    public void onCategoriaCreada(CategoriaCreadaMessage msg) {
        log.info("Evento recibido: eventId={} tipo={} categoriaId={}", msg.eventId(), msg.tipoEvento(), msg.categoriaId());
        if (msg.categoriaId() == null || msg.nombre() == null || msg.eventId() == null) {
            throw new IllegalArgumentException("Evento inválido: faltan eventId, categoriaId o nombre");
        }
        repository.save(new CategoriaCopia(msg.categoriaId(), msg.nombre(), msg.eventId(), msg.fechaEvento()));
        log.info("Categoría guardada en RDS Solicitudes: categoriaId={} eventId={}", msg.categoriaId(), msg.eventId());
    }
}
