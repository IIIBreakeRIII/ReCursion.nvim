-- lua/ReCursion/lib.lua
local M = {}
local result_bufnr, result_winid

-- Run a shell command and capture output
local function run_cmd(cmd)
  local h = io.popen(cmd)
  local out = h:read("*a")
  h:close()
  return out
end

-- Open or reuse result window
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
    result_bufnr  = vim.api.nvim_get_current_buf()
  end
  vim.bo[result_bufnr].filetype   = ft
  vim.bo[result_bufnr].buftype    = "nofile"
  vim.bo[result_bufnr].bufhidden  = "hide"
  vim.bo[result_bufnr].swapfile   = false
  vim.bo[result_bufnr].modifiable = true

  -- Close buffer shortcut
  vim.keymap.set("n", ";bd", function()
    vim.cmd("bd")
  end, { buffer = result_bufnr, silent = true, noremap = true })
end

-- Make buffer read-only
local function finalize()
  if result_bufnr and vim.api.nvim_buf_is_valid(result_bufnr) then
    vim.bo[result_bufnr].modifiable = false
  end
end

-- Disassemble object file (.o) with temp symbols and basic assembly
function M.disasmObj()
  local name = vim.fn.expand("%:t:r")
  local tmp_c = "/tmp/recursion_code.c"
  local tmp_o = "/tmp/recursion_code.o"

  vim.cmd("write! " .. tmp_c)
  run_cmd("gcc -g -O0 -fno-builtin -c " .. tmp_c .. " -o " .. tmp_o)

  local asm = run_cmd("objdump -d -l -S " .. tmp_o)

  open_window("asm")
  vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(asm, "\n"))
  vim.api.nvim_buf_set_name(result_bufnr, name .. "-ObjDisasm")

  finalize()
end

-- Disassemble full linked executable with PLT/GOT (shows external calls)
function M.disasmExe()
  local name = vim.fn.expand("%:t:r")
  local tmp_c   = "/tmp/recursion_code.c"
  local tmp_exe = "/tmp/recursion_code_exe"

  vim.cmd("write! " .. tmp_c)
  run_cmd("gcc -g -O0 -fno-builtin -o " .. tmp_exe .. " " .. tmp_c)

  local asm = run_cmd("objdump -d -l -S " .. tmp_exe)

  open_window("asm")
  vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(asm, "\n"))
  vim.api.nvim_buf_set_name(result_bufnr, name .. "-FullDisasm")

  finalize()
end

function M.setup()
  vim.api.nvim_create_user_command("ReCDisasmObj", M.disasmObj, {})
  vim.api.nvim_create_user_command("ReCDisasmExe", M.disasmExe, {})
end

return M

