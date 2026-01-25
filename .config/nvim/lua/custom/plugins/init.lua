-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
	{
	  "ThePrimeagen/harpoon",
	  branch = "harpoon2",
	  dependencies = { "nvim-lua/plenary.nvim" }
	},

  {
    "craftzdog/solarized-osaka.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },
  {
    "unixsuperhero/demo.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },
}
