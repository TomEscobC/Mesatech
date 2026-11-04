package com.mesatech.solicitudes.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/** Copia local (RDS Solicitudes) de una categoría creada en Catálogo. categoria_id = id de origen. */
@Entity
@Table(name = "categoria_copia")
public class CategoriaCopia {

    @Id
    @Column(name = "categoria_id")
    private Long categoriaId;

    @Column(nullable = false, length = 100)
    private String nombre;

    @Column(name = "event_id", nullable = false, length = 64)
    private String eventId;

    @Column(name = "fecha_evento", length = 40)
    private String fechaEvento;

    @Column(name = "fecha_recepcion", nullable = false)
    private LocalDateTime fechaRecepcion;

    public CategoriaCopia() {
    }

    public CategoriaCopia(Long categoriaId, String nombre, String eventId, String fechaEvento) {
        this.categoriaId = categoriaId;
        this.nombre = nombre;
        this.eventId = eventId;
        this.fechaEvento = fechaEvento;
        this.fechaRecepcion = LocalDateTime.now();
    }

    public Long getCategoriaId() { return categoriaId; }
    public String getNombre() { return nombre; }
    public String getEventId() { return eventId; }
    public String getFechaEvento() { return fechaEvento; }
    public LocalDateTime getFechaRecepcion() { return fechaRecepcion; }
}
