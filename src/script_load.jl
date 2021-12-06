using ChatAnalysis

# Carga en base de datos del fichero de conversaciones.
turnosDB = turnos_df(joinpath(data_dir, "test.csv")) #|> tokensDf |> createDbTurnos