include("commons_test.jl")

test_db = turnos_df(joinpath(test_data, "test.csv")) |> tokensDf |> createDbTurnos