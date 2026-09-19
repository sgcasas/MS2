package pe.utec.cs2032.ms2.resena;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface ResenaRepository extends JpaRepository<Resena, Long> {

    Page<Resena> findByPlatoIdOrderByCreadoEnDesc(Long platoId, Pageable pageable);

    @Query("""
            SELECT r.platoId AS platoId, AVG(r.calificacion) AS promedio, COUNT(r) AS total
            FROM Resena r
            WHERE r.platoId IN :ids
            GROUP BY r.platoId
            """)
    List<ResumenResenas> resumenPorPlatos(@Param("ids") Collection<Long> ids);
}
