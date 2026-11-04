package com.mesatech.catalogo.messaging;

import com.mesatech.catalogo.dto.CategoriaDTO;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.MessageDeliveryMode;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

/**
 * Publica "categoria.creada" con mensaje persistente y espera la confirmación del broker.
 * La confirmación indica que RabbitMQ aceptó el mensaje; NO acredita que el consumidor lo haya guardado.
 */
@Component
public class CategoriaEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(CategoriaEventPublisher.class);

    private final RabbitTemplate rabbitTemplate;
    private final String exchange;
    private final String routingKey;
    private final long confirmTimeoutMs;

    public CategoriaEventPublisher(RabbitTemplate rabbitTemplate,
                                   @Value("${app.rabbitmq.exchange}") String exchange,
                                   @Value("${app.rabbitmq.routing-key}") String routingKey,
                                   @Value("${app.rabbitmq.confirm-timeout-ms:5000}") long confirmTimeoutMs) {
        this.rabbitTemplate = rabbitTemplate;
        this.exchange = exchange;
        this.routingKey = routingKey;
        this.confirmTimeoutMs = confirmTimeoutMs;
    }

    /** @return eventId publicado y confirmado */
    public String publicarCategoriaCreada(CategoriaDTO categoria) {
        String eventId = UUID.randomUUID().toString();
        CategoriaCreadaEvent event = new CategoriaCreadaEvent(
                eventId, CategoriaCreadaEvent.TIPO, Instant.now().toString(), categoria.getId(), categoria.getNombre());
        CorrelationData correlation = new CorrelationData(eventId);
        try {
            rabbitTemplate.convertAndSend(exchange, routingKey, event, message -> {
                message.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
                message.getMessageProperties().setMessageId(eventId);
                return message;
            }, correlation);

            CorrelationData.Confirm confirm = correlation.getFuture().get(confirmTimeoutMs, TimeUnit.MILLISECONDS);
            if (!confirm.isAck()) {
                throw new EventoNoConfirmadoException(
                        "RabbitMQ rechazó el mensaje (nack): " + confirm.getReason(), categoria.getId(), eventId, null);
            }
            if (correlation.getReturned() != null) {
                throw new EventoNoConfirmadoException(
                        "El mensaje no tiene ruta hacia ninguna cola (" + correlation.getReturned().getReplyText() + ")",
                        categoria.getId(), eventId, null);
            }
            log.info("Evento publicado y confirmado: eventId={} categoriaId={} exchange={} routingKey={}",
                    eventId, categoria.getId(), exchange, routingKey);
            return eventId;
        } catch (EventoNoConfirmadoException e) {
            log.error("Publicación no confirmada: eventId={} categoriaId={} motivo={}", eventId, categoria.getId(), e.getMessage());
            throw e;
        } catch (Exception e) {
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            log.error("Fallo al publicar: eventId={} categoriaId={} error={}", eventId, categoria.getId(), e.toString());
            throw new EventoNoConfirmadoException(
                    "No se pudo publicar o confirmar el evento en RabbitMQ: " + e.getClass().getSimpleName(),
                    categoria.getId(), eventId, e);
        }
    }
}
