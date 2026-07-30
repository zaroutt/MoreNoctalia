local function enable_transparency()
    local groups = {
        "Normal", "NormalNC", "LineNr", "CursorLineNr", "SignColumn",
        "FoldColumn", "VertSplit", "EndOfBuffer", "MsgArea",
    }
    for _, g in ipairs(groups) do
        vim.api.nvim_set_hl(0, g, { bg = "none" })
    end
end


return {
    {
        "RRethy/base16-nvim",
        lazy = false,
        priority = 1000,
        config = function()
            local ok, matugen = pcall(require, "matugen")
            if ok then
                matugen.setup()
            end
            enable_transparency()
        end,
    },

    {
        'ellisonleao/gruvbox.nvim',
        config = function ()
            enable_transparency()
        end
    },

    {
        "nvim-lualine/lualine.nvim",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
            "RRethy/base16-nvim",
        }, opts = {
            theme = "base16",
        },
    },
}
