using RCall

# === File for udpipe R library === 
const udp_file = pwd()*"/src/resources/"*"spanish-gsd-ud-2.5-191206.udpipe"

function udpModel(udpFile::String)::RObject
    R"library(udpipe)"
    es_model = R"es_model <- udpipe_load_model(file = $udpFile)"
    return es_model
end

# To avoid to repeat this call every time we need the udp model.
const default_udpModel = udpModel(udp_file)

function udpTokens(turnoText::String, classWords::Array{String})::Vector{String}
    if length(strip(turnoText)) == 0
        return Vector{String}(undef, 0)
    end
    R"""
    x <- as.data.frame(udpipe_annotate($default_udpModel, x = $turnoText, tagger = "default", parser = "none")) 
    dfx <- subset(x, upos %in% $classWords)[, c("token")]
    """
    tokens = @rget dfx
    if !isa(tokens, Vector{String})
        tokens = vcat(tokens)
    end
    return length(tokens) > 0 ? tokens : Vector{String}(undef, 0)
end

function udpTokens(turnoText::String)
    return udpTokens(turnoText, ["ADJ", "ADP", "ADV", "AUX", "CCONJ", "NOUN", "NUM", "PROPN", "SCONJ", "SYM", "VERB", "X"])
end