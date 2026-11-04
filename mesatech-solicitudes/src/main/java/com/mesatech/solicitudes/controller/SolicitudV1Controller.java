package com.mesatech.solicitudes.controller;

import com.mesatech.solicitudes.dto.AsignarOperadorDTO;
import com.mesatech.solicitudes.dto.CambiarEstadoDTO;
import com.mesatech.solicitudes.dto.SolicitudRequestDTO;
import com.mesatech.solicitudes.dto.SolicitudResponseV1DTO;
import com.mesatech.solicitudes.exception.BusinessRuleException;
import com.mesatech.solicitudes.model.CategoriaCopia;
import com.mesatech.solicitudes.model.EstadoSolicitud;
import com.mesatech.solicitudes.repository.CategoriaCopiaRepository;
import com.mesatech.solicitudes.service.SolicitudService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/v1/solicitudes")
public class SolicitudV1Controller {

    private final SolicitudService solicitudService;
    private final CategoriaCopiaRepository categoriaCopiaRepository;

    public SolicitudV1Controller(SolicitudService solicitudService, CategoriaCopiaRepository categoriaCopiaRepository) {
        this.solicitudService = solicitudService;
        this.categoriaCopiaRepository = categoriaCopiaRepository;
    }

    /** Categorías disponibles localmente (copia recibida por RabbitMQ). No consulta la BD de Catálogo. */
    @GetMapping("/categorias")
    public ResponseEntity<List<CategoriaCopia>> listarCategoriasLocales() {
        return ResponseEntity.ok(categoriaCopiaRepository.findAllByOrderByNombreAsc());
    }

    @GetMapping
    public ResponseEntity<List<SolicitudResponseV1DTO>> listarSolicitudes(
            @RequestParam(required = false) String usuarioSolicitante,
            @RequestParam(required = false) String usuarioAsignado,
            @RequestParam(required = false) EstadoSolicitud estado) {
        return ResponseEntity.ok(solicitudService.listarTodasV1(usuarioSolicitante, usuarioAsignado, estado));
    }

    @GetMapping("/{id}")
    public ResponseEntity<SolicitudResponseV1DTO> obtenerPorId(@PathVariable Long id) {
        return ResponseEntity.ok(solicitudService.obtenerPorIdV1(id));
    }

    @PostMapping
    public ResponseEntity<SolicitudResponseV1DTO> crearSolicitud(@Valid @RequestBody SolicitudRequestDTO dto) {
        if (dto.getCategoriaId() != null) {
            CategoriaCopia copia = categoriaCopiaRepository.findById(dto.getCategoriaId())
                    .orElseThrow(() -> new BusinessRuleException("La categoría " + dto.getCategoriaId()
                            + " aún no está disponible en Solicitudes (la copia es asíncrona). Reintente en unos segundos."));
            dto.setCategoria(copia.getNombre());
        }
        if (dto.getCategoria() == null || dto.getCategoria().isBlank()) {
            throw new BusinessRuleException("La categoría es obligatoria (categoriaId o categoria)");
        }
        SolicitudResponseV1DTO creada = solicitudService.crearSolicitud(dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(creada);
    }

    @PutMapping("/{id}/estado")
    public ResponseEntity<SolicitudResponseV1DTO> cambiarEstado(
            @PathVariable Long id,
            @Valid @RequestBody CambiarEstadoDTO dto) {
        return ResponseEntity.ok(solicitudService.cambiarEstado(id, dto));
    }

    @PutMapping("/{id}/asignar")
    public ResponseEntity<SolicitudResponseV1DTO> asignarOperador(
            @PathVariable Long id,
            @Valid @RequestBody AsignarOperadorDTO dto) {
        return ResponseEntity.ok(solicitudService.asignarOperador(id, dto));
    }
}
