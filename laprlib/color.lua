local M = {}

local escape = 0x1B
local CSI = string.char(escape) .. "["
local csi_sgr = CSI .. "%sm"
local reset = "0"

local lookup = {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    bold = 1,
    underline = 4,
    inverse = 7,
    crossout = 9,
    normal = 53,
}

function M.position()
    io.write(CSI .. "6n")
    local line = io.read()
    print(string.dump(line))
end

function M.clear()
    io.write(CSI .. "2J")
end

function M.set_cursor(x, y)
    local x = (x and tostring(x)) or ""
    local y = (y and tostring(y)) or ""

    io.write(string.format(CSI .. "%s;%sf", y, x))
end

function M.printm(str, mode)
    M.switch_mode(mode)
    print(str)
    M.reset()
end

function M.switch_mode(mode)
    local mode = mode or {}
    if type(mode) == "string" then mode = { mode } end
    local modetab = {}
    for _, m in ipairs(mode) do
        if not lookup[m] then
            print(string.format("unkown print mode '%s'", m))
        else
            table.insert(modetab, lookup[m])
        end
    end
    local modestr = table.concat(modetab, ";")
    io.write(csi_sgr:format(modestr))
end

function M.reset()
    io.write(csi_sgr:format(reset))
end

return M
