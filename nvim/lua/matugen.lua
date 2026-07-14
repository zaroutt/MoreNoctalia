 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#0e3020',
    base01 = '#174f36',
    base02 = '#154731',
    base03 = '#62786e',
    base04 = '#afb6b3',
    base05 = '#f2f3f2',
    base06 = '#f2f3f2',
    base07 = '#f2f3f2',
    base08 = '#fd4663',
    base09 = '#6093d2',
    base0A = '#5cd0d6',
    base0B = '#67e4ac',
    base0C = '#96bbe9',
    base0D = '#93ecc4',
    base0E = '#96e5e9',
    base0F = '#910017',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  hi('TelescopeNormal',         { fg = '#f2f3f2',          bg = '#0e3020' })
  hi('TelescopeBorder',         { fg = '#62786e',             bg = '#0e3020' })
  hi('TelescopePromptNormal',   { fg = '#f2f3f2',          bg = '#0e3020' })
  hi('TelescopePromptBorder',   { fg = '#62786e',             bg = '#0e3020' })
  hi('TelescopePromptPrefix',   { fg = '#67e4ac',             bg = '#0e3020' })
  hi('TelescopePromptCounter',  { fg = '#afb6b3',  bg = '#0e3020' })
  hi('TelescopePromptTitle',    { fg = '#0e3020',             bg = '#67e4ac' })
  hi('TelescopePreviewTitle',   { fg = '#0e3020',             bg = '#5cd0d6' })
  hi('TelescopeResultsTitle',   { fg = '#0e3020',             bg = '#6093d2' })
  hi('TelescopeSelection',      { fg = '#f2f3f2',          bg = '#154731' })
  hi('TelescopeSelectionCaret', { fg = '#67e4ac',             bg = '#154731' })
  hi('TelescopeMatching',       { fg = '#67e4ac',             bold = true })
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
