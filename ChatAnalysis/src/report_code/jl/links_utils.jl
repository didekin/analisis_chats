# include("common_report.jl")

using TextAnalysis, Languages, SparseArrays, Clustering, LinearAlgebra, Distances, Gadfly, Cairo, Fontconfig

#  Extracción de los tokens de los turnos anteriores (hasta 4) al turno donde se responde con un link. Incluyo turnos y enlaces de agente y cliente.
const sql_tokens_link = "SELECT e.link, 
                                e.id_conv,
                                GROUP_CONCAT(DISTINCT t.tokens SEPARATOR ' ') AS tokens
                         FROM  enlace e  LEFT JOIN turno t 
                            ON e.id_conv = t.id_conv
                                AND e.turno_rol >= t.turno_rol
                                AND e.turno_rol - t.turno_rol <= 4
                        GROUP BY e.link, e.id_conv;";

# ======================== FUNCIONES ==========================  

# ================== Accesos BD ==================

# ================================================

function clusterKmedoidsDf(distances::Matrix, numMedoids::Integer, joinDf::DataFrame)
    cluResult = kmedoids(distances, numMedoids; maxiter = 100, display = :final)
    cluDfOut = innerjoin(DataFrame(numRow = rowNumber(length(cluResult.assignments)), grupo = cluResult.assignments), joinDf, on = :numRow)
    return cluResult, cluDfOut
end

function convByCluster(clustersDf::DataFrame)::DataFrame
    groupby(clustersDf, :cluste) |> df -> combine(df, nrow => :num_conversaciones) |> df2 -> select!(df2, :cluster => :grupo, :num_conversaciones)
end

function convsFromTurnos(sqlQuery::String, rol::String)::DataFrame
    posArray = ["NOUN", "PROPN", "SYM", "X"]
    queryDbtoDf(sqlQuery) |>
    df -> filter!(:rol => ==(rol), df) |> df1 -> select!(df1, Not([:id, :rol])) |>
                                                 df2 -> groupby(df2, [:id_conv]) |>
                                                        df3 -> combine(df3, :tokens => (tk -> join(tk, ' ')) => :tokens) |>
                                                               df4 -> select!(df4, Not([:tokens]), :tokens => ByRow(tk -> udpTokens(tk, posArray)) => :tokensArr) |>
                                                                      df5 -> filter!(:tokensArr => tk -> length(tk) > 0, df5)
end

function convTokensQuery(list)
    listStr = join(list, ',')
    query = "SELECT id_conv, tokens FROM turno WHERE id_conv IN (" * listStr * ") AND rol='cl' ORDER BY id;"
    return query
end

#  Corpus. Fields: documents::Vector{T}, total_terms::Int, lexicon::Dict{String, Int}, inverse_index::Dict{String, Vector{Int}}, h::TextHashFunction
function corpustokens(turnosDf::DataFrame)::Corpus
    corpus = select(turnosDf, Not([:tokensArr]), :tokensArr => ByRow(TokenDocument) => :tokendoc) |>
             df -> Corpus(df[:, :tokendoc])
    remove_corrupt_utf8!(corpus)
    remove_patterns!(corpus, r"^\++|\*+|\.+|\?+|:\)|^\\+|^-+|^\/+")
    update_lexicon!(corpus)
    return corpus
end

function distancesKmedoids(queryIn::String)
    # Seleccionamos los turnos de cliente en las conversaciones.
    conv_tokens_df = convsFromTurnos(queryIn, cliente) |> df1 -> hcat(df1, DataFrame(numRow = rowNumber(size(df1, 1))))
    corpus = corpustokens(conv_tokens_df)
    U, S, V = rm_sparse_freq_terms(corpus) |> # Terms to be included in the dtm matrix.
              terms -> DocumentTermMatrix(corpus, terms) |> # Dense.
                       dtm -> tf_idf(dtm) |>  # Sparse. Each row is a turno, each column is a word.
                              tf_idf -> collect(transpose(tf_idf)) |> # Dense. Each row is a word, each column is a turno.
                                        tf_idf_T -> svd(tf_idf_T) # SVD analysis; thin or reduced version.

    # Distances.
    dist_SVt30 = Diagonal(S[1:30]) * V'[1:30, :] |>
                 SVt30 -> pairwise(CosineDist(), SVt30, dims = 2)

    return conv_tokens_df, dist_SVt30
end

# Return the six number-of-row of the conversations with greatest cosines with the center of a cluster.
function greatest_turnoscosines(clusterNumber::Integer, cluDf::DataFrame, centers::Matrix{Float64})::Vector{Integer}
    # I normalize the center fot the cosine product. Clusters elements are already normalized.
    centerNorm = centers[:, clusterNumber] / norm(centers[:, clusterNumber])
    cluOut = filter(:cluster => .==(clusterNumber), cluDf) |> df1 -> select(df1, Not(:cluster))
    cosines = Matrix(cluOut[:, Not(:numRow)]) * centerNorm
    dfOut = select(cluOut, :numRow => (n -> convert.(Int, n)) => :numRow) |>
            df1 -> hcat(df1, DataFrame(cosine = cosines)) |>
                   df2 -> sort!(df2, :cosine, rev = true)[1:6, :numRow]
end

function normRowMatrix(mtx::Matrix)::Matrix
    mtxOut = copy(mtx)
    for i = 1:size(mtxOut, 1)
        normIn = norm(mtxOut[i, :])
        normIn == 0 ? mtxOut[i, :] : mtxOut[i, :] /= normIn
    end
    return mtxOut
end

function plotFreqRelativeWords(cluDf::DataFrame, namePlot::String, colorIn)
    grupos = sort(unique(cluDf.grupo))
    for i in grupos
        @show i
        filter(:grupo => ==(i), cluDf) |>
        df1 -> corpustokens(df1).lexicon |>
               lex -> DataFrame(vocablo = collect(keys(lex)), frecuencia = collect(values(lex))) |>
                      df2 -> select(df2, :vocablo, :frecuencia => (f -> f / size(df1, 1)) => :frecuencia) |>
                             df3 -> sort!(df3, :frecuencia, rev = true)[1:min(size(df3, 1), 25), :] |>
                                    df4 -> plot(
            df4, x = :vocablo, y = :frecuencia,
            Guide.yticks(ticks = collect(0:0.05:maximum(df4.frecuencia))),
            color = colorIn,
            Geom.bar(position = :dodge)
        ) |>
                                           plot1 -> draw(PNG(imgReportDir * "/" * namePlot * string(i) * ".png", 18cm, 14cm), plot1)
    end
end

function printTurnosInConv(clusterTurnos::DataFrame)
    rowDf = eachrow(clusterTurnos)
    rowDf[1]
    i = 1
    while i <= length(rowDf)
        idcurrent = rowDf[i].id_conv
        while i <= length(rowDf) && rowDf[i].id_conv == idcurrent
            println("-- " * rowDf[i].tokens)
            i += 1
        end
        # println("------------------------------------------------------------------")
    end
end

function printMedoid(numMedoid::Integer, cluResult, tokensDf::DataFrame)
    tokensDf[cluResult.medoids[numMedoid], :id_conv] |> num -> convert(Int64, num) |>
                                                               idConv -> prepareStmtQuery(convTokensQuery([idConv])) |>
                                                                         medoidDf -> printTurnosInConv(medoidDf)
end

# Without sparse and frequent terms.
function rm_sparse_freq_terms(corpusIn::Corpus, sparse = 0.01, frequent = 0.99)::Dict{String,Integer}
    lexout = lexicon(corpusIn)
    sp = sparse_terms(corpusIn, sparse)
    ft = frequent_terms(corpusIn, frequent)
    sp_ft = [sp; ft]
    for word in sp_ft
        delete!(lexout, word)
    end
    return lexout
end

function rowNumber(lengthVector::Integer)::Vector{Integer}
    rownumbers = [i += 1 for i = 0:lengthVector-1]
end

# To write a test file.
function writeTestFile(fileName::String)
    open(data_dir * "trash_file.txt", "w") do f
        for term in keys(ll)
            write(f, term * " " * "\n")
        end
    end
end