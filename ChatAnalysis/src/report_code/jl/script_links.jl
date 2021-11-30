# =========================== 5.  Análisis semántico de los enlaces a producto ============================================

# Creamos fichero de entrada para word2vec.
df = convsDf(all_turnos) # |> df -> writeFileInW2vec(df, w2VecfileIn)
writeFileInW2vec(df, w2VecfileIn)
# Creamos fichero de salidad para word2vec. Ventana 5. Embeddings 100.
writeFileOutW2vec(20, 5, w2VecfileIn, w2vecfileOut)
embedvec = wordvectors(w2vecfileOut)
voca = sort(embedvec.vocab)

open(joinpath(data_dir, "trash_voca.txt"), "w") do f
    for term in voca#[:, :link]
        write(f, term * " " * "\n")
    end
end

# Obtenemos los embeddings para los links.
embedLinksDf = getEmbeddingsLinks(distinct_links, w2vecfileOut)

# Obtnemos nombres de columnas para clusters data frame.
vecNamesLk = embedLkDf[:, :link] |> vec -> vec[map(!ismissing, vec)] |> vec1 -> convert(Vector{String}, vec1)
# Centers y cluster assignments
matrixCl = select(embedLkDf, Not(:link)) |> df -> collect(Matrix(df)')
# Num clusters = 4.
centersLk, clusLk = clusterLk(matrixCl, 4, vecNamesLk)
links_by_grupo = linksByCluster(clusLk)

# ====== 5.  Análisis semántico de los enlaces: GRÁFICO DE FRECUENCIA DE ENLACES =====

link_df = queryDbtoDf(sql_links_all_count) |> dropmissing! |>
          df -> filter!(:link => !=(mark_soporte), df) |>
                df1 -> groupby(df, :frecuencia) |>
                       df2 -> combine(df2, nrow => :enlaces)

plot_link_all_freq = plot(link_df, x = :frecuencia, y = :enlaces,
    Guide.xticks(ticks = collect(0:2:maximum(link_df.frecuencia))),
    Guide.yticks(ticks = collect(0:20:maximum(link_df.enlaces))),
    color = [colorant"indigo"], Geom.bar(position = :dodge))
draw(PNG(imgReportDir * "/plot_link_all_freq.png", 15cm, 12cm), plot_link_all_freq)

# =====  K-medoids analysis  ======
tokensDf_5, distances_5 = distancesKmedoids(turno_link)
cluResult_5, cluDf_5 = clusterKmedoidsDf(distances_5, 2, tokensDf_5)
plotFreqRelativeWords(cluDf_5, "freq_grupo_links", [colorant"turquoise"])
conv_bycluster_5 = groupby(cluDf_5, :grupo) |> df -> combine(df, nrow => :num_conversaciones)
