local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  print("nvim is bootstrapping.")
  local fn = vim.fn

  fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--single-branch",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end

vim.opt.runtimepath:prepend(lazypath)
vim.loader.enable()

require("lazy").setup("plugins")

vim.cmd [[set background=light]]
vim.cmd [[let g:gruvbox_contrast_light = "hard"]]
vim.cmd [[let g:gruvbox_contrast_dark = "soft"]]
vim.cmd [[colorscheme gruvbox]]

