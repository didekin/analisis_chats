function plotFreqRelativeWords(cluDf::DataFrame, namePlot::String, colorIn)
    grupos = sort(unique(cluDf.grupo))
    for i in grupos
        filter(:grupo => ==(i), cluDf) |>
        df1 -> corpustokens(df1).lexicon |>
               lex -> DataFrame(vocablo = collect(keys(lex)), frecuencia = collect(values(lex))) |>
                      df2 -> select(df2, :vocablo, :frecuencia => (f -> f / size(df1, 1)) => :frecuencia) |>
                             df3 -> sort!(df3, :frecuencia, rev = true)[1:min(size(df3, 1), 25), :] |>
                                    df4 -> plot(
                                                df4, x = :vocablo, y = :frecuencia,
                                                Guide.yticks(ticks = collect(0:0.05:maximum(df4.frecuencia))),
                                                color = colorIn,
                                                Geom.bar(position = :dodge)
                                          ) |>
        plot1 -> draw(PNG(imgReportDir * "/" * namePlot * string(i) * ".png", 18cm, 14cm), plot1)
    end
end