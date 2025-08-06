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

-- Disassemble C code and annotate source-to-assembly mapping
function M.disasm()
  local fname = vim.fn.expand("%:t:r")
  local cwd = vim.fn.getcwd()
  local workdir = cwd .. "/" .. fname .. "-decompile"
  run_cmd("mkdir -p " .. workdir)

  local src = workdir .. "/" .. fname .. ".c"
  local exe = workdir .. "/" .. fname .. "_exe"

  -- save and compile
  vim.cmd("write! " .. src)
  compile_exe(src, exe)

  -- choose disassembler, prefer objdump variants for source interleaving
  local cmd = "objdump -d -l -S " .. exe
  if run_cmd("which llvm-objdump"):match("llvm%-objdump") then
    cmd = "llvm-objdump -d -l -S " .. exe
  elseif run_cmd("which gobjdump"):match("gobjdump") then
    cmd = "gobjdump -d -l -S " .. exe
  end

  -- run disassembly
  local asm = run_cmd(cmd)
  local lines_tbl = vim.split(asm, "\n", true)

  -- open buffer and set assembly lines
  open_window("asm")
  vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, lines_tbl)
  vim.api.nvim_buf_set_name(result_bufnr, fname .. "-Disassembly")

  -- annotate mapping: add virt_text addresses to source comment lines
  local ns = vim.api.nvim_create_namespace("ReCursionMapping")
  for idx, line in ipairs(lines_tbl) do
    local src_ln = line:match"; [^:]+:(%d+)"
    if src_ln then
      local instr = lines_tbl[idx+1] or ""
      local addr = instr:match"^%s*([%w]+):"
      if addr then
        vim.api.nvim_buf_set_extmark(result_bufnr, ns, idx-1, 0, {
          virt_text = {{"→ " .. addr, "Comment"}},
          virt_text_pos = "eol",
        })
      end
    end
  end

  finalize()
end

-- Decompile C code using RetDec (JSON-based reconstruction)
function M.decompile()
  local fname = vim.fn.expand("%:t:r")
  local cwd = vim.fn.getcwd()
  local workdir = cwd .. "/" .. fname .. "-decompile"
  run_cmd("mkdir -p " .. workdir)

  local src   = workdir .. "/" .. fname .. ".c"
  local exe   = workdir .. "/" .. fname .. "_exe"
  local jsonf = workdir .. "/" .. fname .. ".json"

  -- save and compile
  vim.cmd("write! " .. src)
  compile_exe(src, exe)

  -- run RetDec for JSON-human output keeping library calls
  local cmd = table.concat({
    "retdec-decompiler",
    "--mode bin",
    "--backend-keep-library-funcs",
    "--output-format json-human",
    "-o", jsonf,
    exe
  }, " ")
  local out = run_cmd(cmd)

  -- error if JSON missing
  if not vim.loop.fs_stat(jsonf) then
    open_window("text")
    vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(out, "\n"))
    vim.api.nvim_buf_set_name(result_bufnr, fname .. "-DecompileError")
    finalize()
    return
  end

  -- reconstruct C from tokens
  local raw = run_cmd("cat " .. jsonf)
  local data = vim.fn.json_decode(raw)
  if not data or type(data.tokens) ~= "table" then
    open_window("text")
    vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, {"[error] invalid JSON tokens"})
    vim.api.nvim_buf_set_name(result_bufnr, fname .. "-DecompileError")
    finalize()
    return
  end

  local vals = {}
  for _, tok in ipairs(data.tokens) do
    if tok.val then table.insert(vals, tok.val) end
  end
  local combined = table.concat(vals)
  local lines = vim.split(combined, "\n", true)

  -- write reconstructed source
  local recon = workdir .. "/reconstructed.c"
  local f = io.open(recon, "w")
  if f then f:write(combined); f:close() end

  -- display in vim
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

