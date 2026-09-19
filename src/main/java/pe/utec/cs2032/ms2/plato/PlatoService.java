package pe.utec.cs2032.ms2.plato;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.utec.cs2032.ms2.categoria.Categoria;
import pe.utec.cs2032.ms2.categoria.CategoriaService;
import pe.utec.cs2032.ms2.common.ConflictException;
import pe.utec.cs2032.ms2.common.NotFoundException;
import pe.utec.cs2032.ms2.plato.dto.PlatoRequest;
import pe.utec.cs2032.ms2.plato.dto.PlatoResponse;
import pe.utec.cs2032.ms2.plato.dto.PreciosResponse;
import pe.utec.cs2032.ms2.resena.ResenaService;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class PlatoService {

    private static final int TOPE_SIZE = 500;

    private final PlatoRepository platoRepository;
    private final CategoriaService categoriaService;
    private final ResenaService resenaService;

    @Transactional(readOnly = true)
    public Page<PlatoResponse> listar(int page, int size, Long categoriaId, Boolean disponible, String q) {
        int sizeSeguro = Math.min(size, TOPE_SIZE);
        Pageable pageable = PageRequest.of(page, sizeSeguro);

        Specification<Plato> spec = Specification.allOf(
                PlatoSpecifications.categoriaId(categoriaId),
                PlatoSpecifications.disponible(disponible),
                PlatoSpecifications.nombreContiene(q)
        );

        Page<Plato> pagina = platoRepository.findAll(spec, pageable);

        // Una sola consulta para el agregado de reseñas de toda la página:
        // sin esto serían N consultas (una por plato) al armar la respuesta.
        List<Long> ids = pagina.getContent().stream().map(Plato::getId).toList();
        Map<Long, ResenaService.Agregado> agregados = resenaService.agregadoPorPlatos(ids);

        return pagina.map(plato -> {
            ResenaService.Agregado agregado =
                    agregados.getOrDefault(plato.getId(), ResenaService.Agregado.VACIO);
            return PlatoResponse.from(plato, agregado.calificacionPromedio(), agregado.totalResenas());
        });
    }

    @Transactional(readOnly = true)
    public PlatoResponse obtener(Long id) {
        Plato plato = buscarOrLanzar(id);
        ResenaService.Agregado agregado = resenaService.agregadoPorPlatos(List.of(id))
                .getOrDefault(id, ResenaService.Agregado.VACIO);
        return PlatoResponse.from(plato, agregado.calificacionPromedio(), agregado.totalResenas());
    }

    @Transactional
    public PlatoResponse crear(PlatoRequest request) {
        Categoria categoria = categoriaService.buscarOrLanzar(request.categoriaId());
        if (platoRepository.existsByCategoriaIdAndNombreIgnoreCase(request.categoriaId(), request.nombre())) {
            throw new ConflictException("Ya existe un plato con el nombre " + request.nombre() + " en esa categoría");
        }

        Plato plato = new Plato();
        aplicarRequest(plato, request, categoria);
        Instant ahora = Instant.now();
        plato.setActualizadoEn(ahora);

        return PlatoResponse.from(platoRepository.save(plato));
    }

    @Transactional
    public PlatoResponse actualizar(Long id, PlatoRequest request) {
        Plato plato = buscarOrLanzar(id);
        Categoria categoria = categoriaService.buscarOrLanzar(request.categoriaId());

        boolean cambiaClaveUnica = !plato.getCategoria().getId().equals(request.categoriaId())
                || !plato.getNombre().equalsIgnoreCase(request.nombre());
        if (cambiaClaveUnica
                && platoRepository.existsByCategoriaIdAndNombreIgnoreCase(request.categoriaId(), request.nombre())) {
            throw new ConflictException("Ya existe un plato con el nombre " + request.nombre() + " en esa categoría");
        }

        aplicarRequest(plato, request, categoria);
        plato.setActualizadoEn(Instant.now());

        return PlatoResponse.from(platoRepository.save(plato));
    }

    @Transactional
    public void eliminar(Long id) {
        Plato plato = buscarOrLanzar(id);
        platoRepository.delete(plato);
    }

    @Transactional(readOnly = true)
    public PreciosResponse precios(List<Long> ids) {
        List<Plato> encontrados = platoRepository.findByIdIn(ids);

        List<PreciosResponse.PrecioItem> items = encontrados.stream()
                .map(p -> new PreciosResponse.PrecioItem(p.getId(), p.getNombre(), p.getPrecio(), p.isDisponible()))
                .toList();

        List<Long> idsEncontrados = encontrados.stream().map(Plato::getId).toList();
        List<Long> noEncontrados = new ArrayList<>(ids);
        noEncontrados.removeAll(idsEncontrados);

        return new PreciosResponse(items, noEncontrados);
    }

    private void aplicarRequest(Plato plato, PlatoRequest request, Categoria categoria) {
        plato.setCategoria(categoria);
        plato.setNombre(request.nombre());
        plato.setDescripcion(request.descripcion());
        plato.setPrecio(request.precio());
        plato.setDisponible(request.disponible() == null || request.disponible());
        plato.setTiempoPreparacionMin(request.tiempoPreparacionMin());
        plato.setCalorias(request.calorias());
        plato.setImagenUrl(request.imagenUrl());
    }

    private Plato buscarOrLanzar(Long id) {
        return platoRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("No existe el plato con id " + id));
    }
}
