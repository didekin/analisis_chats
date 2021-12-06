import ChatAnalysis as CH

#  ============================== Files ==============================
const chat_dir = "/Users/pedro/Documents/clientes/rhymarketing/analisis_chats";
#  ==== Data ====
const data_dir = joinpath(chat_dir, "data");
#  ==== Sources ====
const project_dir = joinpath(chat_dir, "ChatAnalysis")
const prod_src_dir = joinpath(project_dir, "src");
const prod_env_file = joinpath(prod_src_dir, "resources/.env")

#  ============================== Base de datos ==============================
const credentials = CH.dbCredentials(prod_env_file)


# using Gadfly, Cairo, Fontconfig