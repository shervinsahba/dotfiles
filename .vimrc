" @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
" vim-plug (https://github.com/junegunn/vim-plug)
call plug#begin('~/.vim/plugged')

Plug 'https://github.com/sainnhe/forest-night'
Plug 'https://github.com/SirVer/ultisnips'
Plug 'https://github.com/honza/vim-snippets'
Plug 'https://github.com/junegunn/vim-easy-align'
Plug 'https://github.com/rdnetto/YCM-Generator', { 'branch': 'stable' }
Plug 'https://github.com/scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'https://github.com/Xuyuanp/nerdtree-git-plugin'
Plug 'https://github.com/tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'https://github.com/junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'https://github.com/ryanoasis/vim-devicons'

call plug#end()

" call vim-devicons last above and set
set encoding=UTF-8


" @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
" @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
" lightline config
" NERDTree settings

" open with Ctrl+n
map <C-n> :NERDTreeToggle<CR>

" autostart NERDTree if no files specified in vim
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | exe 'NERDTree' | endif

" autoclose vim if the only window left open is NERDTree
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" If more than one window and previous buffer was NERDTree, go back to it.
autocmd BufEnter * if bufname('#') =~# "^NERD_tree_" && winnr('$') > 1 | b# | endif

" avoid crashes with vim-plug
let g:plug_window = 'noautocmd vertical topleft new'

"Switch between different windows by their direction`
no <C-j> <C-w>j| "switching to below window
no <C-k> <C-w>k| "switching to above window
no <C-l> <C-w>l| "switching to right window
no <C-h> <C-w>h| "switching to left window



" @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
" vim builtin config
syntax enable
"set termguicolors
set showtabline=2
set laststatus=2
set number
set noshowmode
"set runtimepath+=~/.vim_runtime
set tabstop=4
set softtabstop=0 noexpandtab
set shiftwidth=4

" @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
" vim builtin config
colorscheme forest-night


" @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
" lightline config
let g:lightline = {
    \ 'colorscheme': 'forest_night',
    \ 'active': {
    \ 'left': [ ['mode'], ['filename'] ],
    \ 'right': [ ['filetype'] ]},
    \ 'inactive': {
    \ 'left': [ ['filename'] ],
    \ 'right': [] }
    \ }
let g:lightline.tab = {
 \ 'active' : [ 'filename', 'modified' ],
 \ 'inactive' : [ 'filename', 'modified' ] }





"try
"source ~/.vim_runtime/my_configs.vim
"source ~/.vim_runtime/vimrcs/basic.vim
"source ~/.vim_runtime/vimrcs/filetypes.vim
"source ~/.vim_runtime/vimrcs/plugins_config.vim
"source ~/.vim_runtime/vimrcs/extended.vim
"catch
"endtry

" Mouse functionality for vim in Alacritty. Fixed in neovim
"ttymouse=sgr
