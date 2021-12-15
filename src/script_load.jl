include("script_commons.jl")

# Carga en base de datos del fichero de conversaciones.
turnosDB = CH.turnos_df(joinpath(data_dir, "conv.csv")) |> 
        dfIn -> CH.tokensDf(dfIn, udpModelConst) |> 
            dfIn -> CH.createDbTurnos(dfIn, credentials)