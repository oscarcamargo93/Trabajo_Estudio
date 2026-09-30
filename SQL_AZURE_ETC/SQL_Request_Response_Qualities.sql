--- 1) Tabla temporal para tomar la ultima traza y filtrar
WITH ULTIMATRAZA AS( 
    SELECT
        T.*,
        ROW_NUMBER() OVER( 
            PARTITION BY T.NoSolicitud
            ORDER BY T.FechaRegistro DESC, T.id Desc
        ) AS rn
    FROM [dbo].[DB_BeCleverRegistro] AS T
    WHERE t.id IS NOT NULL
      
      --------------------------------------------------------------------------------------------------
      -- FILTROS DE FECHA Y HORA (Para usarlos, borre los "--" al inicio de la línea que necesite):
      --------------------------------------------------------------------------------------------------
      -- Usa formato YYYYMMDD (sin guiones) para evitar errores de región en SQL Server.
      AND CAST(T.FechaRegistro AS DATE) >= '2026-09-25'                               -- Trae todo desde el 25 de septiembre en adelante.
      -- AND CAST(T.FechaRegistro AS DATE) = '20260920'                             -- Cambie aquí si quiere ver una FECHA EXACTA.
      -- AND CAST(T.FechaRegistro AS DATE) BETWEEN '20260901' AND '20260930'        -- Cambie aquí si quiere ver un RANGO DE FECHAS.
      --------------------------------------------------------------------------------------------------
      -- AND NoSolicitud IN ('60196', '60248')                                      -- Descomente esta línea si en el futuro quiere buscar solicitudes específicas.
      
      --------------------------------------------------------------------------------------------------
      -- NUEVOS FILTROS DE NEGOCIO (Agregados para igualar la data de Juan)
      --------------------------------------------------------------------------------------------------
      AND T.ProductoPpal LIKE '%Veh%'
      AND T.o_tipoScore NOT LIKE '%SC%'
)

---- 3) Primeras filas de la tabla principal
SELECT
    T.NoSolicitud,
    
    --- Fechas de Solicitud (Vienen de T.FechaSolicitud)
    CONVERT(DATE, T.FechaSolicitud) AS FechaSol, 
    CONVERT(CHAR(8), T.FechaSolicitud, 108) AS HoraSol,
    
    --- Fechas de Registro (Vienen de T.FechaRegistro)
    CONVERT(DATE, T.FechaRegistro) AS FechaReg,
    CONVERT(CHAR(8), T.FechaRegistro, 108) AS HoraReg,
    T.FechaRegistro, 
    YEAR(T.FechaRegistro) AS Año_Registro,
    MONTH(T.FechaRegistro) AS Mes_Registro,
    DAY(T.FechaRegistro) AS Dia_Registro,
    
    T.Usuario,
    
    --- 4) Variables procesadas desde los JSON (Request y Response)
    req.*,
    sal.*,
    ent.*,
    dec.*,
    
    --- 4.1) Lógica de modelo agregada para coincidir con columnas de Juan
    CASE
        WHEN ent.FlagChallenger = 0 THEN 'Legacy'
        WHEN ent.FlagChallenger = 1 THEN 'Challenger'
        ELSE 'Legacy'
    END AS Modelo_est

FROM ULTIMATRAZA AS T

---- 5) Convertir el archivo json a columnas (ESTRUCTURA OPTIMIZADA)

----- 5.1 Data del Request (Experian) - Texto sin limpiar
CROSS APPLY (
    SELECT 
        MAX(CASE WHEN req_descripcion = 'tipoIdentificacion' THEN req_valor END) AS [Tipo_identificación_R],
        MAX(CASE WHEN req_descripcion = 'numIdentificacion' THEN req_valor END) AS [numIdentificacion_R],
        MAX(CASE WHEN req_descripcion = 'totalIngresosBrutos' THEN req_valor END) AS [totalIngresosBrutos_R],
        MAX(CASE WHEN req_descripcion = 'primerApellido' THEN req_valor END) AS [TprimerApellido_R],
        MAX(CASE WHEN req_descripcion = 'codActividadEconomica' THEN req_valor END) AS [codActividadEconomica_R],
        MAX(CASE WHEN req_descripcion = 'scoreAcierta' THEN req_valor END) AS [scoreAcierta_R],
        MAX(CASE WHEN req_descripcion = 'codCanal' THEN req_valor END) AS [Canal_R],
        MAX(CASE WHEN req_descripcion = 'marcaVehiculo' THEN req_valor END) AS [marcaVehiculo_R],
        MAX(CASE WHEN req_descripcion = 'codEstadoVehiculo' THEN req_valor END) AS [codEstadoVehiculo_R],
        MAX(CASE WHEN req_descripcion = 'codUsoVehiculo' THEN req_valor END) AS [codUsoVehiculo_R],
        MAX(CASE WHEN req_descripcion = 'EXT004' THEN req_valor END) AS [% Financiación_R],
        MAX(CASE WHEN req_descripcion = 'modeloVehiculo' THEN req_valor END) AS [modeloVehiculo_R],
        MAX(CASE WHEN req_descripcion = 'valorComercial' THEN req_valor END) AS [valorComercial_R],
        MAX(CASE WHEN req_descripcion = 'montoSolicitado' THEN req_valor END) AS [montoSolicitado_R],
        MAX(CASE WHEN req_descripcion = 'plazoSolicitado' THEN req_valor END) AS [plazoSolicitado_R],
        MAX(CASE WHEN req_descripcion = 'plan' THEN req_valor END) AS [plan_R]
    FROM OPENJSON(T.Request, '$.dataInput')
    WITH (
        req_descripcion VARCHAR(100) '$.descripcion',
        req_valor VARCHAR(MAX) '$.valor'
    )
) AS req

------- 5.2 Data del Response (Variables de Salida) Qualities.
CROSS APPLY (
    SELECT 
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END010RO' THEN resp_sal_valor END) AS [CO01END010RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END070RO' THEN resp_sal_valor END) AS [CO01END070RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END060RO' THEN resp_sal_valor END) AS [CO01END060RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END009RO' THEN resp_sal_valor END) AS [CO01END009RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END049RO' THEN resp_sal_valor END) AS [CO01END049RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END037RO' THEN resp_sal_valor END) AS [CO01END037RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END062RO' THEN resp_sal_valor END) AS [CO01END062RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END001RO' THEN resp_sal_valor END) AS [CO01END001RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END001IN' THEN resp_sal_valor END) AS [CO01END001IN_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END061IN' THEN resp_sal_valor END) AS [CO01END061IN_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END051RO' THEN resp_sal_valor END) AS [CO01END051RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END073RO' THEN resp_sal_valor END) AS [CO01END073RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END076RO' THEN resp_sal_valor END) AS [CO01END076RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END080RO' THEN resp_sal_valor END) AS [CO01END080RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01END079RO' THEN resp_sal_valor END) AS [CO01END079RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP006TO' THEN resp_sal_valor END) AS [CO02EXP006TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP006AH' THEN resp_sal_valor END) AS [CO01EXP006AH_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP004RO' THEN resp_sal_valor END) AS [CO01EXP004RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP004AH' THEN resp_sal_valor END) AS [CO01EXP004AH_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP004TO' THEN resp_sal_valor END) AS [CO02EXP004TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP001RO' THEN resp_sal_valor END) AS [CO01EXP001RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP002IN' THEN resp_sal_valor END) AS [CO01EXP002IN_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP002TO' THEN resp_sal_valor END) AS [CO02EXP002TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01ACP007AH' THEN resp_sal_valor END) AS [CO01ACP007AH_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01ACP008RO' THEN resp_sal_valor END) AS [CO01ACP008RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01EXP011AH' THEN resp_sal_valor END) AS [CO01EXP011AH_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP008TO' THEN resp_sal_valor END) AS [CO02EXP008TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP009RO' THEN resp_sal_valor END) AS [CO02EXP009RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP009TO' THEN resp_sal_valor END) AS [CO02EXP009TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP010RO' THEN resp_sal_valor END) AS [CO02EXP010RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP010AH' THEN resp_sal_valor END) AS [CO02EXP010AH_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP011RO' THEN resp_sal_valor END) AS [CO02EXP011RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02EXP007RO' THEN resp_sal_valor END) AS [CO02EXP007RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01INQ001' THEN resp_sal_valor END) AS [CO01INQ001_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01INQ002' THEN resp_sal_valor END) AS [CO01INQ002_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02MOR008TO' THEN resp_sal_valor END) AS [CO02MOR008TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01MOR111VE' THEN resp_sal_valor END) AS [CO01MOR111VE_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01MOR030VE' THEN resp_sal_valor END) AS [CO01MOR030VE_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02MOR119TO' THEN resp_sal_valor END) AS [CO02MOR119TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02MOR030TO' THEN resp_sal_valor END) AS [CO02MOR030TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02MOR017TO' THEN resp_sal_valor END) AS [CO02MOR017TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02MOR002TO' THEN resp_sal_valor END) AS [CO02MOR002TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02MOR004TO' THEN resp_sal_valor END) AS [CO02MOR004TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02MOR061TO' THEN resp_sal_valor END) AS [CO02MOR061TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01ACP040RO' THEN resp_sal_valor END) AS [CO01ACP040RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01ACP015RO' THEN resp_sal_valor END) AS [CO01ACP015RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02NUM042RO' THEN resp_sal_valor END) AS [CO02NUM042RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02NUM043RO' THEN resp_sal_valor END) AS [CO02NUM043RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO01MOR213TO' THEN resp_sal_valor END) AS [CO01MOR213TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'CO02NUM002TO' THEN resp_sal_valor END) AS [CO02NUM002TO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Dif_CO01END001ROCO01END051RO' THEN resp_sal_valor END) AS [Dif_CO01END001ROCO01END051RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Dif_CO01END001INCO01END061IN' THEN resp_sal_valor END) AS [Dif_CO01END001INCO01END061IN_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Dif_CO01END009ROCO01END049RO' THEN resp_sal_valor END) AS [Dif_CO01END009ROCO01END049RO_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Challenger.SegmentoFinal' THEN resp_sal_valor END) AS [Challenger.SegmentoFinal_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Score_BFA.Score Final_Solicitante' THEN resp_sal_valor END) AS [Score_BFA.Score Final_Solicitante_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Qualities.Status' THEN resp_sal_valor END) AS [Qualities.Status_S],
        MAX(CASE WHEN resp_sal_descripcion = 'antiguedadVehiculo' THEN resp_sal_valor END) AS [antiguedadVehiculo_S],
        MAX(CASE WHEN resp_sal_descripcion = 'o_riesgoSolicitud' THEN resp_sal_valor END) AS [o_riesgoSolicitud_S],
        MAX(CASE WHEN resp_sal_descripcion = 'o_pasoFabrica' THEN resp_sal_valor END) AS [o_pasoFabrica_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Challenger.SegmentoFinal_Solicitante' THEN resp_sal_valor END) AS [Challenger.SegmentoFinal_Solicitante_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Qualities.Message' THEN resp_sal_valor END) AS [Qualities.Message_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Qualities.Data.idNumber' THEN resp_sal_valor END) AS [Qualities.Data.idNumber_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Qualities.Data.totalCrts' THEN resp_sal_valor END) AS [Qualities.Data.totalCrts_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Score_BFA.Score Final' THEN resp_sal_valor END) AS [Score_BFA.Score Final_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Python.Status' THEN resp_sal_valor END) AS [Python.Status_S],
        MAX(CASE WHEN resp_sal_descripcion = 'Python.Error' THEN resp_sal_valor END) AS [Python.Error_S],
        MAX(CASE WHEN resp_sal_descripcion = 'FechaUltimoDespliegue' THEN resp_sal_valor END) AS [FechaUltimoDespliegue_S],
        MAX(CASE WHEN resp_sal_descripcion = 'razones_pasoFabrica' THEN resp_sal_valor END) AS [razones_pasoFabrica_S]
    FROM OPENJSON(T.Response, '$.variablesSalida')
    WITH (
        resp_sal_descripcion VARCHAR(150) '$.descripcion',
        resp_sal_valor VARCHAR(MAX) '$.valor'
    )
) AS sal

------- 5.3 Data del Response (Variables de Entrada / Enrutamiento)
CROSS APPLY (
    SELECT 
        MAX(CASE WHEN ent_descripcion = 'FlagChallenger' THEN ent_valor END) AS FlagChallenger,
        MAX(CASE WHEN ent_descripcion = 'MarcaVehiculo_cod_3' THEN ent_valor END) AS MarcaVehiculo_cod_3,
        MAX(CASE WHEN ent_descripcion = 'NoTerminacionIdentificacion' THEN ent_valor END) AS NoTerminacionIdentificacion
    FROM OPENJSON(T.Response, '$.variablesEntrada')
    WITH (
        ent_descripcion VARCHAR(100) '$.descripcion',
        ent_valor VARCHAR(MAX) '$.valor'
    )
) AS ent

------- 5.4 Data del Response (Variables de Decisión)
CROSS APPLY (
    SELECT
        MAX(CASE WHEN dec_descripcion = 'Decision' THEN dec_valor END) AS Decision_Modelo,
        MAX(CASE WHEN dec_descripcion = 'Razones'  THEN dec_valor END) AS Razones_Decision
    FROM OPENJSON(T.Response, '$.variablesDecision') 
    WITH (
        dec_descripcion VARCHAR(100) '$.descripcion', 
        dec_valor VARCHAR(MAX) '$.valor'
    )
) AS dec

---- 6) ORDEN Y FILTRO FINAL
WHERE T.rn = 1 --- Comentar si se quieren ver todas las trazas

ORDER BY T.FechaRegistro DESC;