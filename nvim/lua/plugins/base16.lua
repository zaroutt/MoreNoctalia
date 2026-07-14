local function enable_transparency()
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
end


return {
    {
        "RRethy/base16-nvim",
        config = function()
            local ok, matugen = pcall(require, "matugen")
            if ok then
                matugen.setup()
            end
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
        }, opts = {
            theme = "base16",
            
        },
    },
}
