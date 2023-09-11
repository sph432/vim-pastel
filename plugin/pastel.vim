"#BADA55
function CursorUpdateFunction() abort
  let l:color=matchstr(expand('<cword>'), '\v#[0-9A-Fa-f]{6}')
  highlight pastelColor guifg=#FF00FF guibg=#00FF00
  if empty(l:color)
    if g:pastel_win != ""
      call popup_hide(g:pastel_win)
    endif
  else
    if g:pastel_win == ""
      let g:pastel_win=popup_create([], {'line': 'cursor-2', 'col': 'cursor+2', 'pos': 'topleft'})
    else
      call popup_show(g:pastel_win)
      call popup_move(g:pastel_win, {'line': 'cursor-2', 'col': 'cursor+2', 'pos': 'topleft'})
    endif
    call popup_settext(g:pastel_win, [
\     {'text': '           '},
\     {'text': '    ▞▞▞   ', 'props':[{'col':  2, 'text_align': 'after', 'length': 3, 'type': 'pastel_b'},
\                                    {'col':  5, 'text_align': 'after', 'length': 9, 'type': 'pastel_t'},
\                                    {'col': 14, 'text_align': 'after', 'length': 3, 'type': 'pastel_w'}]},
\     {'text': '    ▞ ▞   ', 'props':[{'col':  2, 'text_align': 'after', 'length': 1, 'type': 'pastel_b'},
\                                    {'col':  3, 'text_align': 'after', 'length': 1, 'type': 'pastel_C'},
\                                    {'col':  4, 'text_align': 'after', 'length': 1, 'type': 'pastel_b'},
\                                    {'col':  5, 'text_align': 'after', 'length': 3, 'type': 'pastel_t'},
\                                    {'col':  8, 'text_align': 'after', 'length': 1, 'type': 'pastel_C'},
\                                    {'col':  9, 'text_align': 'after', 'length': 3, 'type': 'pastel_t'},
\                                    {'col': 12, 'text_align': 'after', 'length': 1, 'type': 'pastel_w'},
\                                    {'col': 13, 'text_align': 'after', 'length': 1, 'type': 'pastel_C'},
\                                    {'col': 14, 'text_align': 'after', 'length': 1, 'type': 'pastel_w'}]},
\     {'text': '    ▞▞▞   ', 'props':[{'col':  2, 'text_align': 'after', 'length': 3, 'type': 'pastel_b'},
\                                    {'col':  5, 'text_align': 'after', 'length': 9, 'type': 'pastel_t'},
\                                    {'col': 14, 'text_align': 'after', 'length': 3, 'type': 'pastel_w'}]},
\     {'text': ''},
\     {'text': "  ".l:color},
\     {'text': ''}])
  endif
endfunc

let g:pastel_win=""
let g:pastel_scale=3

highlight pastelBlack                             guibg=#000000
call prop_type_add('pastel_b', {'highlight': 'pastelBlack'})
highlight pastelWhite                             guibg=#FFFFFF
call prop_type_add('pastel_w', {'highlight': 'pastelWhite'})
highlight pastelTrans                             guifg=#BFBFBF guibg=#404040
call prop_type_add('pastel_t', {'highlight': 'pastelTrans'})
"you should not see this
highlight pastelColor                             guifg=#FF00FF
call prop_type_add('pastel_C', {'highlight': 'pastelColor'})


autocmd CursorMoved * call CursorUpdateFunction()
