let s:jobs = {}

function! run#run(...) abort
  if !has('nvim')
    echom 'vim-run: neovim is currently required for this plugin'
    return
  endif

  let l:args = join(a:000)
  let l:cmd = run#cmd#GenCmd(l:args)
  if l:cmd ==# ''
    return
  endif

  let l:last_winid = win_getid()

  let l:job = s:find_job(l:cmd)
  if !empty(l:job)
    let l:id = s:rerun(l:job)

    if l:id !=# ''
      call win_gotoid(l:last_winid)
      return l:id
    endif
  endif

  call s:split()

  let l:job = {
        \ 'cmd': l:cmd,
        \ 'bufnr': bufnr(),
        \ 'done': v:false,
        \
        \ 'stderr': [],
        \ 'stdout': [],
        \
        \ 'on_stdout': function('s:on_stdout'),
        \ 'on_stderr': function('s:on_stderr'),
        \ 'on_exit': function('s:on_exit'),
        \ }

  let l:id = termopen(l:cmd, l:job)

  let l:job.id = l:id
  let s:jobs[l:id] = l:job

  call win_gotoid(l:last_winid)
  return l:id
endfunction


function! s:find_job(cmd) abort
  if empty(s:jobs)
    return {}
  endif

  for [l:id, l:job] in items(s:jobs)
    if !bufexists(l:job.bufnr)
      unlet s:jobs[l:id]
      continue
    endif
    if l:job.cmd ==# a:cmd
      return l:job
    endif
  endfor

  return {}
endfunction


function! s:rerun(job) abort
  unlet s:jobs[a:job.id]

  if !a:job.done
    silent! call jobstop(a.job.id)
  endif

  let l:buf = getbufinfo(a:job.bufnr)
  if !empty(l:buf) && !empty(l:buf[0].windows)
    call win_gotoid(l:buf[0].windows[0])
    enew
    call s:buf_init()
    execute 'silent! bdelete! ' . a:job.bufnr
  else
    call s:split()
  endif

  let l:id = termopen(a:job.cmd, a:job)

  let a:job.id = l:id
  let a:job.bufnr = bufnr()
  let a:job.done = v:false
  let a:job.stderr = []
  let a:job.stdout = []

  let s:jobs[l:id] = a:job
  return l:id
endfunction


function! s:split() abort
  if exists('g:run_split')
    let l:direction = g:run_split
  else
    let l:direction = 'down'
  endif
  if exists('g:run_split_lines')
    let l:lines = g:run_split_lines
  else
    let l:lines = 10
  endif

  let l:directions = {
        \ 'up':    'topleft ' . l:lines . 'split',
        \ 'down':  'botright ' . l:lines . 'split',
        \ 'right': 'botright ' . l:lines . 'vsplit',
        \ 'left':  'topleft ' . l:lines . 'vsplit',
        \ }

  if has_key(l:directions, l:direction)
    execute l:directions[l:direction] . ' Run'
  endif

  call s:buf_init()
endfunction


function! s:buf_init() abort
  setlocal nobuflisted
  setlocal bufhidden=wipe
  setlocal noswapfile
  set filetype=Run
endfunction


function! s:on_stdout(job_id, data, ...) abort
  if !has_key(s:jobs, a:job_id)
    return
  endif
  let l:job = s:jobs[a:job_id]

  call extend(l:job.stdout, a:data)
endfunction


function! s:on_stderr(job_id, data, ...) abort
  if !has_key(s:jobs, a:job_id)
    return
  endif
  let l:job = s:jobs[a:job_id]

  call extend(l:job.stderr, a:data)
endfunction


function! s:on_exit(job_id, data, ...) abort
  if !has_key(s:jobs, a:job_id)
    return
  endif
  if !exists('g:run_auto_close')
    let g:run_auto_close = 0
  endif
  if g:run_auto_close == 1 && bufnr('') == bufnr('%')
    close
  endif
  let s:jobs[a:job_id].done = v:true
  " unlet s:jobs[a:job_id]
endfunction


function! run#killAll() abort
  if empty(s:jobs)
    return
  endif

  for l:id in keys(s:jobs)
    if l:id > 0
      silent! call jobstop(l:id)
    endif
  endfor

  " let s:jobs = {}
endfunction


function! run#list() abort
  for [l:id, l:job] in items(s:jobs)
    if l:job.done && !bufexists(l:job.bufnr)
      unlet s:jobs[l:id]
      continue
    endif
    echo '[id=' . l:id . ' bufnr=' . l:job.bufnr . '] ' . l:job.cmd
  endfor
endfunction
