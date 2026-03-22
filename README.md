# ForgePages

<p align="center">
  <img src="logo.png" width="512" alt="ForgePages logo">
</p>

A small static site generator written in Lua. You write your pages, it adds your header and footer to everything and builds your site.

No dependencies beyond Lua and [LuaFileSystem](https://lunarmodules.github.io/luafilesystem/).

---

## How it works

You keep your project split into three folders:

- `template/`  shared HTML snippets like your header and footer
- `sites/`  your actual pages
- `content/`  everything else: images, stylesheets, downloads, etc.

Run `lua build.lua` and it builds everything into `output/`, which you can upload straight to your server.

---

## Folder structure

```
build.lua
config.ini
template/
  top.html
  bottom.html
sites/
  index.html
  contact.html
content/
  stylesheets/
    main.css
  images/
    logo.jpg
output/
    Output
```

First run creates `config.ini` and any missing folders automatically.

---

## Templates

Any file you put in `template/` becomes a placeholder. The filename (without extension, uppercased) is what you use in your pages:

- `top.html` -> `{{TOP}}`
- `bottom.html` -> `{{BOTTOM}}`
- `nav.html` -> `{{NAV}}`

Just drop a new file in there, no config needed.

---

## Pages

A page in `sites/` looks like this:

```html
<!-- VAR TITLE=Contact -->

{{TOP}}

<h1>Contact</h1>
<p>...</p>

{{BOTTOM}}
```

`<!-- VAR KEY=value -->` lets you set variables per page. You can use them anywhere, including inside your templates, handy for things like `<title>{{TITLE}}</title>` in your header.

---

## Content

Files directly in `content/` land directly in `output/`. Subfolders stay as subfolders:

```
content/logo.ico        -> output/logo.ico
content/stylesheets/    -> output/stylesheets/
content/images/         -> output/images/
```

Reference them in your HTML the same way you would on the live server.

---

## Config

```ini
# build.lua config

base_url       = https://example.com
output_dir     = output

sitemap        = true

watch          = false
watch_interval = 2
```

| Key | What it does |
|---|---|
| `base_url` | Used for sitemap generation |
| `output_dir` | Where the built files go |
| `sitemap` | Generate a `sitemap.xml` on build |
| `watch` | Rebuild automatically on file changes |
| `watch_interval` | How often to check for changes (seconds) |

---

## Usage

```bash
# single build
lua build.lua

# watch mode (or set watch=true in config.ini)
lua build.lua --watch
```

---

## Requirements

- Lua 5.x
- [LuaFileSystem](https://lunarmodules.github.io/luafilesystem/)

```bash
luarocks install luafilesystem
```
