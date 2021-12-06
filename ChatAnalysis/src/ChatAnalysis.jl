module ChatAnalysis

using CSV, Clustering, DataFrames, DBInterface, Distances, Languages, LinearAlgebra,
    MySQL, Tables, SparseArrays, TextAnalysis, Word2Vec

# Texto para identificar un enlace de soporte.
const mark_soporte = "soporte_enlace";

include("analisis_descrip.jl")
include("db_utils.jl")
include("insert_turnos.jl")
include("links_utils.jl")
include("links.jl")
include("r_upd_utils.jl")
include("token_turnos_df.jl")

end # module