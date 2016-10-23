return {
    -- editing, viewing and compiling environment
    engine = { exe = "lualatex", args = "--interaction=nonstopmode" },
    viewer = "zathura --fork",
    editor = "vim",

    settings = {
        --ignore_hidden = false, -- used for deletion of files
        raw_output = true, -- parse LaTeX output (false) or display LaTeX output plain (true)
        --debug = false,
    },

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
