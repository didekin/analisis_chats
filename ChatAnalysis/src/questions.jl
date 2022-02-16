function hashLkTokens(credentials::Dict{String,String}, udpModelIn::RObject)
    sqlDbToDf(two_previous_turnos_tokens, credentials) |>  # df (hash_link, tokens)
        dfIn -> select!(dfIn, Not(:tokens), :tokens => ByRow(checkPrice) => :tokens) |>
                dfIn -> select!(dfIn, Not(:tokens), :tokens => ByRow(checkFinalTokens) => :tokens) |>
                    dfIn -> filter!(row -> length(row.tokens) > 0, dfIn) |> dropmissing! |>
                        dfIn -> groupby(dfIn, :hash_link) |> 
                            dfIn -> combine(dfIn, :tokens => (tk -> join(tk, ' ')) => :tokens) |>
                                dfIn -> select!(dfIn, Not(:tokens), :tokens => ByRow(tk -> replace(tk, r"\++|\*+|\?+|:\)|\\+|^-+|\/+" => s" ")) => :tokens)

end

function corpusturnos(hashLinkTks::DataFrame)::Corpus
    corpus = select!(hashLinkTks, Not(:tokens), :tokens => ByRow(tk -> join(string.(hash.(split(tk))),' ')) => :tokens) |>
                dfIn -> select(dfIn, Not(:tokens), :tokens => ByRow(StringDocument) => :tokendoc) |>
                    df -> Corpus(df[:, :tokendoc])
    update_lexicon!(corpus)
    return corpus
end

function dtmHashLkHashTks(corpusIn::Corpus)::SVD
    rm_sparse_freq_terms(corpusIn; sparse = 0.01, frequent = 0.95) |> # Terms to be included in the dtm matrix.
        terms -> DocumentTermMatrix(corpusIn, terms) |> # Dense.
            dtm -> tf_idf(dtm) |>  # Sparse. Each row is a link, each column is a word.
                    tf_idf -> collect(transpose(tf_idf)) |> # Dense. Each row is a word, each column is a link.
                        tf_idf_T -> svd(tf_idf_T) # SVD analysis; thin or reduced version.    
end

function reduceDimensions(svdIn::SVD, numDim::Integer)
    # Reduction to numDim rows.
    # Transformed links: each row is a dimension in words space and each column is one of the original links.
    Vtr = SVD.Vt[1:2, :]
    # Transformation matrix for original queries.
    SrUr = inv(Diagonal(SVD.S[1:2])) * SVD.U[:, 1:2]'
    return SrUr, Vtr
end
