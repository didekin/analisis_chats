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
const all_turno_tokenslinks = "SELECT id_conv, tokens_links FROM turno ORDER BY id;"

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

const distinct_links = "SELECT DISTINCT hash_link, link FROM enlace WHERE link != 'soporte_enlace' ORDER BY hash_link;";

function link_byhash(list)
  "SELECT hash_link, link FROM enlace WHERE hash_link IN (" * join(map(x -> "'$x'", list), ',') * ");"
end

# Hay registros con link == NULL por errores en la url, como: https://www,pccomponentes.com/soporte_enlace (la coma).
const turno_enlace = "SELECT ROW_NUMBER() OVER w AS 'row_number', t.id, t.id_conv, t.rol, t.turno_rol, t.tokens, t.tokens_links, e.link
                          FROM turno t
                                LEFT JOIN enlace e ON t.id_conv = e.id_conv AND t.rol = e.rol AND t.turno_rol = e.turno_rol 
                          WINDOW w AS (ORDER BY t.id);"

const turno_tokens_linkproducto = "SELECT id, id_conv, rol, tokens
                    FROM turno
                    WHERE id_conv IN (SELECT id_conv FROM enlace WHERE link != 'soporte_enlace')
                    ORDER BY id;";

function turno_tokens_byconvlist(list)
  "SELECT id_conv, tokens FROM turno WHERE id_conv IN (" * join(list, ',') * ") AND rol='cl' ORDER BY id;"
end

const two_previous_turnos_tokens = "SELECT j.hash_link, tu.tokens
                                    FROM turno tu INNER JOIN (
                                      SELECT t.id, e.id_conv, e.hash_link FROM enlace e 
                                        INNER JOIN turno t 
                                          ON e.id_conv = t.id_conv AND e.rol = t.rol AND e.turno_rol = t.turno_rol
                                      ) AS j
                                    ON tu.id_conv = j.id_conv AND (j.id-tu.id) <= 2 AND (j.id-tu.id) >= 0 ORDER BY tu.id;"

function two_previous_turnos_medoids(list)
              " SELECT j.hash_link, j.link, tu.tokens
                FROM turno tu INNER JOIN (
                  SELECT t.id, e.id_conv, e.hash_link, e.link FROM enlace e 
                    INNER JOIN turno t 
                      ON e.id_conv = t.id_conv AND e.rol = t.rol AND e.turno_rol = t.turno_rol
                  WHERE e.hash_link IN (" * join(map(x -> "'$x'", list), ',') * ")
                  ) AS j
                ON tu.id_conv = j.id_conv AND (j.id-tu.id) <= 2 AND (j.id-tu.id) >= 0 ORDER BY tu.id;"
end 

# To clean DB.
const delete_enlace = "DELETE FROM enlace";
const delete_turno = "DELETE FROM turno";

# For insertions in BD
const insert_turno = "INSERT INTO turno (id_conv, rol, turno_rol, tokens, tokens_links) VALUES (?, ?, ?, ?, ?)";
const insert_enlace = "INSERT INTO enlace (id_conv, rol, turno_rol, link, hash_link) VALUES (?, ?, ?, ?, ?)";

# ============================== Functions ==============================

function cleanConn(conn)
  DBInterface.close!(conn)
end

function cleanConnDb(conn)
  sqlDbToDf(delete_enlace, conn)
  sqlDbToDf(delete_turno, conn)
  cleanConn(conn)
end

function cleanConnStmt(conn, stmts)
  for stmt in stmts
    DBInterface.close!(stmt)
  end
  cleanConn(conn)
end

# Mainly for tests.
function cleanConnStmtDb(conn, stmts, credentials::Dict{String,String})
  cleanConnStmt(conn, stmts)
  cleanDb(credentials)
end

function cleanDb(credentials::Dict{String,String})
  sqlDbToDf(delete_enlace, credentials)
  sqlDbToDf(delete_turno, credentials)
end

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

function prepareSqlToDf(sqlQuery::String, credentials::Dict{String,String}, params...)
  conn = mysqlConn(credentials)
  prepStmt = DBInterface.prepare(conn, sqlQuery)
  df = DataFrame(DBInterface.execute(prepStmt, params))
  DBInterface.close!(prepStmt)
  DBInterface.close!(conn)
  return df
end

function prepareSqlIn(sqlQuery::String, credentials::Dict{String,String}, vectorParams::Vector{Vector{Any}})
  conn = mysqlConn(credentials)
  prepStmt = DBInterface.prepare(conn, sqlQuery)
  for params in vectorParams
    DBInterface.execute(prepStmt, params)
  end
  DBInterface.close!(prepStmt)
  DBInterface.close!(conn)
end

# It allows for sharing of one connection.
function sqlDbToDf(sqlQuery::String, conn::MySQL.Connection)::DataFrame
  df = DataFrame(DBInterface.execute(conn, sqlQuery))
  return df
end

function sqlDbToDf(sqlQuery::String, credentials::Dict{String,String})::DataFrame
  conn = mysqlConn(credentials)
  df = DataFrame(DBInterface.execute(conn, sqlQuery))
  DBInterface.close!(conn)
  return df
end

