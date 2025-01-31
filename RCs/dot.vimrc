let g:airline_powerline_fonts = 1
let g:airline_theme='papercolor'
syntax on
filetype indent on
set textwidth=0
set wrapmargin=0
set wrap
set linebreak " (optional - breaks by word rather than character)
set nocompatible
set ignorecase
set is
set hls
set noai
set bg=dark
colorscheme default
hi Comment ctermfg=34
hi Comment ctermbg=233
set shiftwidth=2
set backspace=indent,eol,start
set paste
set nonumber
set ruler
map <D-A-RIGHT> <C-w>l
map <D-A-LEFT> <C-w>h
map <D-A-DOWN> <C-w><C-w>
map <D-A-UP> <C-w>W
if version >= 703
  let &colorcolumn="80,120"
  highlight ColorColumn ctermbg=23 guibg=#2c2d27
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
set laststatus=2
hi Search cterm=NONE ctermfg=grey ctermbg=blue
set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab
set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<,space:␣
noremap <F5> :set list!<CR>
inoremap <F5> <C-o>:set list!<CR>
cnoremap <F5> <C-c>:set list!<CR>
