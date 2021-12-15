using Test
import ChatAnalysis as CH

@testset verbose=true "lexicon" begin
    @show CH.dictFromArrWords("hola1 adiós adios bb bb bb")
    @test CH.dictFromArrWords("hola1 adiós adios bb bb bb") == Dict("hola1" => 1, "adiós" => 1, "adios" => 1, "bb" => 3)
end