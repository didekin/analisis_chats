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

const all_enlace = "SELECT id_conv, rol, turno_rol, link, hash_link
                    FROM  enlace 
                    ORDER BY id_conv;"

const all_links_count = "SELECT link, COUNT(link) AS frecuencia
                             FROM(
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
                                LEFT JOIN enlace e ON t.id_conv = e.id_conv
                                        AND t.rol = e.rol
                                        AND t.turno_rol = e.turno_rol WINDOW w AS (
                                            ORDER BY
                                            t.id
                                )
                            ) AS lk
                            GROUP BY link
                            ORDER BY frecuencia DESC;";

const all_turno = " SELECT  id_conv, rol, turno_rol, tokens, tokens_links
                    FROM  turno 
                    ORDER BY id_conv;"

# Todos los turnos con enlaces.
const all_turno_tokenslinks = "SELECT id_conv, tokens_links 
                    FROM turno ORDER BY id;"

const conversacion_nolink = "SELECT id, id_conv, rol, tokens 
                             FROM turno
                             WHERE id_conv NOT IN (SELECT id_conv FROM enlace) 
                             ORDER BY id;";

# Conversations with links only to soporte.
const conversacion_soporte = "SELECT id, id_conv, rol, tokens
                              FROM turno
                              WHERE id_conv NOT IN (SELECT id_conv FROM enlace WHERE link != 'soporte_enlace')
                                AND id_conv IN (SELECT id_conv FROM enlace WHERE link = 'soporte_enlace')
                              ORDER BY id;"

const distinct_links = "SELECT DISTINCT link FROM enlace WHERE link != 'soporte_enlace' ORDER BY link;";

# Extracción de los tokens de los turnos anteriores (hasta 4) al turno donde se responde con un link. Incluyo turnos y enlaces de agente y cliente.
# TODO: GROUP_CONCAT da problemas con los links: mejor cambiarlo.
const four_previous_turnos_link = "SELECT e.link, e.id_conv, GROUP_CONCAT(DISTINCT t.tokens SEPARATOR ' ') AS tokens
                                   FROM  enlace e  LEFT JOIN turno t ON e.id_conv = t.id_conv
                                                        AND e.turno_rol >= t.turno_rol
                                                        AND e.turno_rol - t.turno_rol <= 4
                                   GROUP BY e.link, e.id_conv;";

# Hay registros con link == NULL por errores en la url, como: https://www,pccomponentes.com/soporte_enlace (la coma).
const turno_enlace = "SELECT ROW_NUMBER() OVER w AS 'row_number', t.id, t.id_conv, t.rol, t.turno_rol, t.tokens, t.tokens_links, e.link
                          FROM turno t
                                LEFT JOIN enlace e ON t.id_conv = e.id_conv AND t.rol = e.rol AND t.turno_rol = e.turno_rol 
                          WINDOW w AS (ORDER BY t.id);"

const turno_tokens_linkproducto = "SELECT id, id_conv, rol, tokens
                    FROM turno
                    WHERE id_conv IN (SELECT id_conv FROM enlace WHERE link != 'soporte_enlace')
                    ORDER BY id;";

# ============================== Functions ==============================

# It requires a pathTofile/.env file with properties DB_USER=, DB_PASSWD=, DB_NAME= and DB_HOST= with the credentials for the database.
function dbCredentials(path::String)::Dict{String,String}
  credentials = Dict{String,String}()
  envlines = readlines(path)
  for line in envlines
    matchline = match(r"^([A-Z_]+)=((?:\w+\.?)+)", line)
    credentials[matchline[1]] = matchline[2]
  end
  credentials
end

function mysqlConn(credentials::Dict{String,String})::MySQL.Connection
  return DBInterface.connect(MySQL.Connection,
                             credentials["DB_HOST"],
                             credentials["DB_USER"],
                             credentials["DB_PASSWD"];
                             db = credentials["DB_NAME"],
                             port = 3306, unix_socket = MySQL.API.MYSQL_DEFAULT_SOCKET)
end

# It allows for sharing of one connection.
function queryDbtoDf(sqlQuery::String, conn::MySQL.Connection)::DataFrame
  df = DataFrame(DBInterface.execute(conn, sqlQuery))
  return df
end

function queryDbtoDf(sqlQuery::String, credentials::Dict{String,String})::DataFrame
  conn = mysqlConn(credentials)
  df = DataFrame(DBInterface.execute(conn, sqlQuery))
  DBInterface.close!(conn)
  return df
end

function prepareStmtQuery(sqlQuery::String, conn::MySQL.Connection, params...)
  prepStmt = DBInterface.prepare(conn, sqlQuery)
  df = DataFrame(DBInterface.execute(prepStmt, params))
  DBInterface.close!(prepStmt)
  DBInterface.close!(conn)
  return df
end

function turno_tokens_inlist(list)
  listStr = join(list, ',')
  query = "SELECT id_conv, tokens FROM turno WHERE id_conv IN (" * listStr * ") AND rol='cl' ORDER BY id;"
  return query
end

