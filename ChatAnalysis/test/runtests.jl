tests = ["db_utils_.jl",
         "insert_turnos_.jl",
         "token_turnos_df_.jl"
        ]

println("Runing tests:")

for t in tests
    println("* $t ...")
    include(t)
end