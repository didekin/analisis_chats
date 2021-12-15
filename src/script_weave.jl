include("script_commons.jl")
include("fun_weave.jl")

const jmddir = joinpath(src_dir, "jmd")
const reportsdir = joinpath(chat_dir, "reports");
const imgDir = joinpath(reportsdir, "img");

# =========================== Weave reports ============================= 

chatweave(intro_jmd, intro_html)
chatweave(analisis_descrip_jmd, analisis_descrip_html)
chatweave(no_links_jmd, no_links_html)
chatweave(soporte_links_jmd, soporte_links_html)
chatweave(links_jmd, links_html)
chatweave(toc_jmd, toc_html)