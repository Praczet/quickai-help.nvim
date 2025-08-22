-- quickai.nvim — Ask OpenAI from inside Neovim, with Vim :help pointers.
-- (c) You. MIT License.

local M = {}

-- ===== utils =====
local function json_encode(tbl)
	if vim.json and vim.json.encode then
		return vim.json.encode(tbl)
	end
	return vim.fn.json_encode(tbl)
end

local function json_decode(s)
	if vim.json and vim.json.decode then
		return vim.json.decode(s)
	end
	return vim.fn.json_decode(s)
end

local function merge(a, b)
	a = a or {}
	for k, v in pairs(b or {}) do
		if type(v) == "table" and type(a[k]) == "table" then
			merge(a[k], v)
		else
			a[k] = v
		end
	end
	return a
end

-- ===== default config =====
local defaults = {
	model = (vim.fn.getenv("OPENAI_MODEL") ~= vim.NIL and vim.fn.getenv("OPENAI_MODEL")) or "gpt-5",
	endpoint = (vim.fn.getenv("OPENAI_API_BASE") ~= vim.NIL and (vim.fn.getenv("OPENAI_API_BASE") .. "/v1/responses"))
		or "https://api.openai.com/v1/responses",
	popup = {
		width = 0.6,
		height = 12,
		border = "rounded",
		filetype = "markdown",
		map_help_key = "h", -- in the popup: press 'h' to open suggested :help
		map_close_key = "q",
	},
	mappings = {
		-- set false to disable
		visual_ask = { lhs = "<leader>qa", desc = "Ask AI about selection" },
	},
	system_preamble = table.concat({
		"You are a concise Vim/Neovim helper.",
		"Answer in ≤3 short lines.",
		"If the question is about Vim, add a final line exactly like: Help: :h <tag>.",
		"Prefer precise tags (e.g., s_flags, registers, visual-block, quickfix).",
	}, " "),
	heuristics = {}, -- user can extend/override builtin heuristics
}

M._cfg = vim.deepcopy(defaults)

-- ===== heuristics =====
local infer = require("quickai.heuristics").infer_tag

-- ===== transport =====
local function run_curl(args)
	-- Prefer vim.system (Neovim 0.10+), fall back to shell
	if vim.system then
		local res = vim.system(args, { text = true }):wait()
		return res.code, res.stdout, res.stderr
	else
		local cmd = table.concat(vim.tbl_map(vim.fn.shellescape, args), " ")
		local out = vim.fn.system(cmd)
		local code = vim.v.shell_error
		return code, out, ""
	end
end

local function build_body(cfg, question)
	local tag = infer(question, cfg.heuristics)
	local sys = cfg.system_preamble
	if tag then
		sys = sys .. (" If relevant, the user hinted the tag: %q. Prefer it."):format(tag)
	end
	return json_encode({
		model = cfg.model,
		input = {
			{ role = "system", content = sys },
			{ role = "user", content = question },
		},
	})
end

local function request(cfg, question)
	local key = vim.fn.getenv("OPENAI_API_KEY")
	if key == vim.NIL or key == "" then
		return nil, "Set OPENAI_API_KEY in your shell"
	end

	local body = build_body(cfg, question)
	local args = {
		"curl",
		"-sS",
		cfg.endpoint,
		"-H",
		"Content-Type: application/json",
		"-H",
		"Authorization: Bearer " .. key,
		"-d",
		body,
	}
	local code, stdout, stderr = run_curl(args)
	if code ~= 0 then
		return nil, "curl failed: " .. (stderr or "")
	end
	local ok, json = pcall(json_decode, stdout)
	if not ok then
		return nil, "Bad JSON from API:\n" .. stdout
	end

	local text = json.output_text
		or (json.choices and json.choices[1] and json.choices[1].message and json.choices[1].message.content)
		or stdout

	return text, nil
end

-- ===== UI =====
local ui = require("quickai.ui")

local function show(cfg, text)
	return ui.show_popup(cfg.popup, text)
end

-- ===== public API =====
function M.setup(opts)
	M._cfg = merge(vim.deepcopy(defaults), opts or {})
end

local function ensure_setup()
	if not M._cfg then
		M._cfg = vim.deepcopy(defaults)
	end
end

function M.ask(question)
	ensure_setup()
	if not question or question == "" then
		vim.notify("Empty question", vim.log.levels.WARN)
		return
	end
	local text, err = request(M._cfg, question)
	if err then
		show(M._cfg, err)
	else
		show(M._cfg, text)
	end
end

function M.ask_visual()
	ensure_setup()
	local save = vim.fn.getreg('"')
	vim.cmd([[silent normal! "zy]])
	local sel = vim.fn.getreg("z")
	vim.fn.setreg('"', save)
	if not sel or sel == "" then
		vim.notify("No visual selection", vim.log.levels.WARN)
		return
	end
	M.ask("Explain briefly and add a relevant :help tag if any:\n" .. sel)
end

-- Exposed for :Ask command impl.
function M._command(opts)
	local q = table.concat(opts.fargs or {}, " ")
	if q == "" then
		vim.ui.input({ prompt = "Ask ChatGPT: " }, function(inp)
			if inp and #inp > 0 then
				M.ask(inp)
			end
		end)
	else
		M.ask(q)
	end
end

return M
