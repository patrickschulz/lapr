local util = require "laprlib.util"

local M = {}

function M.create_document(class, exe, packages, title, text, custom)
    local content = {}
    table.insert(content, M.create_classline(class))
    table.insert(content, M.create_preamble(exe, packages, title, custom.preamble))
    table.insert(content, "\\begin{document}")
    table.insert(content, custom.beforetitle)
    table.insert(content, M.create_title())
    table.insert(content, custom.before)
    table.insert(content, M.create_text_body(text))
    table.insert(content, custom.after)
    table.insert(content, "\\end{document}")

    return table.concat(content, "\n")
end

function M.create_title()
    return "\\maketitle"
end

function M.create_text_body(text)
    return string.format("%s", text)
end

function M.create_preamble(exe, packages, title, custom)
    local content
    if exe == "lualatex" then
        content = {
            "\\usepackage{fontspec}",
            "\\setmainfont{Linux Libertine O}",
            "\\usepackage{polyglossia}",
            "\\setdefaultlanguage{german}",
        }
    elseif exe == "pdflatex" then
        content = {
            "\\usepackage[utf8]{inputenc}",
            "\\usepackage[ngerman]{babel}",
        }
    else
        util.printf("sorry, engine '%s' is not supported (yet?)", exe)
        return "% unknown LaTeX engine"
    end
    for _, package in ipairs(packages) do
        local packagename = package.name
        local options = package.options
        local packagestr
        if options then
            packagestr = string.format("\\usepackage[%s]{%s}", table.concat(options, ", "), packagename)
        else
            packagestr = string.format("\\usepackage{%s}", packagename)
        end
        table.insert(content, packagestr)
    end
    table.insert(content, string.format("\\title{%s}", title.title))
    --table.insert(content, string.format("\\subtitle{%s}", title.subtitle))
    table.insert(content, string.format("\\author{%s}", title.author))
    table.insert(content, string.format("\\date{%s}", title.date))
    table.insert(content, custom)
    return table.concat(content, "\n")
end

function M.create_classline(class)
    if class.options and (#class.options ~= 0) then
        return string.format("\\documentclass[%s]{%s}", table.concat(class.options, ", "), class.class)
    else
        return string.format("\\documentclass{%s}", class.class)
    end
end

return M
