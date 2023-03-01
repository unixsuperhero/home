call plug#begin()
call plug#begin('~/.vim/plugged')

Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-rsi'
Plug 'adelarsq/vim-matchit'
Plug 'vim-ruby/vim-ruby'
Plug 'kana/vim-textobj-user'
Plug 'nelstrom/vim-textobj-rubyblock'
Plug 'godlygeek/tabular'

if has("nvim")
  Plug 'kristijanhusak/defx-git'
  Plug 'kristijanhusak/defx-icons'
  Plug 'Shougo/defx.nvim', { 'do': ':UpdateRemotePlugins' }
  Plug 'neovim/nvim-lspconfig'
  Plug 'glepnir/lspsaga.nvim'
  Plug 'folke/lsp-colors.nvim'
  Plug 'folke/tokyonight.nvim'
  " Plug 'nvim-lua/completion-nvim'
  " Plug 'nvim-treesitter/nvim-treesitter', { 'do': ':TSUpdate' }
  Plug 'kyazdani42/nvim-web-devicons'
  Plug 'nvim-lua/popup.nvim'
  Plug 'nvim-lua/plenary.nvim'
  Plug 'nvim-telescope/telescope.nvim'
  Plug 'lotabout/skim', { 'dir': '~/.skim', 'do': './install' }
  Plug 'jremmen/vim-ripgrep'
  Plug 'jose-elias-alvarez/null-ls.nvim'
  Plug 'jose-elias-alvarez/nvim-lsp-ts-utils'

  " Collection of common configurations for the Nvim LSP client
Plug 'neovim/nvim-lspconfig'

" Extentions to built-in LSP, for example, providing type inlay hints
Plug 'nvim-lua/lsp_extensions.nvim'

" Autocompletion framework
Plug 'hrsh7th/nvim-cmp'
" cmp LSP completion
Plug 'hrsh7th/cmp-nvim-lsp'
" cmp Snippet completion
" Plug 'hrsh7th/cmp-vsnip'
" cmp Path completion
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-buffer'
" See hrsh7th other plugins for more great completion sources!

" Snippet engine
" Plug 'hrsh7th/vim-vsnip'

" Some color scheme other then default
endif

call plug#end()

colorscheme tokyonight

set clipboard+=unnamedplus

set splitright splitbelow
set ignorecase smartcase
set nowrap nu
set gdefault
set ts=2 sts=2 sw=2 expandtab

set ep=bc\ -l

set mp=ruby\ -c\ %

set mouse=

if exists("&termguicolors") && exists("&winblend")
  syntax enable
  set termguicolors
  set winblend=0
  set wildoptions=pum
  set pumblend=5
  set background=dark
endif

set winheight=10 winminheight=5
set winwidth=20 winminwidth=12

cnoremap %% <c-r>=expand('%:.:h')<cr>/
nnoremap <space><space> :

nnoremap <space>w :w<cr>
nnoremap <space>W :w!<cr>
nnoremap <space>q :q<cr>
nnoremap <space>Q :q!<cr>
nnoremap <space>e :e <c-r>=expand('%:h') . '/'<cr>
nnoremap <space>v :vs <c-r>=expand('%:h') . '/'<cr>
nnoremap <space>s :sp <c-r>=expand('%:h') . '/'<cr>
nnoremap <space>E :e <c-r>=expand('%:h') . '/'<cr>
nnoremap <space>V :vs <c-r>=expand('%:h') . '/'<cr>
nnoremap <space>S :sp <c-r>=expand('%:h') . '/'<cr>

nmap gf <cmd>vert wincmd f<cr>

nnoremap cob :set buftype=nofile<cr>
nnoremap col :set invlist<cr>
nnoremap cow :set invwrap<cr>

nmap ,t :T bundle exec rspec %<cr>
nmap ,T :T bundle exec rspec <c-r>=expand('%')<cr>:<c-r>=line('.')<cr><cr>
nmap <expr> ,s execute(substitute(join([':nmap <\space>t :T bundle exec rspec ', expand('%'), '<\cr>a'], ''), '\\', '', 'g'))
nmap <expr> ,S execute(substitute(join([':nmap <\space>t :T bundle exec rspec ', expand('%'), ':', line('.'), '<\cr>a'], ''), '\\', '', 'g'))

nnoremap ,r <cmd>VT cat -n % \| rg '\b(module\|class\|def)\b'<cr>
nnoremap ,R <cmd>VT cat -n % \| rg '\b(context\|it\|describe)\b'<cr>
nnoremap ,L <cmd>VT cat -n % \| rg '\b(context\|it\|describe\|let)\b'<cr>

nnoremap ,, <c-^>

tnoremap <esc> <c-\><c-n>

cabbrev sk SK
cabbrev rg Rg
cabbrev Spec <c-r>=expand('%:s/lib/spec/:s/\.rb$/_spec.rb/')<cr>
cabbrev Code <c-r>=expand('%:s/spec/lib/:s/_spec.rb/.rb/')<cr>

cabbrev smp set mp=ruby\ -c\ \%
iabbrev sao save_and_open_page
cabbrev V vert
cabbrev vb vert sb

command! -nargs=* T split | wincmd J | terminal <args>; zsh -i
command! -nargs=* VT vsplit | wincmd L | terminal <args>; zsh -i

lua <<EOF

-- nvim_lsp object
local nvim_lsp = require'lspconfig'

local capabilities = vim.lsp.protocol.make_client_capabilities()
-- capabilities.textDocument.completion.completionItem.snippetSupport = true

-- Enable rust_analyzer
nvim_lsp.rust_analyzer.setup({
    capabilities=capabilities,
    -- on_attach is a callback called when the language server attachs to the buffer
    -- on_attach = on_attach,
    settings = {
      -- to enable rust-analyzer settings visit:
      -- https://github.com/rust-analyzer/rust-analyzer/blob/master/docs/user/generated_config.adoc
      ["rust-analyzer"] = {
        -- enable clippy diagnostics on save
        checkOnSave = {
          command = "clippy"
        },
      }
    }
})

-- Enable diagnostics
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
  vim.lsp.diagnostic.on_publish_diagnostics, {
    virtual_text = false,
    signs = true,
    update_in_insert = true,
  }
)
EOF

" Code navigation shortcuts
" as found in :help lsp
nnoremap <silent> <c-]> <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> K     <cmd>lua vim.lsp.buf.hover()<CR>
nnoremap <silent> gD    <cmd>lua vim.lsp.buf.implementation()<CR>
nnoremap <silent> <c-k> <cmd>lua vim.lsp.buf.signature_help()<CR>
nnoremap <silent> 1gD   <cmd>lua vim.lsp.buf.type_definition()<CR>
nnoremap <silent> gr    <cmd>lua vim.lsp.buf.references()<CR>
nnoremap <silent> g0    <cmd>lua vim.lsp.buf.document_symbol()<CR>
nnoremap <silent> gW    <cmd>lua vim.lsp.buf.workspace_symbol()<CR>
nnoremap <silent> gd    <cmd>lua vim.lsp.buf.definition()<CR>

" Quick-fix
nnoremap <silent> ga    <cmd>lua vim.lsp.buf.code_action()<CR>

" Setup Completion
" See https://github.com/hrsh7th/nvim-cmp#basic-configuration
lua <<EOF
local cmp = require'cmp'
cmp.setup({
  mapping = {
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-n>'] = cmp.mapping.select_next_item(),
    ['<C-e>'] = cmp.mapping.close(),
  },
  sources = {
    { name = 'path' },
    { name = 'buffer' },
  },
})
EOF

set updatetime=300

hi LineNr cterm=bold gui=bold guifg=#a9b1d6
hi Comment cterm=bold gui=bold guifg=#a9b1d6

nnoremap <silent> g[ <cmd>lua vim.diagnostic.goto_prev()<CR>
nnoremap <silent> g] <cmd>lua vim.diagnostic.goto_next()<CR>

augroup haml
  au!
  au FileType haml setlocal makeprg=haml\ compile\ -c\ \%
augroup END

augroup ruby
  au!
  au FileType ruby setlocal makeprg=ruby\ -c\ \%
augroup END

augroup rust
  au!
  au FileType rust setlocal makeprg=cargo\ build
  au FileType rust nmap <space>r <cmd>T cargo run %<cr>
augroup END

