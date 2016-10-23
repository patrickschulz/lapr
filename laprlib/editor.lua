local M = {}

local pl = {}
pl.file     = require "pl.file"
pl.stringx  = require "pl.stringx"
pl.utils    = require "pl.utils"

local packages = require "laprlib.packages"
local util = require "laprlib.util"

local packagelookup = packages.load()

local settings = {
    editor = "vim",
    tmpfile = "__tmp"
}

--{{{ edit
function M.edit(content, titleline, parse)
    -- write titleline and content, both optional, separated by a newline
    local content = ((titleline and string.format("%s\n", titleline)) or "") .. (content or "")

    -- write the file, edit it and read the content back in again
    pl.file.write(string.format("%s.tex", settings.tmpfile), content)
    os.execute(string.format("%s %s.tex", settings.editor, settings.tmpfile))
    local new_content = pl.file.read(string.format("%s.tex", settings.tmpfile))
    new_content = pl.stringx.rstrip(new_content)

    local packagelist
    if parse then
        local diff = M.get_difference(content, new_content)
        local newlines = M.extract_commands_from_diff(diff)
        packagelist = M.parse_latex_commands(newlines)
    end

    os.remove(string.format("%s.tex", settings.tmpfile))

    return new_content, packagelist
end
--}}}
--{{{ get difference
function M.get_difference(pre, post)
    -- implementation for now: write the contents to files, compare, delete files. 
    -- better: use some sort of real diff function
    pl.file.write(string.format("%s%d", settings.tmpfile, 1), pre)
    pl.file.write(string.format("%s%d", settings.tmpfile, 2), post)
    local command = string.format("diff %s%d %s%d", settings.tmpfile, 1, settings.tmpfile, 2)
    local status, code, stdout, stderr = pl.utils.executeex(command)
    os.remove(string.format("%s%d", settings.tmpfile, 1))
    os.remove(string.format("%s%d", settings.tmpfile, 2))
    return stdout
end
--}}}
--{{{ extract commands
function M.extract_commands_from_diff(diff)
    local newlines = {}
    for line in pl.stringx.lines(diff) do
        if pl.stringx.startswith(line, ">") then
            line = string.sub(line, 3)
            table.insert(newlines, line)
        end
    end
    return newlines
end
--}}}
--{{{ parse latex
function M.parse_latex_commands(lines)
    local packagelist = {}
    for _, line in ipairs(lines) do
        for command in string.gmatch(line, "\\(%a+)") do
            local package
            if packagelookup:is_command(command) then
                package = packagelookup:get_package("commands", command)
            else
                package = packagelookup:ask_package("command", command)
                packagelookup:insert_command(command, package)
            end
            if not packagelookup:is_latex_command(command) then
                table.insert(packagelist, package)
            end
        end
        for env in string.gmatch(line, "\\begin%{([^}]+)%}") do
            local package
            if packagelookup:is_environment(env) then
                package = packagelookup:get_package("environments", env)
            else
                package = packagelookup:ask_package("environment", env)
                packagelookup:insert_environment(env, package)
            end
            if not packagelookup:is_latex_environment(env) then
                table.insert(packagelist, package)
            end
        end
    end
    return packagelist
end
--}}}
--{{{ strip titleline
function M.strip_titleline(content, title)
    local matchstr = string.format("%%%% %s\n()", title)
    local idx = string.match(content, matchstr)
    if idx then
        content = content:sub(idx)
    end
    -- same without newline
    matchstr = string.format("%%%% %s()", title)
    idx = string.match(content, matchstr)
    if idx then
        content = content:sub(idx)
    end

    return content
end
--}}}

--{{{ set editor
function M.set_editor(editor)
    settings.editor = editor
end
--}}}

return M

-- vim: foldmethod=marker
