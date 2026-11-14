"tests, run from anywhere with
"  vim -Nu NONE -i NONE -es -S test/run.vim
"which prints the failures, if any, and exits with an error status on them

set termguicolors
let s:root=expand('<sfile>:p:h:h')
execute 'source' fnameescape(s:root.'/plugin/pastel.vim')
let s:sid=getscriptinfo({'name': 'plugin/pastel.vim'})[0].sid

let s:count=0
let s:failures=[]
let v:errmsg=''

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

"the color found at column a:col of a buffer holding a:text, and where; the
"buffer can have the filetype a:1 and the b:pastel_alpha_position a:2
function s:At(text, col, ...)
  enew!
  if a:0 >= 1
    let &filetype=a:1
  endif
  if a:0 >= 2
    let b:pastel_alpha_position=a:2
  endif
  call setline(1, a:text)
  call cursor(1, a:col)
  let found=s:Fn('ColorAtCursor')()
  return empty(found) ? [] : [s:Thousandths(found[0]), found[1], found[2]]
endfunction

"the default of the ignored filetypes
call s:Check('default ignored filetypes', g:pastel_ignore_filetypes, ['gitcommit', '*sql*'])

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

"where no colors are looked for: long lines and ignored filetypes
let s:long=repeat(' ', 2990).'#fff'
call s:Check('line within synmaxcol', s:At(s:long, 2992), [[255, 255, 255, 1000], 2990, 2994])
call s:Check('line beyond synmaxcol', s:At(repeat(' ', 3000).'#fff', 3002), [])
set synmaxcol=0
call s:Check('no synmaxcol', s:At(repeat(' ', 3000).'#fff', 3002), [[255, 255, 255, 1000], 3000, 3004])
set synmaxcol=10
call s:Check('small synmaxcol', s:At('          #fff', 12), [])
call s:Check('line within small synmaxcol', s:At('#fff', 2), [[255, 255, 255, 1000], 0, 4])
set synmaxcol=3000
let g:pastel_ignore_filetypes=['sql', 'gitcommit']
call s:Check('ignored filetype', s:At('#fff', 2, 'sql'), [])
call s:Check('another ignored filetype', s:At('fixes #123', 9, 'gitcommit'), [])
call s:Check('ignored compound filetype', s:At('#fff', 2, 'html.sql'), [])
call s:Check('other filetype', s:At('#fff', 2, 'css'), [[255, 255, 255, 1000], 0, 4])
call s:Check('no filetype', s:At('#fff', 2), [[255, 255, 255, 1000], 0, 4])
let g:pastel_ignore_filetypes=['*sql*', 'gitcommit']
call s:Check('glob: sql', s:At('#fff', 2, 'sql'), [])
call s:Check('glob: mysql', s:At('#fff', 2, 'mysql'), [])
call s:Check('glob: plsql', s:At('#fff', 2, 'plsql'), [])
call s:Check('glob: sqloracle', s:At('#fff', 2, 'sqloracle'), [])
call s:Check('glob: pgsql in a compound', s:At('#fff', 2, 'foo.pgsql'), [])
call s:Check('glob: gitcommit exactly', s:At('#fff', 2, 'gitcommit'), [])
call s:Check('glob: not a substring of gitcommit', s:At('#fff', 2, 'gitcommitx'), [[255, 255, 255, 1000], 0, 4])
call s:Check('glob: css', s:At('#fff', 2, 'css'), [[255, 255, 255, 1000], 0, 4])
let g:pastel_ignore_filetypes=['?ml', '[jk]*', '{c,h}pp', 'sql*']
call s:Check('glob: ?', s:At('#fff', 2, 'xml'), [])
call s:Check('glob: ? needs one character', s:At('#fff', 2, 'ml'), [[255, 255, 255, 1000], 0, 4])
call s:Check('glob: [] java', s:At('#fff', 2, 'java'), [])
call s:Check('glob: [] kotlin', s:At('#fff', 2, 'kotlin'), [])
call s:Check('glob: [] css', s:At('#fff', 2, 'css'), [[255, 255, 255, 1000], 0, 4])
call s:Check('glob: {} cpp', s:At('#fff', 2, 'cpp'), [])
call s:Check('glob: {} hpp', s:At('#fff', 2, 'hpp'), [])
call s:Check('glob: {} xpp', s:At('#fff', 2, 'xpp'), [[255, 255, 255, 1000], 0, 4])
call s:Check('glob: prefix', s:At('#fff', 2, 'sqlite'), [])
call s:Check('glob: prefix only', s:At('#fff', 2, 'mysql'), [[255, 255, 255, 1000], 0, 4])
let g:pastel_ignore_filetypes=[]
call s:Check('nothing ignored', s:At('#fff', 2, 'sql'), [[255, 255, 255, 1000], 0, 4])
call s:Check('issue number in a commit message', s:At('fixes #123', 9, 'gitcommit'), [[17, 34, 51, 1000], 6, 10])

"CSS functions, in the comma notation and the space and slash one
let s:T=function('s:Thousandths')
function s:Css(text)
  return s:T(s:Fn('ParseCss')(a:text))
endfunction
call s:Check('rgb', s:Css('rgb(255 0 0)'), [255, 0, 0, 1000])
call s:Check('rgb commas', s:Css('rgb(255, 136, 0)'), [255, 136, 0, 1000])
call s:Check('rgba', s:Css('rgba(255,0,0,0.5)'), [255, 0, 0, 500])
call s:Check('rgb with alpha', s:Css('rgb(255, 0, 0, 0.25)'), [255, 0, 0, 250])
call s:Check('rgb slash', s:Css('rgb(255 0 0 / 0.5)'), [255, 0, 0, 500])
call s:Check('rgba slash', s:Css('rgba(255 0 0/50%)'), [255, 0, 0, 500])
call s:Check('rgb percentages', s:Css('rgb(100% 50% 0%)'), [255, 128, 0, 1000])
call s:Check('rgb mixed', s:Css('rgb(100% 0 255)'), [255, 0, 255, 1000])
call s:Check('rgb clamped', s:Css('rgb(300 -5 0)'), [255, 0, 0, 1000])
call s:Check('alpha clamped', s:Css('rgb(0 0 0 / 7)'), [0, 0, 0, 1000])
call s:Check('rgb exponent', s:Css('rgb(1e2 +.5e1 0)'), [100, 5, 0, 1000])
call s:Check('rgb none', s:Css('rgb(none 128 255)'), [0, 128, 255, 1000])
call s:Check('rgb upper case', s:Css('RGB(255 0 0)'), [255, 0, 0, 1000])
call s:Check('rgb spaces', s:Css('rgb(  255   0 0  )'), [255, 0, 0, 1000])
call s:Check('rgb too few', s:Css('rgb(255 0)'), [])
call s:Check('rgb too many', s:Css('rgb(1 2 3 4)'), [])
call s:Check('rgb comma and slash', s:Css('rgb(1, 2, 3 / 0.5)'), [])
call s:Check('rgb space alpha', s:Css('rgb(1 2 3 0.5)'), [])
call s:Check('rgb empty part', s:Css('rgb(1,,3)'), [])
call s:Check('rgb none with commas', s:Css('rgb(none, 1, 2)'), [])
call s:Check('rgb word', s:Css('rgb(a b c)'), [])
call s:Check('rgb unit', s:Css('rgb(1deg 2 3)'), [])
call s:Check('rgb number dot', s:Css('rgb(5. 2 3)'), [])
call s:Check('rgb empty slash', s:Css('rgb(1 2 3 /)'), [])
call s:Check('hsl red', s:Css('hsl(0 100% 50%)'), [255, 0, 0, 1000])
call s:Check('hsl green', s:Css('hsl(120 100% 50%)'), [0, 255, 0, 1000])
call s:Check('hsl blue', s:Css('hsl(240, 100%, 50%)'), [0, 0, 255, 1000])
call s:Check('hsl yellow', s:Css('hsl(60 100% 50%)'), [255, 255, 0, 1000])
call s:Check('hsl gray', s:Css('hsl(0 0% 50%)'), [128, 128, 128, 1000])
call s:Check('hsl black', s:Css('hsl(200 50% 0%)'), [0, 0, 0, 1000])
call s:Check('hsl white', s:Css('hsl(200 50% 100%)'), [255, 255, 255, 1000])
call s:Check('hsl teal', s:Css('hsl(180deg 100% 25%)'), [0, 128, 128, 1000])
call s:Check('hsl turn', s:Css('hsl(0.5turn 100% 25%)'), [0, 128, 128, 1000])
call s:Check('hsl grad', s:Css('hsl(200grad 100% 25%)'), [0, 128, 128, 1000])
call s:Check('hsl rad', s:Css('hsl(3.14159265rad 100% 50%)'), [0, 255, 255, 1000])
call s:Check('hsl negative hue', s:Css('hsl(-120 100% 50%)'), [0, 0, 255, 1000])
call s:Check('hsl large hue', s:Css('hsl(480 100% 50%)'), [0, 255, 0, 1000])
call s:Check('hsl plain numbers', s:Css('hsl(120 100 50)'), [0, 255, 0, 1000])
call s:Check('hsl negative saturation', s:Css('hsl(0 -50% 50%)'), [128, 128, 128, 1000])
call s:Check('hsl none', s:Css('hsl(none 100% 50%)'), [255, 0, 0, 1000])
call s:Check('hsl alpha', s:Css('hsl(0 100% 50% / 50%)'), [255, 0, 0, 500])
call s:Check('hsla', s:Css('hsla(0, 100%, 50%, 0.5)'), [255, 0, 0, 500])
call s:Check('hsl bad unit', s:Css('hsl(0 100px 50%)'), [])
call s:Check('hsl percent hue', s:Css('hsl(5% 100% 50%)'), [])
call s:Check('hsl too few', s:Css('hsl(0 100%)'), [])
call s:Check('hwb red', s:Css('hwb(0 0% 0%)'), [255, 0, 0, 1000])
call s:Check('hwb green', s:Css('hwb(120 0% 0%)'), [0, 255, 0, 1000])
call s:Check('hwb white', s:Css('hwb(0 100% 0%)'), [255, 255, 255, 1000])
call s:Check('hwb black', s:Css('hwb(90 0% 100%)'), [0, 0, 0, 1000])
call s:Check('hwb gray', s:Css('hwb(0 50% 50%)'), [128, 128, 128, 1000])
call s:Check('hwb gray, over 100%', s:Css('hwb(0 60% 60%)'), [128, 128, 128, 1000])
call s:Check('hwb mixed', s:Css('hwb(210 20% 30%)'), [51, 115, 179, 1000])
call s:Check('hwb plain numbers', s:Css('hwb(120 20 30)'), [51, 179, 51, 1000])
call s:Check('hwb angle', s:Css('hwb(0.5turn 0% 0%)'), [0, 255, 255, 1000])
call s:Check('hwb alpha', s:Css('hwb(0 0% 0% / 25%)'), [255, 0, 0, 250])
call s:Check('hwba', s:Css('hwba(0 0% 0% / .5)'), [255, 0, 0, 500])
call s:Check('hwb none', s:Css('hwb(none 0% 0%)'), [255, 0, 0, 1000])
call s:Check('hwb commas', s:Css('hwb(0, 0%, 0%)'), [])
call s:Check('hwb too few', s:Css('hwb(0 0%)'), [])
call s:Check('hwb bad unit', s:Css('hwb(0 0px 0%)'), [])
call s:Check('hsv red', s:Css('hsv(0, 100%, 100%)'), [255, 0, 0, 1000])
call s:Check('hsv green', s:Css('hsv(120 100% 100%)'), [0, 255, 0, 1000])
call s:Check('hsv half value', s:Css('hsv(240, 100%, 50%)'), [0, 0, 128, 1000])
call s:Check('hsv gray', s:Css('hsv(0, 0%, 50%)'), [128, 128, 128, 1000])
call s:Check('hsv pastel', s:Css('hsv(60, 50%, 100%)'), [255, 255, 128, 1000])
call s:Check('hsv fractions', s:Css('hsv(120, 1, 0.5)'), [0, 128, 0, 1000])
call s:Check('hsv too big', s:Css('hsv(0, 100, 100)'), [255, 0, 0, 1000])
call s:Check('hsv alpha', s:Css('hsv(0 100% 100% / 50%)'), [255, 0, 0, 500])
call s:Check('hsva', s:Css('hsva(0, 100%, 100%, 0.5)'), [255, 0, 0, 500])
call s:Check('hsv too few', s:Css('hsv(0, 100%)'), [])
call s:Check('hwb and hsv at the cursor', s:At('a hwb(0 0% 0%) b hsv(0,1,1)', 20), [[255, 0, 0, 1000], 17, 27])
call s:Check('not a function', s:Css('rgbx(1 2 3)'), [])
call s:Check('at the cursor', s:At('color: rgb(255, 0, 0);', 12), [[255, 0, 0, 1000], 7, 21])
call s:Check('on the name', s:At('color: rgb(255, 0, 0);', 8), [[255, 0, 0, 1000], 7, 21])
call s:Check('on the closing parenthesis', s:At('color: rgb(255, 0, 0);', 21), [[255, 0, 0, 1000], 7, 21])
call s:Check('before the function', s:At('color: rgb(255, 0, 0);', 3), [])
call s:Check('after the function', s:At('color: rgb(255, 0, 0);', 22), [])
call s:Check('hsla at the cursor', s:At('a hsla(120,100%,50%,.5) b', 6), [[0, 255, 0, 500], 2, 23])
call s:Check('preceded by a letter', s:At('xrgb(1 2 3)', 4), [])
call s:Check('invalid function', s:At('rgb(1 2)', 4), [])
call s:Check('two on a line', s:At('rgb(1 2 3) hsl(0 0% 0%)', 15), [[0, 0, 0, 1000], 11, 23])
call s:Check('function and hex', s:At('#fff rgb(1 2 3)', 8), [[1, 2, 3, 1000], 5, 15])
call s:Check('hex before function', s:At('#fff rgb(1 2 3)', 2), [[255, 255, 255, 1000], 0, 4])

"the position of the alpha: explicit, guessed from the filetype, per buffer
let g:pastel_alpha_position='last'
call s:Check('last', s:At('#80FF0000', 1, 'kotlin'), [[128, 255, 0, 0], 0, 9])
call s:Check('explicit first', s:At('#80FF0000', 1, 'css', 'first'), [[255, 0, 0, 502], 0, 9])
let g:pastel_alpha_position='first'
call s:Check('first', s:At('#80FF0000', 1, 'css'), [[255, 0, 0, 502], 0, 9])
call s:Check('explicit last', s:At('#80FF0000', 1, 'kotlin', 'last'), [[128, 255, 0, 0], 0, 9])
call s:Check('#RGBA stays', s:At('#f808', 1), [[255, 136, 0, 533], 0, 5])
call s:Check('#RRGGBB stays', s:At('#FF8800', 1), [[255, 136, 0, 1000], 0, 7])
let g:pastel_alpha_position='auto'
call s:Check('auto, kotlin', s:At('#80FF0000', 1, 'kotlin'), [[255, 0, 0, 502], 0, 9])
call s:Check('auto, java', s:At('#80FF0000', 1, 'java'), [[255, 0, 0, 502], 0, 9])
call s:Check('auto, xml', s:At('#80FF0000', 1, 'xml'), [[128, 255, 0, 0], 0, 9])
call s:Check('auto, css', s:At('#80FF0000', 1, 'css'), [[128, 255, 0, 0], 0, 9])
call s:Check('auto, no filetype', s:At('#80FF0000', 1), [[128, 255, 0, 0], 0, 9])
call s:Check('auto, #RGBA in kotlin', s:At('#f808', 1, 'kotlin'), [[255, 136, 0, 533], 0, 5])
call s:Check('auto, #RRGGBB in kotlin', s:At('#FF8800', 1, 'kotlin'), [[255, 136, 0, 1000], 0, 7])
let g:pastel_alpha_first_filetypes=['css']
call s:Check('auto, own filetypes', s:At('#80FF0000', 1, 'css'), [[255, 0, 0, 502], 0, 9])
call s:Check('auto, compound filetype', s:At('#80FF0000', 1, 'html.css'), [[255, 0, 0, 502], 0, 9])
let g:pastel_alpha_first_filetypes=['java', 'kotlin']
call s:Check('buffer overrides auto', s:At('#80FF0000', 1, 'kotlin', 'last'), [[128, 255, 0, 0], 0, 9])

"the note about the guess: once per buffer, and only when guessing
function s:Notes(text, ...)
  call execute('messages clear')
  let found=call('s:At', [a:text, 1] + a:000)
  return len(filter(split(execute('messages'), "\n"), 'v:val =~# "assuming"'))
endfunction
let g:pastel_alpha_position='auto'
call s:Check('note, 8 digits in kotlin', s:Notes('#80FF0000', 'kotlin'), 1)
call s:Check('note, 8 digits in css', s:Notes('#80FF0000', 'css'), 1)
call s:Check('no note, 6 digits', s:Notes('#FF8800', 'kotlin'), 0)
call s:Check('no note, 3 digits', s:Notes('#f80', 'kotlin'), 0)
call s:Check('no note, set to last', s:Notes('#80FF0000', 'kotlin', 'last'), 0)
let g:pastel_alpha_position='first'
call s:Check('no note, global first', s:Notes('#80FF0000', 'css'), 0)
let g:pastel_alpha_position='auto'
enew!
call setline(1, '#80FF0000 #11223344')
call cursor(1, 1)
call execute('messages clear')
call s:Fn('ColorAtCursor')()
call cursor(1, 12)
call s:Fn('ColorAtCursor')()
call s:Check('note once per buffer', len(filter(split(execute('messages'), "\n"), 'v:val =~# "assuming"')), 1)

"blending over a background
let s:Blend=s:Fn('Blend')
call s:Check('opaque', s:Blend([255, 136, 0, 1.0], '#123456'), '#FF8800')
call s:Check('alpha 0', s:Blend([255, 0, 0, 0.0], '#123456'), '#123456')
call s:Check('half on black', s:Blend([255, 0, 0, 128/255.0], '#000000'), '#800000')
call s:Check('half on white', s:Blend([255, 0, 0, 128/255.0], '#FFFFFF'), '#FF7F7F')
call s:Check('half on dark', s:Blend([255, 0, 0, 128/255.0], '#404040'), '#A02020')
call s:Check('half on light', s:Blend([255, 0, 0, 128/255.0], '#BFBFBF'), '#DF5F5F')
call s:Check('background not a hex color', s:Blend([255, 0, 0, 0.5], 'red'), '#FF0000')

"the colors the popup really gets: they are read back from the highlight
"groups, as the text properties of the popup refer to them by name, so that eg.
"two names that Vim takes to be the same group show up as a wrong color

"the gui color of an attribute (fg# or bg#) of a highlight group, lower case,
"or '' if it has none
function s:Attr(group, what)
  return tolower(synIDattr(synIDtrans(hlID(a:group)), a:what, 'gui'))
endfunction

"show the popup for a:text, with the cursor on its first character, and
"return its pixels, a list of rows, each a list of colors: two rows per line of
"the popup, a character being one pixel wide, and either a space, which is its
"background color twice, or a half block, which is its foreground over its
"background
function s:Pixels(text)
  enew!
  let b:pastel_alpha_position='last'
  call setline(1, a:text)
  call cursor(1, 1)
  call s:Fn('OnCursorMove')()
  let buf=winbufnr(popup_list()[0])
  let rows=[]
  for lnum in range(1, line('$', popup_list()[0]))
    let text=getbufline(buf, lnum)[0]
    let upper=[]
    let lower=[]
    for prop in prop_list(lnum, {'bufnr': buf})
      let fg=s:Attr(prop.type, 'fg#')
      let bg=s:Attr(prop.type, 'bg#')
      for char in split(strpart(text, prop.col-1, prop.length), '\zs')
        call add(upper, char == ' ' ? bg : fg)
        call add(lower, bg)
      endfor
    endfor
    call extend(rows, [upper, lower])
  endfor
  return rows
endfunction

"the pixels expected for a popup of a:width by a:height pixels, with the color
"of the pixel at (x, y) given by a:Color
function s:Grid(width, height, Color)
  return map(range(a:height), {y -> map(range(a:width), {x -> a:Color(x, y)})})
endfunction

"a block of 10 by 10 pixels, 2 of margin and 6 of color, with the background of
"a:back(x, y) and the color a:front, or the pixel of another block at the end
function s:Block(x, y, back, front)
  let inside=a:x >= 2 && a:x < 8 && a:y >= 2 && a:y < 8
  return inside ? a:front : a:back
endfunction

let g:pastel_black_bg='#000000'
let g:pastel_white_bg='#FFFFFF'
let g:pastel_trans_bg='#404040'
let g:pastel_trans_fg='#BFBFBF'
let g:pastel_color_size=6
let g:pastel_bg_size=2

let g:pastel_color_mode='k'
call s:Check('pixels: opaque on black', s:Pixels('#ff8800'),
\            s:Grid(10, 10, {x, y -> s:Block(x, y, '#000000', '#ff8800')}))
let g:pastel_color_mode='w'
call s:Check('pixels: opaque on white', s:Pixels('#ff8800'),
\            s:Grid(10, 10, {x, y -> s:Block(x, y, '#ffffff', '#ff8800')}))
let g:pastel_color_mode='t'
call s:Check('pixels: opaque on checkers', s:Pixels('#ff8800'),
\            s:Grid(10, 10, {x, y -> s:Block(x, y, (x+y) % 2 ? '#404040' : '#bfbfbf', '#ff8800')}))

"half transparent, #FF000080, on each background
let g:pastel_color_mode='k'
call s:Check('pixels: alpha on black', s:Pixels('#ff000080'),
\            s:Grid(10, 10, {x, y -> s:Block(x, y, '#000000', '#800000')}))
let g:pastel_color_mode='w'
call s:Check('pixels: alpha on white', s:Pixels('#ff000080'),
\            s:Grid(10, 10, {x, y -> s:Block(x, y, '#ffffff', '#ff7f7f')}))
let g:pastel_color_mode='t'
call s:Check('pixels: alpha on checkers', s:Pixels('#ff000080'),
\            s:Grid(10, 10, {x, y -> s:Block(x, y, (x+y) % 2 ? '#404040' : '#bfbfbf',
\                                           (x+y) % 2 ? '#a02020' : '#df5f5f')}))

"two rows, the second shorter: the empty part has no color
let g:pastel_color_mode='kw|t'
function s:KwT(x, y)
  let row=a:y / 10
  let col=a:x / 10
  if row == 1 && col == 1
    return ''
  endif
  let x=a:x % 10
  let y=a:y % 10
  let back=row == 0 ? (col == 0 ? '#000000' : '#ffffff') : ((x+y) % 2 ? '#404040' : '#bfbfbf')
  return s:Block(x, y, back, '#00ff00')
endfunction
call s:Check('pixels: two rows', s:Pixels('#00ff00'), s:Grid(20, 20, function('s:KwT')))

"an odd height is padded with a row of no color
let g:pastel_color_mode='k'
let g:pastel_color_size=3
let g:pastel_bg_size=1
call s:Check('pixels: odd height', s:Pixels('#0000ff'),
\            s:Grid(5, 6, {x, y -> y == 5 ? '' : (x >= 1 && x < 4 && y >= 1 && y < 4 ? '#0000ff' : '#000000')}))
let g:pastel_color_size=6
let g:pastel_bg_size=2

"other colors of the backgrounds
let g:pastel_black_bg='#102030'
let g:pastel_color_mode='k'
call s:Check('pixels: changed background', s:Pixels('#ff8800')[0][0], '#102030')
let g:pastel_black_bg='#000000'
call s:Check('pixels: changed back', s:Pixels('#ff8800')[0][0], '#000000')

"every highlight group of the popup, for each of 2 colors: the letters stand
"for the background colors, and the digits for the color on them
let s:names={'k': '#000000', 'w': '#ffffff', 'd': '#404040', 'l': '#bfbfbf', 'n': ''}
for s:code in ['#ff8800', '#12345678']
  let g:pastel_color_mode='k'
  call s:Pixels(s:code)
  let s:shown=s:code == '#ff8800' ? {'1': '#ff8800', '2': '#ff8800', '3': '#ff8800', '4': '#ff8800'}
\                                   : {'1': '#081828', '2': '#8f9faf', '3': '#2a3a4a', '4': '#6e7e8e'}
  let s:wrong=[]
  for s:upper in keys(extend(copy(s:names), s:shown))
    for s:lower in keys(extend(copy(s:names), s:shown))
      let s:group='pastelp'.s:upper.s:lower
      let s:expectedfg=get(s:names, s:upper, get(s:shown, s:upper, ''))
      let s:expectedbg=get(s:names, s:lower, get(s:shown, s:lower, ''))
      if s:Attr(s:group, 'fg#') != s:expectedfg || s:Attr(s:group, 'bg#') != s:expectedbg
        call add(s:wrong, s:group.' is '.s:Attr(s:group, 'fg#').' on '.s:Attr(s:group, 'bg#'))
      endif
    endfor
  endfor
  call s:Check('highlight groups for '.s:code, s:wrong, [])
endfor

"invalid options: no error is raised on a cursor movement, a warning is shown
"once per value, and the default is used

"the number of warnings about options shown so far
function s:Warnings()
  return len(filter(split(execute('messages'), "\n"), 'v:val =~# "^pastel: [gb]:.* is not "'))
endfunction

"move the cursor onto the first color of a css buffer holding a:text, with the
"popup updated; returns what is raised, if anything, and the popup's position
"and size
function s:Shown(text)
  enew!
  let &filetype='css'
  call setline(1, a:text)
  call cursor(1, 2)
  let raised=''
  try
    call s:Fn('OnCursorMove')()
  catch
    let raised=v:exception
  endtry
  let pos=popup_getpos(popup_list()[0])
  return [raised, pos.col, pos.line, pos.width, pos.height]
endfunction

let g:pastel_color_mode='k'
"an 8-digit code, in a filetype, so that all options are read
let s:text=' #ff8800cc'
let s:normal=s:Shown(s:text)
call s:Check('default popup', s:normal[0], '')

"each option with its default and some invalid values
let s:options=[
\ ['color_size', 6, ['x', 0, -3, 2.5, [], '', 1001, 100000, {}]],
\ ['bg_size', 2, ['x', -1, 2.5, [], '', 1001, 100000, {}]],
\ ['offset_x', 2, ['x', 2.5, [], '', {}]],
\ ['offset_y', 0, ['x', 2.5, [], '', {}]],
\ ['color_timer', 5, ['x', [], '', {}]],
\ ['black_bg', '#000000', ['x', 123, [], '', '#12', '#GGGGGG', 'two words']],
\ ['white_bg', '#FFFFFF', ['x', 123, [], '', '#12']],
\ ['trans_fg', '#BFBFBF', ['x', 123, []]],
\ ['trans_bg', '#404040', ['x', 123, []]],
\ ['alpha_position', 'auto', ['x', 5, [], '', 'FIRST', 'middle']],
\ ['alpha_first_filetypes', ['java', 'kotlin'], ['x', 5, {}, [5], [[]], '']],
\ ['ignore_filetypes', ['gitcommit', '*sql*'], ['x', 5, {}, [5], [[]], '']],
\ ]
for [s:name, s:default, s:invalid] in s:options
  let s:variable='g:pastel_'.s:name
  for s:value in s:invalid
    let s:what=s:variable.'='.string(s:value)
    execute 'let '.s:variable.'=s:value'
    let s:before=s:Warnings()
    let s:shown=s:Shown(s:text)
    call s:Check(s:what.': raises nothing', s:shown[0], '')
    call s:Check(s:what.': one warning', s:Warnings()-s:before, 1)
    call s:Shown(s:text)
    call s:Shown(s:text)
    call s:Check(s:what.': warned once', s:Warnings()-s:before, 1)
    call s:Check(s:what.': popup as with the default', s:shown[1:], s:normal[1:])
  endfor
  execute 'let '.s:variable.'=s:default'
endfor

"valid values do not warn, and are used; a number may also be a string
let s:before=s:Warnings()
let g:pastel_color_size='1'
call s:Check('color_size as a string', s:Shown(s:text)[3:], [5, 3])
let g:pastel_color_size=6
let g:pastel_bg_size=0
call s:Check('bg_size 0', s:Shown(s:text)[3:], [6, 3])
let g:pastel_bg_size='2'
call s:Check('bg_size as a string', s:Shown(s:text)[3:], [10, 5])
let g:pastel_offset_x='3'
call s:Check('offset_x as a string', s:Shown(s:text)[1], s:normal[1]+1)
let g:pastel_offset_x=2
let g:pastel_color_timer=0.5
let g:pastel_color_timer='1.5'
let g:pastel_color_timer=-1
let g:pastel_color_timer=5
let g:pastel_black_bg='red'
call s:Shown(s:text)
let g:pastel_black_bg='NONE'
call s:Shown(s:text)
let g:pastel_black_bg='#000000'
let g:pastel_alpha_position='first'
call s:Shown(s:text)
let g:pastel_alpha_position='auto'
call s:Check('valid values do not warn', s:Warnings(), s:before)

"a bad value shown again after another bad one warns again
let g:pastel_color_size='y'
let s:before=s:Warnings()
call s:Shown(s:text)
let g:pastel_color_size='z'
call s:Shown(s:text)
call s:Check('another bad value warns again', s:Warnings()-s:before, 2)
let g:pastel_color_size=6

"the defaults are used for bad colors, which are read back from the popup
let g:pastel_black_bg='nonsense'
call s:Check('bad color: black', s:Pixels('#ff8800')[0][0], '#000000')
let g:pastel_black_bg='#000000'
let g:pastel_white_bg=[]
let g:pastel_color_mode='w'
call s:Check('bad color: white', s:Pixels('#ff8800')[0][0], '#ffffff')
let g:pastel_white_bg='#FFFFFF'
let g:pastel_color_mode='k'

"a bad position of the alpha in a buffer leaves the global one in effect, and
"a bad global one is as if unset
let g:pastel_alpha_position='last'
call s:Check('bad b:pastel_alpha_position, global last', s:At('#ff000080', 2, '', 'nonsense'), [[255, 0, 0, 502], 0, 9])
let g:pastel_alpha_position='first'
call s:Check('bad b:pastel_alpha_position, global first',
\            s:At('#80ff0000', 2, '', 'nonsense'), [[255, 0, 0, 502], 0, 9])
let g:pastel_alpha_position='nonsense'
call s:Check('bad g:pastel_alpha_position: auto', s:At('#ff000080', 2, 'css'), [[255, 0, 0, 502], 0, 9])
let g:pastel_alpha_position='auto'

"a string for a list option is not taken for a list of its characters: the
"default list stays in effect
let g:pastel_ignore_filetypes='css'
call s:Check('ignore_filetypes as a string: not ignored', s:At('#fff', 2, 'css'), [[255, 255, 255, 1000], 0, 4])
call s:Check('ignore_filetypes as a string: default used', s:At('#fff', 2, 'sql'), [])
let g:pastel_ignore_filetypes=['gitcommit', '*sql*']

"sizes too large to draw are clipped to the screen: they used to hang Vim
let g:pastel_color_size=1000
let g:pastel_bg_size=1000
let g:pastel_color_mode='kkkkkk|kkkkkk'
let s:shown=s:Shown(s:text)
let s:popup=popup_list()[0]
call s:Check('huge popup: raises nothing', s:shown[0], '')
call s:Check('huge popup: lines limited to the screen', line('$', s:popup) <= &lines, 1)
let s:widths=map(getbufline(winbufnr(s:popup), 1, '$'), 'strchars(v:val)')
call s:Check('huge popup: width limited to the screen', max(s:widths) <= &columns, 1)
let g:pastel_color_size=6
let g:pastel_bg_size=2
let g:pastel_color_mode='k'

"buffer-local options: b:pastel_<name> overrides g:pastel_<name> in its buffer
"only, an invalid one leaves the global value in effect, and the layout and the
"colors cannot be overridden, as the popup is shared by all buffers

"[raised, col, line, width, height] of the popup for a css buffer holding
"s:text, with the buffer variables of a:vars set (pastel_ prefix left out)
function s:ShownWith(vars)
  enew!
  let &filetype='css'
  for [name, value] in items(a:vars)
    let b:['pastel_'.name]=value
  endfor
  call setline(1, s:text)
  call cursor(1, 2)
  let raised=''
  try
    call s:Fn('OnCursorMove')()
  catch
    let raised=v:exception
  endtry
  let pos=popup_getpos(popup_list()[0])
  return [raised, pos.col, pos.line, pos.width, pos.height]
endfunction

let g:pastel_color_mode='k'
let s:global=s:ShownWith({})
call s:Check('local: no override, no error', s:global[0], '')
call s:Check('local: color_size', s:ShownWith({'color_size': 1})[3:], [5, 3])
call s:Check('local: color_size, then the next buffer is back', s:ShownWith({})[3:], s:global[3:])
call s:Check('local: bg_size', s:ShownWith({'bg_size': 0})[3:], [6, 3])
call s:Check('local: bg_size as a string', s:ShownWith({'bg_size': '0'})[3:], [6, 3])
call s:Check('local: offset_x', s:ShownWith({'offset_x': 4})[1], s:global[1]+2)
call s:Check('local: offset_y', s:ShownWith({'offset_y': 2})[2], s:global[2]+2)
call s:Check('local: offset_x does not leak', s:ShownWith({})[1], s:global[1])

"a global value with a different local one: the local one wins in its buffer
let g:pastel_color_size=2
call s:Check('local: color_size over a global one', s:ShownWith({'color_size': 1})[3:], [5, 3])
call s:Check('local: global one in another buffer', s:ShownWith({})[3:], [6, 3])
let g:pastel_color_size=6

"invalid local values warn once per value and leave the global one in effect
let g:pastel_bg_size=0
let s:before=s:Warnings()
call s:Check('local: invalid, global bg_size used', s:ShownWith({'bg_size': 'x'})[3:], [6, 3])
call s:Check('local: invalid warns', s:Warnings()-s:before, 1)
call s:ShownWith({'bg_size': 'x'})
call s:Check('local: invalid warns once', s:Warnings()-s:before, 1)
let g:pastel_bg_size=2
call s:Check('local: invalid, global changed', s:ShownWith({'bg_size': 'x'})[3:], [10, 5])
let s:before=s:Warnings()
call s:ShownWith({'color_size': 0})
call s:Check('local: out of range warns', s:Warnings()-s:before, 1)
call s:Check('local: the warning names the variable', len(filter(split(execute('messages'), "\n"), 'v:val =~# "^pastel: b:pastel_color_size 0 is not"')), 1)

"the filetype lists and the position of the alpha
call s:Check('local: ignore_filetypes', s:At('#fff', 2, 'css'), [[255, 255, 255, 1000], 0, 4])
function s:AtWith(text, col, ft, vars)
  enew!
  let &filetype=a:ft
  for [name, value] in items(a:vars)
    let b:['pastel_'.name]=value
  endfor
  call setline(1, a:text)
  call cursor(1, a:col)
  let found=s:Fn('ColorAtCursor')()
  return empty(found) ? [] : [s:Thousandths(found[0]), found[1], found[2]]
endfunction
call s:Check('local: ignore_filetypes ignores', s:AtWith('#fff', 2, 'css', {'ignore_filetypes': ['css']}), [])
call s:Check('local: ignore_filetypes can ignore nothing', s:AtWith('#fff', 2, 'sql', {'ignore_filetypes': []}), [[255, 255, 255, 1000], 0, 4])
call s:Check('local: ignore_filetypes does not leak', s:At('#fff', 2, 'sql'), [])
call s:Check('local: invalid ignore_filetypes', s:AtWith('#fff', 2, 'sql', {'ignore_filetypes': 'css'}), [])
let g:pastel_alpha_position='last'
call s:Check('local: alpha_first_filetypes', s:AtWith('#80ff0000', 2, 'css', {'alpha_position': 'auto', 'alpha_first_filetypes': ['css']}), [[255, 0, 0, 502], 0, 9])
call s:Check('local: alpha_position', s:AtWith('#80ff0000', 2, 'css', {'alpha_position': 'first'}), [[255, 0, 0, 502], 0, 9])
let g:pastel_alpha_position='auto'

"the timer interval: 0 turns alternating off in that buffer only
let g:pastel_color_mode='2'
let s:timers=len(timer_info())
call s:ShownWith({'color_timer': 0})
call s:Check('local: color_timer 0, no timer', len(timer_info()), s:timers)
call s:ShownWith({'color_timer': 1})
call s:Check('local: color_timer 1, a timer', len(timer_info()), s:timers+1)
call s:ShownWith({})
call s:Check('local: global color_timer, the timer stays', len(timer_info()), s:timers+1)
call s:Fn('Hide')()
call s:Check('local: timer stopped on hiding', len(timer_info()), s:timers)
let g:pastel_color_mode='k'

"the layout and the colors are not overridden, nor warned about
let s:before=s:Warnings()
let s:shown=s:ShownWith({'color_mode': 'w|w', 'black_bg': '#123456', 'white_bg': '#123456', 'trans_fg': '#123456', 'trans_bg': '#123456'})
call s:Check('local: layout not overridden', s:shown[3:], s:global[3:])
call s:Check('local: layout and colors raise nothing', s:shown[0], '')
call s:Check('local: black not overridden', s:Attr('pastelpkk', 'bg#'), '#000000')
call s:Check('local: white not overridden', s:Attr('pastelpww', 'bg#'), '#ffffff')
call s:Check('local: no warnings from them', s:Warnings(), s:before)

"placement: [start, fits] of a popup of a size on an axis, from the positions
"[first, last] of the code, an offset and the limits low..high
let s:Axis=s:Fn('Axis')
call s:Check('axis: right of the code', s:Axis(10, 16, 10, 2, 1, 80), [18, 1])
call s:Check('axis: left of the code', s:Axis(40, 46, 10, -2, 1, 80), [29, 1])
call s:Check('axis: centered', s:Axis(40, 46, 10, 0, 1, 80), [38, 1])
call s:Check('axis: below', s:Axis(5, 5, 5, 1, 1, 23), [6, 1])
call s:Check('axis: inverted, as it does not fit', s:Axis(70, 76, 10, 2, 1, 80), [59, 1])
call s:Check('axis: moved in below the low limit', s:Axis(2, 2, 5, 0, 2, 23), [2, 0])
call s:Check('axis: moved in above the high limit', s:Axis(22, 22, 5, 0, 1, 22), [18, 0])
call s:Check('axis: low limit respected when inverting', s:Axis(3, 3, 5, 2, 2, 5), [2, 0])
call s:Check('axis: above the low limit, so inverted', s:Axis(4, 4, 3, -1, 2, 10), [5, 1])

"the screen columns of a code, in left-to-right and right-to-left windows
let s:Columns=s:Fn('CodeColumns')
call s:Check('columns: cursor on the first character', s:Columns(20, 0, 7, 0), [20, 26])
call s:Check('columns: cursor inside', s:Columns(20, 3, 7, 0), [17, 23])
call s:Check('columns: right-to-left, on the first character', s:Columns(72, 0, 7, 1), [66, 72])
call s:Check('columns: right-to-left, inside', s:Columns(72, 2, 7, 1), [68, 74])

"the screen lines the popup may cover: not the tabline, the status line of the
"last window nor the command line
silent! only!
let s:Rows=s:Fn('Rows')
let s:base=&lines-&cmdheight
set showtabline=0 laststatus=0
call s:Check('rows: nothing in the way', s:Rows(), [1, s:base])
set showtabline=2
call s:Check('rows: tabline always shown', s:Rows(), [2, s:base])
set showtabline=1
call s:Check('rows: tabline only with several tab pages, one', s:Rows(), [1, s:base])
tabnew
call s:Check('rows: tabline with two tab pages', s:Rows(), [2, s:base])
tabclose
set laststatus=2
call s:Check('rows: status line always shown', s:Rows(), [1, s:base-1])
set laststatus=1
call s:Check('rows: status line only with several windows, one', s:Rows(), [1, s:base])
split
call s:Check('rows: status line with two windows', s:Rows(), [1, s:base-1])
close
set laststatus=3
call s:Check('rows: global status line', s:Rows(), [1, s:base-1])
set showtabline=1 laststatus=1

"nothing is looked for in a closed fold, where the code is not displayed
enew!
call setline(1, ['a', 'foo #fff', 'c', 'd'])
setlocal foldmethod=manual
2,3fold
call cursor(2, 6)
call s:Check('closed fold: no color', s:Fn('ColorAtCursor')(), [])
normal! zo
call s:Check('open fold: a color', len(s:Fn('ColorAtCursor')()), 3)

"folds are closed and opened without the cursor moving: the popup follows when
"Vim is idle
let g:pastel_color_mode='k'
call s:Fn('OnCursorMove')()
let s:popup=popup_list()[0]
call s:Check('fold: popup shown on the code', popup_getpos(s:popup).visible, 1)
normal! zc
call s:Fn('OnSafeState')()
call s:Check('fold closed: popup hidden', popup_getpos(s:popup).visible, 0)
call s:Fn('OnSafeState')()
call s:Check('fold still closed: popup still hidden', popup_getpos(s:popup).visible, 0)
normal! zo
call s:Fn('OnSafeState')()
call s:Check('fold opened: popup shown', popup_getpos(s:popup).visible, 1)

"concealed text on the line makes the screen column wrong until the redraw, so
"the popup is placed once more then, with one timer however often it moves
setlocal foldmethod=manual
let s:timers=len(timer_info())
setlocal conceallevel=0
call s:Fn('OnCursorMove')()
call s:Check('no concealing: no timer', len(timer_info()), s:timers)
setlocal conceallevel=2
call s:Fn('OnCursorMove')()
call s:Fn('OnCursorMove')()
call s:Check('concealing: one timer', len(timer_info()), s:timers+1)
sleep 100m
call s:Check('concealing: the timer is done', len(timer_info()), s:timers)
call s:Check('concealing: the popup is still shown', popup_getpos(s:popup).visible, 1)
setlocal conceallevel=0

"print the results, which :print does to the standard output in Ex mode
function s:Report(lines)
  enew!
  call setline(1, a:lines)
  %print
endfunction

if !empty(v:errmsg)
  call add(s:failures, 'Vim reported an error: '.v:errmsg)
endif
if empty(s:failures)
  call s:Report([s:count.' tests passed'])
  qall!
endif
call s:Report(s:failures + [len(s:failures).' of '.s:count.' tests failed'])
cquit 1
