-- V4 — Tabla de reseñas.
--
-- Es la tabla que cumple el "mínimo 20,000 registros" que pide el enunciado del
-- curso, dentro del mismo microservicio y la misma base de datos que platos
-- (confirmado por la asesora del curso el 19-set-2026). El menú quedó en ~210
-- platos realistas en V3.

CREATE TABLE resenas (
    id           BIGSERIAL PRIMARY KEY,
    plato_id     BIGINT      NOT NULL REFERENCES platos(id) ON DELETE CASCADE,
    calificacion SMALLINT    NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    comentario   VARCHAR(400),
    autor        VARCHAR(80) NOT NULL,
    creado_en    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_resenas_plato ON resenas (plato_id);
CREATE INDEX idx_resenas_creado_en ON resenas (creado_en);
CREATE INDEX idx_resenas_calificacion ON resenas (calificacion);
