# ReCursion.nvim

A Neovim plugin for disassembling and decompiling C code directly in Neovim.  
Uses `objdump` for disassembly and `retdec` for decompilation.

---

## 📦 Installation

### Lazy.nvim
```lua
{
  "IIIBreakeRIII/nvim-ReCursion",
  config = function()
    require("ReCursion").setup()
  end,
}
```

### Packer.nvim
```lua
use {
  "IIIBreakeRIII/nvim-ReCursion",
  config = function()
    require("ReCursion").setup()
  end
}
```

## ⚡ Requirements
- `gcc` (for compilation with debug symbols)
- `objdump` (for assembly output)
- `retdec` (for C decompilation)

Ensure these are available in your PATH.

## 🚀 Usage

> **Disassemble current C file**
```
:ReCDisasm
```
> **Decompile current C file**
```
:ReCDecompile
```
> **Close Buffer**
```
;bd
```

The output opens in a vertical split with syntax highlighting.

## 📂 How It Works
1.	Saves the current buffer to /tmp/recursion_code.c
2.	Compiles with -g -O0 to preserve debug info
3.	Runs objdump (disassembly) or retdec (decompilation)
4.	Displays results in a scratch buffer in Neovim
