vim.lsp.config('lua-language-server', {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = { '.luarc.json', '.luarc.json', '.git' },
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      codeLens = { enable = true },
      hint = { enable = true, semicolon = 'Disable' },
    },
  },
})
vim.lsp.enable('lua-language-server')

vim.opt.updatetime = 1500 -- time until `CursorHold` fire
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    -- Do not open automatically if other float window already open
    for _, winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(winid).zindex then
        return
      end
    end
    vim.diagnostic.open_float({ focusable = false, source = "if_many" })
  end,
})
-- based `:h lsp-attach`
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("my.lsp", {}),
  callback = function(args)
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
    -- completion
    if client:supports_method('textDocument/completion') then
      local triggerChars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\'"< _.:@#&|+-*/%='
      local chars = {}; for i = 1, #triggerChars do table.insert(chars, string.sub(triggerChars, i, i)) end
      client.server_capabilities.completionProvider.triggerCharacters = chars
      vim.lsp.completion.enable(true, client.id, args.buf, {
        autotrigger = true,
      })
    end
    -- auto formatting
    if not client:supports_method('textDocument/willSaveWaitUntil')
        and client:supports_method('textDocument/formatting') then
      vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('my.lsp', { clear = false }),
        buffer = args.buf,
        callback = function()
          vim.lsp.buf.format({
            bufnr = args.buf,
            id = client.id,
            timeout_ms = 3000,
          })
        end,
      })
    end
  end,
})
vim.diagnostic.config({ virtual_text = true })
