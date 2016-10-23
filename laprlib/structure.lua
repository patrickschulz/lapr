--[[
This file belongs to the lapr project.

This module provides document structuring functions
--]]
--{{{ Module loading
local pl = {}
pl.tablex = require "pl.tablex"
pl.stringx = require "pl.stringx"
pl.list = require "pl.List"

local tree = require "laprlib.tree"
local editor = require "laprlib.editor"
local searchstring = require "laprlib.searchstring"
local util = require "laprlib.util"
--}}}

local M = {}

-- metatable for project objects
local meta = util.new_metatable("structure")
meta.__tostring = function(self) return string.format("structure: %s", tostring(table)) end

local valid_structure_types = { "part", "chapter", "section", "subsection", "subsubsection", "paragraph" }
local tags = { "new", "finished", "proofread" }

local function new_struclet(title, content)
    local struclet = {
        title = title,
        content = content or ""
    }
    local m = {
        __tostring = function(self) return string.format("title = %s", self.title) end,
        get_content = function(self) return self.content end,
        get_title = function(self) return self.title end,
        set_content = function(self, content) self.content = content end,
        set_title = function(self, title) self.title = title end,
    }
    m.__index = m

    setmetatable(struclet, m)

    return struclet
end

--{{{ create
function M.create(toplevel)
    local toplevel = toplevel or "part"
    local self = {
        content = tree.create(),
        offset = 2
    }
    setmetatable(self, meta)
    return self
end
--}}}
--{{{ edit
function meta.edit(self, pattern)
    if not pattern then
        print("no pattern given")
        return
    end
    local search = searchstring.create(pattern)
    local entry, msg = self.content:find(search)
    if entry then
        local content = string.format("%% %s\n%s", entry:get_title(), entry:get_content())
        local packagelist = {}
        content, packagelist = editor.edit(content, nil, true)
        content = editor.strip_titleline(content, entry:get_title())
        entry:set_content(content)
        return packagelist
    else
        print(msg)
    end
end
--}}}
--{{{ list structure
function meta.list(self)
    local p = function(struclet, level)
        print(string.format("%-13s: %s", valid_structure_types[level], struclet.title))
    end
    self.content:walk(p)
    meta.get_full_content(self)
end
--}}}
--{{{ get full content
function meta.get_full_content(self)
    local content = {}
    local func = function(entry, level, t)
        if entry:get_content() == "" then
            local str = string.format("\\%s{%s}", valid_structure_types[level + self.offset], entry:get_title())
            table.insert(t, str)
        else
            local str = string.format("\\%s{%s}\n%s", valid_structure_types[level + self.offset], entry:get_title(), entry:get_content())
            table.insert(t, str)
        end
    end

    self.content:walk(func, content)

    return table.concat(content)
end
--}}}
--{{{ define
function meta.define(self)
    print([[Define your document structure. Introduces new levels (e.g. chapter -> section) by inserting a whitespace.]])
    local current_path = pl.list()
    local last_level = 0
    while true do
        io.write(">")
        local line = io.read()
        if line == "" or not line then
            break
        end
        local level, title = string.match(line, "%s*()(.+)$")
        for i = level + 1, last_level do
            current_path:pop()
        end
        for i = last_level + 2, level do
            current_path:append(1)
        end
        if level > last_level then
            current_path:append(0)
        end
        current_path[level] = current_path[level] + 1
        last_level = level
        
        local insert_list = current_path:clone()
        insert_list:pop()
        self.content:append(insert_list, new_struclet(title))
    end
end
--}}}

return M

-- vim: foldmethod=marker
