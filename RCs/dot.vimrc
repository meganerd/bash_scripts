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
hi Comment ctermfg=34
hi Comment ctermbg=233
set tabstop=2
set shiftwidth=2
set smartindent
set autoindent
"set backspace=2
set number
map <D-A-RIGHT> <C-w>l
map <D-A-LEFT> <C-w>h
map <D-A-DOWN> <C-w><C-w>
map <D-A-UP> <C-w>W
if version >= 703
  let &colorcolumn="80,".join(range(120,999),",")
  highlight ColorColumn ctermbg=235 guibg=#2c2d27
endif
" PERFORMANCES & HISTORY
set hidden
set history=100
map  :w!<CR>:!aspell check %<CR>:e! %<CR>
"F7 WordProcessorOn
map <F7> :set linebreak <CR> :set display+=lastline <CR> :set wrap <CR> :setlocal spell spelllang=en_gb <CR>
"F8 WordProcessorOff
map <F8> :set nowrap <CR> :set nospell <CR> 
set statusline="%f%m%r%h%w [%Y] [0x%02.2B]%< %F%=%4v,%4l %3p%% of %L"
