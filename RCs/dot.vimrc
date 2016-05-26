syntax on
filetype indent on
set nocompatible
set ignorecase
set nowrap
set is
set hls
set expandtab
set noai
set ruler
set bg=dark
colorscheme default
set tabstop=2
set shiftwidth=2
set smartindent
set autoindent
"set backspace=2
set colorcolumn=90
set number
map <D-A-RIGHT> <C-w>l
map <D-A-LEFT> <C-w>h
map <D-A-DOWN> <C-w><C-w>
map <D-A-UP> <C-w>W
" PERFORMANCES & HISTORY
set hidden
set history=100
map  :w!<CR>:!aspell check %<CR>:e! %<CR>
"F7 WordProcessorOn
map <F7> :set linebreak <CR> :set display+=lastline <CR> :set wrap <CR> :setlocal spell spelllang=en_gb <CR>
"F8 WordProcessorOff
map <F8> :set nowrap <CR> :set nospell <CR> 
