local log = require("venv-selector.logger")
local path = require("venv-selector.path")
local config = require("venv-selector.config")
local venv = require("venv-selector.venv")
local BasePicker = require("venv-selector.pickers.basepicker")
local fzf_lua = require("fzf-lua")

---TODO: Make this configurable by the user for the pickers to save on length...maybe disable this if they want full length?
---shorten the given path
---@param path string
---@param len integer
local path_shortener = function(path, len)
    local path_separator = "\\" or "/"
    local components = {}

    for component in string.gmatch(path, "[^" .. path_separator .. "]+") do
        table.insert(components, component)
    end

    if #components <= len then
        return path:gsub(path_separator, "/")
    end

    for i = 1, #components - len do
        table.remove(components, 1)
    end

    local short_path = table.concat(components, "/")

    return short_path
end

-- Fzf-lua implementation
local FzfLuaPicker = setmetatable({}, BasePicker)
FzfLuaPicker.__index = FzfLuaPicker

function FzfLuaPicker.new()
    local self = setmetatable(BasePicker.new(), FzfLuaPicker)
    return self
end

-- function M:get_sorter()
--   -- Implement in subclass
-- end

function FzfLuaPicker.make_entry_maker(entry)
    local function draw_icons_for_types(entry)
        if vim.tbl_contains({ "cwd", "workspace", "file" }, entry.source) then
            return "󰥨"
        elseif
            vim.tbl_contains({
                "virtualenvs",
                "hatch",
                "poetry",
                "pyenv",
                "anaconda_envs",
                "anaconda_base",
                "miniconda",
                "miniconda",
                "pipx",
            })
        then
            return ""
        else
            return "" -- user created venv icon
        end
    end

    local function hl_active_venv(e)
        local icon_highlight = "VenvSelectActiveVenv"
        if e.path == path.current_python_path then
            return "\27[31m" -- ANSI escape code for red
        end
        return "\27[0m" -- ANSI escape code for reset
    end

    return function(entry)
        local icon = draw_icons_for_types(entry)
        local highlight = hl_active_venv(entry)
        local shortened_path = path_shortener(entry.path, 4)
        return string.format("%s%s\27[0m %s %s", highlight, icon, "~/" .. shortened_path, entry.source)
    end
end

-- function FzfLuaPicker:update_results()
--   -- Format the new results
--   local formatted_results = vim.tbl_map(self:make_entry_maker(), self.results)
--
--   -- Close the current fzf picker and open a new one with the updated results
--   vim.api.nvim_command 'q' -- Close the current fzf picker
--
--   local opts = {
--     prompt = 'Search Results> ',
--     actions = {
--       ['default'] = require('fzf-lua').actions.file_edit,
--       ['ctrl-y'] = function(selected, opts)
--         print('selected item:', selected[1])
--       end,
--     },
--   }
--
--   fzf_lua.fzf_exec(function(cb)
--     for _, result in ipairs(formatted_results) do
--       cb(result)
--     end
--     -- Signal EOF to close the named pipe and stop fzf's loading indicator
--     cb()
--   end, opts)
-- end

function FzfLuaPicker:update_results() -- Sort the results
    self:sort_results()

    local formatted_results = vim.tbl_map(self:make_entry_maker(), self.results)

    local opts = {
        prompt = "Updated Results> ",
        actions = {
            ["default"] = require("fzf-lua").actions.file_edit,
            ["ctrl-y"] = function(selected, opts)
                print("selected item:", selected[1])
            end,
        },
    }

    fzf_lua.fzf_exec(function(cb)
        for _, result in ipairs(formatted_results) do
            cb(result)
        end
        cb() -- EOF
    end, opts)
end

function FzfLuaPicker:open(in_progress)
    local title = "Virtual environments (ctrl-r to refresh)"
    -- If the search is not in progress, sort the results
    if not in_progress then
        self:sort_results()
    end

    local formatted_results = vim.tbl_map(self:make_entry_maker(), self.results)

    local opts = {
        prompt = title,
        actions = {
            ["default"] = function(selected)
                local selected_entry
                for i, result in ipairs(formatted_results) do
                    if result == selected[1] then
                        selected_entry = self.results[i]
                        break
                    end
                end
                if selected_entry then
                    local activated = venv.activate(config.user_settings.hooks, selected_entry)
                    if activated then
                        path.add(path.get_base(selected_entry.path))
                        path.update_python_dap(selected_entry.path)
                        path.save_selected_python(selected_entry.path)
                        if selected_entry.type == "anaconda" then
                            venv.unset_env("VIRTUAL_ENV")
                            venv.set_env(selected_entry.path, "CONDA_PREFIX")
                        else
                            venv.unset_env("CONDA_PREFIX")
                            venv.set_env(selected_entry.path, "VIRTUAL_ENV")
                        end
                    end
                end
            end,
            ["ctrl-r"] = function()
                self.results = {}
                local search = require("venv-selector.search")
                search.New(nil)
                self:open(true)
            end,
        },
        fzf_opts = {
            ["--layout"] = "reverse-list",
        },
        winopts = {
            height = 0.5,
            width = 0.6,
        },
    }

    fzf_lua.fzf_exec(function(cb)
        for _, result in ipairs(formatted_results) do
            cb(result)
        end
    end, opts)
end

return FzfLuaPicker
