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
local searchstring = require "laprlib.searchstring"
local util = require "laprlib.util"
--}}}

local M = {}

-- metatable for project objects
local meta = util.new_metatable("structure")

local valid_structure_types = { "part", "chapter", "section", "subsection", "subsubsection", "paragraph" }
local tags = { "new", "finished", "proofread" }

local function new_struclet(title, content)
    local struclet = {
        title = title,
        content = content
    }

    return setmetatable(struclet, { __tostring = function(self) return title end })
end

--{{{ create
function M.create(toplevel)
    local toplevel = toplevel or "part"
    local self = {
        content = tree.create(),
        toplevel = toplevel,
        current = nil
    }
    setmetatable(self, meta)
    return self
end
--}}}
--{{{ list structure
function meta.list(self)
    local p = function(struclet, level)
        print(string.format("%-13s: %s", valid_structure_types[level], struclet.title))
    end
    self.content:walk(p)
end
--}}}
--{{{ get toplevel offset
function meta.get_toplevel_offset(self)
    return pl.tablex.find(valid_structure_types, self.toplevel)
end
--}}}
--{{{ get structure level
function meta.get_structure_level(self, typ)
    return pl.tablex.find(valid_structure_types, typ)
end
--}}}
--{{{ get structure number
function meta.get_structure_number(self, maxindex, typ)
    local counter = 0
    for i = 1, maxindex do
        --util.printf("%d > %d?", pl.tablex.find(valid_structure_types, self.content[i].typ), pl.tablex.find(valid_structure_types, typ))
        if pl.tablex.find(valid_structure_types, self.content[i].typ) < pl.tablex.find(valid_structure_types, typ) then
            counter = 0
        end
        if self.content[i].typ == typ then
            counter = counter + 1
        end
    end
    return counter
end
--}}}
--{{{ get index from pattern
function meta.get_index_from_pattern(self, pattern)
    -- possible patterns:
    -- foo:bar:baz  -> selects matching struclets
    -- foo:2:3      -> selects section 3 in chapter 2 in a part matching foo
    -- foo:2        -> selects chapter 2 in a part matching foo
    -- foo:{1,4}    -> selects chapter 1 and 4 in a part matching foo
    -- 1:2:3        -> selects section 3 of chapter 2 of part 1
    --
    -- patterns can start with : and can contain ...
    -- : replaces a level, ... replaces any pattern (matches every struclet)

    local number = pl.stringx.count(pattern, ":")
end
--}}}
--{{{ get content
function meta.get_content(self, index)
    if type(index) == "string" then -- index is a pattern like intro:ideas
        index = self:get_index_from_pattern(index)
    end
    return self.content[index].text
end
--}}}
--{{{ get full content
function meta.get_full_content(self, index)
    local text = {}
    for struclet in self.content:iter() do
        table.insert(text, struclet.text)
    end
    return table.concat(text, "\n")
end
--}}}
--{{{ add structure element
function meta.add_structure_element(self, structure, title)
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
        --self.content:append(insert_list, { title = title, typ = valid_structure_types[level], tag = "new" })
        self.content:append(insert_list, new_struclet(title))
    end
end
--}}}

return M

-- vim: foldmethod=marker
