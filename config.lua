return {
    -- editing, viewing and compiling environment
    engine = { exe = "lualatex", args = "--interaction=nonstopmode" },
    viewer = "zathura --fork",
    editor = "vim",

    settings = {
        --ignore_hidden = false, -- used for deletion of files
        raw_output = false, -- parse LaTeX output (false) or display LaTeX output plain (true)
        --debug = false,
    },

    -- file names
    --[[
    file_list = {
        main_file = "main",
        project_file = ".project",
        preamble_file = "preamble"
    },
    --]]

    -- auxiliary files. This list is used to protect files not belonging to the project while cleaning up
    --aux_files = { },

    -- directories in which files will be stored
    --[[
    directories = { 
        file_dir = "files",
        image_dir = "images",
        project_dir = ".build",
        minimal = ".minimal",
    },
    --]]

    -- used for diffs to compare edits
    --temporary_file = ".difftempfile",
}
