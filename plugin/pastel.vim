function SetPopupContent(popup, color)
  "g:pastel_color_size=2
  "g:pastel_bg_size=1
  "g:pastel_white_fill=' '
  "g:pastel_trans_fill='▞'
  "g:pastel_black_fill=' '
  call popup_settext(a:popup, [
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
\     {'text': "  ".a:color},
\     {'text': ''}])
endfunction

function SetupPopupHilightStyles()
  execute 'highlight pastelBlack guibg='.g:pastel_black_bg
  call prop_type_add('pastel_b', {'highlight': 'pastelBlack'})
  execute 'highlight pastelWhite guibg='.g:pastel_white_bg
  call prop_type_add('pastel_w', {'highlight': 'pastelWhite'})
  execute 'highlight pastelTrans guifg='.g:pastel_trans_fg.' guibg='.g:pastel_trans_bg
  call prop_type_add('pastel_t', {'highlight': 'pastelTrans'})
  "you should not see this, ever
  highlight pastelColor guifg=#FF00FF
  call prop_type_add('pastel_C', {'highlight': 'pastelColor'})
endfunction


function OnCursorMove() abort
  let l:color=matchstr(expand('<cword>'), '\v#[0-9A-Fa-f]{6}')
  if empty(l:color)
    if s:pastel_win != ""
      call popup_hide(s:pastel_win)
    endif
  else
    execute 'highlight pastelColor guibg='.l:color
    if s:pastel_win == ""
      let s:pastel_win=popup_create([], {'line': 'cursor-2', 'col': 'cursor+2', 'pos': 'topleft'})
    else
      call popup_show(s:pastel_win)
      call popup_move(s:pastel_win, {'line': 'cursor-2', 'col': 'cursor+2', 'pos': 'topleft'})
    endif
    call SetPopupContent(s:pastel_win, l:color)
  endif
endfunction

"internal
let s:pastel_win=""

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

call SetupPopupHilightStyles()

autocmd CursorMoved * call OnCursorMove()
