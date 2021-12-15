import ChatAnalysis as CH
# using Gadfly, Cairo, Fontconfig

#  ============================== Files ==============================
const chat_dir = "/Users/pedro/Documents/clientes/rhymarketing/analisis_chats";
#  ==== Data ====
const data_dir = joinpath(chat_dir, "data");
#  ==== Sources ====
const pkg_chat_dir = joinpath(chat_dir, "ChatAnalysis")
const src_dir = joinpath(chat_dir, "src"); 
const resources_dir = joinpath(src_dir, "resources"); 
const env_file = joinpath(src_dir, "resources/.env")

#  ============================== Base de datos ==============================
const credentials = CH.dbCredentials(env_file)

# ========================= File for udpipe R library ========================
const udp_file = joinpath(src_dir, "resources/spanish-gsd-ud-2.5-191206.udpipe")
# To avoid to repeat this call every time we need the udp model.
const udpModelConst = CH.udpModel(udp_file)


