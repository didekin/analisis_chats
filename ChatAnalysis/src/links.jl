function convsDf(sqlQuery::String, conn::MySQL.Connection)::DataFrame
    # posArray = ["ADJ", "ADP", "ADV", "NOUN", "PROPN", "SYM", "VERB", "X"]
    queryDbtoDf(sqlQuery, conn)
    # |>
    #     df -> groupby(df, :id_conv) |>
    #         df1 -> combine(df1, :tokens_links => (t -> join(t, ' ')) => :tokens_links)
end

# Extract word2vec embeddings for links.
function getEmbeddingsLinks(linksQuery::String, embeddingsFile::String, conn::MySQL.Connection)::DataFrame
    linksDf = sort!(queryDbtoDf(linksQuery, conn), :link) 
    @show size(linksDf, 1)
    embeddings = wordvectors(embeddingsFile)
    embeddingsDf = hcat(DataFrame(word = embeddings.vocab), DataFrame(collect(embeddings.vectors'), :auto)) 
    @show size(embeddingsDf, 1)
    sort!(embeddingsDf, :word)
    sort!(innerjoin(linksDf, embeddingsDf, on = :link => :word), :link)
    return linksDf
end

function clusterLk(mtxIn::Matrix, numCentros::Integer, vecNamesLinks::Vector{String})
    clusterR = kmeans(mtxIn, numCentros; maxiter = 100, display = :final)
    enlacesDf = DataFrame(enlace = vecNamesLinks)
    embeddingsDf = DataFrame(mtxIn', :auto)
    df_out = hcat(enlacesDf, DataFrame(grupo = clusterR.assignments), embeddingsDf)
    return clusterR.centers, df_out
end

function linksByCluster(clustersDf::DataFrame)::DataFrame
    groupby(clustersDf, :grupo) |> df -> combine(df, nrow => :num_enlaces)
end

function greatest_bycosine(grupoNum::Integer, cluDf::DataFrame, centers::Matrix{Float64}, numInList::Integer)::Vector{String}
    # no normalizo la matriz de embeddings porque ya está normalizada.
    centerNorm = centers[:, grupoNum] / norm(centers[:, grupoNum])
    cluOut = filter(:grupo => .==(grupoNum), cluDf) |> df1 -> select(df1, Not([:grupo]))
    cosines = Matrix(cluOut[:, Not(:enlace)]) * centerNorm
    dfOut = hcat(cluOut, DataFrame(cosine = cosines)) |>
            df2 -> sort!(df2, :cosine, rev = true)[1:min(size(df2)[1], numInList), :enlace] |>
                   vec -> map(v -> SubString(v, 1:min(length(v), 70)), vec)     #select!(df2, :enlace => ByRow(lk -> SubString(lk, 1:min(length(lk), 70)))) 
end

medioin(x::Int64) = (x ÷ 2) + min(1, (x % 2))

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

function writeFileInW2vec(convsDf::DataFrame, w2vecFile::String)
    fileStream = open(w2vecFile, "w")
    for conv in eachrow(convsDf)
        println(fileStream, conv.tokens_links)
    end
    close(fileStream)
end

# cbow = 1: use skip-gram model. Minimum counts is 2.
function writeFileOutW2vec(embedVectorSize::Int64, windowIn::Int64, fileIn::String, fileOut::String)
    word2vec(fileIn, fileOut; size = embedVectorSize, window = windowIn,
        sample = 1e-2, negative = 5, min_count = 2, alpha = 0.025, cbow = 1, verbose = true)
end
