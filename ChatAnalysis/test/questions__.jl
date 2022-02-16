using Test, DataFrames, TextAnalysis, LinearAlgebra
import ChatAnalysis as CH

@testset verbose = true "hashLkTokens" begin

    udpModelIn = CH.udpModel("data/spanish-gsd-ud-2.5-191206.udpipe")
    credentials = CH.dbCredentials("data/.envtest")

    CH.sqlDbToDf(
        "INSERT into turno (id_conv, rol, turno_rol, tokens, tokens_links)
        VALUES  (11, 'ag', 1, 'i5-1135g7/8gb/512gb ssd/15.6-pulgadas','i5-1135g7/8gb/512gb ssd/15.6-pulgadas'),
                (11, 'cl', 1, '15s-fq2093ns','15s-fq2093ns hash_prod1'),
                (11, 'ag', 2, 'adios1','adios1'),
                (12, 'ag', 1, '10400f/16gb/480gbssd+1tb/rtx30604210r/32','10400f/16gb/480gbssd+1tb/rtx30604210r/32 hash_prod2');
        INSERT into enlace(id_conv,rol,turno_rol,link,hash_link) 
        VALUES (11,'cl',1,'prod_1','hash_prod1'),(12,'ag',1,'prod_2','hash_prod2');",
        credentials
    )
    CH.waitForDb(1)
    dfTk = CH.hashLkTokens(credentials, udpModelIn)
    CH.cleanDb(credentials)

    @test size(dfTk) == (2, 2)
    @show dfTk
    @test dfTk[:, :tokens][1] == "i5-1135g7 8gb 512gb ssd 15.6-pulgadas 15s-fq2093ns"
    @test dfTk[:, :tokens][2] == "10400f 16gb 480gbssd 1tb rtx30604210r 32"    
end

@testset verbose=true "corspushashLkTokens" begin
    df1 = DataFrame(hash_link=["hash_prod1", "hash_prod2"],tokens=["i5-1135g7 15.6-pulgadas", "10400 480gbssd"])
    corps1 = CH.corpusturnos(df1)
    @test text(corps1[1]) == string(hash("i5-1135g7")) * ' ' * string(hash("15.6-pulgadas"))
    @test issetequal(keys(lexicon(corps1)), [string(hash("i5-1135g7")), string(hash("15.6-pulgadas")), string(hash("10400")), string(hash("480gbssd"))])
end

@testset verbose=true "dtmHashLkHashTks" begin
    df1 = DataFrame(hash_link=["hash_prod1", "hash_prod2"],tokens=["i5-1135g7 15.6-pulgadas", "10400 480gbssd"])
    corpusIn = CH.corpusturnos(df1)
    @show lexicon(corpusIn)
    terms = CH.rm_sparse_freq_terms(corpusIn; sparse = 0.0, frequent = 1)
    dtmIn = DocumentTermMatrix(corpusIn, terms)
    @show dtm(dtmIn, :dense)
    tf_idfIn = tf_idf(dtmIn)
    @show tf_idfIn
    tf_idf_T = collect(transpose(tf_idfIn))
    @show tf_idf_T    
    F = svd(tf_idf_T;full =false)
    @show F.U
    @show F.S
    @show F.Vt
    @test tf_idf_T ≈ F.U * Diagonal(F.S) * F.Vt
    @test tf_idf_T ≈ F.U * Diagonal(F.S) * F.V'
    @test F.Vt ≈ F.V'
end