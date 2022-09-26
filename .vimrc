set clipboard=unnamedplus  " clipboard set to system clipboard
set belloff=all            " no pc speaker bell

"" file settings
set encoding=utf-8     " encoding used for displaying file
set fileencoding=utf-8 " encoding used when saving file
filetype on            " enable file type detection
filetype plugin on     " load the plugins for specific file types

"" ui settings
set mouse=nic      " mouse aware (n)ormal, (v)isual, (i)nsert, (c)ommand line, (a)lla
set whichwrap+=<,>,h,l,[,]  " wrap cursor left and right
set ruler          " show the cursor position all the time
set showmatch      " highlight matching braces
set showmode       " show insert/replace/visual mode
set number         " show line numbers
"set textwidth=120  " wrap lines at given column

set laststatus=2
set noexpandtab   " don't expand tab with spaces
set tabstop=4     " tab length 4 spaces
set shiftwidth=4  " indent to 4 spacesa
set softtabstop=4 " backspace over 4 spaces like a tab

"" search settings
set hlsearch      " highlight search results
set ignorecase    " ignore search case...
set smartcase     " ...unless caps used
set incsearch     " incremental search
noremap n nzz     " center view on the search result
noremap N Nzz     " center view on the search result

"" theming
try
   " colorscheme wal
   "" dracula theme. see https://draculatheme.com/vim
	packadd! dracula
	colorscheme dracula
catch
    colorscheme desert
endtry
set background=dark
syntax enable  " syntax highlighting

"" transparent background
hi Normal guibg=NONE ctermbg=NONE 

"" clear screen of highlighting
noremap <silent> <C-L> <C-L>:nohlsearch<CR>:match<CR>:diffupdate<CR>
