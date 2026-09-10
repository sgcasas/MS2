package pe.utec.cs2032.ms2.categoria;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.utec.cs2032.ms2.categoria.dto.CategoriaRequest;
import pe.utec.cs2032.ms2.categoria.dto.CategoriaResponse;
import pe.utec.cs2032.ms2.common.ConflictException;
import pe.utec.cs2032.ms2.common.NotFoundException;
import pe.utec.cs2032.ms2.plato.PlatoRepository;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CategoriaService {

    private final CategoriaRepository categoriaRepository;
    private final PlatoRepository platoRepository;

    @Transactional(readOnly = true)
    public List<CategoriaResponse> listar() {
        return categoriaRepository.findAll().stream()
                .map(CategoriaResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public CategoriaResponse obtener(Long id) {
        return CategoriaResponse.from(buscarOrLanzar(id));
    }

    @Transactional
    public CategoriaResponse crear(CategoriaRequest request) {
        if (categoriaRepository.existsByNombreIgnoreCase(request.nombre())) {
            throw new ConflictException("Ya existe una categoría con el nombre " + request.nombre());
        }
        Categoria categoria = new Categoria();
        categoria.setNombre(request.nombre());
        categoria.setDescripcion(request.descripcion());
        categoria.setActivo(request.activo() == null || request.activo());
        return CategoriaResponse.from(categoriaRepository.save(categoria));
    }

    @Transactional
    public void eliminar(Long id) {
        Categoria categoria = buscarOrLanzar(id);
        if (platoRepository.existsByCategoriaId(id)) {
            throw new ConflictException("No se puede eliminar la categoría porque tiene platos asociados");
        }
        categoriaRepository.delete(categoria);
    }

    public Categoria buscarOrLanzar(Long id) {
        return categoriaRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("No existe la categoría con id " + id));
    }
}
