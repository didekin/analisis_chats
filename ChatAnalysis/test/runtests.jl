tests = ["db_utils_.jl",
         "insert_turnos_.jl",
         "links_.jl",
         "token_turnos_df_.jl",
         "utils_.jl"
        ]

println("Runing tests:")

for t in tests
    println("* $t ...")
    include(t)
end