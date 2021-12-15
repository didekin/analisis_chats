using Test
import ChatAnalysis as CH

@testset verbose=true "tokenTurnosDf" begin
    @test CH.dataNormalized(["https://www.pccomponentes.com/buscar/?query=teclado-gaming-inalambrico", "Adiós", "i5-8400/16GB/1TB"]) == 
    ["https://www.pccomponentes.com/buscar/?query=teclado-gaming-inalambrico", "adios", "i5-8400/16gb/1tb"]
    @test replace("https://www.pccomponentes.com/soporte/contacto", CH.soporte_regx => CH.soporte_sub) == "https://www.pccomponentes.com/"*CH.mark_soporte

    udpModel = CH.udpModel("data/spanish-gsd-ud-2.5-191206.udpipe")
    df1 = CH.turnos_df("data/test_load_1.csv") |> dfIn -> CH.tokensDf(dfIn, udpModel)
    @test names(df1) == ["id", "rol", "turno", "data"] && maximum(df1[df1.rol .== CH.agente, :turno]) == 3 && maximum(df1[df1.rol .== CH.cliente, :turno]) == 2    
end

