## 🌲 Otree.nvim

**Otree.nvim** is a lightweight and customizable file tree explorer for [Neovim](https://neovim.io), built for speed, simplicity, and seamless user experience. It optionally integrates with [`oil.nvim`](https://github.com/stevearc/oil.nvim) to provide an elegant and efficient file operations workflow.

<video src="https://private-user-images.githubusercontent.com/24679992/455416305-dd4ef477-4890-4c9b-9be5-cd6efef356fd.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTAwNjM5OTYsIm5iZiI6MTc1MDA2MzY5NiwicGF0aCI6Ii8yNDY3OTk5Mi80NTU0MTYzMDUtZGQ0ZWY0NzctNDg5MC00YzliLTliZTUtY2Q2ZWZlZjM1NmZkLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA2MTYlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNjE2VDA4NDgxNlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWUwYzE5NTEwMTE2MzYyYzRmMjUzZWRlNWU4ZmJiMTEwZGYzMmM2YTdjNGRlNTYxMTIyMThhNWVkNDY4MzgwNWUmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.PiRiw9Sj13iIfVwE2rPTsxw-SU2VszXOtAMMT5GkKmk" controls="controls" style="max-width: 730px;">
</video>

---

## ✨ Features

- **Fast and responsive** file tree using `fd` (optional)
- **Optional integration** with [`oil.nvim`](https://github.com/stevearc/oil.nvim) for enhanced file operations
- **Supports icons** from [mini.icons](https://github.com/echasnovski/mini.icons), [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons), or a **default fallback**
- **Highly customizable** keybindings and appearance
- **Optional Netrw hijack** for a cleaner startup experience
- **Toggle visibility** for hidden and ignored files
- **Floating window support** with adjustable dimensions

---

## ⚙️ Requirements

- [Neovim 0.10+](https://neovim.io)

### Optional Dependencies

- [`fd`](https://github.com/sharkdp/fd) - For faster directory traversal
- [`oil.nvim`](https://github.com/stevearc/oil.nvim) - For file operations (create, delete, move, rename files/directories)

---

## 📦 Installation

Using [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
return {
    "Eutrius/Otree.nvim",
    lazy = false,
    dependencies = {
        -- Optional: Enhanced file operations
        "stevearc/oil.nvim",
        -- Optional: Icon support
        -- { "echasnovski/mini.icons", opts = {} },
        -- "nvim-tree/nvim-web-devicons",
    },
    config = function()
        require("Otree").setup()
    end
}
```

---

## ⚙️ Configuration

Here is the default configuration, which can be customized to suit your preferences:

```lua
require("Otree").setup({
    win_size = 30,
    open_on_startup = false,
    use_default_keymaps = true,
    hijack_netrw = true,
    show_hidden = false,
    show_ignore = false,
    cursorline = true,
    open_on_left = true,
    oil = "float",

    ignore_patterns = {},

    keymaps = {
        ["<CR>"] = "actions.select",
        ["l"] = "actions.select",
        ["h"] = "actions.close_dir",
        ["q"] = "actions.close_win",
        ["<C-h>"] = "actions.goto_parent",
        ["<C-l>"] = "actions.goto_dir",
        ["<M-h>"] = "actions.goto_home_dir",
        ["cd"] = "actions.change_home_dir",
        ["L"] = "actions.open_dirs",
        ["H"] = "actions.close_dirs",
        ["o"] = "actions.oil_dir",
        ["O"] = "actions.oil_into_dir",
        ["t"] = "actions.open_tab",
        ["v"] = "actions.open_vsplit",
        ["s"] = "actions.open_split",
        ["."] = "actions.toggle_hidden",
        ["i"] = "actions.toggle_ignore",
        ["r"] = "actions.refresh",
        ["f"] = "actions.focus_file",
        ["?"] = "actions.open_help",
    },

    tree = {
        space_after_icon = " ",
        space_after_connector = " ",
        connector_space = " ",
        connector_last = "└",
        connector_middle = "├",
        vertical_line = "│",
    },

    icons = {
        title = " ",
        default_file = "",
        default_directory = "",
        empty_dir = "",
        trash = " ",
        keymap = "⌨ ",
        oil = " ",
    },

    highlights = {
        directory = "Directory",
        file = "Normal",
        title = "TelescopeTitle",
        tree = "Comment",
        float_normal = "TelescopeNormal",
        float_border = "TelescopeBorder",
    },

    float = {
        center = true,
        width_ratio = 0.4,
        height_ratio = 0.7,
        padding = 2,
        cursorline = true,
        border = "rounded",
    },
})
```

---

## 🗝️ Keybindings

| Keybinding  | Action                                  |
| ----------- | --------------------------------------- |
| `<CR>`, `l` | Select file or open folder              |
| `h`         | Close selected directory                |
| `<Esc>`     | Close file tree window                  |
| `<C-h>`     | Navigate to parent directory            |
| `<C-l>`     | Enter selected directory                |
| `<M-h>`     | Go to home directory                    |
| `cd`        | Change home directory                   |
| `L`         | Open all directories at the same level  |
| `H`         | Close all directories at the same level |
| `o`         | Open parent directory in Oil\*          |
| `O`         | Open selected directory in Oil\*        |
| `t`         | Open file in new tab                    |
| `v`         | Open file in vertical split             |
| `s`         | Open file in horizontal split           |
| `.`         | Toggle hidden files visibility          |
| `i`         | Toggle ignored files visibility         |
| `r`         | Refresh tree view                       |
| `f`         | Focus the previous buffer               |
| `?`         | Show help with keybinding reference     |

\*_Requires oil.nvim for file operations_

---

## 🧪 User Commands

| Command       | Description                 |
| ------------- | --------------------------- |
| `:Otree`      | Toggle the file tree window |
| `:OtreeFocus` | Focus the file tree window  |

---

## ⚙️ Oil.nvim Integration

**Otree** can optionally integrate with [oil.nvim](https://github.com/stevearc/oil.nvim) for enhanced file management capabilities.

⚠️ **Note**: Without oil.nvim, there are no file operations available (create, delete, move, rename). Oil integration is required for any file management beyond basic navigation and opening.

### Automatic Configuration

If `oil.nvim` is installed but not already configured, Otree will automatically set it up with these optimized defaults:

```lua
require("oil").setup({
    default_file_explorer = false,
    skip_confirm_for_simple_edits = true,
    delete_to_trash = true,
    cleanup_delay_ms = false,
})
```

If Oil is already configured, Otree respects your existing setup and will not override any settings.

### Opening Modes

You can configure how Oil opens using the `oil` option in your Otree setup:

```lua
require("Otree").setup({
    oil = "float"  -- Opens Oil in a floating window (default)
    -- Any other value opens Oil directly inside the tree window
})
```

### Hidden Files Synchronization

Toggling hidden files in Otree automatically syncs with Oil's `view_options.show_hidden` setting, ensuring consistent visibility across both interfaces.

### Dynamic Titles

Oil views display dynamically generated titles with icons and relative paths for better context and navigation.

### ⚠️ Important Note

**Do not use `oil_preview` when Oil is open in floating mode.** This may cause rendering or focus issues. Close floating Oil windows before using preview functionality.

---

## 🔧 Fallback Behavior

When optional dependencies are not available:

- **Without `fd`**: Falls back to basic directory listing (slower performance)
- **Without `oil.nvim`**: No file operations available - only navigation and opening files is supported
- **Without icon plugins**: Uses simple default icons for files and directories
