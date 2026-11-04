package com.mesatech.solicitudes.repository;

import com.mesatech.solicitudes.model.CategoriaCopia;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface CategoriaCopiaRepository extends JpaRepository<CategoriaCopia, Long> {
    List<CategoriaCopia> findAllByOrderByNombreAsc();
}
