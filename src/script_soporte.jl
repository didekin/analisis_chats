#  ============================ 4. Conversaciones con enlace a soporte ====================================================
tokensDf_4, distances_4 = distancesKmedoids(conversacion_soporte)

# =====  K-medoids analysis  ======
cluResult_4, cluDf_4 = clusterKmedoidsDf(distances_4, 2, tokensDf_4)
plotFreqRelativeWords(cluDf_4, "freq_grupo_soporte", [colorant"green"])
conv_bycluster_4 = groupby(cluDf_4, :grupo) |> df -> combine(df, nrow => :num_conversaciones)

printMedoid(1, cluResult_4, tokensDf_4)