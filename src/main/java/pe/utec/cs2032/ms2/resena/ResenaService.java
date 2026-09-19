package pe.utec.cs2032.ms2.resena;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.utec.cs2032.ms2.common.NotFoundException;
import pe.utec.cs2032.ms2.plato.PlatoRepository;
import pe.utec.cs2032.ms2.resena.dto.ResenaResponse;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ResenaService {

    private static final int TOPE_SIZE = 200;

    private final ResenaRepository resenaRepository;
    private final PlatoRepository platoRepository;

    @Transactional(readOnly = true)
    public Page<ResenaResponse> listarPorPlato(Long platoId, int page, int size) {
        if (!platoRepository.existsById(platoId)) {
            throw new NotFoundException("No existe el plato con id " + platoId);
        }
        int sizeSeguro = Math.min(Math.max(size, 1), TOPE_SIZE);
        return resenaRepository
                .findByPlatoIdOrderByCreadoEnDesc(platoId, PageRequest.of(page, sizeSeguro))
                .map(ResenaResponse::from);
    }

    /**
     * Agregado (promedio y total) de varios platos en una sola consulta.
     * Los platos sin reseñas simplemente no aparecen en el mapa.
     */
    @Transactional(readOnly = true)
    public Map<Long, Agregado> agregadoPorPlatos(Collection<Long> platoIds) {
        if (platoIds == null || platoIds.isEmpty()) {
            return Map.of();
        }
        List<ResumenResenas> filas = resenaRepository.resumenPorPlatos(platoIds);
        Map<Long, Agregado> porPlato = new HashMap<>(filas.size());
        for (ResumenResenas fila : filas) {
            BigDecimal promedio = fila.getPromedio() == null
                    ? null
                    : BigDecimal.valueOf(fila.getPromedio()).setScale(2, RoundingMode.HALF_UP);
            porPlato.put(fila.getPlatoId(), new Agregado(promedio, fila.getTotal()));
        }
        return porPlato;
    }

    public record Agregado(BigDecimal calificacionPromedio, long totalResenas) {
        public static final Agregado VACIO = new Agregado(null, 0L);
    }
}
