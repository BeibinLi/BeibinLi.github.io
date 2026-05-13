" My gist page for this configuration file is at:
" https://gist.github.com/BeibinLi/1407e6507a185410b909

scriptencoding utf-8
set encoding=utf-8

" ================ Plugin Manager: vim-plug ========================
" Bootstrap: setup.sh fetches ~/.vim/autoload/plug.vim. Manual install:
"   curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
"     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

call plug#begin('~/.vim/plugged')

" --- UI / display ---
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'sickill/vim-monokai'
Plug 'nathanaelkane/vim-indent-guides'

" --- File / fuzzy / git ---
Plug 'scrooloose/nerdtree'                              " :NERDTree
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'                                 " :Files :Rg :Buffers
Plug 'tpope/vim-fugitive'                               " :Git
Plug 'christoomey/vim-tmux-navigator'

" --- Lint / language ---
Plug 'dense-analysis/ale'                               " async lint (replaces syntastic)
Plug 'pangloss/vim-javascript'
Plug 'tpope/vim-rails'
Plug 'BeibinLi/vim-sce-syntax'

call plug#end()


" ================ ALE (lint) ========================
nmap <F3> :ALEToggle<CR>
let g:ale_linters = { 'python': ['flake8'] }
let g:ale_python_flake8_options = '--max-line-length=120 --ignore=E501,W503'
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 1
let g:ale_lint_on_save = 1


" ================ Vim defaults ========================
set nocompatible
filetype plugin indent on
syntax on

set modelines=0           " CVE-2007-2438
set number
set hidden                " allow :argdo / :bufdo across modified buffers
set autoread              " auto-reload externally-modified files

" Don't write backup file if vim is called by crontab / chpass
au BufWrite /private/tmp/crontab.* set nowritebackup
au BufWrite /private/etc/pw.*      set nowritebackup


" ================ Syntax and Color ========================
silent! colorscheme monokai


" ================ Tab and Space ========================
set listchars=tab:>\ ,eol:¬
set list
set tabstop=2
set softtabstop=2
set shiftwidth=0          " use shiftwidth=tabstop
set backspace=2
set expandtab
set smarttab
autocmd FileType python setlocal ts=2 sw=2 expandtab


" ================ Cursor / ruler ========================
set cursorline
highlight CursorLine guibg=#303030
set ruler
set nosplitright          " split on the left
set colorcolumn=100


" ================ Scrolling ========================
set scrolloff=8
set sidescrolloff=15
set sidescroll=1


" ================ Searching ========================
set hlsearch
set incsearch
set ignorecase
set smartcase


" ================ Key maps ========================
" Ctrl-J to break one line
nnoremap <NL> i<CR><ESC>

" F2 to open .vimrc
map <F2> :e ~/.vimrc<CR>

" F5 to run current file
au FileType python   map <F5> <esc>:w\|!python %<CR><esc>
au FileType perl     map <F5> <esc>:w\|!perl %<CR><esc>
au FileType tex      map <F5> <esc>:w\|!pdflatex %<CR><esc>
au FileType cpp      map <F5> <esc>:w\|!make %<CR><esc>
au FileType sml      map <F5> <esc>:w\|!sml %<CR><esc>
au FileType markdown map <F5> <esc>:w\|!pandoc % -s -o %:r.html<CR><esc>
au FileType markdown map <F6> <esc>:w\|!pandoc % -s -o %:r.pdf<CR><esc>
au FileType sh       nnoremap <buffer> <F5> :exec '!bash %'<cr><esc>

" fzf bindings
nnoremap <C-p> :Files<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>g :Rg<CR>


" ================ Markdown / LaTeX ========================
autocmd BufNewFile,BufRead *.md,*.rmd,*.txt set filetype=markdown
au BufRead,BufNewFile *.txt,*.tex,*.md,*.rmd set wrap linebreak nolist textwidth=0 wrapmargin=0 spell
au FileType markdown,tex set colorcolumn=0


" ================ Command-line completion ========================
set wildmenu
set wildmode=full


" ================ File jumping ========================
set suffixesadd+=.py,.cpp,.h
set path=.,,,**


" ================ Encoding ========================
set termencoding=utf-8
set fileencoding=utf-8
set ff=unix
if has("gui_running")
    set guifont=Consolas:h12
endif


" ================ Omni completion ========================
set omnifunc=syntaxcomplete#Complete
