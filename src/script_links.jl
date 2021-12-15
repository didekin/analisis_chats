include("script_commons.jl")
using DataFrames

# =========================== 5.  Análisis semántico de los enlaces a producto ============================================

const w2VecfileIn = joinpath(resources_dir,"file_in_w2vec.txt");
const w2VecfileOut = joinpath(resources_dir, "file_out_w2vec.txt");
# Creamos fichero de entrada para word2vec.
# CH.writeFileInW2vec(credentials, udpModelConst, w2VecfileIn)
# Creamos fichero de salidad para word2vec. Ventana 6. Embeddings 100.
# CH.writeFileOutW2vec(100, 6, w2VecfileIn, w2VecfileOut)
# medoids y dataframe con :hash_link, :grupo y :link.
medoids, dfGrupos = CH.dfFromKmedoids(w2VecfileOut,10,credentials)
links_by_grupo = CH.linksByCluster(dfGrupos)
grupo_freqwords = CH.mostFrequentWords(dfGrupos,credentials, udpModelConst)
tokens_medoids = CH.turnosTokensMedoids(medoids, credentials)

# ====== 5.  Análisis semántico de los enlaces: GRÁFICO DE FRECUENCIA DE ENLACES =====

# link_df = sqlDbToDf(all_links_count) |> dropmissing! |>   # TODO: falta parámetro conn en sqlDbToDf
#           df -> filter!(:link => !=(mark_soporte), df) |>
#                 df1 -> groupby(df, :frecuencia) |>
#                        df2 -> combine(df2, nrow => :enlaces)

# plot_link_all_freq = plot(link_df, x = :frecuencia, y = :enlaces,
#     Guide.xticks(ticks = collect(0:2:maximum(link_df.frecuencia))),
#     Guide.yticks(ticks = collect(0:20:maximum(link_df.enlaces))),
#     color = [colorant"indigo"], Geom.bar(position = :dodge))
# draw(PNG(imgReportDir * "/plot_link_all_freq.png", 15cm, 12cm), plot_link_all_freq)

# =====  K-medoids analysis  ======
# tokensDf_5, distances_5 = distancesKmedoids(turno_tokens_linkproducto)
# cluResult_5, cluDf_5 = clusterKmedoidsDf(distances_5, 2, tokensDf_5)
# plotFreqRelativeWords(cluDf_5, "freq_grupo_links", [colorant"turquoise"])
# conv_bycluster_5 = groupby(cluDf_5, :grupo) |> df -> combine(df, nrow => :num_conversaciones)


