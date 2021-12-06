import ChatAnalysis as CH

const reportsrc = joinpath(prod_src_dir, "report_code");
const jmddir = joinpath(report_src, "jmd")
const reportsdir = joinpath(chat_dir, "reports");
const imgDir = joinpath(reportsdir, "img");

# =========================== Weave reports ============================= 

function chatweave(jmdDoc::String, htmlOut::String)
    CH.chatweave(jmdDoc, htmlOut; jmdsrcdir=jmddir, reports_dir=reportsdir, imgReportDir=imgDir, report_src=reportsrc)
end

chatweave(intro_jmd, intro_html)
chatweave(analisis_descrip_jmd, analisis_descrip_html)
chatweave(no_links_jmd, no_links_html)
chatweave(soporte_links_jmd, soporte_links_html)
chatweave(links_jmd, links_html)
chatweave(toc_jmd, toc_html)