# ReCursion.nvim

A Neovim plugin for disassembling and decompiling C code directly in Neovim.\
Uses `objdump` for disassembly and `retdec` for decompilation.

---

## 📦 Installation

### Lazy.nvim

```lua
{
  "IIIBreakeRIII/ReCursion.nvim",
  config = function()
    require("ReCursion").setup()
  end,
}
```

### Packer.nvim

```lua
use {
  "IIIBreakeRIII/ReCursion.nvim",
  config = function()
    require("ReCursion").setup()
  end,
}
```

---

## ⚡ Requirements

- `gcc` (for compilation with debug symbols)
- `objdump` (for assembly output)
- `retdec` (for C decompilation, requires `retdec-decompiler` CLI)

Ensure these are available in your `PATH`.

---

## 🚀 Usage

```vim
" Disassemble current C file
:ReCDisasm

" Decompile current C file
:ReCDecompile

" Close result buffer
;bd
```

The output opens in a vertical split with syntax highlighting.

---

## 📂 How It Works

1. Saves the current buffer to `/tmp/recursion_code.c`.
2. Compiles with `-g -O0 -fno-builtin` to preserve debug info and disable built-ins.
3. Runs `objdump -d -l -S` (or `otool -tvV` on macOS) for disassembly, or `retdec-decompiler` for decompilation in JSON-human mode.
4. Reconstructs and displays results in a scratch buffer inside Neovim.

---

## 📜 License

MIT