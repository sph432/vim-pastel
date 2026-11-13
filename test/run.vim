"tests, run from anywhere with
"  vim -Nu NONE -i NONE -es -S test/run.vim
"which prints the failures, if any, and exits with an error status on them

set termguicolors
let s:root=expand('<sfile>:p:h:h')
execute 'source' fnameescape(s:root.'/plugin/pastel.vim')
let s:sid=getscriptinfo({'name': 'plugin/pastel.vim'})[0].sid

let s:count=0
let s:failures=[]

"the plugin's script-local function a:name
function s:Fn(name)
  return function('<SNR>'.s:sid.'_'.a:name)
endfunction

function s:Check(what, actual, expected)
  let s:count+=1
  if a:actual !=# a:expected
    call add(s:failures, a:what.': got '.string(a:actual)
\                        .', expected '.string(a:expected))
  endif
endfunction

"a color with its alpha in thousandths, to compare without rounding errors
function s:Thousandths(color)
  return empty(a:color) ? [] : a:color[:2] + [float2nr(round(a:color[3]*1000))]
endfunction

"the color found at column a:col of a buffer holding a:text, and where
function s:At(text, col)
  enew!
  call setline(1, a:text)
  call cursor(1, a:col)
  let found=s:Fn('ColorAtCursor')()
  return empty(found) ? [] : [s:Thousandths(found[0]), found[1], found[2]]
endfunction

"hexadecimal codes
call s:Check('#RRGGBB', s:At('x #FF8800 y', 4), [[255, 136, 0, 1000], 2, 9])
call s:Check('#RRGGBB lower case', s:At('#ff8800', 1), [[255, 136, 0, 1000], 0, 7])
call s:Check('#RRGGBBAA', s:At('x #FF000080 y', 4), [[255, 0, 0, 502], 2, 11])
call s:Check('#RRGGBBAA opaque', s:At('#12345678', 1), [[18, 52, 86, 471], 0, 9])
call s:Check('on the last digit', s:At('#FF8800', 7), [[255, 136, 0, 1000], 0, 7])
call s:Check('before the code', s:At('x #FF8800', 2), [])
call s:Check('after the code', s:At('#FF8800 x', 9), [])
call s:Check('7 digits', s:At('#FF88000', 1), [])
call s:Check('10 digits', s:At('#FF000080FF', 1), [])
call s:Check('5 digits', s:At('#abcde', 1), [])
call s:Check('#RGB', s:At('color: #f80;', 10), [[255, 136, 0, 1000], 7, 11])
call s:Check('#RGBA', s:At('#f808', 1), [[255, 136, 0, 533], 0, 5])
call s:Check('in parentheses', s:At('(#fff)', 3), [[255, 255, 255, 1000], 1, 5])
call s:Check('next to punctuation', s:At('a:#0a0,', 4), [[0, 170, 0, 1000], 2, 6])
call s:Check('#define', s:At('#define X', 2), [])
call s:Check('followed by a letter', s:At('#abcdefg1', 1), [])
call s:Check('followed by an underscore', s:At('#fff_x', 1), [])
call s:Check('preceded by a letter', s:At('a#fff', 3), [])
call s:Check('preceded by a digit', s:At('1#fff', 3), [])
call s:Check('second code', s:At('#111111 #222222', 12), [[34, 34, 34, 1000], 8, 15])

"blending over a background
let s:Blend=s:Fn('Blend')
call s:Check('opaque', s:Blend([255, 136, 0, 1.0], '#123456'), '#FF8800')
call s:Check('alpha 0', s:Blend([255, 0, 0, 0.0], '#123456'), '#123456')
call s:Check('half on black', s:Blend([255, 0, 0, 128/255.0], '#000000'), '#800000')
call s:Check('half on white', s:Blend([255, 0, 0, 128/255.0], '#FFFFFF'), '#FF7F7F')
call s:Check('half on dark', s:Blend([255, 0, 0, 128/255.0], '#404040'), '#A02020')
call s:Check('half on light', s:Blend([255, 0, 0, 128/255.0], '#BFBFBF'), '#DF5F5F')
call s:Check('background not a hex color', s:Blend([255, 0, 0, 0.5], 'red'), '#FF0000')

"print the results, which :print does to the standard output in Ex mode
function s:Report(lines)
  enew!
  call setline(1, a:lines)
  %print
endfunction

if empty(s:failures)
  call s:Report([s:count.' tests passed'])
  qall!
endif
call s:Report(s:failures + [len(s:failures).' of '.s:count.' tests failed'])
cquit 1
