command! -nargs=* Run call run#run(<q-args>)
command! RunKillAll call run#killAll()

nnoremap <silent> <F5> :Run<CR>
inoremap <silent> <F5> <C-o>:Run<CR>
vnoremap <silent> <F5> :<C-u>Run<CR>
