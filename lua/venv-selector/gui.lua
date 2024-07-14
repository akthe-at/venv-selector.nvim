local BasePicker = require("venv-selector.pickers.basepicker")
local TelescopePicker = require("venv-selector.pickers.telescope")
local FzfLuaPicker = require("venv-selector.pickers.fzflua")

-- FIX: can't rely on user_settings.options.picker to be set in time for Venvselect autocmd.
-- local guiPicker = require("venv-selector.config").user_settings.options.picker
local guiPicker = "fzf-lua"

if guiPicker == "telescope" then
    M = TelescopePicker:new()
elseif guiPicker == "fzf-lua" then
    M = FzfLuaPicker:new()
else
    vim.notify('Invalid picker setting, please select one of "telescope" or "fzf-lua"', vim.log.levels.ERROR)
    vim.notify("The currently selected picker is: " .. guiPicker, vim.log.levels.ERROR)
end

return M
