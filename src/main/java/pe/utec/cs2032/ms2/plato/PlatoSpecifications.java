package pe.utec.cs2032.ms2.plato;

import org.springframework.data.jpa.domain.Specification;

public final class PlatoSpecifications {

    private PlatoSpecifications() {
    }

    public static Specification<Plato> categoriaId(Long categoriaId) {
        return (root, query, cb) -> categoriaId == null
                ? null
                : cb.equal(root.get("categoria").get("id"), categoriaId);
    }

    public static Specification<Plato> disponible(Boolean disponible) {
        return (root, query, cb) -> disponible == null
                ? null
                : cb.equal(root.get("disponible"), disponible);
    }

    public static Specification<Plato> nombreContiene(String q) {
        return (root, query, cb) -> (q == null || q.isBlank())
                ? null
                : cb.like(cb.lower(root.get("nombre")), "%" + q.toLowerCase() + "%");
    }
}
