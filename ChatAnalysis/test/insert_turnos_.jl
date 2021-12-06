using Test, DataFrames, DBInterface
import ChatAnalysis as CH

const delete_enlace = "DELETE FROM enlace";
const delete_turno = "DELETE FROM turno";

@testset verbose = true "turnoWithLinks" begin
    testMatch1 = match(CH.prod_link_regexp, "https://www.google.com/search?q=Asus+ZenBook+14+BX425EA-BM144R&oq=Asus+ZenBook+14+BX425EA-BM144R&aqs=chrome..69i57j69i59j69i60l3&sourceid=chrome&ie=UTF-8")
    testMatch2 = match(CH.prod_link_regexp, "https://www.pccomponentes.com/configurador/")
    testMatch3 = match(CH.prod_link_regexp, "https://downloadcenter.intel.com/es/download/29904/Gr-ficos-Intel-Controladores-de-Windows-10-DCH?wapkw=i5-10300H")
    testMatch4 = match(CH.prod_link_regexp, "https://downloadcenter.intel.com/es/product/55005")
    @test CH.checkPathUrl(testMatch1) == "Asus+ZenBook+14+BX425EA-BM144R"
    @test CH.checkPathUrl(testMatch2) == CH.configurador_link
    @test CH.checkPathUrl(testMatch3) == "downloadcenter.intel.com/es/download/29904/Gr-ficos-Intel-Controladores-de-Windows-10-DCH"
    @test CH.checkPathUrl(testMatch4) == "downloadcenter.intel.com/es/product/55005"

    @test CH.extractLinks("https://www.pccomponentes.com/asus-tuf-gaming-dash-f15-fx516pr-hn002-intel-core-i7-11370h-16gb-512gb-ssd-rtx-3070-156") ==
            [
                ("asus-tuf-gaming-dash-f15-fx516pr-hn002-intel-core-i7-11370h-16gb-512gb-ssd-rtx-3070-156",
                 CH.linkHashed*string(hash("asus-tuf-gaming-dash-f15-fx516pr-hn002-intel-core-i7-11370h-16gb-512gb-ssd-rtx-3070-156")))
            ]
    @test CH.extractLinks("turno_sin_links") == []
    # Devuelve los productos en orden inverso.
    @test CH.turnoWithLinks("https://www.pccomponentes.com/produ-1https://www.pccomponentes.com/produ-2") ==
            CH.linkHashed*string(hash("produ-2"))*" "*CH.linkHashed*string(hash("produ-1"))
    @test CH.turnoWithLinks("turno_sin_links") == "turno_sin_links"
end # testset

# It requires a data/.envtest file with properties DB_USER=, DB_PASSWD=, DB_NAME= and DB_HOST= with the credentials for the database.
@testset verbose=true "insertTurno" begin
    df1 = DataFrame(id=[11],rol=[CH.cliente],turno=[2],data=[["hola", "https://www.pccomponentes.com/produ-1", "adios"]])
    credentials = CH.dbCredentials("data/.envtest")
    conn = CH.mysqlConn(credentials)

    stmt1 = DBInterface.prepare(conn, CH.insert_enlace)   
    dfRowOut1 = DataFrame(id_conv=[11],rol=[CH.cliente],turno_rol=[2], link="produ-1", hash_link=CH.linkHashed*string(hash("produ-1")))[1,:]  
    CH.insertEnlace(stmt1,df1[1,:])    
    @test CH.queryDbtoDf(CH.all_enlace, credentials)[1,:] == dfRowOut1
    CH.queryDbtoDf(delete_enlace,credentials)

    stmt2 = DBInterface.prepare(conn, CH.insert_turno) 
    dfRowOut2 = DataFrame(id_conv=[11],rol=[CH.cliente],turno_rol=[2], tokens="hola adios", tokens_links="hola "*CH.linkHashed*string(hash("produ-1"))*" adios")[1,:]  
    CH.insertTurno(stmt2, stmt1, df1[1,:])
    @test CH.queryDbtoDf(CH.all_enlace, credentials)[1,:] == dfRowOut1 && CH.queryDbtoDf(CH.all_turno, conn)[1,:] == dfRowOut2
    
    DBInterface.close!(stmt1)
    DBInterface.close!(stmt2)
    DBInterface.close!(conn)
    CH.queryDbtoDf(delete_enlace, credentials)
    CH.queryDbtoDf(delete_turno, credentials)
end

# test_db = turnos_df(joinpath("data/", "test.csv")) |> tokensDf |> createDbTurnos