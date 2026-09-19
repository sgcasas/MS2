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
    -- Entradas frías (14)
    ('Entradas frías', 'Causa limeña de pollo',        'Papa amarilla prensada con ají amarillo y limón, rellena de pollo deshilachado', 19.00),
    ('Entradas frías', 'Causa de atún',                'Causa limeña rellena de atún con mayonesa y palta',                              21.00),
    ('Entradas frías', 'Causa de cangrejo',            'Causa de papa amarilla rellena de cangrejo con salsa golf',                      28.00),
    ('Entradas frías', 'Palta rellena',                'Media palta rellena de ensalada de pollo con mayonesa casera',                   18.00),
    ('Entradas frías', 'Ensalada rusa',                'Papa, zanahoria y arvejas con mayonesa, servida fría',                           14.00),
    ('Entradas frías', 'Papa a la huancaína',          'Papa amarilla en salsa de ají amarillo, queso fresco y leche',                   16.00),
    ('Entradas frías', 'Ocopa arequipeña',             'Papa en salsa de huacatay, maní y ají mirasol',                                  17.00),
    ('Entradas frías', 'Solterito arequipeño',         'Habas, choclo, queso fresco, tomate y aceituna de botija',                       16.00),
    ('Entradas frías', 'Rocoto relleno frío',          'Rocoto macerado relleno de carne, servido a temperatura ambiente',               22.00),
    ('Entradas frías', 'Choclo con queso',             'Choclo serrano tierno con queso fresco de Cajamarca',                            13.00),
    ('Entradas frías', 'Tiradito de lenguado',         'Láminas de lenguado en crema de ají amarillo y limón',                           34.00),
    ('Entradas frías', 'Pulpo al olivo',               'Pulpo en láminas con salsa de aceituna de botija y mayonesa',                    38.00),
    ('Entradas frías', 'Ensalada de quinua',           'Quinua blanca con palta, tomate cherry y vinagreta de limón',                    20.00),
    ('Entradas frías', 'Ensalada Caesar de pollo',     'Lechuga romana, pollo a la plancha, crotones y aderezo Caesar',                  24.00),

    -- Entradas calientes (16)
    ('Entradas calientes', 'Anticuchos de corazón',    'Dos brochetas de corazón de res marinadas en ají panca, con papa y choclo',      24.00),
    ('Entradas calientes', 'Anticuchos de pollo',      'Brochetas de pollo en ají panca con papa dorada',                                21.00),
    ('Entradas calientes', 'Chicharrón de pescado',    'Trozos de pescado apanados y fritos, con salsa criolla',                         28.00),
    ('Entradas calientes', 'Chicharrón de calamar',    'Anillos de calamar apanados con salsa tártara',                                  30.00),
    ('Entradas calientes', 'Choritos a la chalaca',    'Choros abiertos con cebolla, tomate, choclo y limón',                            22.00),
    ('Entradas calientes', 'Conchitas a la parmesana', 'Media docena de conchas de abanico gratinadas con parmesano',                    36.00),
    ('Entradas calientes', 'Tequeños de queso',        'Seis tequeños de queso con salsa de guacamole',                                  18.00),
    ('Entradas calientes', 'Tequeños de lomo',         'Seis tequeños rellenos de lomo saltado con salsa huancaína',                     24.00),
    ('Entradas calientes', 'Yuquitas fritas',          'Bastones de yuca frita con salsa huancaína',                                     14.00),
    ('Entradas calientes', 'Papa rellena',             'Papa rellena de carne, pasas y huevo, con salsa criolla',                        16.00),
    ('Entradas calientes', 'Rocoto relleno',           'Rocoto relleno de carne y queso, gratinado al horno con pastel de papa',         25.00),
    ('Entradas calientes', 'Empanada de ají de gallina','Dos empanadas horneadas rellenas de ají de gallina',                            17.00),
    ('Entradas calientes', 'Salchipapa de la casa',    'Papas fritas con salchicha, huevo frito y salsas de la casa',                    19.00),
    ('Entradas calientes', 'Chicharrón de chancho',    'Panceta de cerdo frita con camote y salsa criolla',                              26.00),
    ('Entradas calientes', 'Langostinos al ajillo',    'Seis langostinos salteados en ajo, mantequilla y vino blanco',                   38.00),
    ('Entradas calientes', 'Choclo con rocoto',        'Choclo desgranado salteado con rocoto y queso',                                  15.00),

    -- Sopas y caldos (14)
    ('Sopas y caldos', 'Caldo de gallina',             'Presa de gallina, fideos, papa y huevo en caldo concentrado',                    22.00),
    ('Sopas y caldos', 'Chupe de camarones',           'Chupe arequipeño con camarones de río, huevo, queso y leche',                    46.00),
    ('Sopas y caldos', 'Chupe de pescado',             'Chupe con filete de pescado, papa, arroz y leche',                               32.00),
    ('Sopas y caldos', 'Parihuela',                    'Caldo concentrado de pescados y mariscos con ají panca',                         44.00),
    ('Sopas y caldos', 'Sopa criolla',                 'Sopa de carne picada, fideos cabello de ángel, leche y huevo',                   20.00),
    ('Sopas y caldos', 'Aguadito de pollo',            'Sopa espesa de pollo, culantro, arroz y verduras',                               21.00),
    ('Sopas y caldos', 'Sopa a la minuta',             'Carne molida, fideos, leche y huevo escalfado',                                  19.00),
    ('Sopas y caldos', 'Consomé de pollo',             'Caldo claro de pollo con fideos y culantro',                                     16.00),
    ('Sopas y caldos', 'Chairo paceño',                'Sopa de chuño, carne de res, verduras y hierbas andinas',                        24.00),
    ('Sopas y caldos', 'Menestrón',                    'Sopa de verduras, fideos y albahaca con queso parmesano',                        22.00),
    ('Sopas y caldos', 'Sancochado',                   'Caldo de res con papa, yuca, camote, choclo y col',                              34.00),
    ('Sopas y caldos', 'Caldo verde',                  'Caldo serrano con huevo, queso y culantro',                                      18.00),
    ('Sopas y caldos', 'Crema de zapallo',             'Crema de zapallo loche con crotones',                                            17.00),
    ('Sopas y caldos', 'Shambar',                      'Sopa trujillana de trigo, menestras y carne de cerdo',                           23.00),

    -- Ceviches (16)
    ('Ceviches', 'Ceviche clásico',                    'Pescado del día en leche de tigre, cebolla, camote y choclo',                    38.00),
    ('Ceviches', 'Ceviche mixto',                      'Pescado, pulpo, calamar y langostinos en leche de tigre',                        46.00),
    ('Ceviches', 'Ceviche de conchas negras',          'Conchas negras de Tumbes en su jugo con limón y rocoto',                         58.00),
    ('Ceviches', 'Ceviche de camarones',               'Camarones de río frescos marinados en limón y ají limo',                         52.00),
    ('Ceviches', 'Ceviche de pulpo',                   'Pulpo tierno en leche de tigre con cebolla morada',                              44.00),
    ('Ceviches', 'Ceviche nikkei',                     'Pescado en leche de tigre con sillao, jengibre y palta',                         42.00),
    ('Ceviches', 'Ceviche de langostinos',             'Langostinos marinados en leche de tigre con choclo y camote',                    48.00),
    ('Ceviches', 'Ceviche carretillero',               'Ceviche clásico coronado con chicharrón de calamar',                             49.00),
    ('Ceviches', 'Tiradito clásico',                   'Láminas de pescado en leche de tigre de ají amarillo',                           36.00),
    ('Ceviches', 'Tiradito al rocoto',                 'Láminas de pescado en crema de rocoto y limón',                                  37.00),
    ('Ceviches', 'Tiradito nikkei',                    'Pescado en salsa de sillao, aceite de ajonjolí y cebolla china',                 39.00),
    ('Ceviches', 'Leche de tigre',                     'Vaso de leche de tigre con trozos de pescado y chicharrón de calamar',           26.00),
    ('Ceviches', 'Leche de pantera',                   'Leche de tigre preparada con conchas negras',                                    32.00),
    ('Ceviches', 'Ceviche de trucha',                  'Trucha andina marinada en limón con choclo serrano',                             35.00),
    ('Ceviches', 'Causa acevichada',                   'Causa de papa amarilla coronada con ceviche de pescado',                         34.00),
    ('Ceviches', 'Trio marino',                        'Degustación de ceviche clásico, tiradito y leche de tigre',                      54.00),

    -- Criollos (30)
    ('Criollos', 'Lomo saltado',                       'Lomo fino salteado al wok con cebolla, tomate, papas fritas y arroz',            46.00),
    ('Criollos', 'Lomo saltado de pollo',              'Pechuga de pollo salteada al wok con papas fritas y arroz',                      38.00),
    ('Criollos', 'Ají de gallina',                     'Gallina deshilachada en crema de ají amarillo, papa, huevo y aceituna',          34.00),
    ('Criollos', 'Seco de res con frejoles',           'Seco de res al culantro con frejoles canarios y arroz',                          42.00),
    ('Criollos', 'Seco de cordero',                    'Cordero norteño al culantro y chicha de jora con frejoles',                      48.00),
    ('Criollos', 'Cabrito a la norteña',               'Cabrito tierno macerado en chicha de jora con yuca y frejoles',                  52.00),
    ('Criollos', 'Tacu tacu con lomo',                 'Tacu tacu de frejoles coronado con lomo saltado',                                49.00),
    ('Criollos', 'Tacu tacu a lo pobre',               'Tacu tacu con bistec, plátano frito y huevo',                                    45.00),
    ('Criollos', 'Carapulcra con sopa seca',           'Carapulcra chinchana acompañada de sopa seca',                                   38.00),
    ('Criollos', 'Arroz con pollo',                    'Arroz verde al culantro con presa de pollo y salsa criolla',                     32.00),
    ('Criollos', 'Arroz con pato',                     'Arroz al culantro y cerveza negra con pierna de pato',                           48.00),
    ('Criollos', 'Estofado de pollo',                  'Pollo guisado con zanahoria, arvejas y papa, con arroz blanco',                  31.00),
    ('Criollos', 'Cau cau de mondongo',                'Mondongo en salsa de palillo con papa, hierbabuena y arroz',                     30.00),
    ('Criollos', 'Escabeche de pollo',                 'Pierna de pollo en escabeche de cebolla y ají, con camote',                      33.00),
    ('Criollos', 'Escabeche de pescado',               'Filete de pescado en escabeche de cebolla y ají panca',                          36.00),
    ('Criollos', 'Adobo de cerdo',                     'Cerdo macerado en chicha de jora y ají panca, estilo arequipeño',                36.00),
    ('Criollos', 'Chicharrón con tamal',               'Chicharrón de panceta con tamal criollo y salsa de cebolla',                     38.00),
    ('Criollos', 'Tallarín saltado criollo',           'Tallarines salteados al wok con lomo, cebolla y tomate',                         42.00),
    ('Criollos', 'Bistec a lo pobre',                  'Bistec de res con plátano frito, papas y huevo',                                 44.00),
    ('Criollos', 'Bistec apanado',                     'Bistec apanado con papas fritas y ensalada fresca',                              38.00),
    ('Criollos', 'Olluquito con charqui',              'Olluco guisado con charqui de res y arroz blanco',                               29.00),
    ('Criollos', 'Locro de zapallo',                   'Guiso de zapallo loche con queso, choclo y arroz',                               26.00),
    ('Criollos', 'Pepián de choclo',                   'Pepián de choclo rallado con presa de pollo',                                    30.00),
    ('Criollos', 'Patita con maní',                    'Guiso de patita de cerdo en salsa de maní con papa',                             28.00),
    ('Criollos', 'Rachi a la parrilla',                'Panza de res a la parrilla con papa dorada y salsa criolla',                     27.00),
    ('Criollos', 'Tallarín verde con bistec',          'Tallarines al pesto de albahaca con bistec apanado',                             41.00),
    ('Criollos', 'Chanfainita',                        'Bofe guisado con papa y mote, con arroz blanco',                                 25.00),
    ('Criollos', 'Sudado de pollo',                    'Pollo sudado con cebolla, tomate y chicha de jora',                              32.00),
    ('Criollos', 'Pollo a la brasa (1/4)',             'Cuarto de pollo a la brasa con papas fritas y ensalada',                         28.00),
    ('Criollos', 'Pollo a la brasa (1/2)',             'Medio pollo a la brasa con papas fritas y ensalada',                             46.00),

    -- Pescados y mariscos (24)
    ('Pescados y mariscos', 'Pescado a lo macho',      'Filete de pescado frito bañado en salsa de mariscos',                            52.00),
    ('Pescados y mariscos', 'Jalea mixta',             'Fritura de pescado y mariscos con yuca y salsa criolla',                         56.00),
    ('Pescados y mariscos', 'Jalea de pescado',        'Pescado apanado y frito con yuca, camote y salsa criolla',                       44.00),
    ('Pescados y mariscos', 'Arroz con mariscos',      'Arroz al ají panca con pulpo, calamar, langostinos y choros',                    48.00),
    ('Pescados y mariscos', 'Arroz chaufa de mariscos','Chaufa al wok con langostinos, calamar y tortilla de huevo',                     44.00),
    ('Pescados y mariscos', 'Pescado a la chorrillana','Filete de pescado en salsa de cebolla, tomate y ají',                            42.00),
    ('Pescados y mariscos', 'Pescado a la plancha',    'Filete de pescado del día a la plancha con ensalada y papa',                     40.00),
    ('Pescados y mariscos', 'Pescado frito entero',    'Pescado entero frito con yuca y salsa criolla',                                  46.00),
    ('Pescados y mariscos', 'Sudado de pescado',       'Pescado sudado en chicha de jora, cebolla y tomate',                             41.00),
    ('Pescados y mariscos', 'Sudado de tramboyo',      'Tramboyo sudado con ají amarillo y culantro',                                    45.00),
    ('Pescados y mariscos', 'Trucha frita',            'Trucha andina frita con papa dorada y ensalada',                                 34.00),
    ('Pescados y mariscos', 'Trucha a la plancha',     'Trucha a la plancha con mantequilla de hierbas y quinua',                        36.00),
    ('Pescados y mariscos', 'Langostinos a la parrilla','Langostinos a la parrilla con mantequilla de ajo y limón',                      54.00),
    ('Pescados y mariscos', 'Langostinos apanados',    'Langostinos apanados con salsa tártara y papas fritas',                          48.00),
    ('Pescados y mariscos', 'Pulpo a la parrilla',     'Pulpo a la parrilla con papa andina y chimichurri',                              56.00),
    ('Pescados y mariscos', 'Pulpo a la gallega',      'Pulpo con papa, pimentón y aceite de oliva',                                     54.00),
    ('Pescados y mariscos', 'Choros a la chalaca',     'Docena de choros con cebolla, tomate y limón',                                   30.00),
    ('Pescados y mariscos', 'Picante de mariscos',     'Guiso picante de mariscos con arroz y papa',                                     46.00),
    ('Pescados y mariscos', 'Corvina a la meunière',   'Corvina en mantequilla, limón y perejil con puré',                               58.00),
    ('Pescados y mariscos', 'Chita a la sal',          'Chita entera horneada en costra de sal con guarnición',                          62.00),
    ('Pescados y mariscos', 'Cangrejo reventado',      'Cangrejo reventado con huevo y ají amarillo',                                    50.00),
    ('Pescados y mariscos', 'Conchas a la parrilla',   'Conchas de abanico a la parrilla con mantequilla de ajo',                        42.00),
    ('Pescados y mariscos', 'Tortilla de raya',        'Tortilla norteña de raya con arroz y zarza criolla',                             38.00),
    ('Pescados y mariscos', 'Ronda marina',            'Degustación de ceviche, chicharrón de calamar y arroz con mariscos',             64.00),

    -- Carnes (22)
    ('Carnes', 'Bife de chorizo',                      'Corte de 300 g a la parrilla con guarnición a elección',                         64.00),
    ('Carnes', 'Bife ancho',                           'Corte marmoleado de 350 g a la parrilla con chimichurri',                        68.00),
    ('Carnes', 'Lomo fino a la parrilla',              'Medallón de lomo fino de 250 g con puré de papa',                                62.00),
    ('Carnes', 'Churrasco a lo pobre',                 'Churrasco con plátano frito, papas y huevo',                                     52.00),
    ('Carnes', 'Asado de tira',                        'Costilla de res a la parrilla, cocción lenta, con papa andina',                  58.00),
    ('Carnes', 'Parrilla mixta para dos',              'Res, pollo, chorizo, anticucho y chuleta con guarniciones',                      96.00),
    ('Carnes', 'Costillar de cerdo BBQ',               'Costillar glaseado en salsa barbacoa con papas rústicas',                        56.00),
    ('Carnes', 'Chuleta de cerdo',                     'Chuleta a la parrilla con puré de manzana y papa dorada',                        42.00),
    ('Carnes', 'Cordero a la parrilla',                'Chuletas de cordero con menta y papa andina',                                    66.00),
    ('Carnes', 'Anticucho de res (ración)',            'Tres brochetas de corazón con papa dorada y choclo',                             34.00),
    ('Carnes', 'Pollo a la parrilla',                  'Pechuga de pollo a la parrilla con ensalada y papa',                             34.00),
    ('Carnes', 'Alitas BBQ',                           'Ocho alitas glaseadas con salsa barbacoa y papas',                               32.00),
    ('Carnes', 'Milanesa de res',                      'Milanesa apanada con papas fritas y ensalada',                                   40.00),
    ('Carnes', 'Lomo a la pimienta',                   'Medallón de lomo en salsa de pimienta verde con puré',                           60.00),
    ('Carnes', 'Lomo al vino tinto',                   'Lomo fino en reducción de vino tinto con verduras salteadas',                    62.00),
    ('Carnes', 'Hamburguesa de la casa',               'Hamburguesa de res 200 g con queso, tocino y papas rústicas',                    38.00),
    ('Carnes', 'Cuy chactado',                         'Cuy frito a la piedra con papa, mote y salsa de rocoto',                         72.00),
    ('Carnes', 'Cerdo al horno',                       'Pierna de cerdo al horno con salsa de tamarindo y puré',                         48.00),
    ('Carnes', 'Brochetas de pollo',                   'Dos brochetas de pollo marinadas con papa y ensalada',                           32.00),
    ('Carnes', 'Chorizo parrillero',                   'Dos chorizos a la parrilla con pan y chimichurri',                               26.00),
    ('Carnes', 'Entraña a la parrilla',                'Entraña de 300 g con chimichurri y papa dorada',                                 66.00),
    ('Carnes', 'Pavo al horno',                        'Pechuga de pavo al horno con puré de camote',                                    44.00),

    -- Pastas (12)
    ('Pastas', 'Tallarines verdes',                    'Pasta al pesto peruano de albahaca y espinaca con queso fresco',                 30.00),
    ('Pastas', 'Tallarines verdes con bistec',         'Pasta al pesto peruano con bistec apanado',                                      42.00),
    ('Pastas', 'Fettuccine Alfredo',                   'Fettuccine en salsa de crema, mantequilla y parmesano',                          34.00),
    ('Pastas', 'Fettuccine a la huancaína',            'Fettuccine en salsa huancaína con lomo saltado',                                 44.00),
    ('Pastas', 'Spaghetti a la boloñesa',              'Spaghetti con salsa de carne, tomate y hierbas',                                 32.00),
    ('Pastas', 'Spaghetti a la carbonara',             'Spaghetti con tocino, huevo y parmesano',                                        35.00),
    ('Pastas', 'Ravioles de ricotta y espinaca',       'Ravioles caseros en salsa de mantequilla y salvia',                              38.00),
    ('Pastas', 'Lasaña de carne',                      'Lasaña al horno con ragú de carne y bechamel',                                   36.00),
    ('Pastas', 'Lasaña de verduras',                   'Lasaña vegetariana con zapallo italiano, berenjena y ricotta',                   33.00),
    ('Pastas', 'Canelones de pollo',                   'Canelones rellenos de pollo con salsa blanca gratinada',                         35.00),
    ('Pastas', 'Ñoquis a la crema',                    'Ñoquis de papa en salsa de crema de hongos',                                     32.00),
    ('Pastas', 'Penne al pesto genovés',               'Penne al pesto de albahaca, piñones y parmesano',                                31.00),

    -- Chifa (18)
    ('Chifa', 'Arroz chaufa de pollo',                 'Arroz salteado al wok con pollo, cebolla china y tortilla',                      30.00),
    ('Chifa', 'Arroz chaufa de carne',                 'Chaufa al wok con lomo, sillao y cebolla china',                                 34.00),
    ('Chifa', 'Arroz chaufa especial',                 'Chaufa con pollo, cerdo, langostinos y tortilla de huevo',                       40.00),
    ('Chifa', 'Aeropuerto',                            'Chaufa salteado con tallarín, pollo y cerdo',                                    38.00),
    ('Chifa', 'Tallarín saltado de pollo',             'Tallarines al wok con pollo, verduras y sillao',                                 32.00),
    ('Chifa', 'Tallarín saltado especial',             'Tallarines al wok con tres carnes y verduras',                                   40.00),
    ('Chifa', 'Pollo chi jau kay',                     'Pollo apanado en salsa chi jau kay con verduras',                                34.00),
    ('Chifa', 'Pollo enrollado',                       'Pollo enrollado con jamón y queso en salsa de la casa',                          36.00),
    ('Chifa', 'Pollo con piña',                        'Pollo salteado en salsa agridulce con piña y pimiento',                          33.00),
    ('Chifa', 'Chancho asado con tamarindo',           'Cerdo asado en salsa de tamarindo con verduras al wok',                          38.00),
    ('Chifa', 'Kam lu wantán',                         'Wantanes fritos con verduras, carnes y salsa agridulce',                         42.00),
    ('Chifa', 'Wantán frito',                          'Ocho wantanes fritos con salsa de tamarindo',                                    20.00),
    ('Chifa', 'Sopa wantán',                           'Caldo con wantanes rellenos, verduras y cerdo asado',                            26.00),
    ('Chifa', 'Sopa fuchifú',                          'Sopa de pollo con fideo chino, verduras y huevo',                                24.00),
    ('Chifa', 'Tipakay de pollo',                      'Pollo apanado en salsa agridulce con piña',                                      35.00),
    ('Chifa', 'Langostinos al tamarindo',              'Langostinos apanados con salsa de tamarindo',                                    46.00),
    ('Chifa', 'Verduras salteadas al wok',             'Mix de verduras salteadas con sillao y aceite de ajonjolí',                      24.00),
    ('Chifa', 'Min pao',                               'Pan chino al vapor relleno de cerdo asado',                                      18.00),

    -- Guarniciones (10)
    ('Guarniciones', 'Papas fritas',                   'Porción de papas fritas crocantes',                                              12.00),
    ('Guarniciones', 'Papas rústicas',                 'Papas al horno con romero y sal de mar',                                         14.00),
    ('Guarniciones', 'Arroz blanco',                   'Porción de arroz graneado',                                                       8.00),
    ('Guarniciones', 'Yuca frita',                     'Bastones de yuca frita con salsa criolla',                                       13.00),
    ('Guarniciones', 'Camote frito',                   'Rodajas de camote frito',                                                        11.00),
    ('Guarniciones', 'Puré de papa',                   'Puré de papa amarilla con mantequilla',                                          12.00),
    ('Guarniciones', 'Ensalada mixta',                 'Lechuga, tomate, pepino y palta con vinagreta',                                  14.00),
    ('Guarniciones', 'Frejoles',                       'Porción de frejoles canarios',                                                   10.00),
    ('Guarniciones', 'Choclo desgranado',              'Choclo serrano desgranado con mantequilla',                                      11.00),
    ('Guarniciones', 'Verduras al vapor',              'Brócoli, zanahoria y vainita al vapor',                                          13.00),

    -- Postres (16)
    ('Postres', 'Suspiro a la limeña',                 'Manjar blanco con merengue de oporto y canela',                                  18.00),
    ('Postres', 'Mazamorra morada',                    'Mazamorra de maíz morado con frutas secas',                                      14.00),
    ('Postres', 'Combinado de mazamorra y arroz',      'Mazamorra morada con arroz con leche',                                           16.00),
    ('Postres', 'Arroz con leche',                     'Arroz con leche, canela y pasas',                                                13.00),
    ('Postres', 'Picarones',                           'Seis picarones de zapallo y camote con miel de chancaca',                        16.00),
    ('Postres', 'Torta tres leches',                   'Bizcocho bañado en tres leches con merengue',                                    19.00),
    ('Postres', 'Crema volteada',                      'Flan de huevo con caramelo',                                                     14.00),
    ('Postres', 'Alfajores de manjar',                 'Tres alfajores rellenos de manjar blanco',                                       12.00),
    ('Postres', 'Turrón de doña Pepa',                 'Porción de turrón con miel de chancaca y grageas',                               15.00),
    ('Postres', 'Cheesecake de maracuyá',              'Cheesecake con coulis de maracuyá',                                              21.00),
    ('Postres', 'Cheesecake de lúcuma',                'Cheesecake de lúcuma con base de galleta',                                       22.00),
    ('Postres', 'Torta helada de lúcuma',              'Torta helada con crema de lúcuma y durazno',                                     20.00),
    ('Postres', 'Brownie con helado',                  'Brownie tibio de chocolate con helado de vainilla',                              20.00),
    ('Postres', 'Helado de lúcuma',                    'Dos bolas de helado artesanal de lúcuma',                                        14.00),
    ('Postres', 'Tejas de chocolate',                  'Cuatro tejas rellenas de manjar y pecanas',                                       16.00),
    ('Postres', 'Ensalada de frutas',                  'Frutas de estación con miel y yogur',                                            15.00),

    -- Bebidas (18)
    ('Bebidas', 'Chicha morada (jarra)',               'Jarra de chicha morada casera de un litro',                                      20.00),
    ('Bebidas', 'Chicha morada (vaso)',                'Vaso de chicha morada casera',                                                    9.00),
    ('Bebidas', 'Limonada frozen',                     'Limonada helada batida con hielo',                                               12.00),
    ('Bebidas', 'Limonada clásica',                    'Vaso de limonada natural',                                                        9.00),
    ('Bebidas', 'Maracuyá frozen',                     'Refresco de maracuyá batido con hielo',                                          13.00),
    ('Bebidas', 'Jugo de naranja',                     'Vaso de jugo de naranja recién exprimido',                                       11.00),
    ('Bebidas', 'Jugo surtido',                        'Jugo de papaya, plátano, manzana y leche',                                       14.00),
    ('Bebidas', 'Emoliente',                           'Emoliente caliente de linaza, cebada y limón',                                    8.00),
    ('Bebidas', 'Infusión de hierbas',                 'Manzanilla, anís o hierbaluisa',                                                  7.00),
    ('Bebidas', 'Café pasado',                         'Taza de café pasado de Chanchamayo',                                              9.00),
    ('Bebidas', 'Café con leche',                      'Café pasado con leche caliente',                                                 11.00),
    ('Bebidas', 'Inca Kola (500 ml)',                  'Botella personal de Inca Kola',                                                   8.00),
    ('Bebidas', 'Agua mineral (625 ml)',               'Botella de agua mineral con o sin gas',                                           7.00),
    ('Bebidas', 'Pisco sour',                          'Pisco quebranta, limón, jarabe, clara de huevo y amargo',                        26.00),
    ('Bebidas', 'Chilcano de pisco',                   'Pisco, ginger ale, limón y hielo',                                               22.00),
    ('Bebidas', 'Maracuyá sour',                       'Pisco, maracuyá, jarabe y clara de huevo',                                       28.00),
    ('Bebidas', 'Cerveza artesanal',                   'Botella de cerveza artesanal peruana de 330 ml',                                 18.00),
    ('Bebidas', 'Cerveza nacional',                    'Botella de cerveza nacional de 650 ml',                                          14.00)
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
