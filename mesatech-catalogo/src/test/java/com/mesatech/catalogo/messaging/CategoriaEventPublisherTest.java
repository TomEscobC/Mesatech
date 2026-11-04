package com.mesatech.catalogo.messaging;

import com.mesatech.catalogo.dto.CategoriaDTO;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.AmqpConnectException;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;

import java.io.IOException;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

class CategoriaEventPublisherTest {

    private CategoriaDTO categoria() {
        CategoriaDTO c = new CategoriaDTO();
        c.setId(10L);
        c.setNombre("Impresoras");
        return c;
    }

    @Test
    @DisplayName("Con ack del broker devuelve el eventId")
    void publicaYConfirma() {
        RabbitTemplate rt = mock(RabbitTemplate.class);
        doAnswer(inv -> {
            CorrelationData cd = inv.getArgument(4);
            cd.getFuture().complete(new CorrelationData.Confirm(true, null));
            return null;
        }).when(rt).convertAndSend(anyString(), anyString(), any(Object.class), any(org.springframework.amqp.core.MessagePostProcessor.class), any(CorrelationData.class));

        String id = new CategoriaEventPublisher(rt, "catalogo.exchange", "categoria.creada", 1000).publicarCategoriaCreada(categoria());
        assertNotNull(id);
    }

    @Test
    @DisplayName("Con nack lanza EventoNoConfirmadoException con categoriaId")
    void nackLanzaExcepcion() {
        RabbitTemplate rt = mock(RabbitTemplate.class);
        doAnswer(inv -> {
            CorrelationData cd = inv.getArgument(4);
            cd.getFuture().complete(new CorrelationData.Confirm(false, "sin permisos"));
            return null;
        }).when(rt).convertAndSend(anyString(), anyString(), any(Object.class), any(org.springframework.amqp.core.MessagePostProcessor.class), any(CorrelationData.class));

        EventoNoConfirmadoException ex = assertThrows(EventoNoConfirmadoException.class,
                () -> new CategoriaEventPublisher(rt, "catalogo.exchange", "categoria.creada", 1000).publicarCategoriaCreada(categoria()));
        assertEquals(10L, ex.getCategoriaId());
    }

    @Test
    @DisplayName("Broker caído (sin conexión) produce error controlado")
    void brokerCaido() {
        RabbitTemplate rt = mock(RabbitTemplate.class);
        doThrow(new AmqpConnectException(new IOException("conexión rechazada")))
                .when(rt).convertAndSend(anyString(), anyString(), any(Object.class), any(org.springframework.amqp.core.MessagePostProcessor.class), any(CorrelationData.class));

        assertThrows(EventoNoConfirmadoException.class,
                () -> new CategoriaEventPublisher(rt, "catalogo.exchange", "categoria.creada", 1000).publicarCategoriaCreada(categoria()));
    }
}
