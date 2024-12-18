# beancount.nvim
Growing collection of functions & functionality for editing beancount files

Dependencies
- [ctags](https://ctags.io/)
- [beancount](https://github.com/beancount/beancount)
    - `bean-format`
    - `bean-check`
- Wells Fargo _.qfx_ export
    - Maybe other banks use the same format?

# Usage
Functionality provided via user commands defined in [_ftplugin/beancount.lua_](ftplugin/beancount.lua).

1. `BImport`
    - Parses and imports a _.qfx_ file
2. `:BFormat`
    - Calls `bean-format`
3. `:Bcheck`
    - Calls `:make`...
    - ...which calls `bean-check`

Currently the bulk (read: 95%) of the functionality of this plugin comes from `BImport`.
Reads a _.qfx_ file (Quicken data file, exported by several banks), parses, and inserts beancount transaction data.

The parser can be found at [_lua/beancount/ofx/parser.lua_](lua/beancount/ofx/parser.lua).
It's not half bad.

# Setup
1. Install the plugin

## Native
```bash
PLUGIN_DIR=~/.local/share/nvim/site/pack/plugins/start/
mkdir -p "$PLUGIN_DIR"
git clone 'https://git.sr.ht/~carlinigraphy/beancount.nvim' "$PLUGIN_DIR"
```

## Lazy
```lua
{ "https://git.sr.ht/~carlinigraphy/beancount.nvim" }
```

# Caveats
The _.qfx_ parser expects data to be formatted how Wells Fargo does as of Nov. 2024.
It's very possible other banks format the data/fields differently.
Equally so that Wells Fargo makes changes in the future.

I have plans to add a layer of abstraction.
Allow users (me) to provide a parser/specification for each account.
For now, it's hard coded.
