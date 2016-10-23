--[[
This file belongs to the lapr project.

This module provides the main project administration functionality.
It will perhaps be split up in several other modules.
--]]
--{{{ Module loading
local pl   = {}
pl.file    = require "pl.file"
pl.path    = require "pl.path"
pl.dir     = require "pl.dir"
pl.tablex  = require "pl.tablex"
pl.pretty  = require "pl.pretty"
pl.list    = require "pl.List"
pl.utils   = require "pl.utils"
pl.stringx = require "pl.stringx"

local iterate = pl.list.iterate
local dp = pl.pretty.dump

local latex         = require "laprlib.latex"
local util          = require "laprlib.util"
local packages      = require "laprlib.packages"
local config        = require "laprlib.config"
local debug         = require "laprlib.debug"
local structlib     = require "laprlib.structure"
local codegenerator = require "laprlib.codegenerator"
local editor        = require "laprlib.editor"
--}}}

local M = {}

-- metatable for project objects
local meta = util.new_metatable("projectlib")

-- load package database
-- this loads both the system and the user database
local packagelookup = packages.load()

local known_classes = pl.tablex.makeset{
    -- standard classes
    "article",
    "report",
    "book",
    -- KOMA script
    "scrartcl",
    "scrreprt",
    "scrbook",
    -- misc
    "IEEEtran",
    "minimal",
    "standalone"
}

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
function M.create(name, class, file_list)
    if not name then
        print("no project name given")
        return
    end
    -- arguments
    local file_list = file_list or {}
    if not class then
        print("no documentclass given")
        return
    end
    if not known_classes[class] then
        local option = util.choose_option(string.format("the class '%s' is unknown.", class), { "abort", "fix", "ignore", "add to known classes" })
        if option == "abort" then
            return
        elseif option == "fix" then
            local class = read_class()
        elseif option == "ignore" then
            -- nothing to do
        elseif option == "add to known classes" then
            known_classes[class] = true
        else -- shouldn't happen
            error("this should not happen! wrong option returned. Report a bug")
        end
    end

    -- object
    local self = {
        document = {
            title = "Title",
            subtitle = "Subtitle",
            author = "Patrick Schulz",
            date = "\\today"
        },

        structure = structlib.create(),

        project_name = name,

        packages = {
            --{ name = "amsmath", options = { "sumlimits", "intlimits" } },
        },
        class = { class = class, options = {} },

        custom_content = {
            preamble = nil
        },

        last_edits = nil,

        minimal_templates = nil,

        aux_files = {},

        -- environment
        engine = { exe = "lualatex", args = "--interaction=nonstopmode" },
        editor = "vim",
        viewer = "zathura --fork",

        settings = {
            ignore_hidden = true,
            raw_output = false,
            debug = true,
        },
    }
    setmetatable(self, meta)

    -- not yet implemented
    self:scan_aux()

    self:load_config_file()
    self:load_minimal_templates()

    return self
end
--}}}
--{{{ load config file
-- This function is written rather explicit, one COULD use just the table loaded from the config file and insert all entries automatically.
-- But the way used here makes it possible to have a more flexible way of handling options
function meta.load_config_file(self)
    local filename = config.get_user_config_filename()
    local conf = loadfile(filename)
    if conf then
        conf = conf()
        if conf.viewer then
            self.viewer = conf.viewer
        end
        if conf.engine then
            self.engine = conf.engine
        end
        if conf.editor then
            self.editor = conf.editor
        end
        if conf.settings then
            if conf.settings.ignore_hidden then self.settings.ignore_hidden = conf.settings.ignore_hidden end
            if conf.settings.raw_output then self.settings.raw_output = conf.settings.raw_output end
            if conf.settings.debug then self.settings.debug = conf.settings.debug end
        end
        if conf.file_list then
            if conf.settings.main_file then self.settings.main_file = conf.settings.main_file end
            if conf.settings.project_file then self.settings.project_file = conf.settings.project_file end
            if conf.settings.preamble_file then self.settings.preamble_file = conf.settings.preamble_file end
        end
        if conf.directories then
            if conf.settings.file_dir then self.settings.file_dir = conf.settings.file_dir end
            if conf.settings.image_dir then self.settings.image_dir = conf.settings.image_dir end
            if conf.settings.project_dir then self.settings.project_dir = conf.settings.project_dir end
            if conf.settings.minimal_dir then self.settings.minimal_dir = conf.settings.minimal_dir end
        end
        if conf.temporary_file then 
            self.temporary_file = conf.temporary_file
        end
    else
        print("could not load user config file (perhaps you don't have one)")
    end
end
--}}}
--{{{ load minimal templates
function meta.load_minimal_templates(self)
    local filename = config.get_user_templates_filename()
    local templates = loadfile(filename)
    if templates then
        self.minimal_templates = templates()
    else
        print("could not load user templates file (perhaps you don't have one)")
    end
end
--}}}
--{{{ scan auxiliary files
function meta.scan_aux(self)
    -- get a list of all present file names
    -- this list can later on be used to prevent files from being deleted
    self.aux_files = pl.dir.getallfiles(".")
end
--}}}
--{{{ read class
function read_class()
    local class = ""
    repeat
        io.write("class: ")
        class = io.read()
    until known_classes[class]
    return class
end
--}}}
--}}}
--{{{ settings
function meta.set_class(self, class, ...)
    local options = { ... }
    if class then
        self.class.class = class
        self.class.options = options
    else
        util.printf("%s [%s]", self.class.class, table.concat(self.class.options, ", "))
    end
end

function meta.set_editor(self, editor)
    if editor then
        self.editor = editor
    else
        print(self.editor)
    end
end

function meta.set_latex_engine(self, engine, ...)
    local options = { ... }
    if engine then
        self.engine.exe = engine
    else
        print(self.engine.exe)
    end
end

function meta.set_viewer(self, viewer)
    self.viewer = viewer
end

function meta.reset(self, mode)
    if mode == "editor" then
        self.editor = "vim"
    elseif mode == "engine" then
        self.engine.exe = "lualatex --interaction=nonstopmode"
    elseif mode == "viewer" then
        self.viewer = "zathura --fork"
    end
end

function meta.generic_set(self, mode, ...)
    if mode == "editor" then

    elseif mode == "engine" then

    elseif mode == "viewer" then
        if not ... then
            util.printf("pdf viewer = %s", self.viewer)
        end
    elseif mode == "raw" then
        if not ... then
            util.printf("raw_output = %s", self.settings.raw_output)
        else
            self.settings.raw_output = (... == "true") or false
        end
    elseif mode == "class" then
        if not ... then

        else

        end
    end
end
--}}}
--{{{ Utility Functions
--{{{ check existing project
function meta.check_existing_project(filename)
    local filename = filename or ".project"
    return pl.path.exists(filename)
end
--}}}
--{{{ info
function meta.info(self, mode)
    local indent = "  "
    print("Project Information:")
    print("---------------------------")
    util.printf("project name:  %s", self.project_name)
    util.printf("engine: %s", self.engine.exe)
    util.printf("viewer: %s", self.viewer)
end
--}}}
--{{{ show preamble
function meta.show_preamble(self)
    local classline = codegenerator.create_classline(self.class)
    local preamble = codegenerator.create_preamble(self.engine.exe, self.packages, self.document, self.custom_content.preamble)
    util.printf("%s\n\n%s\n", classline, preamble)
end
--}}}
--{{{ show full document
function meta.show_full_document(self)
    local content = codegenerator.create_document(self.class, self.engine.exe, self.packages, self.document, self.structure:get_full_content(), self.custom_content)
    print(content)
end
--}}}
--{{{ list packages
function meta.list_packages(self)
    for _, package in ipairs(self.packages) do
        if package.options then
            util.printf("%s [%s]", package.name, table.concat(package.options, ", "))
        else
            util.printf("%s", package.name)
        end
    end
end
--}}}
--{{{ compare and insert missing packages
function meta.compare_and_insert_missing_packages(self, packagelist)
    local used_packages = {}
    for _, package in ipairs(self.packages) do
        used_packages[package.name] = true
    end
    local new_packages = pl.tablex.keys(pl.tablex.difference(pl.tablex.makeset(packagelist), used_packages))
    for _, package in ipairs(new_packages) do
        table.insert(self.packages, { name = package })
    end
end
--}}}
--{{{ add custom preamble
function meta.add_custom_preamble(self, preamble)
    self.custom_content.preamble = preamble
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
    self:load_config_file()
    return self
end
--}}}
--{{{ adopt
function meta.adopt(main_file)
    local main_file = main_file or "main"
end
--}}}
--}}}
--{{{ Editing Functions
--{{{ edit titlepage
function meta.edit_titlepage(self)
    local tp = editor.edit(nil, "% titlepage")
end
--}}}
--{{{ edit preamble
function meta.edit_preamble(self)
    local preamble = editor.edit(self.custom_content.preamble, "% preamble")
    preamble = editor.strip_titleline(preamble, "preamble")
    --[[ TODO: parse new preamble
    for line in pl.stringx.lines(preamble) do

    end
    --]]
    self:add_custom_preamble(preamble)
end
--}}}
--{{{ edit before/after
function meta.edit_before_after(self, mode)
    local content, packagelist = editor.edit(self.custom_content[mode], string.format("%% content %s text body", mode), true)
    content = editor.strip_titleline(content, string.format("content %s text body", mode))
    self.custom_content[mode] = content
    if packagelist then
        self:compare_and_insert_missing_packages(packagelist)
    end
end
--}}}
--}}}
--{{{ Document Generation Functions
function meta.compile(self, mode)
    -- get snapshot of current directory
    local files = pl.dir.getfiles(".")
    local dirs = pl.dir.getdirectories(".")
    files:extend(dirs)
    local content = codegenerator.create_document(self.class, self.engine.exe, self.packages, self.document, self.structure:get_full_content(), self.custom_content)
    if mode == "document" or not mode then
        local filename = string.format("%s.tex", self.project_name)
        pl.file.write(filename, content)
        local command = string.format("%s %s %s", self.engine.exe, self.engine.args, filename)
        if not self.settings.raw_output then
            local status, code, stdout, stderr = pl.utils.executeex(command)
            latex.parse_output(stdout)
        else
            os.execute(command)
        end
    elseif mode == "single" then

    elseif mode == "bibtex" then

    end
end
--}}}
--{{{ Document settings (title, author, ...)
function meta.set_title(self, title)
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
                    util.printf("%s is not allowed and will be removed", file)
                end
                pl.file.delete(file)
            else
                if self.settings.debug then
                    util.printf("%s is allowed", file)
                end
            end
        end
    end
end
--}}}
--{{{ purge
function meta.purge(self) -- use with care
    local delete = pl.list()
    local files = pl.dir.getallfiles(".")
    for file in files:iterate() do
        if not self.aux_files:contains(file) then
            delete:append(file)
        end
    end
    print("these files will be deleted:")
    for file in delete:iterate() do
        print(file)
    end
    local answer = util.confirm_decline("do you want to proceed?")
    if answer then
        for file in delete:iterate() do
            os.remove(file)
        end
    end
end
--}}}
--{{{ is allowed file
function meta.is_allowed_file(self, filename)
    --[[
    return self:is_managed_file(filename) 
        or self:is_auxiliary_file(filename)
    --]]
    return self:is_auxiliary_file(filename)
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
function meta.view(self)
    local command = string.format("%s %s.pdf", self.viewer, self.project_name)
    os.execute(command)
end
--}}}
--{{{ Minimal session functions
-- A 'minimal' session gives to user the possibility to try out some commands while speeding up compilation time
function meta.create_minimal(self, template, options)

end

function meta.insert_minimal(self, filename)

end
--}}}
--{{{ Structure functions
function meta.list_structure(self)
    self.structure:list()
end
function meta.define_structure(self)
    self.structure:define()
end
function meta.edit_structure_element(self, pattern)
    local packagelist = self.structure:edit(pattern)
    if packagelist then
        self:compare_and_insert_missing_packages(packagelist)
    end
end
function meta.show_structure(self)
    io.write(self.structure:get_full_content())
end
--}}}

setmetatable(M, meta)

return M

-- vim: foldmethod=marker
