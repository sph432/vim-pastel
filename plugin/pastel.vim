function CursorUpdateFunction() abort
  let l:color=matchstr(expand('<cword>'), '\v#[0-9A-Fa-f]{6}')
  if empty(l:color)
    if g:pastel_win != ""
      call popup_hide(g:pastel_win)
    endif
  else
    execute 'highlight pastelColor guibg='.l:color
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

"internal
let g:pastel_win=""

"options
let g:pastel_color_size=2
let g:pastel_bg_size=1

let g:pastel_white_fill=' '
let g:pastel_white_bg='#FFFFFF'
let g:pastel_trans_fill='▞'
let g:pastel_trans_fg='#BFBFBF'
let g:pastel_trans_bg='#404040'
let g:pastel_black_fill=' '
let g:pastel_black_bg='#000000'



execute 'highlight pastelBlack guibg='.g:pastel_black_bg
call prop_type_add('pastel_b', {'highlight': 'pastelBlack'})
execute 'highlight pastelWhite guibg='.g:pastel_white_bg
call prop_type_add('pastel_w', {'highlight': 'pastelWhite'})
execute 'highlight pastelTrans guifg='.g:pastel_trans_fg.' guibg='.g:pastel_trans_bg
call prop_type_add('pastel_t', {'highlight': 'pastelTrans'})
"you should not see this, ever
highlight pastelColor guifg=#FF00FF
call prop_type_add('pastel_C', {'highlight': 'pastelColor'})

autocmd CursorMoved * call CursorUpdateFunction()
