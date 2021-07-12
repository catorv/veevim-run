let s:jobs = {}

function! run#Run(...) abort
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

  call s:split()

  let l:job = {
        \ 'stderr' : [],
        \ 'stdout' : [],
        \ 'on_stdout': function('s:on_stdout'),
        \ 'on_stderr': function('s:on_stderr'),
        \ 'on_exit' : function('s:on_exit'),
        \ }

  let l:id = termopen(l:cmd, l:job)

  let l:job.id = l:id
  let l:job.bufnr = bufnr()
  let l:job.cmd = l:cmd

  let s:jobs[l:id] = l:job

  call win_gotoid(l:last_winid)
  return l:id
endfunction

function! s:split() abort
  if exists('g:run_split')
    let l:direction = g:run_split
  else
    let l:direction = 'down'
  endif
  if exists('g:run_split_lines')

    let l:directions = {
          \ 'up':    'topleft split',
          \ 'down':  'botright split',
          \ 'right': 'botright vsplit',
          \ 'left':  'topleft vsplit',
          \ }

    if has_key(l:directions, l:direction)
      execute l:directions[l:direction] . ' Run'
    endif

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
    unlet s:jobs[a:job_id]
  endfunction

  function! s:find_job_by_cmd(cmd) abort
    if empty(s:jobs)
      return ''
    endif

    for l:id in keys(s:jobs)
      let l:job = s:jobs[l:id]
      if l:job.cmd ==# a:cmd
        return l:job
      endif
    endfor
    return ''
  endfunction

  function! run#KillAll() abort
    if empty(s:jobs)
      return
    endif

    for l:id in keys(s:jobs)
      if l:id > 0
        silent! call jobstop(l:id)
      endif
    endfor

    let s:jobs = {}
  endfunction
