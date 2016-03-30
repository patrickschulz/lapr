--{{{ Module loading
local pl  = {}
pl.file   = require "pl.file"
pl.path   = require "pl.path"
pl.dir    = require "pl.dir"
pl.tablex = require "pl.tablex"
pl.pretty = require "pl.pretty"
pl.utils  = require "pl.utils"

local latex = require "latex"

local util = require "util"
--}}}

local M = {}

-- metatable for project objects
local meta = util.new_metatable("projectlib")

--{{{ Object Creation Functions
--{{{ create a project
--
-- this function creates all needed files and directories for a project
-- and stores all information in the project file
--
-- parameters:
--  project name
--  initial files
--
-- project files can be added later on
function M.create(name, file_list)
    if not name then
        print("no project name given")
        return
    end
    -- arguments
    local file_list = file_list or {}

    -- object
    local self = {
        file_list = {
            main_file = "main",
            project_file = ".project",
            preamble_file = "preamble",
            table.unpack(file_list)
        },
        aux_files = { }, -- use this to save all present files while creating a project
                         -- this list is used to move or delete all unwanted files
        directories = { 
            file_dir = "files",
            image_dir = "images",
            project_dir = ".build"
        },
        last_active_file = nil,

        project_name = name,

        packages = {
            "tikz",
            "kantlispum"
        },

        -- environment
        engine = "lualatex --interaction=nonstopmode",
        editor = "vim",
        viewer = "zathura --fork",

        settings = {
            ignore_hidden = true,
            raw_output = false,
            debug = false,
        },
    }
    setmetatable(self, meta)

    -- create directories
    for _, dir in pairs(self.directories) do
        pl.path.mkdir(dir)
    end

    -- create files
    -- main file
    local main_content = self:get_main_content()
    util.write_tex_file(self.file_list.main_file, main_content)
    
    -- preamble
    local preamble_content = self:get_preamble_content()
    util.write_sty_file(self.file_list.preamble_file, preamble_content, self.directories.file_dir)

    -- project master file (includes all other files)
    self:write_master_file()

    return self
end
--}}}
--}}}
--{{{ Utility Functions
--{{{ get full file path
function meta.get_full_file_path(self, filename)
    -- search order:
    -- 1. Main file
    -- 2. Content files
    if filename == self.file_list.main_file then
        return filename .. ".tex"
    elseif filename == self.file_list.preamble_file then
        return self.directories.file_dir .. "/" .. filename .. ".sty"
    else
        for _, file in ipairs(self.file_list) do
            if filename == file then
                return self.directories.file_dir .. "/" .. file .. ".tex"
            end
        end
    end
end
--}}}
--{{{ info
function meta.info(self, mode)
    local indent = "  "
    print("Project Information:")
    print("---------------------------")
    print(string.format("project name:  %s", self.project_name))
    print(string.format("main file:     %s", self.file_list.main_file))
    print(string.format("preamble file: %s", self.file_list.preamble_file))
    print("content files:")
    for _, file in ipairs(self.file_list) do
        print(string.format(" -> %s", file))
    end
    print(string.format("engine: %s", self.engine))
    print(string.format("viewer: %s", self.viewer))
end
--}}}
--}}}
--{{{ Saving/Loading Functions
--{{{ save
function meta.save(self)
    local rep = pl.pretty.write(self)
    pl.file.write(".project", rep)
end
--}}}
--{{{ load
function meta.load()
    local project_table = pl.file.read(".project")
    if not project_table then
        print("couldn't read project file ('.project')")
        return nil
    end
    local self = pl.pretty.read(project_table)
    setmetatable(self, meta)
    return self
end
--}}}
--{{{ adopt
function meta.adopt(main_file)
    local main_file = main_file or "main"
end
--}}}
--}}}
--{{{ File Functions
function meta.add_file(self, filename)
    if type(filename) == "table" then
        for _, fn in ipairs(filename) do
            self:add_file(fn)
        end
    else
        local content = string.format("%% %s.tex", filename)
        util.write_tex_file(filename, content, self.directories.file_dir)
        table.insert(self.file_list, filename)
        self:write_master_file()
    end
end

function meta.add_aux_file(self, filename)
    if type(filename) == "table" then
        for _, fn in ipairs(filename) do
            self:add_aux_file(fn)
        end
    else
        table.insert(self.aux_files, filename)
    end
end
--}}}
--{{{ Editing Functions
--{{{ edit preamble
function meta.edit_preamble(self)
    self:edit_file(self.file_list.preamble_file)
end
--}}}
--{{{ edit file
function meta.edit_file(self, filename)
    if not (filename or self.last_active_file) then
        print("specify file to edit")
        return
    end
    local filename = filename or self.last_active_file
    if filename == "preamble" then
        filename = self.file_list.preamble_file
    end
    filename = self:get_full_file_path(filename)
    if not filename then
        print("file not found in project")
        return
    end
    local command = string.format("%s %s", self.editor, filename)
    os.execute(command)
end
--}}}
--{{{ add package
function meta.add_package(self, package)
    table.insert(self.packages, package)
end
--}}}
--}}}
--{{{ Document Generation Functions
function meta.compile(self, mode)
    if mode == "document" or not mode then
        local command = string.format("%s %s", self.engine, self.file_list.main_file)
        if self.settings.raw_output then
            os.execute(command)
        else
            local status, code, stdout, stderr = pl.utils.executeex(command)
            latex.parse_output(stdout)
        end
    elseif mode == "bibtex" then

    end
end
--}}}
--{{{ Access Functions
--{{{ ignore hidden files
function meta.ignore_hidden_files(self, bool)
    self.settings.ignore_hidden = bool
end
--}}}
--{{{ enable debuggin messages
function meta.enable_debuggin_messages(self, bool)
    self.settings.debug = bool
end
--}}}
--{{{ setting
function meta.setting(self, options)
    if type(options) ~= "table" then
        print("project: setting options is not a table")
    end
end
--}}}
--}}}
--{{{ Content Generation Functions
--{{{ get main content
function meta.get_main_content(self, options)
    return string.format([[
\documentclass{scrartcl}

\usepackage{files/%s}

\begin{document}
\input{files/project_master}
\end{document}
]],
self.file_list.preamble_file)
end
--}}}

function meta.get_master_content(self)
    local t = {}
    for i = 1, #self.file_list do
        t[i] = string.format("\\input{%s/%s}", self.directories.file_dir, self.file_list[i])
    end
    return table.concat(t, "\n")
end

function meta.get_preamble_content(self)
    local content = {
        "\\usepackage{fontspec}",
        "\\setmainfont{Linux Libertine O}",
        "\\usepackage{polyglossia}",
        "\\setdefaultlanguage{german}",
    }
    for _, package in ipairs(self.packages) do
        local packagestr = string.format("\\usepackage{%s}", package)
        table.insert(content, packagestr)
    end
    return table.concat(content, "\n")
end
--}}}
--{{{ Content Write Functions
--{{{ write master file
function meta.write_master_file(self)
    local master_content = self:get_master_content()
    util.write_tex_file("project_master", master_content, self.directories.file_dir)
end
--}}}
--}}}
--{{{ Cleanup Functions
--{{{ clean up
function meta.clean_up(self)
    -- iterate over directory and move all files NOT in the file list (or the auxiliary file list) to a hidden (or specified) directory
    local files = pl.dir.getfiles(".")
    for _, file in ipairs(files) do
        if not (util.is_hidden(file) and self.settings.ignore_hidden) then
            -- check if file is 'allowed':
            -- - it can be part of the project
            -- - it can be an auxiliary which should not be (re-)moved
            if not self:is_allowed_file(pl.path.basename(file)) then
                if self.settings.debug then
                    print(string.format("%s is not allowed and will be removed", file))
                end
                pl.file.delete(file)
            else
                if self.settings.debug then
                    print(string.format("%s is allowed", file))
                end
            end
        end
    end
end
--}}}
--{{{ purge
function meta.purge(self) -- use with care
    -- this function removes all files created by the project
    -- this includes both files created by this tool and files created by LaTeX
    --
    -- current simple implementation: delete all files which are not in the auxiliary file list
end
--}}}
--{{{ is allowed file
function meta.is_allowed_file(self, filename)
    return self:is_managed_file(filename) 
        or self:is_auxiliary_file(filename)
end
--}}}
--{{{ is managed file
function meta.is_managed_file(self, filename)
    return filename == self.file_list.main_file .. ".tex"  -- main file
        or filename == self.file_list.main_file .. ".pdf"  -- output document
        or pl.tablex.find(self.file_list, filename)        -- content file
end
--}}}
--{{{ is auxiliary file
function meta.is_auxiliary_file(self, filename)
    return pl.tablex.find(self.aux_files, filename)
end
--}}}
--}}}
--{{{ Viewing Functions
--{{{ view
function meta.view(self)
    local command = string.format("%s %s", self.viewer, self.file_list.main_file .. ".pdf")
    os.execute(command)
end
--}}}
--}}}

setmetatable(M, meta)

return M

-- vim: foldmethod=marker
