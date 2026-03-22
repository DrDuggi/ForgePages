--[[
MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

-- build.lua

local lfs = require("lfs")

local TEMPLATE_DIR = "template"
local SITES_DIR    = "sites"
local CONTENT_DIR  = "content"
local CONFIG_FILE  = "config.ini"

-- Config

local function load_config()
	local cfg = {
		base_url       = "",
		output_dir     = "output",
		sitemap        = false,
		watch          = false,
		watch_interval = 2,
	}

	local f = io.open(CONFIG_FILE, "r")
	if not f then
		print("WARN: No config.ini found, using defaults")
		return cfg
	end

	for line in f:lines() do
		-- Skip comments and empty lines
		if not line:match("^%s*#") and line:match("=") then
			local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
			if key and value then
				if key == "sitemap" or key == "watch" then
					cfg[key] = (value == "true")
				elseif key == "watch_interval" then
					cfg[key] = tonumber(value) or 2
				else
					cfg[key] = value
				end
			end
		end
	end

	f:close()
	return cfg
end

-- Utility functions

local function read_file(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

local function write_file(path, data)
	local f = io.open(path, "w")
	if not f then
		print("ERROR: Cannot write " .. path)
		return
	end
	f:write(data)
	f:close()
end

local function is_dir(path)
	return lfs.attributes(path, "mode") == "directory"
end

local function mkdir(path)
	local current = path:sub(1, 1) == "/" and "/" or ""
	for part in path:gmatch("[^/]+") do
		current = current .. part
		if not is_dir(current) then
			lfs.mkdir(current)
		end
		current = current .. "/"
	end
end

local function list_files(dir, prefix)
	local files = {}
	prefix = prefix or ""
	if not is_dir(dir) then return files end
	for name in lfs.dir(dir) do
		if name ~= "." and name ~= ".." then
			local full = dir .. "/" .. name
			local rel  = prefix == "" and name or prefix .. "/" .. name
			if is_dir(full) then
				for _, sub in ipairs(list_files(full, rel)) do
					table.insert(files, sub)
				end
			else
				table.insert(files, rel)
			end
		end
	end
	table.sort(files)
	return files
end

local function basename(filename)
	return filename:match("^(.+)%..+$") or filename
end

-- last modified timestamp of a file
local function mtime(path)
	return lfs.attributes(path, "modification") or 0
end

-- collect mtimes for all files in sites/ and template/
local function snapshot()
	local times = {}
	for _, dir in ipairs({ SITES_DIR, TEMPLATE_DIR }) do
		for _, f in ipairs(list_files(dir)) do
			local path = dir .. "/" .. f
			times[path] = mtime(path)
		end
	end
	return times
end

-- true if changed
local function changed(old, new)
	for path, t in pairs(new) do
		if old[path] ~= t then return true end
	end
	for path in pairs(old) do
		if not new[path] then return true end
	end
	return false
end

-- Templates
-- Loads all files from template
-- top.html to {{TOP}}, bottom.html to {{BOTTOM}}
local function load_templates()
	local templates = {}
	for _, filename in ipairs(list_files(TEMPLATE_DIR)) do
		local key = basename(filename):upper()
		local content = read_file(TEMPLATE_DIR .. "/" .. filename)
		if content then
			templates[key] = content
		end
	end
	return templates
end

-- Variables

local function parse_vars(text)
	local vars = {}
	for key, value in text:gmatch("<!%-%- VAR (%w+)=([^\n]-) %-%->") do
		vars[key] = value
	end
	local clean = text:gsub("<!%-%- VAR %w+=[^\n]- %%->%s*\n?", "")
	return clean, vars
end

local function apply_vars(text, vars)
	return (text:gsub("{{(%w+)}}", function(key)
		return vars[key] or ("{{" .. key .. "}}")
	end))
end

-- copy

local function copy_content(output_dir)
	for name in lfs.dir(CONTENT_DIR) do
		if name ~= "." and name ~= ".." then
			local src = CONTENT_DIR .. "/" .. name
			os.execute("cp -r \"" .. src .. "\" \"" .. output_dir .. "/\" 2>/dev/null")
		end
	end
end

-- Sitemap

local function generate_sitemap(site_files, output_dir, base_url)
	base_url = base_url:gsub("/$", "")

	local date = os.date("%Y-%m-%d")
	local lines = { '<?xml version="1.0" encoding="UTF-8"?>' }
	table.insert(lines, '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')

	for _, filename in ipairs(site_files) do
		local page = basename(filename) .. ".html"
		table.insert(lines, "  <url>")
		table.insert(lines, "    <loc>" .. base_url .. "/" .. page .. "</loc>")
		table.insert(lines, "    <lastmod>" .. date .. "</lastmod>")
		table.insert(lines, "  </url>")
	end

	table.insert(lines, "</urlset>")
	write_file(output_dir .. "/sitemap.xml", table.concat(lines, "\n") .. "\n")
	print("OK: sitemap.xml generated")
end

-- Build

local function build(cfg)
	local output_dir = cfg.output_dir
	local templates  = load_templates()

	if not next(templates) then
		print("ERROR: No templates found in " .. TEMPLATE_DIR .. "/")
		return
	end

	os.execute("rm -rf \"" .. output_dir .. "\"")
	mkdir(output_dir)
	copy_content(output_dir)

	local site_files = list_files(SITES_DIR)
	local count = 0

	for _, filename in ipairs(site_files) do
		local input_path  = SITES_DIR .. "/" .. filename
		local output_path = output_dir .. "/" .. basename(filename) .. ".html"

		local raw = read_file(input_path)
		if not raw then
			print("SKIP: Cannot read " .. input_path)
		else
			local content, vars = parse_vars(raw)

			-- Apply
			local resolved = {}
			for key, tmpl in pairs(templates) do
				resolved[key] = apply_vars(tmpl, vars)
			end

			local merged = apply_vars(content, resolved)
			merged = apply_vars(merged, vars)

			local out_subdir = output_path:match("^(.+)/[^/]+$")
			if out_subdir then mkdir(out_subdir) end
			write_file(output_path, merged)
			print("OK: " .. input_path .. " -> " .. output_path)
			count = count + 1
		end
	end

	if cfg.sitemap then
		if cfg.base_url == "" then
			print("WARN: sitemap=true but base_url is empty in config.ini")
		else
			generate_sitemap(site_files, output_dir, cfg.base_url)
		end
	end

	print("Done! " .. count .. " site(s) built -> " .. output_dir .. "/")
end

local cfg = load_config()

-- Create default config.ini if it doesnt exist
if not io.open(CONFIG_FILE, "r") then
	local f = io.open(CONFIG_FILE, "w")
	if f then
		f:write("# build.lua config\n\n")
		f:write("base_url       = https://example.com\n")
		f:write("output_dir     = output\n\n")
		f:write("sitemap        = true\n\n")
		f:write("watch          = false\n")
		f:write("watch_interval = 2\n")
		f:close()
		print("INFO: config.ini created")
	end
end

-- Create missing project folders
for _, dir in ipairs({ TEMPLATE_DIR, SITES_DIR, CONTENT_DIR }) do
	if not is_dir(dir) then
		mkdir(dir)
		print("INFO: Created missing folder: " .. dir .. "/")
	end
end

-- --watch flag overrides config
local watch = cfg.watch
for _, arg in ipairs(arg or {}) do
	if arg == "--watch" then watch = true end
end

if watch then
	print("Watching for changes (interval: " .. cfg.watch_interval .. "s) | Ctrl+C to stop\n")
	local last = {}
	while true do
		local current = snapshot()
		if changed(last, current) then
			print(os.date("[%H:%M:%S] Change detected, rebuilding..."))
			build(cfg)
			print()
			last = current
		end
		os.execute("sleep " .. cfg.watch_interval)
	end
else
	build(cfg)
end