-- Auto-register commands and default mappings on startup.
if vim.g.loaded_quickai then
	return
end
vim.g.loaded_quickai = 1

local ok, quickai = pcall(require, "quickai")
if not ok then
	return
end

-- Ensure defaults even if user didn't call setup()
quickai.setup()

vim.api.nvim_create_user_command("Ask", function(opts)
	quickai._command(opts)
end, { nargs = "*", range = 0 })

-- Default visual mapping (can be disabled by user via opts)
local cfg = require("quickai")._cfg
if cfg.mappings and cfg.mappings.visual_ask then
	local m = cfg.mappings.visual_ask
	if m ~= false then
		vim.keymap.set("v", m.lhs or "<leader>qa", function()
			quickai.ask_visual()
		end, { desc = m.desc or "Ask AI about selection" })
	end
end
