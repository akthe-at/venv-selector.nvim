local path = require("venv-selector.path")
local config = require("venv-selector.config")
local venv = require("venv-selector.venv")
local BasePicker = require("venv-selector.pickers.basepicker")

local TelescopePicker = setmetatable({}, BasePicker)
TelescopePicker.__index = TelescopePicker

function TelescopePicker.new()
    local self = setmetatable(BasePicker.new(), TelescopePicker)
    return self
end

function TelescopePicker:get_sorter()
    local sorters = require("telescope.sorters")
    local conf = require("telescope.config").values

    local choices = {
        ["character"] = function()
            return conf.file_sorter()
        end,
        ["substring"] = function()
            return sorters.get_substr_matcher()
        end,
    }

    return choices[config.user_settings.options.telescope_filter_type]
end

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

function TelescopePicker:make_entry_maker()
    local entry_display = require("telescope.pickers.entry_display")

    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = 2 },
            { width = 90 },
            { width = 2 },
            { width = 20 },
            { width = 0.95 },
        },
    })

    local function draw_icons_for_types(e)
        if vim.tbl_contains({ "cwd", "workspace", "file" }, e.source) then
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
            return icon_highlight
        end
        return nil
    end

    return function(entry)
        local icon = entry.icon
        entry.value = path_shortener(entry.name, 2)
        entry.ordinal = entry.path
        entry.display = function(e)
            return displayer({
                {
                    icon,
                    hl_active_venv(entry),
                },
                { e.name },
                { config.user_settings.options.show_telescope_search_type and draw_icons_for_types(entry) or "" },
                { config.user_settings.options.show_telescope_search_type and e.source or "" },
            })
        end

        return entry
    end
end

function TelescopePicker:update_results()
    local finders = require("telescope.finders")
    local actions_state = require("telescope.actions.state")

    local finder = finders.new_table({
        results = self.results,
        entry_maker = self:make_entry_maker(),
    })

    local bufnr = vim.api.nvim_get_current_buf()
    local picker = actions_state.get_current_picker(bufnr)
    if picker ~= nil then
        picker:refresh(finder, { reset_prompt = false })
    end
end

function TelescopePicker:open(in_progress)
    local finders = require("telescope.finders")
    local pickers = require("telescope.pickers")
    local actions_state = require("telescope.actions.state")
    local actions = require("telescope.actions")

    local title = "Virtual environments (ctrl-r to refresh)"

    if in_progress == false then
        self:sort_results()
    end

    local finder = finders.new_table({
        results = self.results,
        entry_maker = self:make_entry_maker(),
    })

    local opts = {
        prompt_title = title,
        finder = finder,
        layout_strategy = "vertical",
        layout_config = {
            height = 0.5,
            width = 0.6,
            prompt_position = "top",
        },
        cwd = require("telescope.utils").buffer_dir(),

        sorting_strategy = "ascending",
        sorter = self:get_sorter()(),
        attach_mappings = function(bufnr, map)
            map("i", "<cr>", function()
                local selected_entry = actions_state.get_selected_entry()
                local activated = false
                if selected_entry ~= nil then
                    activated = venv.activate(config.user_settings.hooks, selected_entry)
                    if activated == true then
                        path.add(path.get_base(path_shortener(selected_entry.path, 1)))
                        path.update_python_dap(path_shortener(selected_entry.path, 1))
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
                actions.close(bufnr)
            end)

            map("i", "<C-r>", function()
                self.results = {}
                local search = require("venv-selector.search")
                search.New(nil)
            end)

            return true
        end,
    }
    pickers.new({}, opts):find()
end

return TelescopePicker
