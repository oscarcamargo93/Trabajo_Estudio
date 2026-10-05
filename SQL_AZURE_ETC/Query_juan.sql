drop table if exists #data;

with Insumo_JSON as (
Select 
*
,ROW_NUMBER () over (partition by nosolicitud order by fecharegistro desc) RK
from Finandina_cartera.dbo.DB_BeCleverRegistro
where FechaSolicitud >= '2026-09-01'
     /*@cierreBeClever*/
      and o_tipoScore NOT LIKE '%SC%' and ProductoPpal like '%Veh%'
),

Data_JSON as (
    /*DATA DE BECLEVER*/
    -- NOTA DE OPTIMIZACION: antes se hacian 3 OUTER APPLY OPENJSON (dataInput, variablesSalida,
    -- variablesEntrada) al mismo nivel. Eso multiplica filas (cross product) antes del GROUP BY:
    -- si dataInput tiene M elementos y variablesSalida N, se generaban M x N filas por solicitud
    -- solo para volver a colapsarlas. Ademas 'variablesEntrada' nunca se usaba en el SELECT (codigo muerto).
    -- Ahora cada fuente JSON se agrega en su propio CROSS APPLY (ya reducido a 1 fila por solicitud
    -- antes de unirse), evitando la explosion de filas y sin necesidad de GROUP BY.
    SELECT 
        t.NoSolicitud,
        t.FechaSolicitud,
        t.FechaRegistro,
        t.o_RiesgoSolicitud,
        t.o_ScoreSolicitud as Fico_tabla,
        t.o_tipoScore as Segmento,
        req.identificacion,
        req.Ingresos,
        req.Acierta,
        req.Score_Acierta_codeudor,
        sal.Fico,
        req.marca_Vehiculo,
        sal.Tipo_Score,
        req.Valor_vehiculo,
        req.Monto_solicitado,
        req.Plazo_solicitado,
        req.modelo_veh,
        req.CodCanal,
        req.codEstadoVehiculo,
        sal.porc_financiacion,
        req.CodActividadEconomica,
        req.Tipo_Vehiculo,
        req.ACP002,
        req.ACP003,
        req.END003,
        req.END007,
        req.END008,
        req.END071,
        req.END076,
        req.EXP003,
        req.EXP004,
        req.EXP007,
        req.EXT001,
        req.EXT002,
        req.EXT003,
        req.EXT004,
        req.EXT005,
        req.EXT006,
        req.EXT007,
        req.EXT008,
        req.EXT009,
        req.INQ001,
        req.INQ002,
        req.MER001,
        req.MER002,
        req.MOR001,
        req.MOR053,
        req.MOR060,
        req.NUM005,
        req.NUM043,
        req.lineaVehiculo,
        ent.FlagChallenger,
        ent.MarcaVehiculo_cod_3,
        ent.NoTerminacionIdentificacion,
        sal.o_pasoFabrica,
        sal.CantidadSolicitantes,
        sal.IngresoSMMLV,
        sal.antiguedadVehiculo,
        sal.Score_BFA_ScoreIntermedio12,
        sal.Score_BFA_ScoreIntermedio3,
        sal.Score_BFA_ScoreIntermedio4,
        sal.Challenger_SegmentoFinal,-- as Segmento,
        sal.Score_BFA_ScoreFinal,
        sal.Score_BFA_ScoreFinal_Solicitante,
        sal.Qualities_Status,
        sal.CO01ACP007AH,
        sal.CO01ACP008RO,
        sal.CO01ACP015RO,
        sal.CO01ACP040RO,
        sal.CO01END010RO,
        sal.CO01END037RO,
        sal.CO01END060RO,
        sal.CO01END062RO,
        sal.CO01END070RO,
        sal.CO01END073RO,
        sal.CO01END076RO,
        sal.CO01END079RO,
        sal.CO01END080RO,
        sal.CO01EXP001RO,
        sal.CO01EXP002IN,
        sal.CO01EXP004AH,
        sal.CO01EXP004RO,
        sal.CO01EXP006AH,
        sal.CO01EXP011AH,
        sal.CO02EXP002TO,
        sal.CO02EXP004TO,
        sal.CO02EXP006TO,
        sal.CO02EXP007RO,
        sal.CO02EXP008TO,
        sal.CO02EXP009RO,
        sal.CO02EXP009TO,
        sal.CO02EXP010AH,
        sal.CO02EXP010RO,
        sal.CO02EXP011RO,
        sal.CO02MOR061TO,
        sal.CO02NUM042RO,
        sal.CO02NUM043RO,
        sal.CO01END001IN,
        sal.CO01END061IN,
        sal.CO01END001RO,
        sal.CO01END051RO,
        sal.CO01END009RO,
        sal.CO01END049RO,
        sal.CO01INQ001,
        sal.CO01INQ002,
        sal.Dif_CO01END001ROCO01END051RO,
        sal.Dif_CO01END001INCO01END061IN,
        sal.Dif_CO01END009ROCO01END049RO,
        dec.Decision_Modelo,
        dec.Razones_Decision,
        -- NUEVO: Modelo_est -- 'Challenger' solo si Qualities.Status vino como 'true' (LGBM via Experian);
        -- cualquier otro caso (vacio, 'False', o ausente por ser arquitectura anterior) es 'Legacy'.
        -- OJO: se han visto casos (ultimo digito 2/3/4 desde el 18-sep) que ENTRAN a la rama
        -- Challenger pero el servicio Qualities de Experian falla (Decision_Modelo='ERROR',
        -- Razones_Decision='Error llamada Qualities...') y el flujo recae en Legacy. Este campo
        -- ya queda correctamente en 'Legacy' para esos casos porque refleja el modelo que
        -- REALMENTE califico, no el que la regla de reparto habria elegido.
        CASE
            WHEN ent.FlagChallenger = 0 THEN 'Legacy'
            WHEN ent.FlagChallenger = 1 THEN 'Challenger'
            ELSE 'Legacy'
        END AS Modelo_est,
        'BeClever' as Origen,
        CAST(NULL AS int) as Reprocesos_OMDM
    FROM
        Insumo_JSON t
    CROSS APPLY (
        SELECT
            MAX(CASE WHEN req_descripcion = 'numIdentificacion' THEN
                CASE WHEN CHARINDEX(';', req_valor) > 0 THEN LEFT(req_valor, CHARINDEX(';', req_valor) - 1) ELSE req_valor END
            END) AS identificacion,
            MAX(CASE WHEN req_descripcion = 'totalIngresosBrutos' THEN
                CASE WHEN CHARINDEX(';', req_valor) > 0 THEN LEFT(req_valor, CHARINDEX(';', req_valor) - 1) ELSE req_valor END
            END) AS Ingresos,
            MAX(CASE WHEN req_descripcion = 'scoreAcierta' THEN
                CASE WHEN CHARINDEX(';', req_valor) > 0 THEN LEFT(req_valor, CHARINDEX(';', req_valor) - 1) ELSE req_valor END
            END) AS Acierta,
            MAX(CASE WHEN req_descripcion = 'scoreAcierta' THEN
                CASE WHEN CHARINDEX(';', req_valor) > 0 THEN
                    SUBSTRING(req_valor, CHARINDEX(';', req_valor) + 1, CHARINDEX(';', req_valor + ';', CHARINDEX(';', req_valor) + 1) - CHARINDEX(';', req_valor) - 1)
                ELSE '0' END
            END) AS Score_Acierta_codeudor,
            MAX(CASE WHEN req_descripcion = 'marcaVehiculo'      THEN req_valor END) AS marca_Vehiculo,
            MAX(CASE WHEN req_descripcion = 'lineaVehiculo'      THEN req_valor END) AS lineaVehiculo,
            MAX(CASE WHEN req_descripcion = 'valorComercial'          THEN req_valor END) AS Valor_vehiculo,
            MAX(CASE WHEN req_descripcion = 'montoSolicitado'         THEN req_valor END) AS Monto_solicitado,
            MAX(CASE WHEN req_descripcion = 'plazoSolicitado'         THEN req_valor END) AS Plazo_solicitado,
            MAX(CASE WHEN req_descripcion = 'modeloVehiculo'          THEN req_valor END) AS modelo_veh,
            MAX(CASE WHEN req_descripcion = 'codCanal'                THEN req_valor END) AS CodCanal,
            MAX(CASE WHEN req_descripcion = 'codEstadoVehiculo'       THEN req_valor END) AS codEstadoVehiculo,
            MAX(CASE WHEN req_descripcion = 'codActividadEconomica' THEN
                CASE WHEN CHARINDEX(';', req_valor) > 0 THEN LEFT(req_valor, CHARINDEX(';', req_valor) - 1) ELSE req_valor END
            END) AS CodActividadEconomica,
            MAX(CASE WHEN req_descripcion = 'TipoVehiculo'      THEN req_valor END) AS Tipo_Vehiculo,
            MAX(CASE WHEN req_descripcion = 'ACP002' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS ACP002,
            MAX(CASE WHEN req_descripcion = 'ACP003' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS ACP003,
            MAX(CASE WHEN req_descripcion = 'END003' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS END003,
            MAX(CASE WHEN req_descripcion = 'END007' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS END007,
            MAX(CASE WHEN req_descripcion = 'END008' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS END008,
            MAX(CASE WHEN req_descripcion = 'END071' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS END071,
            MAX(CASE WHEN req_descripcion = 'END076' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS END076,
            MAX(CASE WHEN req_descripcion = 'EXP003' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXP003,
            MAX(CASE WHEN req_descripcion = 'EXP004' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXP004,
            MAX(CASE WHEN req_descripcion = 'EXP007' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXP007,
            MAX(CASE WHEN req_descripcion = 'EXT001' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXT001,
            MAX(CASE WHEN req_descripcion = 'EXT002' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXT002,
            MAX(CASE WHEN req_descripcion = 'EXT003' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXT003,
            MAX(CASE WHEN req_descripcion = 'EXT004' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXT004,
            MAX(CASE WHEN req_descripcion = 'EXT005' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXT005,
            MAX(CASE WHEN req_descripcion = 'EXT006' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXT006,
            MAX(CASE WHEN req_descripcion = 'EXT007' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXT007,
            MAX(CASE WHEN req_descripcion = 'EXT008' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXT008,
            MAX(CASE WHEN req_descripcion = 'EXT009' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS EXT009,
            MAX(CASE WHEN req_descripcion = 'INQ001' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS INQ001,
            MAX(CASE WHEN req_descripcion = 'INQ002' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS INQ002,
            MAX(CASE WHEN req_descripcion = 'MER001' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS MER001,
            MAX(CASE WHEN req_descripcion = 'MER002' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS MER002,
            MAX(CASE WHEN req_descripcion = 'MOR001' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS MOR001,
            MAX(CASE WHEN req_descripcion = 'MOR053' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS MOR053,
            MAX(CASE WHEN req_descripcion = 'MOR060' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS MOR060,
            MAX(CASE WHEN req_descripcion = 'NUM005' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS NUM005,
            MAX(CASE WHEN req_descripcion = 'NUM043' THEN CASE WHEN CHARINDEX(';', req_valor)>0 THEN LEFT(req_valor, CHARINDEX(';', req_valor)-1) ELSE req_valor END END) AS NUM043
        FROM OPENJSON(t.Request, '$.dataInput') WITH (req_descripcion NVARCHAR(100) '$.descripcion', req_valor NVARCHAR(MAX) '$.valor')
    ) req
    -- NUEVO: variablesEntrada del Response (BeClever) -- trae el flag real de enrutamiento
    -- Challenger/Legacy, la agrupacion de marca usada por el modelo LGBM, y el ultimo digito
    -- de identificacion (util para validar la regla de reparto 70/30).
    CROSS APPLY (
        SELECT
            MAX(CASE WHEN ent_descripcion = 'FlagChallenger'               THEN ent_valor END) AS FlagChallenger,
            MAX(CASE WHEN ent_descripcion = 'MarcaVehiculo_cod_3'          THEN ent_valor END) AS MarcaVehiculo_cod_3,
            MAX(CASE WHEN ent_descripcion = 'NoTerminacionIdentificacion' THEN ent_valor END) AS NoTerminacionIdentificacion
            -- NUEVO (importante para el PSI por segmento de modelo): Python.ParamName /
            -- Python.ParamValue son listas paralelas separadas por ';'. El primer elemento de
            -- Python.ParamValue siempre es el PMML EXACTO que califico la solicitud (su pareja en
            -- Python.ParamName es literalmente la palabra 'model'), ej.
            -- 'modelo_t_Finandina_Grupo1y2_Model_3.pmml'. Esto es mas confiable que inferir el
            -- segmento LGBM desde EXT/segmento de negocio, porque es el dato real que uso el flujo.
            -- En Legacy/arquitectura anterior este campo llega vacio o NULL.
        FROM OPENJSON(t.Response, '$.variablesEntrada') WITH (ent_descripcion NVARCHAR(100) '$.descripcion', ent_valor NVARCHAR(MAX) '$.valor')
    ) ent
    CROSS APPLY (
        SELECT
            MAX(CASE WHEN resp_sal_descripcion = 'o_finalScore'           THEN resp_sal_valor END) AS Fico,
            MAX(CASE WHEN resp_sal_descripcion = 'tipoScoreDC'        THEN resp_sal_valor END) AS Tipo_Score,
            CAST(MAX(CASE WHEN resp_sal_descripcion = 'porcentajeFinanciacion' THEN resp_sal_valor END) AS FLOAT) * 100 AS porc_financiacion,
            -- NUEVO: se traen TODOS los campos de variablesSalida (Champion+Challenger comparten
            -- exactamente el mismo esquema de 79 campos; en legacy/arquitectura anterior llegan vacios o NULL)
            MAX(CASE WHEN resp_sal_descripcion = 'Qualities.Status' THEN resp_sal_valor END) AS Qualities_Status,
            MAX(CASE WHEN resp_sal_descripcion = 'o_pasoFabrica' THEN resp_sal_valor END) AS o_pasoFabrica,
            MAX(CASE WHEN resp_sal_descripcion = 'o_tipoScore' THEN resp_sal_valor END) AS o_tipoScore,--
            MAX(CASE WHEN resp_sal_descripcion = 'CantidadSolicitantes' THEN resp_sal_valor END) AS CantidadSolicitantes,
            MAX(CASE WHEN resp_sal_descripcion = 'o_totalIngresosBrutos' THEN resp_sal_valor END) AS o_totalIngresosBrutos,
            MAX(CASE WHEN resp_sal_descripcion = 'o_codActividadEconomica' THEN resp_sal_valor END) AS o_codActividadEconomica,
            MAX(CASE WHEN resp_sal_descripcion = 'o_riesgoSolicitud' THEN resp_sal_valor END) AS o_riesgoSolicitud_salida,
            MAX(CASE WHEN resp_sal_descripcion = 'Score_Fico' THEN resp_sal_valor END) AS Score_Fico,--
            MAX(CASE WHEN resp_sal_descripcion = 'Score_Advance' THEN resp_sal_valor END) AS Score_Advance,
            MAX(CASE WHEN resp_sal_descripcion = 'IngresoSMMLV' THEN resp_sal_valor END) AS IngresoSMMLV,
            MAX(CASE WHEN resp_sal_descripcion = 'antiguedadVehiculo' THEN resp_sal_valor END) AS antiguedadVehiculo,
            MAX(CASE WHEN resp_sal_descripcion = 'Score_BFA.Score Intermedio 12' THEN resp_sal_valor END) AS Score_BFA_ScoreIntermedio12,
            MAX(CASE WHEN resp_sal_descripcion = 'Score_BFA.Score Intermedio 3' THEN resp_sal_valor END) AS Score_BFA_ScoreIntermedio3,
            MAX(CASE WHEN resp_sal_descripcion = 'Score_BFA.Score Intermedio 4' THEN resp_sal_valor END) AS Score_BFA_ScoreIntermedio4,
            MAX(CASE WHEN resp_sal_descripcion = 'Challenger.SegmentoFinal' THEN resp_sal_valor END) AS Challenger_SegmentoFinal,
            MAX(CASE WHEN resp_sal_descripcion = 'Score_BFA.Score Final' THEN resp_sal_valor END) AS Score_BFA_ScoreFinal,
            MAX(CASE WHEN resp_sal_descripcion = 'Score_BFA.Score Final_Solicitante' THEN resp_sal_valor END) AS Score_BFA_ScoreFinal_Solicitante,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01ACP007AH' THEN resp_sal_valor END) AS CO01ACP007AH,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01ACP008RO' THEN resp_sal_valor END) AS CO01ACP008RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01ACP015RO' THEN resp_sal_valor END) AS CO01ACP015RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01ACP040RO' THEN resp_sal_valor END) AS CO01ACP040RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END010RO' THEN resp_sal_valor END) AS CO01END010RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END037RO' THEN resp_sal_valor END) AS CO01END037RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END060RO' THEN resp_sal_valor END) AS CO01END060RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END062RO' THEN resp_sal_valor END) AS CO01END062RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END070RO' THEN resp_sal_valor END) AS CO01END070RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END073RO' THEN resp_sal_valor END) AS CO01END073RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END076RO' THEN resp_sal_valor END) AS CO01END076RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END079RO' THEN resp_sal_valor END) AS CO01END079RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END080RO' THEN resp_sal_valor END) AS CO01END080RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP001RO' THEN resp_sal_valor END) AS CO01EXP001RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP002IN' THEN resp_sal_valor END) AS CO01EXP002IN,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP004AH' THEN resp_sal_valor END) AS CO01EXP004AH,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP004RO' THEN resp_sal_valor END) AS CO01EXP004RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP006AH' THEN resp_sal_valor END) AS CO01EXP006AH,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP011AH' THEN resp_sal_valor END) AS CO01EXP011AH,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP002TO' THEN resp_sal_valor END) AS CO02EXP002TO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP004TO' THEN resp_sal_valor END) AS CO02EXP004TO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP006TO' THEN resp_sal_valor END) AS CO02EXP006TO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP007RO' THEN resp_sal_valor END) AS CO02EXP007RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP008TO' THEN resp_sal_valor END) AS CO02EXP008TO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP009RO' THEN resp_sal_valor END) AS CO02EXP009RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP009TO' THEN resp_sal_valor END) AS CO02EXP009TO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP010AH' THEN resp_sal_valor END) AS CO02EXP010AH,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP010RO' THEN resp_sal_valor END) AS CO02EXP010RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP011RO' THEN resp_sal_valor END) AS CO02EXP011RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02MOR061TO' THEN resp_sal_valor END) AS CO02MOR061TO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02NUM042RO' THEN resp_sal_valor END) AS CO02NUM042RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO02NUM043RO' THEN resp_sal_valor END) AS CO02NUM043RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END001IN' THEN resp_sal_valor END) AS CO01END001IN,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END061IN' THEN resp_sal_valor END) AS CO01END061IN,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END001RO' THEN resp_sal_valor END) AS CO01END001RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END051RO' THEN resp_sal_valor END) AS CO01END051RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END009RO' THEN resp_sal_valor END) AS CO01END009RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01END049RO' THEN resp_sal_valor END) AS CO01END049RO,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01INQ001' THEN resp_sal_valor END) AS CO01INQ001,
            MAX(CASE WHEN resp_sal_descripcion = 'CO01INQ002' THEN resp_sal_valor END) AS CO01INQ002,
            MAX(CASE WHEN resp_sal_descripcion = 'Dif_CO01END001ROCO01END051RO' THEN resp_sal_valor END) AS Dif_CO01END001ROCO01END051RO,
            MAX(CASE WHEN resp_sal_descripcion = 'Dif_CO01END001INCO01END061IN' THEN resp_sal_valor END) AS Dif_CO01END001INCO01END061IN,
            MAX(CASE WHEN resp_sal_descripcion = 'Dif_CO01END009ROCO01END049RO' THEN resp_sal_valor END) AS Dif_CO01END009ROCO01END049RO
        FROM OPENJSON(t.Response, '$.variablesSalida') WITH (resp_sal_descripcion NVARCHAR(100) '$.descripcion', resp_sal_valor NVARCHAR(MAX) '$.valor')
    ) sal
    -- NUEVO: variablesDecision -- solo aplica a la rama Challenger (Qualities); en Legacy y en
    -- arquitectura anterior este nodo llega como JSON null, por lo que OPENJSON no itera nada y
    -- el MAX(...) de una fila-agregado sin GROUP BY sigue devolviendo NULL de forma segura.
    CROSS APPLY (
        SELECT
            MAX(CASE WHEN dec_descripcion = 'Decision' THEN dec_valor END) AS Decision_Modelo,
            MAX(CASE WHEN dec_descripcion = 'Razones'  THEN dec_valor END) AS Razones_Decision
        FROM OPENJSON(t.Response, '$.variablesDecision') WITH (dec_descripcion NVARCHAR(100) '$.descripcion', dec_valor NVARCHAR(MAX) '$.valor')
    ) dec
    WHERE RK = 1)
Select * into #data from Data_JSON

Select * from #data
