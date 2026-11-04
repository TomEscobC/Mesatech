package com.mesatech.solicitudes.messaging;

import com.mesatech.solicitudes.model.CategoriaCopia;
import com.mesatech.solicitudes.repository.CategoriaCopiaRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class CategoriaListenerTest {

    private final CategoriaCopiaRepository repo = mock(CategoriaCopiaRepository.class);
    private final CategoriaListener listener = new CategoriaListener(repo);

    @Test
    @DisplayName("Guarda la copia conservando el categoriaId de origen")
    void guardaCopiaConIdDeOrigen() {
        listener.onCategoriaCreada(new CategoriaCreadaMessage("ev-1", "CATEGORIA_CREADA", "2026-11-04T20:00:00Z", 42L, "Redes"));
        ArgumentCaptor<CategoriaCopia> cap = ArgumentCaptor.forClass(CategoriaCopia.class);
        verify(repo).save(cap.capture());
        assertEquals(42L, cap.getValue().getCategoriaId());
        assertEquals("Redes", cap.getValue().getNombre());
        assertEquals("ev-1", cap.getValue().getEventId());
    }

    @Test
    @DisplayName("Evento inválido propaga excepción (no se confirma el mensaje) y no guarda")
    void eventoInvalidoPropagaError() {
        assertThrows(IllegalArgumentException.class,
                () -> listener.onCategoriaCreada(new CategoriaCreadaMessage("ev-2", "CATEGORIA_CREADA", null, null, "X")));
        verify(repo, never()).save(any());
    }

    @Test
    @DisplayName("Error de BD se propaga para que el mensaje se reencole")
    void errorDeBdSePropaga() {
        when(repo.save(any())).thenThrow(new RuntimeException("RDS caído"));
        assertThrows(RuntimeException.class,
                () -> listener.onCategoriaCreada(new CategoriaCreadaMessage("ev-3", "CATEGORIA_CREADA", null, 7L, "Y")));
    }
}
