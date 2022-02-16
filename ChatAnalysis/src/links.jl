function checkPrice(text::String)
    replace(text, r"((?:\d{1,3})?\.?(?:\d+))\s*(euros)" => s"\1-\2")
end

function checkHashLink(hashText::String)
    occursin(r"^(?:lkHs_)\d+$", hashText)
end

function checkFinalTokens(tokens::String)
    replace(tokens, r"modelo[s]?|enlace[s]?|link[s]?" => s"")
end

function convsDf(credentials::Dict{String,String}, udpModel::RObject; sqlQuery::String = all_turno_tokenslinks)::DataFrame
    posArray = ["ADJ", "ADP", "ADV", "NOUN", "NUM", "PROPN", "SYM", "VERB", "X"]
    conn = mysqlConn(credentials)
    dfOut = sqlDbToDf(sqlQuery, conn) |>
            dfIn -> select!(
                            dfIn,
                            Not(:tokens_links),
                            :tokens_links => ByRow(tk -> udpTokens(tk, posArray, udpModel)) => :tokensArr
                    ) |>
                    dfIn -> select!(dfIn, Not(:tokensArr), :tokensArr => ByRow(arr -> checkPrice(join(arr, ' '))) => :tokens_links) |>
                            dfIn -> filter!(row -> length(row.tokens_links) > 0, dfIn)
    cleanConn(conn)
    dfOut
end

# Extract word2vec embeddings for links. Returns a data frame where each row is a link: :word (name) + :x1...:x100 for the embeddings.
function embeddingsForLinks(embeddingsFile::String)::DataFrame
    embeddings = wordvectors(embeddingsFile)
    hcat(DataFrame(word = embeddings.vocab), DataFrame(collect(embeddings.vectors'), :auto)) |>
    dfIn -> filter(:word => checkHashLink, dfIn)
end

function kMedoidsFromEmbeddings(dfEmbeddingsLinks::DataFrame, numMedoids::Integer)::KmedoidsResult
    dfEmbeddingsLinks[:, Not(:word)] |> Matrix |>
    # Transpongo: cada columna es ahora un vector con los elementos del embedding.
    mtIn -> collect(mtIn') |> mtIn -> pairwise(CosineDist(), mtIn, dims = 2) |>
                                      distIn -> kmedoids(distIn, numMedoids; maxiter = 100, display = :final)
end
# It returns a vector with hash_link of medoids and df with (hash_link, grupo) of the Kmedoids clusters.
function dfFromKmedoids(embeddingsFile::String, numMedoids::Integer, credentials::Dict{String,String})
    embeddings = embeddingsForLinks(embeddingsFile)
    result = kMedoidsFromEmbeddings(embeddings, numMedoids)
    wordMedoids = [embeddings[i, :word] for i in result.medoids]
    dfIn1 = DataFrame(hash_link = embeddings[:, :word], grupo = result.assignments)
    dfIn2 = sqlDbToDf(distinct_links, credentials)
    dfOut = leftjoin(dfIn1, dfIn2, on = :hash_link)
    return wordMedoids, dfOut
end

# Table of number of links per cluster(grupo)
function linksByCluster(clustersDf::DataFrame)::DataFrame
    groupby(clustersDf, :grupo) |> df -> combine(df, nrow => :num_enlaces)
end

# It returns the 20 most frequent words for the string parameter.
function lexicoCluster(rowDfGrupos::String)::Vector{String}
    lexico = dictFromArrWords(rowDfGrupos)
    DataFrame(vocablo = collect(keys(lexico)), frecuencia = collect(values(lexico))) |>
        # dfIn -> filter!(:vocablo => v -> length(v) > 0, dfIn) |> 
            dfIn -> sort!(dfIn, :frecuencia, rev = true)[1:min(size(dfIn, 1), 20), :vocablo]
end

medioin(x::Int64) = (x ÷ 2) + min(1, (x % 2))

# It returns a df with (grupo, grupofreqwordsVec): grupo and a vector with the most frequent words in the grupo.
function mostFrequentWords(dfHashLinkGrupo::DataFrame, credentials::Dict{String,String}, udpModelIn::RObject)::DataFrame
    mostFrequentWords(dfHashLinkGrupo, mysqlConn(credentials), udpModelIn)
end

function mostFrequentWords(dfHashLinkGrupo::DataFrame, conn::MySQL.Connection, udpModelIn::RObject)::DataFrame
    posArray = ["ADJ", "NOUN", "NUM", "PROPN", "X"]

    dfTokens = sqlDbToDf(two_previous_turnos_tokens, conn) |>
        dfIn -> select!(dfIn, Not(:tokens), :tokens => ByRow(tk -> checkPrice(join(udpTokens(tk, posArray, udpModelIn), ' '))) => :tokens) |>
            dfIn -> select!(dfIn, Not(:tokens), :tokens => ByRow(checkFinalTokens) => :tokens) |>
                dfIn -> filter!(row -> length(row.tokens) > 0, dfIn) |> dropmissing!
    
    leftjoin(dfHashLinkGrupo, dfTokens, on = :hash_link) |>
    dfIn -> groupby(dfIn, :grupo) |>
            dfIn -> combine(dfIn, :tokens => (tk -> join(tk, ' ')) => :grupotokens) |>
                    dfIn -> select!(dfIn, :grupo, :grupotokens => ByRow(lexicoCluster) => :grupofreqwordsVec)
end

# Parámetro con los hash_link de los medoids. It returns df (link, alltokens) for the medoids.
function turnosTokensMedoids(medoids::Vector{String}, credentials)
    sqlDbToDf(two_previous_turnos_medoids(medoids), credentials) |> 
        dfIn -> groupby(dfIn, :link) |> 
            dfIn -> combine(dfIn, :tokens => (tk -> join(tk, ' ')) => :alltokens)
end

struct WindowEmbed
    w::Int64
end

# Función para utilizar con el constructor de WindowEmbed.
# (WindowEmbed(2))(test_tkens_3, link1)
function (linktomiddle::WindowEmbed)(tokens::String, link::String)
    window = linktomiddle.w
    tkArrOld = split(tokens, ' ')
    lengthOld = length(tkArrOld)
    if lengthOld == 0
        return link
    elseif lengthOld == 1
        return join([tkArrOld[1]; link], ' ')
    else
        middleIndex = medioin(length(tkArrOld))
        return (lengthOld - middleIndex) <= window ?
               join([tkArrOld[1:middleIndex]; link; tkArrOld[middleIndex+1:end]], ' ') :
               join([tkArrOld[1:lengthOld-window]; link; tkArrOld[lengthOld-window+1:end]], ' ')

    end
end

function writeFileInW2vec(credentials::Dict{String,String}, udpModel::RObject, w2vecFile::String)
    convDf = convsDf(credentials, udpModel)
    fileStream = open(w2vecFile, "w")
    for conv in eachrow(convDf)
        println(fileStream, conv.tokens_links)
    end
    close(fileStream)
end

# cbow = 1: use skip-gram model. Minimum counts is 0.
function writeFileOutW2vec(embedVectorSize::Int64, windowIn::Int64, fileIn::String, fileOut::String)
    word2vec(fileIn, fileOut; size = embedVectorSize, window = windowIn,
        sample = 1e-2, negative = 5, min_count = 0, alpha = 0.025, cbow = 1, verbose = true)
end
