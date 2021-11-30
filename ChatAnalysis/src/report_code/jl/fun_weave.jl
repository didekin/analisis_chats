# include("jl/common_report.jl")

using Weave

const jmdsrcdir = joinpath(report_src, "jmd")
const jlsrcdir = joinpath(report_src, "jl")

const toc_jmd = "toc.jmd"
const intro_jmd = "intro.jmd"
const analisis_descrip_jmd = "analisis_descrip.jmd"
const no_links_jmd = "no_links.jmd"
const soporte_links_jmd = "soporte_links.jmd"
const links_jmd = "links.jmd"

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
const chat_template = joinpath(report_src, "chat.tpl");

function src_jmd_path(jmdName::String)
        return joinpath(jmdsrcdir, jmdName)
end

function src_jl_path(jlName::String)
        return joinpath(jlsrcdir, jlName)
end

function out_html_path(htmlName::String)
        return joinpath(reports_dir, htmlName)
end

function chatweave(jmdDoc::String, htmlOut::String)
        weave(
                src_jmd_path(jmdDoc);
                informat = "markdown",
                doctype = chat_report_format,
                out_path = out_html_path(htmlOut),
                fig_path = imgReportDir,
                template = chat_template
        )
end