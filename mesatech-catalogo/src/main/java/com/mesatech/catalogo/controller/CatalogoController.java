package com.mesatech.catalogo.controller;

import com.mesatech.catalogo.dto.CategoriaDTO;
import com.mesatech.catalogo.dto.PrioridadDTO;
import com.mesatech.catalogo.messaging.CategoriaEventPublisher;
import com.mesatech.catalogo.service.CatalogoService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/v1/catalogo")
public class CatalogoController {

    private final CatalogoService catalogoService;
    private final CategoriaEventPublisher eventPublisher;

    public CatalogoController(CatalogoService catalogoService, CategoriaEventPublisher eventPublisher) {
        this.catalogoService = catalogoService;
        this.eventPublisher = eventPublisher;
    }

    // --- Categorías ---
    @GetMapping("/categorias")
    public ResponseEntity<List<CategoriaDTO>> listarCategorias(@RequestParam(defaultValue = "false") boolean soloActivas) {
        return ResponseEntity.ok(catalogoService.listarCategorias(soloActivas));
    }

    @GetMapping("/categorias/{id}")
    public ResponseEntity<CategoriaDTO> obtenerCategoria(@PathVariable Long id) {
        return ResponseEntity.ok(catalogoService.obtenerCategoriaPorId(id));
    }

    @PostMapping("/categorias")
    public ResponseEntity<CategoriaDTO> crearCategoria(@Valid @RequestBody CategoriaDTO dto) {
        // 1) Persistir (la transacción termina y hace commit dentro del servicio)
        CategoriaDTO creada = catalogoService.crearCategoria(dto);
        // 2) Publicar como operación separada; si falla, el registro ya quedó guardado (ver GlobalExceptionHandler)
        eventPublisher.publicarCategoriaCreada(creada);
        return ResponseEntity.status(HttpStatus.CREATED).body(creada);
    }

    @PutMapping("/categorias/{id}")
    public ResponseEntity<CategoriaDTO> actualizarCategoria(@PathVariable Long id, @Valid @RequestBody CategoriaDTO dto) {
        return ResponseEntity.ok(catalogoService.actualizarCategoria(id, dto));
    }

    @DeleteMapping("/categorias/{id}")
    public ResponseEntity<Void> eliminarCategoria(@PathVariable Long id) {
        catalogoService.eliminarCategoria(id);
        return ResponseEntity.noContent().build();
    }

    // --- Prioridades ---
    @GetMapping("/prioridades")
    public ResponseEntity<List<PrioridadDTO>> listarPrioridades(@RequestParam(defaultValue = "false") boolean soloActivas) {
        return ResponseEntity.ok(catalogoService.listarPrioridades(soloActivas));
    }

    @GetMapping("/prioridades/{id}")
    public ResponseEntity<PrioridadDTO> obtenerPrioridad(@PathVariable Long id) {
        return ResponseEntity.ok(catalogoService.obtenerPrioridadPorId(id));
    }

    @PostMapping("/prioridades")
    public ResponseEntity<PrioridadDTO> crearPrioridad(@Valid @RequestBody PrioridadDTO dto) {
        return ResponseEntity.status(HttpStatus.CREATED).body(catalogoService.crearPrioridad(dto));
    }

    @PutMapping("/prioridades/{id}")
    public ResponseEntity<PrioridadDTO> actualizarPrioridad(@PathVariable Long id, @Valid @RequestBody PrioridadDTO dto) {
        return ResponseEntity.ok(catalogoService.actualizarPrioridad(id, dto));
    }

    @DeleteMapping("/prioridades/{id}")
    public ResponseEntity<Void> eliminarPrioridad(@PathVariable Long id) {
        catalogoService.eliminarPrioridad(id);
        return ResponseEntity.noContent().build();
    }
}
