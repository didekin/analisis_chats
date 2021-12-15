# Regexp to extract prduct name from recommendation link.
const prod_link_regexp = r"(.*)?(http[s]?:\/{2}){1}([\.\-_\w]+)((\/\w+)*\/)([\w\-\.]+[^#?\s]+)(.*)?(#[\w\-]+)?$";

# Group in regexp.
const buscar_s_string = s"\1";
const buscar_regex_str = r"\?q(?:uery)?=([\w\-\.]+[^#?&\s]+)#?.*"
const init_link_regexp = r"^http[s]?:\/{1,2}";

# To identify links hashed
const linkHashed = "lkHs_";
# To identify links with "configurador"
const configurador_link = "configurador_enlace";

# Este código es altamente dependiente del formato de URLs de el chatbot de Rhy.
    function checkPathUrl(regexMatch::RegexMatch)::String
        if occursin(r"(?:buscar)|(?:search)", regexMatch.captures[6])
            return replace(regexMatch.captures[7], buscar_regex_str => buscar_s_string)
        end
        if occursin(r".*(?:configurador).*", regexMatch.match)
            return configurador_link
        end
        if occursin(r".*(?:downloadcenter.intel.com).*", regexMatch.match)
            return regexMatch.captures[3] * regexMatch.captures[4] * regexMatch.captures[6]
        end
        return regexMatch.captures[6]
    end

# The iteration is for the case where more than one URL is chained to others; perhaps by mistake.
function extractLinks(tokenTurno::String)::Vector{Tuple{String,String}}
    stringLink = tokenTurno
    links = Vector{Tuple{String,String}}(undef, 0)
    while occursin(prod_link_regexp, stringLink)
        matchTk = match(prod_link_regexp, stringLink)
        # Tuple of (link, hashLink)
        linkIn = (checkPathUrl(matchTk), linkHashed * (string ∘ hash ∘ checkPathUrl)(matchTk))
        push!(links, linkIn)
        stringLink = matchTk.captures[1]
    end
    return links
end

function turnoWithLinks(tokenTurno::String)::String
    tuplesLink::Vector{Tuple{String,String}} = extractLinks(tokenTurno)
    hashLinks = [tuplesLink[i][2] for i in  1:length(tuplesLink)]
    return length(hashLinks) == 0 ? tokenTurno : join(hashLinks, ' ') |> strip |> s -> convert(String, s)
end

# Puede insertar un stringToken vacío: es válido para permitir la inserción de un enlace sin texto.
function insertTurno(stmtTurno::MySQL.Statement, stmtRecom::MySQL.Statement, turnoRow::DataFrameRow)
    rowdata::Array{String} = turnoRow.data
    stringTokens = join(rowdata[.!(occursin.(init_link_regexp, rowdata))], ' ') |> strip |> s -> convert(String, s)
    stringTksLks = join(map(turnoWithLinks, rowdata), ' ') |> strip |> s -> convert(String, s)
    DBInterface.execute(stmtTurno, [turnoRow.id, turnoRow.rol, turnoRow.turno, stringTokens, stringTksLks])
    insertEnlace(stmtRecom, turnoRow)
end

function insertEnlace(stmtRecom::MySQL.Statement, turnoRow::DataFrameRow)
    for token in turnoRow.data
        linksIn = extractLinks(token)
        if length(linksIn) == 0
            continue
        end
        for linkIn in linksIn
            DBInterface.execute(stmtRecom, [turnoRow.id, turnoRow.rol, turnoRow.turno, linkIn[1], linkIn[2]])
        end
    end
end

function createDbTurnos(dfTurnos::DataFrame, credentials::Dict{String,String})
    conn = mysqlConn(credentials)
    stmtTurno = DBInterface.prepare(conn, insert_turno)
    stmtRecom = DBInterface.prepare(conn, insert_enlace)
    rows = eachrow(dfTurnos)
    for turnoRow in rows
        insertTurno(stmtTurno, stmtRecom, turnoRow)
    end
    cleanConnStmt(conn, [stmtRecom, stmtTurno])
end

# TODO: pendiente este tipo https://www.adaptadores-pc.com/index.php?main_page=product_info&cPath=31_4&products_id=347729&gclid=Cj0KCQiAst2BBhDJARIsAGo2ldX6OAIGHBst_ZzPZiptr3Gvbe7WRhnTdTNaO-BA5womJxmLZeUQqZEaAgJxEALw_wcB
# TODO: https://store.hp.com/SpainStore/Merch/Product.aspx?id=2T0Y8EA&opt=ABE&sel=DTP


