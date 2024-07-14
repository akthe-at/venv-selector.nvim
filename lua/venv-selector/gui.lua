local BasePicker = require("venv-selector.pickers.basepicker")
local TelescopePicker = require("venv-selector.pickers.telescope")
local FzfPicker = require("venv-selector.pickers.fzflua")

-- local testPicker = require('venv-selector.config').default_settings.options.picker
-- local guiPicker = getGuiPicker()
-- vim.notify(guiPicker)
local guiPicker = "fzf-lua"

if guiPicker == "telescope" then
    M = TelescopePicker:new()
elseif guiPicker == "fzf-lua" then
    M = FzfPicker:new()
else
    vim.notify('Invalid picker setting, please select one of "telescope" or "fzf-lua"', vim.log.levels.ERROR)
    vim.notify("The currently selected picker is: " .. guiPicker, vim.log.levels.ERROR)
end

return M
