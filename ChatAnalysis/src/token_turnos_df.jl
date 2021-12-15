# ======================= CONSTANTS =========================
# Texto para identificar rol cliente.
const cliente = "cl";
# Texto para identificar rol agente.
const agente = "ag";
# URL for support in Rhy chatbot.
const soporte_regx = Regex("(\\s*https:\\/{2}www.pccomponentes.com\\/)(soporte[\\w\\/#=?-]*)")
const soporte_sub = SubstitutionString("\\1$mark_soporte")

# ======================= FUNCTIONS =========================

# TODO: resumir los cambios con expresiones regulares. 
# TODO: homogeneizar el formato de números. Formato número con comas y punto: ^(?!0(?!\.))\d{1,3}(,\d{3})*(\.\d+)?$
function sedProcess(convFile::String)::String
    run(`sed -i '' 's/\([0-9]\)\\"/\1-pulgadas/g;s/\\"//g;
                    s/%20/-/g;
                    s/€/ euros/g;s/con IVA/con_iva/g;s/con iva/con_iva/g;s/sin IVA/sin_iva/g;s/sin iva/sin_iva/g;
                    s/por favor//g;s/Por favor//g;
                    s/Muchas gracias//g;s/muchas gracias//g;s/gracias//g;s/Gracias!//g;s/GRACIAS//g;s/Gracias//g;
                    s/Que tenga buen día//g;s/Que tenga un buen día//g;s/que tenga buen día//g;s/que tenga un buen día//g;
                    s/buenos días//g;s/buenos dias//g;s/Buenos días//g;s/BUENOS DIAS//g;s/Buenos dias//g;s/buen día//g;s/buenos d ´ias//g;
                    s/buenas tardes//g;s/Buenas tardes//g;s/BUENAS TARDES//g;s/tardes//g;
                    s/Que tenga feliz noche//g;
                    s/buenas noches//g;s/Buenas noches//g;s/Buenas, noches//g;s/buenas, noches//g;
                    s/buenas//g;s/Buenas//g;s/güenas//g;s/güena//g;s/guenas//g;
                    s/un momento//g;s/Un momento//g;
                    s/De nada//g;s/de nada//g;
                    s/valee//g;s/vale//g;s/Vale//g;s/okis//g;s/okey//g;s/ok//g;s/OK//g;s/Ok//g;s/oK//g;
                    s/adiós//g;s/ADIÓS//g;s/adios//g;s/ADIOS//g;
                    s/hola//g;s/Hola//g' $convFile`)
    return convFile
end

# Clasifica las líneas de texto en dos categorías, en función de la cuenta de email asociada.
function clAgRol(rolMail::String)
    if (occursin(r".*@chat.inbenta.*", rolMail))
        return cliente
    else
        return agente
    end
end

function checkSoporte(rowIn::String) 
    replace(rowIn, r"[\n]+" => " ") |> 
        w2 -> replace(w2, r"\s?[E|e]ste es el horario de soporte.* 968977977\.?\s?" => "") |>  
            w3 -> replace(w3, soporte_regx => soporte_sub) |>  
                w4 -> replace(w4, r"[\\\']+" => "")            
end

# Concatena las líneas de conversación de un mismo interviniente en un mismo turno de conversación.
function aggregateByRol(groupLines::SubDataFrame)
    back_df = empty(groupLines)
    rows = eachrow(groupLines[:,:])
    rowIn = rows[1]
    if length(rows) == 1
        push!(back_df, rowIn)
    else
        i = 1
        while i <= (length(rows) - 1)
            i += 1
            if rows[i].rol == rowIn.rol
                rowIn.data *= (" " * rows[i].data)
            else
                push!(back_df, rowIn)
                rowIn = rows[i] 
            end
        end 
        push!(back_df, rowIn)
    end     
    return back_df
end

function dataNormalized(vectorData::Vector{String})::Vector{String}
    return lowercase.(strip.(Unicode.normalize.(vectorData, stripmark=true)))
end

# TODO: hay que pasar los tokens por una aplicación de corrección.
# TODO: expresión regular para numero + euros => numero-euros. Está puesta sólo para enlaces.

function turnos_df(fileIn::String)::DataFrame
    CSV.File(
          sedProcess(fileIn);
          delim=',',
          missingstrings="",
          ignoreemptyrows=true,
          normalizenames=true,
          quoted=true,
          openquotechar='"',
          closequotechar='"',
          escapechar='"',
          select=[
              "id",
              "action",
              "data",
              "trigger"
          ],
          types=Dict(
              "id" => Int64,
              "action" => String,
              "data" => String,
              "trigger" => String
          ),
      ) |> DataFrame |>
        df -> dropmissing(df)  |> 
                df -> filter(:action => x -> (x == "reply.text.create"), df) |>
                    df -> select!(df, 
                                Cols(:id, :action),
                                :trigger => ByRow(lowercase) => :rol,
                                :data => ByRow(checkSoporte) => :data  
                                ) |>                    
                        df -> select!(df, Cols(:id, :data), :rol => (rolMail -> clAgRol.(rolMail))  => :rol) |>
                                df -> groupby(df, [:id]) |>
                                    df -> combine(df, aggregateByRol) |>
                                        df -> insertcols!(df, 2, :turno => 1) |> 
                                            df -> groupby(df, [:id, :rol]) |>
                                                df -> select!(df, Cols(:id, :rol, :data), :turno => cumsum => :turno)
end

function tokensDf(turnosDf::DataFrame, udpModel::RObject)
    return select(turnosDf, Not(:data), :data => ByRow(tk -> udpTokens(tk, udpModel))  => :data) |>
            df -> select(df, Not(:data), :data => ByRow(dataNormalized) => :data) |>
                df -> filter!(row -> length(row.data) > 0, df)
end