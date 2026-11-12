if exists('g:loaded_pastel')
  finish
endif
let g:loaded_pastel=1

if !has('popupwin') || !has('textprop')
  finish
endif
if !has('gui_running') && !&termguicolors
  finish
endif

"internal
let s:pastel_win=0

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
let g:pastel_color_mode=get(g:, 'pastel_color_mode', 't')

"alternate between backgrounds every n seconds in "2" and "3" blocks
let g:pastel_color_timer=get(g:, 'pastel_color_timer', 5)

"a definition of color codes to show, from top to bottom
"  combination of the following as a string:
"  x - hexadecimal RGB
"  r - rgb  0-255
"  c - cmyk 0-255
let g:pastel_detail_mode=get(g:, 'pastel_detail_mode', 'x')

"size is measured vertically in half-chars, horizontally in chars
"6/2 is how sharkdp/pastel looks
let g:pastel_color_size=get(g:, 'pastel_color_size', 6)
let g:pastel_bg_size=get(g:, 'pastel_bg_size', 2)

"these are better left alone but you may want to change trans colors
let g:pastel_white_bg=get(g:, 'pastel_white_bg', '#FFFFFF')
let g:pastel_trans_fg=get(g:, 'pastel_trans_fg', '#BFBFBF') "75% gray
let g:pastel_trans_bg=get(g:, 'pastel_trans_bg', '#404040') "25% gray
let g:pastel_black_bg=get(g:, 'pastel_black_bg', '#000000')

if g:pastel_color_size % 2 || g:pastel_bg_size % 2
  echohl WarningMsg
  echom 'pastel: odd sizes are not yet implemented'
  echohl None
  finish
endif

function s:SetPopupContent(popup, bg)
  let bgh=g:pastel_bg_size / 2
  let bgw=g:pastel_bg_size
  let colh=g:pastel_color_size / 2
  let colw=g:pastel_color_size
  let totw=bgw*2+colw
  let blank=repeat(' ', totw)
  let bgline={'text': blank,
\             'props': [{'col': 1, 'length': totw, 'type': a:bg}]}
  let colline={'text': blank,
\              'props': [{'col': 1, 'length': bgw, 'type': a:bg},
\                        {'col': bgw+1, 'length': colw, 'type': 'pastel_C'},
\                        {'col': bgw+colw+1, 'length': bgw, 'type': a:bg}]}
  let popuptext=repeat([bgline], bgh) + repeat([colline], colh)
\              + repeat([bgline], bgh)
  call popup_settext(a:popup, popuptext)
endfunction
function s:DefineHighlights()
  execute 'highlight pastelBlack guibg='.g:pastel_black_bg
  execute 'highlight pastelWhite guibg='.g:pastel_white_bg
  execute 'highlight pastelTrans    guifg='.g:pastel_trans_fg
\         .' guibg='.g:pastel_trans_bg
  execute 'highlight pastelTransInv guifg='.g:pastel_trans_bg
\         .' guibg='.g:pastel_trans_fg
  "you should not see this, ever
  highlight pastelColor guifg=#FF00FF
endfunction

function s:SetupPopupHilightStyles()
  call s:DefineHighlights()
  call prop_type_add('pastel_b', {'highlight': 'pastelBlack'})
  call prop_type_add('pastel_w', {'highlight': 'pastelWhite'})
  call prop_type_add('pastel_t', {'highlight': 'pastelTrans'})
  call prop_type_add('pastel_T', {'highlight': 'pastelTransInv'})
  call prop_type_add('pastel_C', {'highlight': 'pastelColor'})
endfunction
"the #rrggbb code under the cursor, or ''
function s:ColorAtCursor()
  let line=getline('.')
  let col=col('.')-1
  let start=0
  while 1
    let [color, mbeg, mend]=matchstrpos(line, '\v#\x{6}\x@!', start)
    if mbeg < 0
      return ''
    endif
    if col < mbeg
      return ''
    elseif col < mend
      return color
    endif
    let start=mend
  endwhile
endfunction

function s:OnCursorMove() abort
  let color=s:ColorAtCursor()
  if empty(color)
    if s:pastel_win
      call popup_hide(s:pastel_win)
    endif
  else
    execute 'highlight pastelColor guibg='.color
    let pos={'line': 'cursor-2', 'col': 'cursor+2', 'pos': 'topleft'}
    if s:pastel_win
      call popup_show(s:pastel_win)
      call popup_move(s:pastel_win, pos)
    else
      let s:pastel_win=popup_create([], pos)
    endif
    call s:SetPopupContent(s:pastel_win, 'pastel_b')
  endif
endfunction

call s:SetupPopupHilightStyles()

augroup pastel
  autocmd!
  autocmd CursorMoved * call s:OnCursorMove()
  autocmd ColorScheme * call s:DefineHighlights()
augroup end

"vim: sw=2 ts=2 et fdm=syntax
