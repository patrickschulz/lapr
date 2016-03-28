local M = {}

local pl = {}
pl.file = require "pl.file"
pl.path = require "pl.path"
pl.dir  = require "pl.dir"
pl.tablex = require "pl.tablex"
pl.pretty = require "pl.pretty"
pl.stringx = require "pl.stringx"

local util = require "util"

local meta = {}
meta.__index = meta

function M.create()
    -- object
    local self = { }
    setmetatable(self, meta)

    return self
end

function M.parse_output(output)
    local result = {
        errors = {},
        warnings = {},
        pages = 0
    }
    for line in pl.stringx.lines(output) do
        if string.match(line, "Output written on") then
            result.pages = string.match(line, "Output written on %S+%s*%((%d+)") 
        end
        -- ! LaTeX Error: File `kantlispum.sty' not found.
        if string.match(line, "LaTeX Error:") then
            local msg = string.match(line, "LaTeX Error: (.+)$")
            print(msg)
            table.insert(result.errors, msg)
        end
    end

    M.print_results(result)
end

function M.print_results(result)
    print("Run summary:")
    print("------------")
    print(string.format("Errors:   %d", #result.errors))
    print(string.format("Warnings: %d", #result.warnings))
    print(string.format("Pages:    %d", result.pages))
    print()
end

function M.print_output(parsed_output)
    -- make it possible for the user to define a format
    -- print(output)
end

setmetatable(M, meta)

return M
