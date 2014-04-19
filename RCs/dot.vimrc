syntax on
set ignorecase
set nowrap
set is
set hls
set noexpandtab
set noai
set ruler
set noautoindent
set backspace=2
colorscheme default
set bg=dark
map  :w!<CR>:!aspell check %<CR>:e! %<CR>
"F7 WordProcessorOn
map <F7> :set linebreak <CR> :set display+=lastline <CR> :set wrap <CR> :setlocal spell spelllang=en_gb <CR>
"F8 WordProcessorOff
map <F8> :set nowrap <CR> :set nospell <CR> 
