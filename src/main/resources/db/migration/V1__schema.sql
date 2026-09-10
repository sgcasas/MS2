CREATE TABLE categorias (
    id          BIGSERIAL PRIMARY KEY,
    nombre      VARCHAR(80)  NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    activo      BOOLEAN      NOT NULL DEFAULT true,
    creado_en   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE platos (
    id                     BIGSERIAL PRIMARY KEY,
    categoria_id           BIGINT       NOT NULL REFERENCES categorias(id) ON DELETE RESTRICT,
    nombre                 VARCHAR(120) NOT NULL,
    descripcion            VARCHAR(400),
    precio                 NUMERIC(10,2) NOT NULL CHECK (precio > 0),
    disponible             BOOLEAN      NOT NULL DEFAULT true,
    tiempo_preparacion_min INT,
    calorias               INT,
    imagen_url             VARCHAR(300),
    creado_en              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_platos_categoria_nombre UNIQUE (categoria_id, nombre)
);

CREATE INDEX idx_platos_categoria ON platos (categoria_id);
CREATE INDEX idx_platos_disponible ON platos (disponible);
CREATE INDEX idx_platos_nombre_lower ON platos (lower(nombre));
