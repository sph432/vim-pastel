function CursorUpdateFunction() abort
  let l:color=matchstr(expand('<cword>'), '\v#[0-9A-Fa-f]{6}')
  if !empty(l:color)
    if g:pastel_win==""
      let g:pastel_win=popup_create([{'text': l:color, 'props': {}}], {'line': 'cursor-2', 'col': 'cursor+2', 'pos': 'topleft'})
    else
      call popup_move(g:pastel_win, {'line': 'cursor-2', 'col': 'cursor+2', 'pos': 'topleft'})
    endif
  endif
endfunc

let g:pastel_win=""

autocmd CursorMoved * call CursorUpdateFunction()
