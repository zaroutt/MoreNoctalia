 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#0c0c0c',
    base01 = '#1c1c1c',
    base02 = '#262626',
    base03 = '#5e5e5e',
    base04 = '#a0a0a0',
    base05 = '#ffffff',
    base06 = '#ffffff',
    base07 = '#ffffff',
    base08 = '#ff8080',
    base09 = '#fbadff',
    base0A = '#99ffe4',
    base0B = '#ffc799',
    base0C = '#f980ff',
    base0D = '#ffb980',
    base0E = '#80ffdd',
    base0F = '#cd0000',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  hi('TelescopeNormal',         { fg = '#ffffff',          bg = '#0c0c0c' })
  hi('TelescopeBorder',         { fg = '#5e5e5e',             bg = '#0c0c0c' })
  hi('TelescopePromptNormal',   { fg = '#ffffff',          bg = '#0c0c0c' })
  hi('TelescopePromptBorder',   { fg = '#5e5e5e',             bg = '#0c0c0c' })
  hi('TelescopePromptPrefix',   { fg = '#ffc799',             bg = '#0c0c0c' })
  hi('TelescopePromptCounter',  { fg = '#a0a0a0',  bg = '#0c0c0c' })
  hi('TelescopePromptTitle',    { fg = '#0c0c0c',             bg = '#ffc799' })
  hi('TelescopePreviewTitle',   { fg = '#0c0c0c',             bg = '#99ffe4' })
  hi('TelescopeResultsTitle',   { fg = '#0c0c0c',             bg = '#fbadff' })
  hi('TelescopeSelection',      { fg = '#ffffff',          bg = '#262626' })
  hi('TelescopeSelectionCaret', { fg = '#ffc799',             bg = '#262626' })
  hi('TelescopeMatching',       { fg = '#ffc799',             bold = true })
end

 -- Register a signal handler for SIGUSR1 (matugen updates)
 local signal = vim.uv.new_signal()
 signal:start(
   'sigusr1',
   vim.schedule_wrap(function()
     package.loaded['matugen'] = nil
     require('matugen').setup()
   end)
 )

 return M
