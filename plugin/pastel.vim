function SetPopupContent(popup, bg)
  const BLOCK_WIDTH=3 "a single ▀ or ▄ takes up 3 bytes in UTF-8
  if g:pastel_color_size % 2
    if g:pastel_bg_size % 2
      "IMPLEMENT
      echom "odd sizes are not yet implemented"
    else
      "IMPLEMENT
      echom "odd sizes are not yet implemented"
    endif
  else
    if g:pastel_bg_size % 2
      "IMPLEMENT
      echom "odd sizes are not yet implemented"
    else
      let bgh=g:pastel_bg_size / 2
      let bgw=g:pastel_bg_size
      let colh=g:pastel_color_size / 2
      let colw=g:pastel_color_size
      echom 'bgh'.bgh.'bgw'.bgw.'colh'.colh.'colw'.colw
      let toth=bgh+colh
      let totw=bgw*2+colw
      let popuptext = []
      for i in range(1,bgh) "top bg rows
        let linetext=""
        for j in range (1,totw)
          let linetext=linetext." "
        endfor
        let line={'text': linetext, 'props': [{'col': 1, 'length': totw, 'type': a:bg}]}
        call add(popuptext, line)
      endfor
      for i in range(1,colh) "color block
        let linetext=""
        for j in range (1,totw)
          let linetext=linetext." "
        endfor
        let line={'text': linetext, 'props': [{'col': 1, 'length': bgw, 'type': a:bg},
\                                             {'col': bgw+1, 'length': colw, 'type': 'pastel_C'},
\                                             {'col': bgw+colw+1, 'length': bgw, 'type': a:bg}]}
        call add(popuptext, line)
      endfor
      for i in range(1,bgh) "bottom bg rows
        let linetext=""
        for j in range (1,totw)
          let linetext=linetext." "
        endfor
        let line={'text': linetext, 'props': [{'col': 1, 'length': totw, 'type': a:bg}]}
        call add(popuptext, line)
      endfor
    endif
  endif
  call popup_settext(a:popup, popuptext)
endfunction
function SetupPopupHilightStyles()
  execute 'highlight pastelBlack guibg='.g:pastel_black_bg
  call prop_type_add('pastel_b', {'highlight': 'pastelBlack'})
  execute 'highlight pastelWhite guibg='.g:pastel_white_bg
  call prop_type_add('pastel_w', {'highlight': 'pastelWhite'})
  execute 'highlight pastelTrans    guifg='.g:pastel_trans_fg.' guibg='.g:pastel_trans_bg
  execute 'highlight pastelTransInv guifg='.g:pastel_trans_bg.' guibg='.g:pastel_trans_fg
  call prop_type_add('pastel_t', {'highlight': 'pastelTrans'})
  call prop_type_add('pastel_T', {'highlight': 'pastelTransInv'})
  highlight pastelDebug1    guifg=#FF0000 guibg=#00FFFF
  highlight pastelDebug2    guifg=#00FF00 guibg=#FF00FF
  highlight pastelDebug3    guifg=#0000FF guibg=#FFFF00
  call prop_type_add('pastel_1', {'highlight': 'pastelDebug1'})
  call prop_type_add('pastel_2', {'highlight': 'pastelDebug2'})
  call prop_type_add('pastel_3', {'highlight': 'pastelDebug3'})
  "you should not see this, ever
  highlight pastelColor guifg=#FF00FF
  call prop_type_add('pastel_C', {'highlight': 'pastelColor'})
endfunction
function OnCursorMove() abort
  let color=matchstr(expand('<cword>'), '\v#[0-9A-Fa-f]{6}')
  if empty(color)
    if s:pastel_win != ""
      call popup_hide(s:pastel_win)
    endif
  else
    execute 'highlight pastelColor guibg='.color
    if s:pastel_win == ""
      let s:pastel_win=popup_create([], {'line': 'cursor-2', 'col': 'cursor+2', 'pos': 'topleft'})
    else
      call popup_show(s:pastel_win)
      call popup_move(s:pastel_win, {'line': 'cursor-2', 'col': 'cursor+2', 'pos': 'topleft'})
    endif
    call SetPopupContent(s:pastel_win, 'pastel_b')
  endif
endfunction

"internal
let s:pastel_win=""

"options
"a definition of color blocks to show, from left to right
"  combination of the following as a string:
"  w - color on white background
"  b - color on black background
"  t - color on checkered "transparent" background
"  2 - b and w alternating
"  3 - b, t and w alternating (in that order)
"  | - put blocks right of it in a new line
"
"blocks are of the same size (see below)
" default is "btw", sharkdp/pastel's look would be "t",
" other suggested combinations are "2t" "2|t" and "3"
let g:pastel_color_mode="t"

"alternate between backgrounds every n seconds in "2" and "3" blocks
let g:pastel_color_timer=5

"a definition of color codes to show, from top to bottom
"  combination of the following as a string:
"  x - hexadecimal RGB
"  r - rgb  0-255
"  c - cmyk 0-255
"
"blocks are of the same size (see below)
" default is "btw", sharkdp/pastel's look would be "t",
" other suggested combinations are "2t" "2|t" and "3"
let g:pastel_detail_mode="x"

"size is measured vertically in half-chars, horizontally in chars
"6/2 is how sharkdp/pastel looks
let g:pastel_color_size=6
let g:pastel_bg_size=2

"these are better left alone but you may want to change trans colors
let g:pastel_white_bg='#FFFFFF'
let g:pastel_trans_fg='#BFBFBF' "75% gray
let g:pastel_trans_bg='#404040' "25% gray
let g:pastel_black_bg='#000000'

call SetupPopupHilightStyles()

autocmd CursorMoved * call OnCursorMove()

"vim: sw=2 ts=2 et fdm=syntax
