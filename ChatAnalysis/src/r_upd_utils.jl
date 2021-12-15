function udpModel(udpFile::String)::RObject
    R"library(udpipe)"
    es_model = R"es_model <- udpipe_load_model(file = $udpFile)"
    return es_model
end

function udpTokens(turnoText::String, classWords::Array{String}, udpModel::RObject)::Vector{String}
    if length(strip(turnoText)) == 0
        return Vector{String}(undef, 0)
    end
    R"""
    x <- as.data.frame(udpipe_annotate($udpModel, x = $turnoText, tagger = "default", parser = "none")) 
    dfx <- subset(x, upos %in% $classWords)[, c("token")]
    """
    tokens = @rget dfx
    if !isa(tokens, Vector{String})
        tokens = vcat(tokens)
    end
    return length(tokens) > 0 ? tokens : Vector{String}(undef, 0)
end

function udpTokens(turnoText::String, udpModel::RObject)
    return udpTokens(turnoText, ["ADJ", "ADP", "ADV", "AUX", "CCONJ", "NOUN", "NUM", "PROPN", "SCONJ", "SYM", "VERB", "X"], udpModel)
end