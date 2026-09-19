-- V5 — Carga masiva de reseñas (una sola vez, con generate_series, sin INSERT por fila).
--
-- Determinismo: igual que V3, no se usa random() ni now(). Cada valor sale de
-- aritmética modular sobre (plato_id, número de reseña), así que esta migración
-- produce EXACTAMENTE los mismos datos en el entorno local y en la VM de
-- producción. Eso permite que los archivos subidos al bucket S3 coincidan con lo
-- que devuelve la API sin importar desde dónde se haya hecho el volcado.
--
-- Dos detalles que hacen que los datos no se vean generados:
--   * Cada plato tiene su propio "nivel de calidad" (q), que corre los umbrales de
--     la distribución de notas. Así el promedio por plato va de ~3.6 a ~4.6 y la
--     consulta "platos mejor calificados" devuelve un ranking real, no un empate.
--   * Los selectores usan un término cuadrático (id*i) además de los lineales. Sin
--     eso los residuos se reparten de forma perfectamente uniforme y salen
--     porcentajes exactos (10.00% por día de semana), que delatan el seed.
--
-- Cantidad de reseñas por plato: entre 20 y 200, desigual.
-- Fechas: 78 semanas desde el 03-mar-2025, con más densidad en viernes, sábado y
-- domingo, y horario de atención (11:00 a 21:59).

WITH pools AS (
    SELECT
        ARRAY['No me gustó nada',
              'Muy salado y además llegó frío',
              'Mala experiencia, no lo recomiendo',
              'Pésima preparación, tuve que devolverlo',
              'Nada que ver con la foto de la carta',
              'Lo peor que he pedido acá']::text[] AS c1,
        ARRAY['Me esperaba más por el precio',
              'Llegó tibio y sin mucho sabor',
              'La porción es pequeña para lo que cuesta',
              'No me convenció, le falta trabajo',
              'Estuvo desabrido, no lo repetiría',
              'Demasiado aceitoso para mi gusto']::text[] AS c2,
        ARRAY['Cumple, nada del otro mundo',
              'Estuvo bien, pero le faltó sazón',
              'Aceptable para el precio',
              'Ni bueno ni malo, del montón',
              'Correcto, aunque la porción es justa',
              'Pasable, esperaba un poco más']::text[] AS c3,
        ARRAY['Muy bueno, lo recomiendo',
              'Rico y bien servido, aunque tardó un poco',
              'Buen sabor y buena presentación',
              'Me gustó bastante, volvería a pedirlo',
              'Muy rico, solo le faltó un poco más de sazón',
              'Buena relación precio calidad']::text[] AS c4,
        ARRAY['Excelente, de lo mejor que he probado',
              'Delicioso. Volvería solo por este plato',
              'Sabor impecable y porción generosa',
              'Superó mis expectativas, lo recomiendo sin dudarlo',
              'Preparación perfecta y muy bien servido',
              'Un clásico bien hecho, nada que corregir']::text[] AS c5,
        ARRAY['Ana Quispe','Luis Mendoza','María Ccahuana','Jorge Palomino','Rosa Huamán',
              'Carlos Vílchez','Patricia Ramos','Miguel Ángel Rojas','Lucía Cárdenas','Diego Salazar',
              'Fiorella Chávez','Renzo Aguilar','Claudia Espinoza','Álvaro Ponce','Gabriela Flores',
              'Sebastián Ríos','Andrea Bustamante','Marco Zevallos','Valeria Torres','Julio Paredes',
              'Milagros Ávila','Kevin Gutiérrez','Silvia Coronado','Óscar Benavides','Melissa Arana',
              'Iván Castillo','Paola Luján','Fernando Ríos','Karla Medina','Bruno Delgado',
              'Sandra Ipanaqué','Héctor Valverde','Camila Loayza','Raúl Ñahui','Jimena Sotelo',
              'Christian Barreto','Teresa Manrique','Nicolás Guevara','Elena Puma','Martín Alcántara']::text[] AS autores
),
-- Nivel de calidad por plato: q en [-12, 12]. Corre los umbrales de la distribución
-- de notas, de modo que cada plato tenga su propio promedio.
calidad AS (
    SELECT
        p.id,
        (((p.id * 53) % 25) - 12)                   AS q,
        (20 + ((p.id * 37) % 181))::int             AS n_resenas
    FROM platos p
)
INSERT INTO resenas (plato_id, calificacion, comentario, autor, creado_en)
SELECT
    k.id,
    cal.calificacion,
    CASE cal.calificacion
        WHEN 1 THEN po.c1[((k.id * 7 + g.i * 13 + k.id * g.i) % 6) + 1]
        WHEN 2 THEN po.c2[((k.id * 7 + g.i * 13 + k.id * g.i) % 6) + 1]
        WHEN 3 THEN po.c3[((k.id * 7 + g.i * 13 + k.id * g.i) % 6) + 1]
        WHEN 4 THEN po.c4[((k.id * 7 + g.i * 13 + k.id * g.i) % 6) + 1]
        ELSE        po.c5[((k.id * 7 + g.i * 13 + k.id * g.i) % 6) + 1]
    END,
    po.autores[((k.id * 11 + g.i * 29 + k.id * g.i * 3) % 40) + 1],
    TIMESTAMPTZ '2025-03-03 00:00:00+00'
        + ( ((k.id * 19 + g.i * 41 + k.id * g.i * 5) % 78) * 7
            + CASE (k.id * k.id * 3 + g.i * g.i * 7 + k.id * g.i) % 20
                  WHEN 0 THEN 5 WHEN 1 THEN 5 WHEN 2 THEN 5
                  WHEN 3 THEN 5 WHEN 4 THEN 5                               -- sábado  (~25%)
                  WHEN 5 THEN 6 WHEN 6 THEN 6 WHEN 7 THEN 6 WHEN 8 THEN 6   -- domingo (~20%)
                  WHEN 9 THEN 4 WHEN 10 THEN 4 WHEN 11 THEN 4 WHEN 12 THEN 4 -- viernes (~20%)
                  WHEN 13 THEN 3 WHEN 14 THEN 3                             -- jueves  (~10%)
                  WHEN 15 THEN 2 WHEN 16 THEN 2                             -- miércoles
                  WHEN 17 THEN 1 WHEN 18 THEN 1                             -- martes
                  ELSE 0                                                    -- lunes   (~5%)
              END
          ) * INTERVAL '1 day'
        + (11 + ((k.id * 5 + g.i * 3 + k.id * g.i) % 11)) * INTERVAL '1 hour'
        + ((k.id * 13 + g.i * 7 + k.id * g.i * 2) % 60) * INTERVAL '1 minute'
FROM calidad k
CROSS JOIN pools po
CROSS JOIN LATERAL generate_series(1, k.n_resenas) AS g(i)
CROSS JOIN LATERAL (
    SELECT CASE
               WHEN (k.id * 31 + g.i * 17 + k.id * g.i * 7) % 100 < greatest(1,  3 - k.q / 3)      THEN 1
               WHEN (k.id * 31 + g.i * 17 + k.id * g.i * 7) % 100 < greatest(4,  9 - k.q / 2)      THEN 2
               WHEN (k.id * 31 + g.i * 17 + k.id * g.i * 7) % 100 < greatest(10, 22 - k.q)         THEN 3
               WHEN (k.id * 31 + g.i * 17 + k.id * g.i * 7) % 100 < greatest(25, 51 - k.q * 2)     THEN 4
               ELSE 5
           END::smallint AS calificacion
) cal;
