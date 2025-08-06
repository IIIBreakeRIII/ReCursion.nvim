-- lua/ReCursion/lib.lua
local M = {}
local result_bufnr, result_winid

-- Run a shell command and capture both stdout and stderr
local function run_cmd(cmd)
  local handle = io.popen(cmd .. " 2>&1")
  local result = handle:read("*a")
  handle:close()
  return result
end

-- Open or reuse a scratch window for results
local function open_window(ft)
  if result_bufnr and vim.api.nvim_buf_is_valid(result_bufnr)
     and result_winid and vim.api.nvim_win_is_valid(result_winid) then
    vim.api.nvim_set_current_win(result_winid)
    vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, {})
  else
    vim.cmd("rightbelow vsplit")
    result_winid = vim.api.nvim_get_current_win()
    vim.cmd("enew")
    result_bufnr = vim.api.nvim_get_current_buf()
  end
  vim.bo[result_bufnr].filetype   = ft
  vim.bo[result_bufnr].buftype    = "nofile"
  vim.bo[result_bufnr].bufhidden  = "hide"
  vim.bo[result_bufnr].swapfile   = false
  vim.bo[result_bufnr].modifiable = true
  vim.keymap.set("n", ";bd", function() vim.cmd("bd") end,
                 { buffer = result_bufnr, silent = true, noremap = true })
end

-- Make buffer read-only
local function finalize()
  if result_bufnr and vim.api.nvim_buf_is_valid(result_bufnr) then
    vim.bo[result_bufnr].modifiable = false
  end
end

-- Compile helper: source -> output (.o or exe)
local function compile(source, output, is_executable)
  local parts = {"gcc", "-g", "-O0", "-fno-builtin"}
  if is_executable then
    table.insert(parts, "-o"); table.insert(parts, output)
    table.insert(parts, source)
  else
    table.insert(parts, "-c"); table.insert(parts, source)
    table.insert(parts, "-o"); table.insert(parts, output)
  end
  return run_cmd(table.concat(parts, " "))
end

-- Disassemble object file (.o) with temp symbols
function M.disasmObj()
  local name = vim.fn.expand("%:t:r")
  local tmp_c, tmp_o = "/tmp/recursion_code.c", "/tmp/recursion_code.o"
  vim.cmd("write! " .. tmp_c)
  compile(tmp_c, tmp_o, false)
  local file_info = run_cmd("file " .. tmp_o)
  local cmd = file_info:match("Mach%-O") and "otool -tvV " .. tmp_o
                                           or "objdump -d -l -S " .. tmp_o
  local asm = run_cmd(cmd)
  open_window("asm")
  vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(asm, "\n"))
  vim.api.nvim_buf_set_name(result_bufnr, name .. "-ObjDisasm")
  finalize()
end

-- Disassemble full linked executable with PLT/GOT
function M.disasmExe()
  local name = vim.fn.expand("%:t:r")
  local tmp_c, tmp_exe = "/tmp/recursion_code.c", "/tmp/recursion_code_exe"
  vim.cmd("write! " .. tmp_c)
  compile(tmp_c, tmp_exe, true)
  local file_info = run_cmd("file " .. tmp_exe)
  local cmd = file_info:match("Mach%-O") and "otool -tvV " .. tmp_exe
                                           or "objdump -d -l -S " .. tmp_exe
  local asm = run_cmd(cmd)
  open_window("asm")
  vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(asm, "\n"))
  vim.api.nvim_buf_set_name(result_bufnr, name .. "-FullDisasm")
  finalize()
end

-- Decompile full executable to C using RetDec (bin mode, keep library funcs, cleanup)
function M.decompileExe()
  local name = vim.fn.expand("%:t:r")
  local tmp_c, tmp_exe, tmp_dc = "/tmp/recursion_code.c", "/tmp/recursion_code_exe", "/tmp/recursion_code_exe_decompiled.c"
  vim.cmd("write! " .. tmp_c)
  compile(tmp_c, tmp_exe, true)
  local cmd = table.concat({
    "retdec-decompiler",
    "--mode bin",
    "--keep-library-funcs",
    "--cleanup",
    "-o", tmp_dc,
    tmp_exe,
  }, " ")
  local output = run_cmd(cmd)
  if not vim.loop.fs_stat(tmp_dc) then
    open_window("text")
    vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(output, "\n"))
    vim.api.nvim_buf_set_name(result_bufnr, name .. "-DecompileError")
    return finalize()
  end
  local dc = run_cmd("cat " .. tmp_dc)
  open_window("c")
  vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(dc, "\n"))
  vim.api.nvim_buf_set_name(result_bufnr, name .. "-FullDecompiled")
  finalize()
end

-- Register user commands
function M.setup()
  vim.api.nvim_create_user_command("ReCDisasmObj", M.disasmObj, {})
  vim.api.nvim_create_user_command("ReCDisasmExe", M.disasmExe, {})
  vim.api.nvim_create_user_command("ReCDecompileExe", M.decompileExe, {})
end

return M
