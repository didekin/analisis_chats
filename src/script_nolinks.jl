# ============================ 3.  Análisis semántico de las conversaciones sin enlaces ===================================
tokensDf_3, distances_3 = distancesKmedoids(conversacion_nolink)

# =====  K-medoids analysis  ======
cluResult_3, cluDf_3 = clusterKmedoidsDf(distances_3, 2, tokensDf_3)
plotFreqRelativeWords(cluDf_3, "freq_grupo_nolinks", [colorant"olive"])
conv_bycluster_3 = groupby(cluDf_3, :grupo) |> df -> combine(df, nrow => :num_conversaciones)

printMedoid(1, cluResult_3, tokensDf_3)