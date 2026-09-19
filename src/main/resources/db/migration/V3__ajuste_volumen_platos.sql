-- V3 — Ajuste del volumen de platos a una carta realista.
--
-- Contexto: V2 sembró 20,500 platos para cumplir "mínimo 20,000 registros" del
-- enunciado. La asesora del curso (19-set-2026) indicó reducir el menú a un tamaño
-- creíble y cumplir el mínimo con otra tabla del mismo microservicio y la misma BD
-- (ver V4/V5: resenas).
--
-- Determinismo: esta migración corre tanto en el entorno local como en la VM de
-- producción del equipo. TODO lo que inserta es determinístico (precios literales,
-- fechas calculadas sobre una constante, resto por aritmética modular sobre el
-- número de fila). Nada de random() ni now(): así los dos entornos quedan con
-- exactamente los mismos datos y los archivos que se suben al bucket S3 coinciden
-- con lo que devuelve la API en cualquier máquina.

-- Las categorías vienen de V2 con creado_en = now(), que es lo único que quedaba
-- dependiendo del momento de la migración. Se fija a una constante para que el
-- volcado de las tres tablas sea idéntico en cualquier entorno.
UPDATE categorias
SET creado_en = TIMESTAMPTZ '2026-01-15 09:00:00+00' + (id || ' minutes')::interval;

TRUNCATE TABLE platos RESTART IDENTITY;

WITH nuevos (categoria, nombre, descripcion, precio) AS (
    VALUES
    -- Entradas frías (3)
    ('Entradas frías', 'Causa limeña de pollo',        'Papa amarilla prensada con ají amarillo y limón, rellena de pollo deshilachado', 19.00),
    ('Entradas frías', 'Papa a la huancaína',          'Papa amarilla en salsa de ají amarillo, queso fresco y leche',                   16.00),
    ('Entradas frías', 'Palta rellena',                'Media palta rellena de ensalada de pollo con mayonesa casera',                   18.00),

    -- Entradas calientes (4)
    ('Entradas calientes', 'Anticuchos de corazón',    'Dos brochetas de corazón de res marinadas en ají panca, con papa y choclo',      24.00),
    ('Entradas calientes', 'Tequeños de queso',        'Seis tequeños de queso con salsa de guacamole',                                  18.00),
    ('Entradas calientes', 'Chicharrón de pescado',    'Trozos de pescado apanados y fritos, con salsa criolla',                         28.00),
    ('Entradas calientes', 'Conchitas a la parmesana', 'Media docena de conchas de abanico gratinadas con parmesano',                    36.00),

    -- Sopas y caldos (3)
    ('Sopas y caldos', 'Caldo de gallina',             'Presa de gallina, fideos, papa y huevo en caldo concentrado',                    22.00),
    ('Sopas y caldos', 'Chupe de camarones',           'Chupe arequipeño con camarones de río, huevo, queso y leche',                    46.00),
    ('Sopas y caldos', 'Parihuela',                    'Caldo concentrado de pescados y mariscos con ají panca',                         44.00),

    -- Ceviches (5)
    ('Ceviches', 'Ceviche clásico',                    'Pescado del día en leche de tigre, cebolla, camote y choclo',                    38.00),
    ('Ceviches', 'Ceviche mixto',                      'Pescado, pulpo, calamar y langostinos en leche de tigre',                        46.00),
    ('Ceviches', 'Ceviche de conchas negras',          'Conchas negras de Tumbes en su jugo con limón y rocoto',                         58.00),
    ('Ceviches', 'Tiradito clásico',                   'Láminas de pescado en leche de tigre de ají amarillo',                           36.00),
    ('Ceviches', 'Leche de tigre',                     'Vaso de leche de tigre con trozos de pescado y chicharrón de calamar',           26.00),

    -- Criollos (7)
    ('Criollos', 'Lomo saltado',                       'Lomo fino salteado al wok con cebolla, tomate, papas fritas y arroz',            46.00),
    ('Criollos', 'Ají de gallina',                     'Gallina deshilachada en crema de ají amarillo, papa, huevo y aceituna',          34.00),
    ('Criollos', 'Seco de res con frejoles',           'Seco de res al culantro con frejoles canarios y arroz',                          42.00),
    ('Criollos', 'Arroz con pollo',                    'Arroz verde al culantro con presa de pollo y salsa criolla',                     32.00),
    ('Criollos', 'Tacu tacu con lomo',                 'Tacu tacu de frejoles coronado con lomo saltado',                                49.00),
    ('Criollos', 'Carapulcra con sopa seca',           'Carapulcra chinchana acompañada de sopa seca',                                   38.00),
    ('Criollos', 'Pollo a la brasa (1/4)',             'Cuarto de pollo a la brasa con papas fritas y ensalada',                         28.00),

    -- Pescados y mariscos (5)
    ('Pescados y mariscos', 'Pescado a lo macho',      'Filete de pescado frito bañado en salsa de mariscos',                            52.00),
    ('Pescados y mariscos', 'Jalea mixta',             'Fritura de pescado y mariscos con yuca y salsa criolla',                         56.00),
    ('Pescados y mariscos', 'Arroz con mariscos',      'Arroz al ají panca con pulpo, calamar, langostinos y choros',                    48.00),
    ('Pescados y mariscos', 'Sudado de pescado',       'Pescado sudado en chicha de jora, cebolla y tomate',                             41.00),
    ('Pescados y mariscos', 'Chicharrón de calamar',   'Anillos de calamar apanados con salsa tártara y yuca',                           30.00),

    -- Carnes (5)
    ('Carnes', 'Bife de chorizo',                      'Corte de 300 g a la parrilla con guarnición a elección',                         64.00),
    ('Carnes', 'Churrasco a lo pobre',                 'Churrasco con plátano frito, papas y huevo',                                     52.00),
    ('Carnes', 'Parrilla mixta para dos',              'Res, pollo, chorizo, anticucho y chuleta con guarniciones',                      96.00),
    ('Carnes', 'Costillar de cerdo BBQ',               'Costillar glaseado en salsa barbacoa con papas rústicas',                        56.00),
    ('Carnes', 'Lomo a la pimienta',                   'Medallón de lomo en salsa de pimienta verde con puré',                           60.00),

    -- Pastas (3)
    ('Pastas', 'Tallarines verdes con bistec',         'Pasta al pesto peruano de albahaca con bistec apanado',                          42.00),
    ('Pastas', 'Fettuccine a la huancaína',            'Fettuccine en salsa huancaína con lomo saltado',                                 44.00),
    ('Pastas', 'Lasaña de carne',                      'Lasaña al horno con ragú de carne y bechamel',                                   36.00),

    -- Chifa (5)
    ('Chifa', 'Arroz chaufa de pollo',                 'Arroz salteado al wok con pollo, cebolla china y tortilla',                      30.00),
    ('Chifa', 'Tallarín saltado especial',             'Tallarines al wok con tres carnes y verduras',                                   40.00),
    ('Chifa', 'Pollo chi jau kay',                     'Pollo apanado en salsa chi jau kay con verduras',                                34.00),
    ('Chifa', 'Wantán frito',                          'Ocho wantanes fritos con salsa de tamarindo',                                    20.00),
    ('Chifa', 'Sopa wantán',                           'Caldo con wantanes rellenos, verduras y cerdo asado',                            26.00),

    -- Guarniciones (2)
    ('Guarniciones', 'Papas fritas',                   'Porción de papas fritas crocantes',                                              12.00),
    ('Guarniciones', 'Arroz blanco',                   'Porción de arroz graneado',                                                       8.00),

    -- Postres (4)
    ('Postres', 'Suspiro a la limeña',                 'Manjar blanco con merengue de oporto y canela',                                  18.00),
    ('Postres', 'Picarones',                           'Seis picarones de zapallo y camote con miel de chancaca',                        16.00),
    ('Postres', 'Mazamorra morada',                    'Mazamorra de maíz morado con frutas secas',                                      14.00),
    ('Postres', 'Cheesecake de maracuyá',              'Cheesecake con coulis de maracuyá',                                              21.00),

    -- Bebidas (4)
    ('Bebidas', 'Chicha morada (jarra)',               'Jarra de chicha morada casera de un litro',                                      20.00),
    ('Bebidas', 'Limonada frozen',                     'Limonada helada batida con hielo',                                               12.00),
    ('Bebidas', 'Pisco sour',                          'Pisco quebranta, limón, jarabe, clara de huevo y amargo',                        26.00),
    ('Bebidas', 'Inca Kola (500 ml)',                  'Botella personal de Inca Kola',                                                   8.00)
),
orden AS (
    SELECT
        c.id                                              AS categoria_id,
        c.nombre                                          AS categoria,
        n.nombre,
        n.descripcion,
        n.precio,
        row_number() OVER (ORDER BY c.id, n.nombre)       AS rn
    FROM nuevos n
    JOIN categorias c ON c.nombre = n.categoria
)
INSERT INTO platos (categoria_id, nombre, descripcion, precio, disponible,
                    tiempo_preparacion_min, calorias, creado_en, actualizado_en)
SELECT
    categoria_id,
    nombre,
    descripcion,
    precio::numeric(10,2),
    -- ~92% disponible; el resto simula platos agotados del día
    (rn % 12) <> 0,
    -- tiempo de preparación por familia de platos
    CASE
        WHEN categoria IN ('Bebidas', 'Guarniciones')                     THEN 3  + (rn * 7  % 8)
        WHEN categoria IN ('Postres', 'Entradas frías')                   THEN 5  + (rn * 7  % 10)
        WHEN categoria IN ('Entradas calientes', 'Ceviches', 'Pastas')    THEN 10 + (rn * 11 % 13)
        WHEN categoria = 'Sopas y caldos'                                 THEN 15 + (rn * 11 % 16)
        ELSE                                                                   18 + (rn * 13 % 23)
    END,
    -- calorías por familia de platos
    CASE
        WHEN categoria = 'Bebidas'                                        THEN 60  + (rn * 29 % 190)
        WHEN categoria = 'Guarniciones'                                   THEN 150 + (rn * 37 % 260)
        WHEN categoria = 'Postres'                                        THEN 250 + (rn * 31 % 310)
        WHEN categoria IN ('Entradas frías', 'Ceviches')                  THEN 180 + (rn * 41 % 280)
        WHEN categoria IN ('Entradas calientes', 'Sopas y caldos')        THEN 220 + (rn * 43 % 320)
        WHEN categoria = 'Pastas'                                         THEN 450 + (rn * 53 % 420)
        ELSE                                                                   480 + (rn * 59 % 520)
    END,
    -- fechas determinísticas: la carta se "creó" el 15-ene-2026, un plato por minuto
    TIMESTAMPTZ '2026-01-15 10:00:00+00' + (rn || ' minutes')::interval,
    TIMESTAMPTZ '2026-01-15 10:00:00+00' + (rn || ' minutes')::interval
FROM orden
ORDER BY rn;
