local M = {}

function M.show_popup(conf, text)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text or "", "\n"))
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = conf.filetype or "markdown"

	local width = math.floor(vim.o.columns * (conf.width or 0.6))
	local height = conf.height or 12
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = 1,
		col = 2,
		style = "minimal",
		border = conf.border or "rounded",
	})

	-- h → open suggested :help tag
	if conf.map_help_key ~= false then
		vim.keymap.set("n", conf.map_help_key or "h", function()
			for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
				local tag = line:match("^Help:%s*:h%s+([%w%-%._]+)")
				if tag then
					if vim.api.nvim_win_is_valid(win) then
						vim.api.nvim_win_close(win, true)
					end
					vim.cmd("help " .. tag)
					return
				end
			end
			vim.notify("No 'Help: :h <tag>' line found.", vim.log.levels.WARN)
		end, { buffer = buf, nowait = true, desc = "Open help for suggested tag" })
	end

	-- q → close
	if conf.map_close_key ~= false then
		vim.keymap.set("n", conf.map_close_key or "q", function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end, { buffer = buf, nowait = true, desc = "Close" })
	end

	return win
end

return M
