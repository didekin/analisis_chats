using Test
import ChatAnalysis as CH

credentials = CH.dbCredentials("data/.envtest")
# It requires a data/.envtest file with properties DB_USER=pedro, DB_PASSWD=, DB_NAME= and DB_HOST=127.0.0.1 
@test credentials["DB_USER"] == "pedro" && credentials["DB_HOST"] == "127.0.0.1"


