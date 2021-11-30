#  ============================== Files ==============================
const chat_dir = "/Users/pedro/Documents/clientes/rhymarketing/analisis_chats";
#  ==== Data ====
const data_dir = joinpath(chat_dir, "data");
#  ==== Sources ====
const project_dir = joinpath(chat_dir, "ChatAnalysis")
const prod_rsc_dir = joinpath(project_dir, "resources");
const prod_src_dir = joinpath(project_dir, "src");
const report_src = joinpath(prod_src_dir, "report_code");
#  ============================== Reports ==============================
const reports_dir = chat_dir * "/reports";
const imgReportDir = reports_dir * "/img";

#  === Literals ===
# Texto para identificar un enlace de soporte.
const mark_soporte = "soporte_enlace";
# Texto para identificar rol cliente.
const cliente = "cl";
# Texto para identificar rol agente.
const agente = "ag";

# ============================== Functions ==============================

function mysqlConn()::MySQL.Connection
    return DBInterface.connect(MySQL.Connection, "127.0.0.1", "pedro", "21m01y20s20"; db = "chatrhy", port = 3306, unix_socket = MySQL.API.MYSQL_DEFAULT_SOCKET)
end
