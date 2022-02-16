using Test, DataFrames, DBInterface
import ChatAnalysis as CH

@testset verbose = true "word2vecLinks" begin
    credentials = CH.dbCredentials("data/.envtest")
    udpModelIn = CH.udpModel("data/spanish-gsd-ud-2.5-191206.udpipe")

    @test CH.checkPrice("intel de 1500 euros") == "intel de 1500-euros"

    # Previous state in BD.
    df1 = DataFrame(id = [11], rol = [CH.cliente], turno = [2], data = [["hola", "pero", "https://www.pccomponentes.com/produ-1", "2.000", "euros", "adios"]])
    CH.createDbTurnos(df1, credentials)
    # Test execution. 
    df2 = CH.convsDf(credentials, udpModelIn)
    @test df2[:, :tokens_links] == ["hola " * CH.linkHashed * string(hash("produ-1")) * " 2.000-euros"]
    # Cleaning DB.
    CH.cleanDb(credentials)

    @test CH.checkHashLink(CH.linkHashed * "6261800333186040637") && !CH.checkHashLink("lkHs_A6261800333186040637") && !CH.checkHashLink("kHs_6261800333186040637")

    # Each row is a link: :word (name) + :x1...:x100 for the embeddings.
    dfLinks = CH.embeddingsForLinks("data/w2vec_out_test1.txt")
    @test size(dfLinks) == (2, 101) && dfLinks[:, :word] == ["lkHs_16522637756095235590", "lkHs_16215600956087645700"]
end

@testset verbose = true "Kmedoids_clusters_medoidsTokens" begin
    # File with ten links and one extra word.
    dfEmb = CH.embeddingsForLinks("data/w2vec_out_test2.txt")
    result = CH.kMedoidsFromEmbeddings(dfEmb, 2)
    @test length(result.medoids) == 2 && length(dfEmb[result.medoids[1], Not(:word)]) == 100 && length(result.assignments) == 10 && sum(result.counts) == 10

    credentials = CH.dbCredentials("data/.envtest")

    # File with 2 links and one extra word.
    CH.prepareSqlIn(CH.insert_enlace, credentials,
        [
            [1, CH.agente, 1, "prod-1", "lkHs_16522637756095235590"],
            [2, CH.cliente, 1, "prod-2", "lkHs_16215600956087645700"]
        ]
    )
    wordMedoids, dfOut = CH.dfFromKmedoids("data/w2vec_out_test3.txt", 2, credentials)
    # Assertion about medoids.
    @test issetequal(wordMedoids, ["lkHs_16522637756095235590", "lkHs_16215600956087645700"])
    # Assertions about resulting clusters
    @test issetequal(dfOut[:, :hash_link], wordMedoids) && issetequal(dfOut[:, :grupo], [1, 2]) && issetequal(dfOut[:, :link], ["prod-1", "prod-2"])
    # Assertions about linka and turno_tokens of medoids.
    CH.prepareSqlIn(CH.insert_turno, credentials,
        [
            # Dos turnos y un enlace.
            [1, CH.cliente, 1, "hola1 info1", "hola1 info1"],
            [1, CH.agente, 1, "hola2 adios2", "hola2 lkHs_16522637756095235590 adios2"],
            # Un turno y un enlace.
            [2, CH.cliente, 1, "hola enlace", "hola enlace lkHs_16215600956087645700"]
        ]
    )
    dfMedoidsTokens = CH.turnosTokensMedoids(wordMedoids, credentials)
    @test issetequal(dfMedoidsTokens[:, :link], ["prod-1", "prod-2"]) && issetequal(dfMedoidsTokens[:, :alltokens], ["hola1 info1 hola2 adios2", "hola enlace"])
    CH.cleanDb(credentials)
end

@testset verbose = true "mostFrequentWords_inclusters" begin
    udpModelIn = CH.udpModel("data/spanish-gsd-ud-2.5-191206.udpipe")
    credentials = CH.dbCredentials("data/.envtest")

    @test  issetequal(CH.checkFinalTokens("modelos link"), " ") && CH.checkFinalTokens("enlace") == "" && CH.checkFinalTokens("prod-1") == "prod-1"

    rowStr = "hola2 hola2 buenas1"
    @test issetequal(CH.lexicoCluster(rowStr), ["hola2", "buenas1"])

    CH.sqlDbToDf(
        "INSERT into turno (id_conv, rol, turno_rol, tokens, tokens_links)
        VALUES  (11, 'ag', 1, 'hola1','hola1'),(11, 'cl', 1, 'buenas1','buenas1 hash_prod1'),(11, 'ag', 2, 'adios1','adios1'),
                (12, 'ag', 1, 'buenas2','buenas2 hash_prod2');
        INSERT into enlace(id_conv,rol,turno_rol,link,hash_link) 
        VALUES (11,'cl',1,'prod_1','hash_prod1'),(12,'ag',1,'prod_2','hash_prod2');",
        credentials
    )
    CH.waitForDb(1)
    conn = CH.mysqlConn(credentials)
    # Two links in the same group: grupo 1.
    dfHashLinkGrupo = DataFrame(hash_link = ["hash_prod1", "hash_prod2"], grupo = [1, 1])
    dfFinal1 = CH.mostFrequentWords(dfHashLinkGrupo, conn, udpModelIn)
    @test size(dfFinal1) == (1, 2) && issetequal(dfFinal1[:, :grupofreqwordsVec][1], ["hola1", "buenas1", "buenas2"])

    # One link in each group.
    dfHashLinkGrupo = DataFrame(hash_link = ["hash_prod1", "hash_prod2"], grupo = [1, 2])
    dfFinal2 = CH.mostFrequentWords(dfHashLinkGrupo, conn, udpModelIn)
    @test size(dfFinal2) == (2, 2) && issetequal(dfFinal2[:, :grupofreqwordsVec][1], ["hola1", "buenas1"]) && issetequal(dfFinal2[:, :grupofreqwordsVec][2], ["buenas2"])

    CH.cleanConnDb(conn)
end