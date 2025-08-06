-- lua/ReCursion/lib.lua
local M = {}
local result_bufnr, result_winid

-- Run a shell command, capturing stdout and stderr
local function run_cmd(cmd)
  local handle = io.popen(cmd .. " 2>&1")
  local out = handle:read("*a")
  handle:close()
  return out
end

-- Open (or reuse) a right-side split buffer for results
local function open_window(ft)
  if result_bufnr and vim.api.nvim_buf_is_valid(result_bufnr)
     and result_winid and vim.api.nvim_win_is_valid(result_winid)
  then
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

-- Finalize buffer: make it read-only
local function finalize()
  if result_bufnr and vim.api.nvim_buf_is_valid(result_bufnr) then
    vim.bo[result_bufnr].modifiable = false
  end
end

-- Compile current buffer to an executable
local function compile_exe(source, exe)
  local cmd = table.concat({
    "gcc", "-g", "-O0", "-fno-builtin",
    "-o", exe,
    source
  }, " ")
  return run_cmd(cmd)
end

-- Disassemble C code (via full executable and objdump/otool)
function M.disasm()
  local fname = vim.fn.expand("%:t:r")
  local tmp_c   = "/tmp/recursion_code.c"
  local tmp_exe = "/tmp/recursion_code_exe"

  -- save and compile
  vim.cmd("write! " .. tmp_c)
  compile_exe(tmp_c, tmp_exe)

  -- choose tool based on file type
  local info = run_cmd("file " .. tmp_exe)
  local cmd = info:match("Mach%-O")
    and ("otool -tvV " .. tmp_exe)
    or ("objdump -d -l -S " .. tmp_exe)

  local asm = run_cmd(cmd)
  open_window("asm")
  vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(asm, "\n"))
  vim.api.nvim_buf_set_name(result_bufnr, fname .. "-Disassembly")
  finalize()
end

-- Decompile C code using RetDec (full executable mode)
function M.decompile()
  local fname = vim.fn.expand("%:t:r")
  local tmp_c   = "/tmp/recursion_code.c"
  local tmp_exe = "/tmp/recursion_code_exe"
  local tmp_dc  = "/tmp/recursion_code_decompiled.c"

  -- save and compile
  vim.cmd("write! " .. tmp_c)
  compile_exe(tmp_c, tmp_exe)

  -- run RetDec
  local cmd = table.concat({
    "retdec-decompiler",
    "--mode bin",
    "--keep-library-funcs",
    "--cleanup",
    "-o", tmp_dc,
    tmp_exe
  }, " ")
  local out = run_cmd(cmd)

  if not vim.loop.fs_stat(tmp_dc) then
    -- on error, show retdec output
    open_window("text")
    vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(out, "\n"))
    vim.api.nvim_buf_set_name(result_bufnr, fname .. "-DecompileError")
    return finalize()
  end

  -- display decompiled C
  local dc = run_cmd("cat " .. tmp_dc)
  open_window("c")
  vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(dc, "\n"))
  vim.api.nvim_buf_set_name(result_bufnr, fname .. "-Decompiled")
  finalize()
end

-- Register user commands
function M.setup()
  vim.api.nvim_create_user_command("ReCDisasm",    M.disasm,    {})
  vim.api.nvim_create_user_command("ReCDecompile", M.decompile, {})
end

return M
