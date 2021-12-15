using Weave

const toc_jmd = "toc.jmd"
const intro_jmd = "intro.jmd"
const analisis_descrip_jmd = "analisis_descrip.jmd"
const no_links_jmd = "no_links.jmd"
const soporte_links_jmd = "soporte_links.jmd"
const links_jmd = "links.jmd"

# Constants to be referenced in jmd docs.
const analisis_descrip_jl = "analisis_descrip.jl"
const no_links_jl = "no_links.jl"
const soporte_links_jl = "soporte_links.jl"
const links_jl = "links.jl"

const toc_html = "toc.html"
const intro_html = "intro.html"
const analisis_descrip_html = "analisis_descrip.html"
const no_links_html = "no_links.html"
const soporte_links_html = "soporte_links.html"
const links_html = "links.html"

const chat_report_format = "md2html";
const chat_template = "chat.tpl";

function src_jmd_path(jmdName::String, jmdsrcdir::String)
        return joinpath(jmdsrcdir, jmdName)
end

function out_html_path(htmlName::String, reports_dir::String)
        return joinpath(reports_dir, htmlName)
end

function chatweave(jmdDoc::String, htmlOut::String; jmdsrcdir=jmddir, reports_dir=reportsdir, imgReportDir=imgDir)
        weave(
                src_jmd_path(jmdDoc, jmdsrcdir);
                informat = "markdown",
                doctype = chat_report_format,
                out_path = out_html_path(htmlOut, reports_dir),
                fig_path = imgReportDir,
                template = joinpath(jmdsrcdir, chat_template)
        )
end