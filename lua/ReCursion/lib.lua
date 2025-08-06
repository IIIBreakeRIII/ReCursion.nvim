-- lua/ReCursion/lib.lua
local M = {}
local result_bufnr, result_winid

-- Run a shell command, capturing stdout and stderr
local function run_cmd(cmd)
  local h = io.popen(cmd .. " 2>&1")
  local out = h:read("*a")
  h:close()
  return out
end

-- Open or reuse a right-side split buffer for results
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

-- Disassemble C code (unchanged)
function M.disasm()
  local fname = vim.fn.expand("%:t:r")
  local tmp_c   = "/tmp/recursion_code.c"
  local tmp_exe = "/tmp/recursion_code_exe"

  vim.cmd("write! " .. tmp_c)
  compile_exe(tmp_c, tmp_exe)

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

-- Decompile C code using RetDec (JSON-based reconstruction)
function M.decompile()
  local fname = vim.fn.expand("%:t:r")
  local cwd = vim.fn.getcwd()
  local workdir = cwd .. "/" .. fname .. "-decompile"

  -- Create working directory
  run_cmd("mkdir -p " .. workdir)

  -- Define paths
  local src   = workdir .. "/" .. fname .. ".c"
  local exe   = workdir .. "/" .. fname .. "_exe"
  local jsonf = workdir .. "/" .. fname .. ".json"
  local recon = workdir .. "/reconstructed.c"

  -- Save current buffer and compile to executable
  vim.cmd("write! " .. src)
  compile_exe(src, exe)

  -- Run RetDec for JSON-human output keeping library calls
  local cmd = table.concat({
    "retdec-decompiler",
    "--mode bin",
    "--backend-keep-library-funcs",
    "--output-format json-human",
    "-o", jsonf,
    exe
  }, " ")
  local out = run_cmd(cmd)

  -- Check if JSON file was created
  if not vim.loop.fs_stat(jsonf) then
    open_window("text")
    vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(out, "\n"))
    vim.api.nvim_buf_set_name(result_bufnr, fname .. "-DecompileError")
    finalize()
    return
  end

  -- Read and reconstruct source from tokens
  local raw = run_cmd("cat " .. jsonf)
  local data = vim.fn.json_decode(raw)
  if not data or type(data.tokens) ~= 'table' or #data.tokens == 0 then
    open_window("text")
    vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, {"[error] invalid JSON tokens"})
    vim.api.nvim_buf_set_name(result_bufnr, fname .. "-DecompileError")
    finalize()
    return
  end

  -- Extract token values safely
  local vals = {}
  for _, tok in ipairs(data.tokens) do
    if tok.val then table.insert(vals, tok.val) end
  end
  if #vals == 0 then
    open_window("text")
    vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, {"[error] no token values"})
    vim.api.nvim_buf_set_name(result_bufnr, fname .. "-DecompileError")
    finalize()
    return
  end

  -- Concatenate and split into lines
  local combined = table.concat(vals)
  local lines = vim.split(combined, "\n", true)

  -- Write reconstructed source to file
  local f = io.open(recon, "w")
  if f then
    f:write(combined)
    f:close()
  end

  -- Display reconstructed source in Vim
  open_window("c")
  vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(result_bufnr, fname .. "-Decompiled")
  finalize()
end

-- Register user commands
function M.setup()
  vim.api.nvim_create_user_command("ReCDisasm",    M.disasm,    {})
  vim.api.nvim_create_user_command("ReCDecompile", M.decompile, {})
end

return M

