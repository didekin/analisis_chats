function clusterKmedoidsDf(distances::Matrix, numMedoids::Integer, joinDf::DataFrame)
    cluResult = kmedoids(distances, numMedoids; maxiter = 100, display = :final)
    cluDfOut = innerjoin(DataFrame(numRow = rowNumber(length(cluResult.assignments)), grupo = cluResult.assignments), joinDf, on = :numRow)
    return cluResult, cluDfOut
end

function convByCluster(clustersDf::DataFrame)::DataFrame
    groupby(clustersDf, :cluste) |> df -> combine(df, nrow => :num_conversaciones) |> df2 -> select!(df2, :cluster => :grupo, :num_conversaciones)
end

function convsFromTurnos(sqlQuery::String, rol::String, conn::MySQL.Connection, udpModel::RObject)::DataFrame
    posArray = ["NOUN", "PROPN", "SYM", "X"]
    sqlDbToDf(sqlQuery, conn) |>
    df -> filter!(:rol => ==(rol), df) |> 
        df1 -> select!(df1, Not([:id, :rol])) |>
            df2 -> groupby(df2, [:id_conv]) |>
                df3 -> combine(df3, :tokens => (tk -> join(tk, ' ')) => :tokens) |>
                        df4 -> select!(df4, Not([:tokens]), :tokens => ByRow(tk -> udpTokens(tk, posArray, udpModel)) => :tokensArr) |>
                                df5 -> filter!(:tokensArr => tk -> length(tk) > 0, df5)
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

function distancesKmedoids(queryIn::String, conn::MySQL.Connection, udpModel::RObject)
    # Seleccionamos los turnos de cliente en las conversaciones.
    conv_tokens_df = convsFromTurnos(queryIn, cliente, conn, udpModel) |> df1 -> hcat(df1, DataFrame(numRow = rowNumber(size(df1, 1))))
    corpus = corpustokens(conv_tokens_df)
    U, S, V = rm_sparse_freq_terms(corpus) |> # Terms to be included in the dtm matrix.
                    terms -> DocumentTermMatrix(corpus, terms) |> # Dense.
                        dtm -> tf_idf(dtm) |>  # Sparse. Each row is a conversation, each column is a word.
                              tf_idf -> collect(transpose(tf_idf)) |> # Dense. Each row is a word, each column is a conversation.
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
    select(cluOut, :numRow => (n -> convert.(Int, n)) => :numRow) |>
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

function printMedoid(numMedoid::Integer, cluResult, tokensDf::DataFrame, credentials::Dict{String,String})
    tokensDf[cluResult.medoids[numMedoid], :id_conv] |> 
        num -> convert(Int64, num) |> 
            idConv -> sqlDbToDf(turno_tokens_byconvlist([idConv]), credentials) |>
                 medoidDf -> printTurnosInConv(medoidDf)
end

# Without sparse and frequent terms.
function rm_sparse_freq_terms(corpusIn::Corpus; sparse = 0.01, frequent = 0.99)::Dict{String,Integer}
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
    [i += 1 for i = 0:lengthVector-1]
end
