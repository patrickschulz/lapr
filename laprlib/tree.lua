local pl = {}
pl.stringx = require "pl.stringx"
pl.tablex = require "pl.tablex"
pl.list = require "pl.List"
pl.pretty = require "pl.pretty"

local util = require "laprlib.util"

local M = {}

-- utility
--{{{ linearize helper
local function linearize_helper(common, subtree)
    local result = pl.list()

    if #subtree == 0 then
        table.insert(result, pl.list{common})
    else
        for elem in pl.list.iterate(subtree) do
            if is_entry(elem) then
                for sub in pl.list.iterate(elem:linearize()) do
                    table.insert(result, sub:insert(1, common))
                end
            else
                table.insert(result, pl.list{common, elem})
            end
        end
    end

    return result
end
--}}}
--{{{ linearize list
local function linearize_list(list)
    local result = pl.list()
    for _, elem in ipairs(list) do
        local linlist = elem:linearize()
        for sublist in linlist:iterate() do
            result:append(sublist)
        end
    end

    return result
end
--}}}
--{{{ check match while ignoring case
local function check_match_ignore_case(first, second)
    return string.match(first:lower(), second:lower()) and true or false
end
--}}}

--{{{ entry functions
function create_entry(common, sublist)
    local self = {
        common = common,
        sublist = pl.list(sublist)
    }

    local meta = {
        linearize = function(self)
            return linearize_helper(self.common, self.sublist)
        end,
        __tostring = function(self) return tostring(self.common) .. ":" .. tostring(self.sublist) end
    }
    meta.__index = meta

    setmetatable(self, meta)

    return self
end

function is_entry(entry)
    if type(entry) == "table" and entry.common and entry.sublist then
        return true
    end
end
--}}}

-- nodes
--{{{ find
local function find(node, searchpattern, list, index)
    local match = check_match_ignore_case(node.value, searchpattern:get_prefix())
    if match then -- current node matches current search pattern
        local entry = create_entry(index)
        --list:append(index) -- save index
        if not node:is_leaf() then 
            searchpattern:strip_prefix() -- advance current search pattern, since we are going one level deeper
            local sublist = pl.list()
            for i, child in ipairs(node.children) do
                child:find(searchpattern:copy(), sublist, i)
            end
            entry.sublist = sublist
            --list:append(sublist)
        end
        list:append(entry)
    end
end
--}}}
--{{{ create node
local function node(value, ...)
    local self = {
        value = value,
        children = (... and pl.list({ ... })) or (not value and pl.list() or nil)
    }

    local meta = {
        is_leaf = function(self)
            return not self.children
        end,
        is_node = function(self)
            return not not self.children
        end,
        is_root = function(self)
            return not self.value and true
        end,
        ensure_node = function(self)
            if not self.children then
                self.children = pl.list()
            end
        end,
        append_child = function(self, leaf)
            self.children:append(leaf)
        end,
        find = find
    }
    meta.__index = meta

    setmetatable(self, meta)

    return self
end
--}}}

-- tree
local treemeta = util.new_metatable("treelib")
--{{{ create tree
function M.create()
    local self = {
        root = node()
    }

    setmetatable(self, treemeta)

    return self
end
--}}}
--{{{ append entry
function treemeta.append(self, path, value)
    local path = path or { }
    local current_node = self.root
    while true do
        local idx = table.remove(path, 1)
        if not idx then
            break
        end

        current_node = current_node.children[idx]
        current_node:ensure_node()
    end
    current_node:append_child(node(value))
end
--}}}
--{{{ extract max
local function extract_max(list)
    local linlist = linearize_list(list)
    local lengths = linlist:map(pl.list.len)
    local _, max = lengths:minmax()
    if lengths:count(max) > 1 then
        return nil
    else
        local index = lengths:index(max)
        return max, linlist[index]
    end
end
--}}}
--{{{ tree find
function treemeta.find(self, searchpattern)
    local list = pl.list()
    for i, child in ipairs(self.root.children) do
        find(child, searchpattern:copy(), list, i)
    end
    local max, path = extract_max(list)
    if max then
    else
        util.printf("ambigious pattern '%s'", searchpattern:string_representation())
    end

    return path
end
--}}}
--{{{ walk the tree
local function walk(node, func, level)
    if not node:is_root() then 
        func(node.value, level)
    end
    if node:is_node() then
        for child in node.children:iterate() do
            walk(child, func, level + 1)
        end
    end
end

function treemeta.walk(self, func)
    walk(self.root, func, 0)
end
--}}}

return M

-- vim: foldmethod=marker
