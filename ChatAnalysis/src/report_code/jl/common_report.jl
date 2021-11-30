# include("../../commons.jl")

#= 
Descomposition of turnos with the link of soporte_datos within its tokens.

 -- 404 Turnos with at least one soporte_datos in its tokens table TURNO. They have other links within its tokens.
SELECT t.id_conv, t.rol, t.turno_rol, t.tokens, t.tokens_links, e.link FROM  turno t  
LEFT JOIN enlace e ON t.id_conv = e.id_conv AND t.rol = e.rol AND t.turno_rol = e.turno_rol 
WHERE t.tokens_links LIKE '%soporte_datos%';  

-- 393  Turnos with a link soporte_datos table ENLACE.
SELECT t.id_conv, t.rol, t.turno_rol, t.tokens, t.tokens_links, e.link FROM  turno t  
LEFT JOIN enlace e ON t.id_conv = e.id_conv AND t.rol = e.rol AND t.turno_rol = e.turno_rol
WHERE e.link LIKE '%soporte_datos%';

--  393 Turnos similar to the previous group.
SELECT t.id_conv, t.rol, t.turno_rol, t.tokens, t.tokens_links, e.link FROM  turno t  
LEFT JOIN enlace e ON t.id_conv = e.id_conv AND t.rol = e.rol AND t.turno_rol = e.turno_rol
WHERE t.tokens_links LIKE '%soporte_datos%' AND e.link LIKE '%soporte_datos%';

-- 10 Turnos with soporte_datos and other links in table ENLACE.
SELECT t.id_conv, t.rol, t.turno_rol, t.tokens_links, e.link FROM  turno t  
LEFT JOIN enlace e ON t.id_conv = e.id_conv AND t.rol = e.rol AND t.turno_rol = e.turno_rol
WHERE t.tokens_links LIKE '%soporte_datos%' AND e.link NOT LIKE '%soporte_datos%' AND e.link IS NOT NULL;

-- 1 Turnos with soporte_datos and a NULL link in table ENLACE.
SELECT t.id_conv, t.rol, t.turno_rol, t.tokens_links, e.link FROM  turno t  
LEFT JOIN enlace e ON t.id_conv = e.id_conv AND t.rol = e.rol AND t.turno_rol = e.turno_rol
WHERE t.tokens_links LIKE '%soporte_datos%' AND e.link IS NULL; =#

# Hay registros con link == NULL por errores en la url, como: https://www,pccomponentes.com/soporte_enlace (la coma).
const sql_turno_enlace = "
            SELECT
                ROW_NUMBER() OVER w AS 'row_number',
                t.id,
                t.id_conv,
                t.rol,
                t.turno_rol,
                t.tokens,
                t.tokens_links,
                e.link
            FROM turno t
                    LEFT JOIN enlace e 
                    ON t.id_conv = e.id_conv AND t.rol = e.rol AND t.turno_rol = e.turno_rol 
            WINDOW w AS (ORDER BY t.id);"

const conversacion_nolink = "
    SELECT
    id,
    id_conv,
    rol,
    tokens
    FROM
    turno
    WHERE
    id_conv NOT IN (
        SELECT
        id_conv
        FROM
        enlace
    ) 
    ORDER BY id;";

# Conversations with links only to soporte.
const conversacion_soporte = "
    SELECT
        id,
        id_conv,
        rol,
        tokens
    FROM
        turno
    WHERE
        id_conv NOT IN (
            SELECT
            id_conv
            FROM
            enlace
            WHERE
            link != 'soporte_enlace'
        )
    AND id_conv IN (
        SELECT
        id_conv
        FROM
        enlace
        WHERE
        link = 'soporte_enlace'
    )
    ORDER BY
    id;"

macro Name(arg)
    string(arg)
end

function queryDbtoDf(sqlQuery::String)::DataFrame
    conn = mysqlConn()
    df = DataFrame(DBInterface.execute(conn, sqlQuery))
    DBInterface.close!(conn)
    return df
end

function prepareStmtQuery(sqlQuery::String, params...)
    conn = mysqlConn()
    prepStmt = DBInterface.prepare(conn, sqlQuery)
    df = DataFrame(DBInterface.execute(prepStmt, params))
    DBInterface.close!(prepStmt)
    DBInterface.close!(conn)
    return df
end