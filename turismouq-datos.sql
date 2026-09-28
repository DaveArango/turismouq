-- ============================================================================
-- TurismoUQ - Script de carga de datos - CONTINUACION
-- Este script asume que MUNICIPIO, TIPO_ALOJAMIENTO, ROL y TEMPORADA
-- YA estan cargados correctamente (12, 4, 2 y 10 filas respectivamente).
-- Si por alguna razon no lo estan, este bloque los deja en ese estado
-- antes de continuar con el resto (ALOJAMIENTO en adelante).
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON;

-- ---------- Reset seguro de catalogos base (idempotente) ----------
DELETE FROM USUARIO_ALOJAMIENTO;
DELETE FROM USUARIO_SISTEMA;
DELETE FROM RESENA;
DELETE FROM RESERVA_SERVICIO;
DELETE FROM SERVICIO;
DELETE FROM PAGO;
DELETE FROM RESERVA_HABITACION;
DELETE FROM RESERVA;
DELETE FROM CLIENTE;
DELETE FROM TARIFA;
DELETE FROM HABITACION;
DELETE FROM ALOJAMIENTO;
DELETE FROM TEMPORADA;
DELETE FROM ROL;
DELETE FROM TIPO_ALOJAMIENTO;
DELETE FROM MUNICIPIO;
COMMIT;

INSERT INTO MUNICIPIO (nombre) VALUES ('Armenia');
INSERT INTO MUNICIPIO (nombre) VALUES ('Calarca');
INSERT INTO MUNICIPIO (nombre) VALUES ('Montenegro');
INSERT INTO MUNICIPIO (nombre) VALUES ('Quimbaya');
INSERT INTO MUNICIPIO (nombre) VALUES ('La Tebaida');
INSERT INTO MUNICIPIO (nombre) VALUES ('Circasia');
INSERT INTO MUNICIPIO (nombre) VALUES ('Filandia');
INSERT INTO MUNICIPIO (nombre) VALUES ('Salento');
INSERT INTO MUNICIPIO (nombre) VALUES ('Genova');
INSERT INTO MUNICIPIO (nombre) VALUES ('Pijao');
INSERT INTO MUNICIPIO (nombre) VALUES ('Buenavista');
INSERT INTO MUNICIPIO (nombre) VALUES ('Cordoba');

INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('FINCA_CAFETERA');
INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('HOTEL');
INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('GLAMPING');
INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('HOSTAL');

INSERT INTO ROL (nombre) VALUES ('ADMINISTRADOR');
INSERT INTO ROL (nombre) VALUES ('ENCARGADO_ALOJAMIENTO');

COMMIT;

INSERT INTO TEMPORADA (nombre, categoria, anio, fecha_inicio, fecha_fin)
   VALUES ('Semana Santa', 'ALTA', 2025, DATE '2025-04-13', DATE '2025-04-20');
INSERT INTO TEMPORADA (nombre, categoria, anio, fecha_inicio, fecha_fin)
   VALUES ('Mitad de ano',  'ALTA', 2025, DATE '2025-06-15', DATE '2025-07-20');
INSERT INTO TEMPORADA (nombre, categoria, anio, fecha_inicio, fecha_fin)
   VALUES ('Diciembre-Enero', 'ALTA', 2025, DATE '2025-12-01', DATE '2025-12-31');
INSERT INTO TEMPORADA (nombre, categoria, anio, fecha_inicio, fecha_fin)
   VALUES ('Temporada media I', 'MEDIA', 2025, DATE '2025-02-01', DATE '2025-03-31');
INSERT INTO TEMPORADA (nombre, categoria, anio, fecha_inicio, fecha_fin)
   VALUES ('Temporada baja I', 'BAJA', 2025, DATE '2025-08-15', DATE '2025-09-30');
INSERT INTO TEMPORADA (nombre, categoria, anio, fecha_inicio, fecha_fin)
   VALUES ('Semana Santa', 'ALTA', 2026, DATE '2026-03-29', DATE '2026-04-05');
INSERT INTO TEMPORADA (nombre, categoria, anio, fecha_inicio, fecha_fin)
   VALUES ('Mitad de ano',  'ALTA', 2026, DATE '2026-06-15', DATE '2026-07-20');
INSERT INTO TEMPORADA (nombre, categoria, anio, fecha_inicio, fecha_fin)
   VALUES ('Diciembre-Enero', 'ALTA', 2026, DATE '2026-12-01', DATE '2026-12-31');
INSERT INTO TEMPORADA (nombre, categoria, anio, fecha_inicio, fecha_fin)
   VALUES ('Temporada media I', 'MEDIA', 2026, DATE '2026-02-01', DATE '2026-03-28');
INSERT INTO TEMPORADA (nombre, categoria, anio, fecha_inicio, fecha_fin)
   VALUES ('Temporada baja I', 'BAJA', 2026, DATE '2026-08-15', DATE '2026-09-30');

COMMIT;

-- ============================================================================
-- 5. ALOJAMIENTO (60) + HABITACION (>=400, ASIMETRICO)
--    - Cada municipio recibe un peso distinto (Armenia y Salento concentran
--      mas oferta que Buenavista o Cordoba).
--    - Cada municipio tiene un "perfil" de tipo dominante (70% de sus
--      alojamientos son de ese tipo, 30% se reparte entre los otros 3).
--    - El numero de habitaciones depende del tipo: hoteles 20-40,
--      hostales 8-15, glampings 4-10, fincas cafeteras 3-8.
-- ============================================================================
DECLARE
    TYPE t_str IS TABLE OF VARCHAR2(60);
    TYPE t_num IS TABLE OF NUMBER;

    l_municipios t_str := t_str('Armenia','Calarca','Montenegro','Quimbaya',
                                 'La Tebaida','Circasia','Filandia','Salento',
                                 'Genova','Pijao','Buenavista','Cordoba');
    l_pesos      t_num := t_num(14,6,5,4,3,4,6,12,2,2,1,1); -- suma = 60
    l_perfil     t_str := t_str('HOTEL','HOTEL','FINCA_CAFETERA','GLAMPING',
                                 'HOTEL','FINCA_CAFETERA','GLAMPING','GLAMPING',
                                 'FINCA_CAFETERA','FINCA_CAFETERA','FINCA_CAFETERA',
                                 'FINCA_CAFETERA');
    l_tipos      t_str := t_str('FINCA_CAFETERA','HOTEL','GLAMPING','HOSTAL');
    l_adjetivos  t_str := t_str('Real','Andino','Cafetero','Colonial','del Valle',
                                 'Mirador','Bosque Verde','Rio Claro','Paraiso',
                                 'Sol Naciente','Los Yarumos','La Montana');

    l_municipio_id NUMBER;
    l_tipo_id      NUMBER;
    l_aloj_id      NUMBER;
    v_tipo_txt     VARCHAR2(30);
    v_num_hab      NUMBER;
    v_hab_tipo     VARCHAR2(15);
    v_capacidad    NUMBER;
    v_rand         NUMBER;
    v_estrellas    NUMBER;
    v_nombre_comercial VARCHAR2(200);
    v_direccion    VARCHAR2(250);
    v_telefono     VARCHAR2(30);
    contador       NUMBER := 0;
BEGIN
    FOR m IN 1..l_municipios.COUNT LOOP
        SELECT municipio_id INTO l_municipio_id
          FROM MUNICIPIO WHERE nombre = l_municipios(m);

        FOR a IN 1..l_pesos(m) LOOP
            contador := contador + 1;

            -- 70% del tipo dominante del municipio, 30% aleatorio entre los 4
            IF DBMS_RANDOM.VALUE < 0.7 THEN
                v_tipo_txt := l_perfil(m);
            ELSE
                v_tipo_txt := l_tipos(TRUNC(DBMS_RANDOM.VALUE(1, l_tipos.COUNT + 1)));
            END IF;
            SELECT tipo_alojamiento_id INTO l_tipo_id
              FROM TIPO_ALOJAMIENTO WHERE nombre = v_tipo_txt;

            -- calificacion autoasignada: sesgada hacia 4-5, con casos bajos ocasionales
            v_estrellas := LEAST(5, GREATEST(1,
                              ROUND(DBMS_RANDOM.NORMAL * 0.8 + 4)));

            -- se calculan antes en variables porque DBMS_RANDOM dentro del
            -- VALUES de un INSERT puede provocar PLS-00425
            v_nombre_comercial := INITCAP(REPLACE(v_tipo_txt,'_',' ')) || ' ' ||
                        l_adjetivos(TRUNC(DBMS_RANDOM.VALUE(1, l_adjetivos.COUNT + 1))) ||
                        ' ' || l_municipios(m) || ' ' || TO_CHAR(contador);
            v_direccion := 'Km ' || TRUNC(DBMS_RANDOM.VALUE(1,20)) || ' via ' ||
                        l_municipios(m) || ', vereda ' ||
                        TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(1,15)));
            v_telefono := '+57 3' || TRUNC(DBMS_RANDOM.VALUE(100000000,999999999));

            INSERT INTO ALOJAMIENTO (municipio_id, tipo_alojamiento_id,
                        nombre_comercial, direccion, calificacion_estrellas,
                        telefono, correo)
            VALUES (l_municipio_id, l_tipo_id,
                    v_nombre_comercial,
                    v_direccion,
                    v_estrellas,
                    v_telefono,
                    'contacto' || contador || '@turismouq.co')
            RETURNING alojamiento_id INTO l_aloj_id;

            -- volumen de habitaciones asimetrico segun el tipo de alojamiento
            v_num_hab := CASE v_tipo_txt
                           WHEN 'HOTEL'           THEN ROUND(DBMS_RANDOM.VALUE(20,40))
                           WHEN 'HOSTAL'          THEN ROUND(DBMS_RANDOM.VALUE(8,15))
                           WHEN 'GLAMPING'        THEN ROUND(DBMS_RANDOM.VALUE(4,10))
                           ELSE                        ROUND(DBMS_RANDOM.VALUE(3,8))
                         END;

            FOR h IN 1..v_num_hab LOOP
                v_rand := DBMS_RANDOM.VALUE;
                v_hab_tipo := CASE WHEN v_rand < 0.25 THEN 'SENCILLA'
                                   WHEN v_rand < 0.75 THEN 'DOBLE'
                                   WHEN v_rand < 0.90 THEN 'SUITE'
                                   ELSE 'CABANA' END;
                v_capacidad := CASE v_hab_tipo
                                 WHEN 'SENCILLA' THEN ROUND(DBMS_RANDOM.VALUE(1,2))
                                 WHEN 'DOBLE'    THEN ROUND(DBMS_RANDOM.VALUE(2,4))
                                 WHEN 'SUITE'    THEN ROUND(DBMS_RANDOM.VALUE(2,6))
                                 ELSE                 ROUND(DBMS_RANDOM.VALUE(2,8))
                               END;

                INSERT INTO HABITACION (alojamiento_id, numero, capacidad_maxima,
                            tipo_habitacion, descripcion)
                VALUES (l_aloj_id, TO_CHAR(100 + h), v_capacidad, v_hab_tipo,
                        'Habitacion tipo ' || v_hab_tipo || ' en ' || l_municipios(m));
            END LOOP;
        END LOOP;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('ALOJAMIENTO/HABITACION generados.');
END;
/

-- ============================================================================
-- 6. TARIFA = cruce HABITACION x TEMPORADA
--    Precio base por tipo de habitacion, multiplicado por un factor de
--    temporada. El factor de temporada ALTA es distinto POR ALOJAMIENTO
--    (algunos suben poco el precio para competir por volumen, como pide
--    el enunciado), no un porcentaje fijo global.
-- ============================================================================
DECLARE
    TYPE t_hab IS TABLE OF HABITACION%ROWTYPE;
    l_hab t_hab;
    l_base NUMBER;
    l_factor NUMBER;
    l_factor_alta NUMBER;
    l_ultimo_aloj NUMBER := -1;
BEGIN
    SELECT * BULK COLLECT INTO l_hab
      FROM HABITACION ORDER BY alojamiento_id;

    FOR i IN 1..l_hab.COUNT LOOP
        -- un factor de temporada alta distinto cada vez que cambiamos de
        -- alojamiento (todas las habitaciones de un mismo alojamiento
        -- comparten la misma "politica" de subida en temporada alta)
        IF l_hab(i).alojamiento_id != l_ultimo_aloj THEN
            l_factor_alta := DBMS_RANDOM.VALUE(1.05, 1.5);
            l_ultimo_aloj := l_hab(i).alojamiento_id;
        END IF;

        l_base := CASE l_hab(i).tipo_habitacion
                    WHEN 'SENCILLA' THEN ROUND(DBMS_RANDOM.VALUE(70000,100000), -3)
                    WHEN 'DOBLE'    THEN ROUND(DBMS_RANDOM.VALUE(110000,160000), -3)
                    WHEN 'SUITE'    THEN ROUND(DBMS_RANDOM.VALUE(200000,300000), -3)
                    ELSE                 ROUND(DBMS_RANDOM.VALUE(160000,240000), -3) -- CABANA
                  END;

        FOR t IN (SELECT temporada_id, categoria FROM TEMPORADA) LOOP
            -- el factor se calcula en PL/SQL puro y se pasa como literal al INSERT,
            -- porque DBMS_RANDOM.VALUE dentro de un CASE en una sentencia SQL
            -- provoca PLS-00425 (tipos de argumento/retorno deben ser SQL)
            l_factor := CASE t.categoria
                          WHEN 'ALTA'  THEN l_factor_alta
                          WHEN 'MEDIA' THEN DBMS_RANDOM.VALUE(0.95,1.15)
                          ELSE              DBMS_RANDOM.VALUE(0.75,0.95)
                        END;

            INSERT INTO TARIFA (habitacion_id, temporada_id, precio_noche)
            VALUES (l_hab(i).habitacion_id, t.temporada_id,
                    ROUND(l_base * l_factor, -3));
        END LOOP;

        IF MOD(i,50) = 0 THEN COMMIT; END IF;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('TARIFA generada: ' || l_hab.COUNT || ' habitaciones x temporadas.');
END;
/

-- ============================================================================
-- 7. CLIENTE (3.000) - ciudades variadas, no solo del Quindio
-- ============================================================================
DECLARE
    TYPE t_str IS TABLE OF VARCHAR2(40);
    l_nombres   t_str := t_str('Andres','Maria','Carlos','Laura','Juan','Camila',
                                'Santiago','Valentina','Felipe','Daniela','Diego',
                                'Paola','Julian','Natalia','Sebastian','Mariana',
                                'Alejandro','Isabella','Nicolas','Gabriela');
    l_apellidos t_str := t_str('Gomez','Rodriguez','Martinez','Lopez','Garcia',
                                'Hernandez','Perez','Sanchez','Ramirez','Torres',
                                'Florez','Vargas','Castro','Ortiz','Rojas','Mejia',
                                'Cardona','Restrepo','Zapata','Londono');
    l_ciudades  t_str := t_str('Armenia','Pereira','Manizales','Bogota','Medellin',
                                'Cali','Barranquilla','Cartagena','Bucaramanga',
                                'Ibague','Neiva','Cucuta','Miami','Madrid',
                                'Ciudad de Mexico');
    v_nombre_cliente VARCHAR2(150);
    v_telefono_cliente VARCHAR2(30);
    v_ciudad_cliente VARCHAR2(100);
BEGIN
    FOR i IN 1..3000 LOOP
        v_nombre_cliente := l_nombres(TRUNC(DBMS_RANDOM.VALUE(1,l_nombres.COUNT+1))) || ' ' ||
                l_apellidos(TRUNC(DBMS_RANDOM.VALUE(1,l_apellidos.COUNT+1)));
        v_telefono_cliente := '+57 3' || TRUNC(DBMS_RANDOM.VALUE(100000000,999999999));
        v_ciudad_cliente := l_ciudades(TRUNC(DBMS_RANDOM.VALUE(1,l_ciudades.COUNT+1)));

        INSERT INTO CLIENTE (nombre, documento_identidad, correo, telefono, ciudad_origen)
        VALUES (
            v_nombre_cliente,
            TO_CHAR(100000000 + i),          -- documento unico (contador)
            'cliente' || i || '@correo.com',
            v_telefono_cliente,
            v_ciudad_cliente
        );
        IF MOD(i,500) = 0 THEN COMMIT; END IF;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('CLIENTE generado: 3000.');
END;
/

-- ============================================================================
-- 8. SERVICIO (30) repartidos de forma desigual entre los 60 alojamientos
--    (no todos los alojamientos tienen servicios adicionales)
-- ============================================================================
DECLARE
    TYPE t_str IS TABLE OF VARCHAR2(60);
    TYPE t_num IS TABLE OF NUMBER;
    l_servicios t_str := t_str('Desayuno incluido','Tour guiado cafetero',
                                'Transporte al aeropuerto','Alquiler de bicicletas',
                                'Spa y masajes','Parqueadero privado','Piscina',
                                'Cabalgata','Zona de BBQ','Wifi premium');
    l_aloj t_num;
    v_precio_serv NUMBER;
    v_aloj_serv   NUMBER;
    v_nombre_serv VARCHAR2(60);
BEGIN
    SELECT alojamiento_id BULK COLLECT INTO l_aloj
      FROM ALOJAMIENTO ORDER BY DBMS_RANDOM.VALUE;   -- orden aleatorio

    FOR i IN 1..30 LOOP
        v_precio_serv := ROUND(DBMS_RANDOM.VALUE(15000,120000), -3);
        v_aloj_serv   := l_aloj(MOD(i-1, l_aloj.COUNT) + 1);
        v_nombre_serv := l_servicios(MOD(i-1, l_servicios.COUNT) + 1);
        INSERT INTO SERVICIO (alojamiento_id, nombre, descripcion, precio)
        VALUES (v_aloj_serv, v_nombre_serv,
                'Servicio complementario ofrecido por el alojamiento',
                v_precio_serv);
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SERVICIO generado: 30.');
END;
/

-- ============================================================================
-- 9. USUARIO_SISTEMA (10) + USUARIO_ALOJAMIENTO
--    2 administradores + 2 encargados por cada uno de los 4 tipos de
--    alojamiento (8), asignados a alojamientos de su mismo tipo.
-- ============================================================================
DECLARE
    l_admin_rol NUMBER;
    l_enc_rol   NUMBER;
    l_user_id   NUMBER;
    l_n_aloj    NUMBER;
    v_clave_hash VARCHAR2(255);
BEGIN
    SELECT rol_id INTO l_admin_rol FROM ROL WHERE nombre = 'ADMINISTRADOR';
    SELECT rol_id INTO l_enc_rol   FROM ROL WHERE nombre = 'ENCARGADO_ALOJAMIENTO';

    FOR i IN 1..2 LOOP
        SELECT RAWTOHEX(STANDARD_HASH('clave_admin' || i, 'SHA256')) INTO v_clave_hash FROM dual;
        INSERT INTO USUARIO_SISTEMA (rol_id, nombre, correo, clave_hash)
        VALUES (l_admin_rol, 'Administrador ' || i,
                'admin' || i || '@turismouq.co',
                v_clave_hash);
    END LOOP;

    FOR t IN (SELECT tipo_alojamiento_id, nombre FROM TIPO_ALOJAMIENTO) LOOP
        FOR k IN 1..2 LOOP
            SELECT RAWTOHEX(STANDARD_HASH('clave' || t.tipo_alojamiento_id || k, 'SHA256')) INTO v_clave_hash FROM dual;
            INSERT INTO USUARIO_SISTEMA (rol_id, nombre, correo, clave_hash)
            VALUES (l_enc_rol, 'Encargado ' || t.nombre || ' ' || k,
                    'encargado.' || LOWER(t.nombre) || k || '@turismouq.co',
                    v_clave_hash)
            RETURNING usuario_id INTO l_user_id;

            -- FETCH FIRST exige una expresion constante, no una funcion evaluada
            -- en tiempo de ejecucion (ORA-62550); se calcula antes en l_n_aloj
            l_n_aloj := TRUNC(DBMS_RANDOM.VALUE(1,3));
            FOR a IN (SELECT alojamiento_id FROM ALOJAMIENTO
                       WHERE tipo_alojamiento_id = t.tipo_alojamiento_id
                       ORDER BY DBMS_RANDOM.VALUE
                       FETCH FIRST l_n_aloj ROWS ONLY) LOOP
                INSERT INTO USUARIO_ALOJAMIENTO (usuario_id, alojamiento_id)
                VALUES (l_user_id, a.alojamiento_id);
            END LOOP;
        END LOOP;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('USUARIO_SISTEMA generado: 10.');
END;
/

-- ============================================================================
-- 10. RESERVA + RESERVA_HABITACION + PAGO + RESERVA_SERVICIO + RESENA
--     Este es el bloque grande: 25.000 reservas con estacionalidad real
--     (mas reservas en Semana Santa, mitad de ano y diciembre-enero),
--     repartidas 2024-2026, con habitaciones, pagos y servicios asociados.
--     RESENA se genera al final para el ~45% de las reservas COMPLETADAS.
-- ============================================================================
DECLARE
    TYPE t_num     IS TABLE OF NUMBER;
    TYPE t_numlist IS TABLE OF NUMBER;
    TYPE t_map     IS TABLE OF t_numlist INDEX BY PLS_INTEGER;

    l_hab_id  t_num;
    l_hab_aloj t_num;
    l_clientes t_num;
    l_rooms_by_aloj t_map;   -- habitaciones agrupadas por alojamiento_id
    l_serv_by_aloj  t_map;   -- servicios agrupados por alojamiento_id

    TYPE t_completada IS RECORD (reserva_id NUMBER, cliente_id NUMBER,
                                 alojamiento_id NUMBER, fecha_out DATE);
    TYPE t_completadas IS TABLE OF t_completada;
    l_completadas t_completadas := t_completadas();

    v_reserva_id   NUMBER;
    v_cliente_id   NUMBER;
    v_anio         NUMBER;
    v_mes          NUMBER;
    v_dia          NUMBER;
    v_checkin      DATE;
    v_checkout     DATE;
    v_noches       NUMBER;
    v_fecha_reserva DATE;
    v_estado       VARCHAR2(15);
    v_r NUMBER;
    v_r2 NUMBER;
    v_r3 NUMBER;
    v_anchor_idx   NUMBER;
    v_aloj_id      NUMBER;
    v_num_hab_res  NUMBER;
    v_start        NUMBER;
    v_idx          NUMBER;
    v_room_id      NUMBER;
    v_ci           DATE;
    v_co           DATE;
    v_offset       NUMBER;
    v_valor_estadia NUMBER;
    v_num_pagos    NUMBER;
    v_anticipo     NUMBER;
    v_metodo       VARCHAR2(20);
    v_comentario   VARCHAR2(1000);
    v_fecha_resena DATE;
    v_estado_pago  VARCHAR2(15);
    v_estado_anticipo VARCHAR2(15);
    v_num_serv     NUMBER;
    v_serv_idx     NUMBER;
    v_servicio_id  NUMBER;
    v_cantidad_serv NUMBER;

    l_metodos t_num; -- indices auxiliares, no usado directamente

    FUNCTION f_metodo_aleatorio RETURN VARCHAR2 IS
        v NUMBER := TRUNC(DBMS_RANDOM.VALUE(1,6));
    BEGIN
        RETURN CASE v WHEN 1 THEN 'TARJETA_CREDITO'
                      WHEN 2 THEN 'TARJETA_DEBITO'
                      WHEN 3 THEN 'PSE'
                      WHEN 4 THEN 'TRANSFERENCIA'
                      ELSE 'EFECTIVO' END;
    END;
BEGIN
    -- --- IDs reales de cliente (no se asume que arranquen en 1) ---
    SELECT cliente_id BULK COLLECT INTO l_clientes FROM CLIENTE;

    -- --- precarga de habitaciones agrupadas por alojamiento ---
    SELECT habitacion_id, alojamiento_id BULK COLLECT INTO l_hab_id, l_hab_aloj
      FROM HABITACION;

    FOR i IN 1..l_hab_id.COUNT LOOP
        IF NOT l_rooms_by_aloj.EXISTS(l_hab_aloj(i)) THEN
            l_rooms_by_aloj(l_hab_aloj(i)) := t_numlist();
        END IF;
        l_rooms_by_aloj(l_hab_aloj(i)).EXTEND;
        l_rooms_by_aloj(l_hab_aloj(i))(l_rooms_by_aloj(l_hab_aloj(i)).COUNT) := l_hab_id(i);
    END LOOP;

    -- --- precarga de servicios agrupados por alojamiento ---
    FOR s IN (SELECT servicio_id, alojamiento_id FROM SERVICIO) LOOP
        IF NOT l_serv_by_aloj.EXISTS(s.alojamiento_id) THEN
            l_serv_by_aloj(s.alojamiento_id) := t_numlist();
        END IF;
        l_serv_by_aloj(s.alojamiento_id).EXTEND;
        l_serv_by_aloj(s.alojamiento_id)(l_serv_by_aloj(s.alojamiento_id).COUNT) := s.servicio_id;
    END LOOP;

    FOR n IN 1..25000 LOOP

        -- ---------- fecha de la reserva, con estacionalidad real ----------
        -- anio: 25% 2024, 45% 2025, 30% 2026
        v_r := DBMS_RANDOM.VALUE;
        v_anio := CASE WHEN v_r < 0.25 THEN 2024
                       WHEN v_r < 0.70 THEN 2025
                       ELSE 2026 END;

        -- mes: pesos mas altos en dic/ene, semana santa (abril) y jun-jul
        -- pesos:  E13 F5 M6 A9 M5 J10 J10 A5 S5 O6 N5 D14  (suma=93)
        v_r := DBMS_RANDOM.VALUE(0,93);
        v_mes := CASE WHEN v_r < 13 THEN 1  WHEN v_r < 18 THEN 2
                      WHEN v_r < 24 THEN 3  WHEN v_r < 33 THEN 4
                      WHEN v_r < 38 THEN 5  WHEN v_r < 48 THEN 6
                      WHEN v_r < 58 THEN 7  WHEN v_r < 63 THEN 8
                      WHEN v_r < 68 THEN 9  WHEN v_r < 74 THEN 10
                      WHEN v_r < 79 THEN 11 ELSE 12 END;

        v_dia := TRUNC(DBMS_RANDOM.VALUE(1,
                   TO_NUMBER(TO_CHAR(LAST_DAY(
                     TO_DATE(v_anio || '-' || v_mes || '-01','YYYY-MM-DD')),'DD')) + 1));
        v_checkin := TO_DATE(v_anio || '-' || v_mes || '-01','YYYY-MM-DD') + (v_dia - 1);

        -- duracion: mayoria 1-4 noches, ocasionalmente estadias largas
        v_noches := TRUNC(DBMS_RANDOM.VALUE(1,5)) +
                    CASE WHEN DBMS_RANDOM.VALUE < 0.15
                         THEN TRUNC(DBMS_RANDOM.VALUE(3,10)) ELSE 0 END;
        v_checkout := v_checkin + v_noches;
        v_fecha_reserva := v_checkin - TRUNC(DBMS_RANDOM.VALUE(1,61));

        -- ---------- estado, segun si ya paso o no la estadia ----------
        IF v_checkout < SYSDATE THEN
            v_estado := CASE WHEN DBMS_RANDOM.VALUE < 0.78 THEN 'COMPLETADA' ELSE 'CANCELADA' END;
        ELSE
            v_r2 := DBMS_RANDOM.VALUE;
            v_estado := CASE WHEN v_r2 < 0.5 THEN 'CONFIRMADA'
                             WHEN v_r2 < 0.9 THEN 'PENDIENTE'
                             ELSE 'CANCELADA' END;
        END IF;

        v_cliente_id := l_clientes(TRUNC(DBMS_RANDOM.VALUE(1, l_clientes.COUNT + 1)));

        INSERT INTO RESERVA (cliente_id, fecha_checkin, fecha_checkout, fecha_reserva, estado)
        VALUES (v_cliente_id, v_checkin, v_checkout, v_fecha_reserva, v_estado)
        RETURNING reserva_id INTO v_reserva_id;

        -- ---------- eleccion de alojamiento y habitaciones ----------
        -- se elige una habitacion "ancla" al azar (ponderado por numero de
        -- habitaciones -> los alojamientos grandes concentran mas reservas,
        -- igual que en la realidad) y de ahi se toma su alojamiento
        v_anchor_idx := TRUNC(DBMS_RANDOM.VALUE(1, l_hab_id.COUNT + 1));
        v_aloj_id := l_hab_aloj(v_anchor_idx);

        v_r3 := DBMS_RANDOM.VALUE;
        v_num_hab_res := CASE WHEN v_r3 < 0.85 THEN 1
                              WHEN v_r3 < 0.95 THEN 2
                              ELSE 3 END;
        v_num_hab_res := LEAST(v_num_hab_res, l_rooms_by_aloj(v_aloj_id).COUNT);

        v_start := TRUNC(DBMS_RANDOM.VALUE(1, l_rooms_by_aloj(v_aloj_id).COUNT + 1));

        FOR k IN 0..v_num_hab_res - 1 LOOP
            v_idx := MOD(v_start - 1 + k, l_rooms_by_aloj(v_aloj_id).COUNT) + 1;
            v_room_id := l_rooms_by_aloj(v_aloj_id)(v_idx);

            IF k = 0 THEN
                v_ci := v_checkin; v_co := v_checkout;
            ELSE
                -- una integrante del grupo puede llegar un dia despues
                v_offset := CASE WHEN v_noches > 1 AND DBMS_RANDOM.VALUE < 0.2
                                 THEN 1 ELSE 0 END;
                v_ci := v_checkin + v_offset; v_co := v_checkout;
            END IF;

            INSERT INTO RESERVA_HABITACION (reserva_id, habitacion_id, fecha_checkin, fecha_checkout)
            VALUES (v_reserva_id, v_room_id, v_ci, v_co);
        END LOOP;

        -- ---------- pagos ----------
        -- valor aproximado de la estadia (el calculo exacto noche a noche
        -- contra TARIFA lo hace fn_valor_estadia en la Entrega 2; aqui basta
        -- un monto plausible para tener volumen de PAGO)
        v_valor_estadia := v_noches * ROUND(DBMS_RANDOM.VALUE(90000,260000));

        v_num_pagos := CASE WHEN DBMS_RANDOM.VALUE < 0.3 THEN 2 ELSE 1 END;

        v_estado_pago := CASE v_estado
                            WHEN 'CANCELADA'  THEN CASE WHEN DBMS_RANDOM.VALUE < 0.5
                                                        THEN 'REEMBOLSADO' ELSE 'FALLIDO' END
                            WHEN 'COMPLETADA' THEN CASE WHEN DBMS_RANDOM.VALUE < 0.95
                                                        THEN 'EXITOSO' ELSE 'PENDIENTE' END
                            WHEN 'CONFIRMADA' THEN CASE WHEN DBMS_RANDOM.VALUE < 0.8
                                                        THEN 'EXITOSO' ELSE 'PENDIENTE' END
                            ELSE 'PENDIENTE'
                          END;

        IF v_num_pagos = 1 THEN
            v_metodo := f_metodo_aleatorio();
            INSERT INTO PAGO (reserva_id, fecha_pago, monto, metodo, estado)
            VALUES (v_reserva_id, v_fecha_reserva, v_valor_estadia,
                    v_metodo, v_estado_pago);
        ELSE
            v_anticipo := ROUND(v_valor_estadia * DBMS_RANDOM.VALUE(0.3,0.5));
            v_estado_anticipo := CASE WHEN v_estado = 'CANCELADA'
                                      THEN v_estado_pago ELSE 'EXITOSO' END;

            v_metodo := f_metodo_aleatorio();
            INSERT INTO PAGO (reserva_id, fecha_pago, monto, metodo, estado)
            VALUES (v_reserva_id, v_fecha_reserva, v_anticipo,
                    v_metodo, v_estado_anticipo);

            v_metodo := f_metodo_aleatorio();
            INSERT INTO PAGO (reserva_id, fecha_pago, monto, metodo, estado)
            VALUES (v_reserva_id, v_checkin, v_valor_estadia - v_anticipo,
                    v_metodo, v_estado_pago);
        END IF;

        -- ---------- servicios contratados ----------
        v_r := DBMS_RANDOM.VALUE;
        v_num_serv := CASE WHEN v_r < 0.40 THEN 0
                           WHEN v_r < 0.75 THEN 1
                           WHEN v_r < 0.93 THEN 2
                           ELSE 3 END;

        IF v_num_serv > 0 AND l_serv_by_aloj.EXISTS(v_aloj_id) THEN
            FOR s IN 1..v_num_serv LOOP
                v_serv_idx := TRUNC(DBMS_RANDOM.VALUE(1, l_serv_by_aloj(v_aloj_id).COUNT + 1));
                v_servicio_id := l_serv_by_aloj(v_aloj_id)(v_serv_idx);
                v_cantidad_serv := ROUND(DBMS_RANDOM.VALUE(1,4));
                BEGIN
                    INSERT INTO RESERVA_SERVICIO (reserva_id, servicio_id, cantidad)
                    VALUES (v_reserva_id, v_servicio_id, v_cantidad_serv);
                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN NULL; -- ese servicio ya estaba en esta reserva
                END;
            END LOOP;
        END IF;

        -- ---------- candidatas a resena (reservas completadas) ----------
        IF v_estado = 'COMPLETADA' THEN
            l_completadas.EXTEND;
            l_completadas(l_completadas.COUNT) := t_completada(v_reserva_id, v_cliente_id, v_aloj_id, v_checkout);
        END IF;

        IF MOD(n,1000) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Reservas generadas: ' || n);
        END IF;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('RESERVA generada: 25000. Completadas: ' || l_completadas.COUNT);

    -- ---------- RESENA: ~45% de las reservas completadas (>= 40% exigido) ----------
    FOR i IN 1..l_completadas.COUNT LOOP
        IF DBMS_RANDOM.VALUE < 0.45 THEN
            v_r := DBMS_RANDOM.VALUE;
            v_fecha_resena := l_completadas(i).fecha_out + 1;
            v_comentario := CASE WHEN DBMS_RANDOM.VALUE < 0.6
                     THEN 'Buena experiencia, volveria a hospedarme.'
                     ELSE NULL END;
            INSERT INTO RESENA (cliente_id, alojamiento_id, reserva_id, calificacion, comentario, fecha)
            VALUES (
                l_completadas(i).cliente_id,
                l_completadas(i).alojamiento_id,
                l_completadas(i).reserva_id,
                CASE WHEN v_r < 0.35 THEN 5 WHEN v_r < 0.65 THEN 4
                     WHEN v_r < 0.85 THEN 3 WHEN v_r < 0.95 THEN 2
                     ELSE 1 END,
                v_comentario,
                v_fecha_resena -- resena un dia despues del checkout
            );
        END IF;
        IF MOD(i,2000) = 0 THEN COMMIT; END IF;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('RESENA generada.');
END;
/

-- ============================================================================
-- 11. Verificacion de volumenes cargados
-- ============================================================================
SELECT 'MUNICIPIO' tabla, COUNT(*) filas FROM MUNICIPIO
UNION ALL SELECT 'TIPO_ALOJAMIENTO', COUNT(*) FROM TIPO_ALOJAMIENTO
UNION ALL SELECT 'ROL', COUNT(*) FROM ROL
UNION ALL SELECT 'ALOJAMIENTO', COUNT(*) FROM ALOJAMIENTO
UNION ALL SELECT 'HABITACION', COUNT(*) FROM HABITACION
UNION ALL SELECT 'TEMPORADA', COUNT(*) FROM TEMPORADA
UNION ALL SELECT 'TARIFA', COUNT(*) FROM TARIFA
UNION ALL SELECT 'CLIENTE', COUNT(*) FROM CLIENTE
UNION ALL SELECT 'RESERVA', COUNT(*) FROM RESERVA
UNION ALL SELECT 'RESERVA_HABITACION', COUNT(*) FROM RESERVA_HABITACION
UNION ALL SELECT 'PAGO', COUNT(*) FROM PAGO
UNION ALL SELECT 'SERVICIO', COUNT(*) FROM SERVICIO
UNION ALL SELECT 'RESERVA_SERVICIO', COUNT(*) FROM RESERVA_SERVICIO
UNION ALL SELECT 'RESENA', COUNT(*) FROM RESENA
UNION ALL SELECT 'USUARIO_SISTEMA', COUNT(*) FROM USUARIO_SISTEMA
UNION ALL SELECT 'USUARIO_ALOJAMIENTO', COUNT(*) FROM USUARIO_ALOJAMIENTO;
