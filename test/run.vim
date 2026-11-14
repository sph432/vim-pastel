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
  return len(filter(split(execute('messages'), "\n"), 'v:val =~# "^pastel: [gb]:pastel_"'))
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
call s:Check('local: the warning names the variable',
\            len(filter(split(execute('messages'), "\n"), 'v:val =~# "^pastel: b:pastel_color_size 0 is not"')), 1)

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
call s:Check('local: ignore_filetypes can ignore nothing',
\            s:AtWith('#fff', 2, 'sql', {'ignore_filetypes': []}), [[255, 255, 255, 1000], 0, 4])
call s:Check('local: ignore_filetypes does not leak', s:At('#fff', 2, 'sql'), [])
call s:Check('local: invalid ignore_filetypes', s:AtWith('#fff', 2, 'sql', {'ignore_filetypes': 'css'}), [])
let g:pastel_alpha_position='last'
call s:Check('local: alpha_first_filetypes',
\            s:AtWith('#80ff0000', 2, 'css', {'alpha_position': 'auto', 'alpha_first_filetypes': ['css']}),
\            [[255, 0, 0, 502], 0, 9])
call s:Check('local: alpha_position',
\            s:AtWith('#80ff0000', 2, 'css', {'alpha_position': 'first'}), [[255, 0, 0, 502], 0, 9])
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
let s:shown=s:ShownWith({'color_mode': 'w|w', 'black_bg': '#123456', 'white_bg': '#123456',
\                        'trans_fg': '#123456', 'trans_bg': '#123456'})
call s:Check('local: layout not overridden', s:shown[3:], s:global[3:])
call s:Check('local: layout and colors raise nothing', s:shown[0], '')
call s:Check('local: black not overridden', s:Attr('pastelpkk', 'bg#'), '#000000')
call s:Check('local: white not overridden', s:Attr('pastelpww', 'bg#'), '#ffffff')
call s:Check('local: no warnings from them', s:Warnings(), s:before)

"templates: a:template expanded for a color, with the segments of a line joined
"by ~, as a list of lines
function s:Ex(template, color, ...)
  let text=a:0 >= 1 ? a:1 : ''
  let lines=s:Fn('Expand')(a:template, a:color, text, a:0 >= 2 ? a:2 : 1)
  return map(lines, 'join(map(copy(v:val), "v:val.t"), "~")')
endfunction
let s:dark=[127, 0, 0, 1.0]
let s:rgb=[255, 136, 0, 1.0]
let s:half=[255, 136, 0, 0.8]
call s:Check('template: text', s:Ex('abc', s:dark), ['abc'])
call s:Check('template: empty', s:Ex('', s:dark), [''])
call s:Check('template: literal percent', s:Ex('100%%', s:dark), ['100%'])
call s:Check('template: channels', s:Ex('%r %g %b', s:rgb), ['255 136 0'])
call s:Check('template: braced channel', s:Ex('%{r}', s:rgb), ['255'])
call s:Check('template: percent', s:Ex('%r:p', s:dark), ['50%'])
call s:Check('template: percent number', s:Ex('%r:P', s:dark), ['50'])
call s:Check('template: fraction', s:Ex('%r:f', s:dark), ['0.5'])
call s:Check('template: hex', s:Ex('%r:x', s:dark), ['7f'])
call s:Check('template: hex upper case', s:Ex('%r:X', s:dark), ['7F'])
call s:Check('template: hex pads', s:Ex('%g:x', s:dark), ['00'])
call s:Check('template: precision', s:Ex('%r:p:.1', s:dark), ['49.8%'])
call s:Check('template: precision of a fraction', s:Ex('%{r:f:.3}', s:dark), ['0.498'])
call s:Check('template: precision keeps zeros', s:Ex('%{a:.3}', s:half), ['0.800'])
call s:Check('template: whole percent', s:Ex('%b:P', s:rgb), ['0'])
call s:Check('template: full fraction', s:Ex('%r:f', s:rgb), ['1'])
call s:Check('template: alpha', s:Ex('%a', s:half), ['0.8'])
call s:Check('template: opaque alpha', s:Ex('%a', s:rgb), ['1'])
call s:Check('template: alpha percent', s:Ex('%a:p', s:half), ['80%'])
call s:Check('template: alpha hex', s:Ex('%a:x', s:half), ['cc'])
call s:Check('template: omitted opaque alpha', s:Ex('[%a:o]', s:rgb), ['[]'])
call s:Check('template: omitted alpha shown if not opaque', s:Ex('[%a:o]', s:half), ['[0.8]'])
call s:Check('template: colon between items', s:Ex('%r:%g:%b', s:rgb), ['255:136:0'])
call s:Check('template: colon and a letter after braces', s:Ex('%{r}:x', s:rgb), ['255:x'])
call s:Check('template: colon and a digit', s:Ex('%r:5', s:rgb), ['255:5'])
call s:Check('template: colon at the end', s:Ex('%r:', s:rgb), ['255:'])
call s:Check('template: hex shorthand', s:Ex('%x', s:dark), ['#7f0000'])
call s:Check('template: hex shorthand, alpha', s:Ex('%x', s:half), ['#ff8800cc'])
call s:Check('template: hex shorthand upper case', s:Ex('%X', s:half), ['#FF8800CC'])
call s:Check('template: hex shorthand, forced alpha', s:Ex('%x:a', s:dark), ['#7f0000ff'])
call s:Check('template: hex shorthand, braced', s:Ex('%{X:a}', s:dark), ['#7F0000FF'])
call s:Check('template: source text', s:Ex('<%t>', s:rgb, 'rgb(255 136 0)'), ['<rgb(255 136 0)>'])
call s:Check('template: region number', s:Ex('Region %{id}', s:rgb, '', 3), ['Region 3'])
call s:Check('template: line break', s:Ex('a%nb%n%nc', s:rgb), ['a', 'b', '', 'c'])
call s:Check('template: soft break', s:Ex('a%Nb c%Nd%ne', s:rgb), ['a~b c~d', 'e'])
call s:Check('template: a text with a percent in it is not expanded', s:Ex('%t', s:rgb, '%r'), ['%r'])
call s:Check('template: fallback', s:Ex('Region %{id}%n%x', s:rgb, '', 2), ['Region 2', '#ff8800'])

"templates that are not valid, with what is wrong
let s:Template=s:Fn('Template')
function s:Why(template)
  return s:Template(a:template)[1]
endfunction
call s:Check('template: valid', s:Why('%r %{g}:p %x %n%N%% %t %{id} %a:o:p:.1'), '')
call s:Check('template: percent at the end', s:Why('a%'), 'a % at the end, write %%')
call s:Check('template: unclosed brace', s:Why('%{r'), 'a %{ without a }')
call s:Check('template: reserved letter', s:Why('%q'), '%q is reserved')
call s:Check('template: reserved capital', s:Why('%R'), '%R is reserved')
call s:Check('template: not known symbol', s:Why('%!'), '%! is not known')
call s:Check('template: digit', s:Why('%1'), '%1 is not known')
call s:Check('template: space', s:Why('% x'), '%  is not known')
call s:Check('template: later name', s:Why('%{hsla}'), '%{hsla} is unsupported')
call s:Check('template: later model', s:Why('%{lab}'), '%{lab} is unsupported')
call s:Check('template: later component', s:Why('%{lab.l}'), '%{lab.l} is unsupported')
call s:Check('template: later names, cmy', s:Why('%{cmy}'), '%{cmy} is unsupported')
call s:Check('template: later color space', s:Why('%{oklch.c}'), '%{oklch.c} is unsupported')
call s:Check('template: braced letter', s:Why('%{s}'), '%s is reserved')
call s:Check('template: braced capital', s:Why('%{L}'), '%L is reserved')
call s:Check('template: not known name', s:Why('%{foo}'), '%{foo} is not known')
call s:Check('template: empty name', s:Why('%{}'), '%{} is not known')
call s:Check('template: not a modifier', s:Why('%r:q'), '%r:q is not a modifier')
call s:Check('template: not a braced modifier', s:Why('%{r:q}'), '%r:q is not a modifier')
call s:Check('template: empty braced modifier', s:Why('%{r:}'), '%r: is not a modifier')
call s:Check('template: two formats', s:Why('%r:p:x'), '%r has two formats')
call s:Check('template: two precisions', s:Why('%{r:p:.1:.2}'), '%r has two precisions')
call s:Check('template: precision of an integer', s:Why('%r:.2'), '%r: modifier not allowed')
call s:Check('template: omitting a channel', s:Why('%r:o'), '%r: modifier not allowed')
call s:Check('template: forcing a channel', s:Why('%r:a'), '%r: modifier not allowed')
call s:Check('template: forcing alpha', s:Why('%a:a'), '%a: modifier not allowed')
call s:Check('template: precision of a hex alpha', s:Why('%a:x:.2'), '%a: modifier not allowed')
call s:Check('template: format of the shorthand', s:Why('%x:p'), '%x: modifier not allowed')
call s:Check('template: omitting in the shorthand', s:Why('%X:o'), '%X: modifier not allowed')
call s:Check('template: modifier of the text', s:Why('%t:p'), '%t: modifier not allowed')
call s:Check('template: modifier of the number', s:Why('%{id:p}'), '%{id}: modifier not allowed')
call s:Check('template: a break takes no modifier, it is text', s:Why('%n:p'), '')
call s:Check('template: id only in braces', s:Why('%id'), '%i is reserved')
let s:letters=[]
for s:code in range(char2nr('A'), char2nr('Z')) + range(char2nr('a'), char2nr('z'))
  let s:letter=nr2char(s:code)
  if s:letter !~# '^[rgbaxXtnN]$' && s:Why('%'.s:letter) != '%'.s:letter.' is reserved'
    call add(s:letters, s:letter)
  endif
endfor
call s:Check('template: every other letter is reserved', s:letters, [])
let s:letters=[]
for s:letter in split('rgbaxXtnN', '\zs')
  if s:letter !~# '^[nN]$' && s:Why('%'.s:letter) != ''
    call add(s:letters, s:letter)
  endif
endfor
call s:Check('template: the letters in use are valid', s:letters, [])

"the models: whole, and by value, of some colors; the conversions are checked
"by the notations that are known to be right for them
let s:orange=[255, 136, 0, 1.0]
call s:Check('model: rgb', s:Ex('%{rgb}', s:orange), ['rgb(255 136 0)'])
call s:Check('model: hsl', s:Ex('%{hsl}', s:orange), ['hsl(32 100% 50%)'])
call s:Check('model: hsv', s:Ex('%{hsv}', s:orange), ['hsv(32 100% 100%)'])
call s:Check('model: hwb', s:Ex('%{hwb}', s:orange), ['hwb(32 0% 0%)'])
call s:Check('model: cmyk', s:Ex('%{cmyk}', s:orange), ['cmyk(0% 47% 100% 0%)'])
call s:Check('model: black',
\            s:Ex('%{hsl} %{hsv} %{hwb} %{cmyk}', [0, 0, 0, 1.0]),
\            ['hsl(0 0% 0%) hsv(0 0% 0%) hwb(0 0% 100%) cmyk(0% 0% 0% 100%)'])
call s:Check('model: white',
\            s:Ex('%{hsl} %{hsv} %{hwb} %{cmyk}', [255, 255, 255, 1.0]),
\            ['hsl(0 0% 100%) hsv(0 0% 100%) hwb(0 100% 0%) cmyk(0% 0% 0% 0%)'])
call s:Check('model: gray',
\            s:Ex('%{hsl} %{hsv} %{hwb}', [128, 128, 128, 1.0]), ['hsl(0 0% 50%) hsv(0 0% 50%) hwb(0 50% 50%)'])
call s:Check('model: red', s:Ex('%{hsl.h} %{hsv.s} %{cmyk.c} %{cmyk.m}', [255, 0, 0, 1.0]), ['0 100% 0% 100%'])
call s:Check('model: green', s:Ex('%{hsl.h}', [0, 255, 0, 1.0]), ['120'])
call s:Check('model: blue', s:Ex('%{hsl.h}', [0, 0, 255, 1.0]), ['240'])
call s:Check('model: rose', s:Ex('%{hsl.h}', [255, 0, 128, 1.0]), ['330'])
call s:Check('model: a hue before red', s:Ex('%{hsl.h}', [255, 0, 1, 1.0]), ['360'])
call s:Check('model: lightness and saturation', s:Ex('%{hsl.s}/%{hsl.l}', [10, 200, 90, 1.0]), ['90%/41%'])
call s:Check('model: dark', s:Ex('%{hsv.v}', [127, 0, 0, 1.0]), ['50%'])
call s:Check('model: value by value', s:Ex('%{hwb.w} %{hwb.b}', s:orange), ['0% 0%'])
call s:Check('model: cmyk by value', s:Ex('%{cmyk.m} %{cmyk.k}', s:orange), ['47% 0%'])
call s:Check('model: a value of rgb is plain', s:Ex('%{rgb.r} %{rgb.g} %{rgb.b}', s:orange), ['255 136 0'])
call s:Check('model: a value of rgb with a modifier', s:Ex('%{rgb.g:p}', s:orange), ['53%'])
call s:Check('model: alpha', s:Ex('%{hsl}', [255, 136, 0, 0.8]), ['hsl(32 100% 50% / 0.8)'])
call s:Check('model: forced alpha', s:Ex('%{hsl:a}', s:orange), ['hsl(32 100% 50% / 1)'])
call s:Check('model: comma', s:Ex('%{hsl:c}', s:orange), ['hsl(32, 100%, 50%)'])
call s:Check('model: comma, alpha', s:Ex('%{hsl:c}', [255, 136, 0, 0.8]), ['hsla(32, 100%, 50%, 0.8)'])
call s:Check('model: comma, forced alpha', s:Ex('%{hsl:a:c}', s:orange), ['hsla(32, 100%, 50%, 1)'])
call s:Check('model: comma, rgb', s:Ex('%{rgb:c}', [255, 136, 0, 0.5]), ['rgba(255, 136, 0, 0.5)'])
call s:Check('model: comma, hsv', s:Ex('%{hsv:c}', [255, 136, 0, 0.5]), ['hsva(32, 100%, 100%, 0.5)'])
call s:Check('model: comma, cmyk', s:Ex('%{cmyk:c}', s:orange), ['cmyk(0%, 47%, 100%, 0%)'])
call s:Check('model: precision', s:Ex('%{hsl:.2}', [255, 136, 0, 0.8]), ['hsl(32.00 100.00% 50.00% / 0.80)'])
call s:Check('model: precision, rounding', s:Ex('%{hsl:.1}', [10, 200, 90, 1.0]), ['hsl(145.3 90.5% 41.2%)'])
call s:Check('model: default precision rounds', s:Ex('%{hsl}', [10, 200, 90, 1.0]), ['hsl(145 90% 41%)'])
call s:Check('model: hue precision', s:Ex('%{hsl.h:.2}', [10, 200, 90, 1.0]), ['145.26'])
call s:Check('model: hue as a turn', s:Ex('%{hsl.h:f:.3}', s:orange), ['0.089'])
call s:Check('model: whole percent', s:Ex('%{hsl.s:P}', s:orange), ['100'])
call s:Check('model: a fraction', s:Ex('%{hsl.l:f}', s:orange), ['0.5'])
call s:Check('model: with text', s:Ex('<%{hsl.h}deg>', s:orange), ['<32deg>'])

"what a model is shown as is read back by the plugin's own parsers: with enough
"decimals it is the same color, with none, which is the default, it is close
let s:Parse=s:Fn('ParseCss')
let s:seed=12345
function s:Random(n)
  let s:seed=(s:seed*1103515245+12345) % 2147483648
  return (s:seed / 65536) % a:n
endfunction
let s:samples=[[0, 0, 0, 1.0], [255, 255, 255, 1.0], [255, 0, 0, 1.0], [0, 255, 0, 1.0], [0, 0, 255, 1.0],
\              [128, 128, 128, 1.0], [255, 136, 0, 1.0]]
for s:n in range(150)
  call add(s:samples, [s:Random(256), s:Random(256), s:Random(256), 1.0])
endfor
for s:n in range(50)
  call add(s:samples, [s:Random(256), s:Random(256), s:Random(256), (1+s:Random(99))/100.0])
endfor
function s:RoundTrip(template, tolerance)
  let worse=[]
  for color in s:samples
    let back=s:Parse(join(map(s:Fn('Expand')(a:template, color, '', 1)[0], 'v:val.t'), ''))
    let errors=empty(back) ? [999] : [abs(back[0]-color[0]), abs(back[1]-color[1]), abs(back[2]-color[2]),
\                                      abs(back[3]-color[3])*100]
    if max(errors) > a:tolerance
      call add(worse, [color, back])
    endif
  endfor
  return len(worse) > 0 ? worse[0] : []
endfunction
for s:model in ['%{rgb}', '%{rgb:c}', '%{hsl:.3}', '%{hsl:c:.3}', '%{hwb:.3}', '%{hsv:.3}', '%{hsv:c:.3}',
\               '%{hsl:a:.3}']
  call s:Check('round trip: '.s:model, s:RoundTrip(s:model, 0.5), [])
endfor
for s:model in ['%{hsl}', '%{hsl:c}', '%{hwb}', '%{hsv}']
  call s:Check('round trip, close: '.s:model, s:RoundTrip(s:model, 4), [])
endfor
call s:Check('round trip is not trivial', s:RoundTrip('%{hsl}', 0.5) != [], 1)

"groups of items: left out if an item in them is empty
call s:Check('group: kept', s:Ex('a%( / %a:o%)b', [1, 2, 3, 0.5]), ['a / 0.5b'])
call s:Check('group: left out', s:Ex('a%( / %a:o%)b', s:orange), ['ab'])
call s:Check('group: with text only', s:Ex('a%( x %)b', s:orange), ['a x b'])
call s:Check('group: an empty source text', s:Ex('a%(%t%)b', s:orange, ''), ['ab'])
call s:Check('group: a source text', s:Ex('a%(<%t>%)b', s:orange, 'x'), ['a<x>b'])
call s:Check('group: with a model', s:Ex('%(%{hsl}%)', s:orange), ['hsl(32 100% 50%)'])
call s:Check('group: two', s:Ex('%(%a:o%)%( %a:p%)', [1, 2, 3, 0.5]), ['0.5 50%'])
call s:Check('group: empty', s:Ex('a%(%)b', s:orange), ['ab'])
call s:Check('group: a percent in it', s:Ex('%(100%%%)', s:orange), ['100%'])
call s:Check('group: with a line break is not valid', s:Why('%(a%nb%)'), '%n is not allowed in %( %)')
call s:Check('group: with a soft break is not valid', s:Why('%(a%Nb%)'), '%N is not allowed in %( %)')
call s:Check('group: with a highlight is not valid', s:Why('%(%#Error#a%)'), '%# is not allowed in %( %)')
call s:Check('group: with a reset is not valid', s:Why('%(%*%)'), '%* is not allowed in %( %)')
call s:Check('group: in a group is not valid', s:Why('%(%(%)%)'), '%( is not allowed in %( %)')
call s:Check('group: not closed', s:Why('%(a'), 'a %( without a %)')
call s:Check('group: not opened', s:Why('a%)'), '%) without a %(')
call s:Check('group: items are validated', s:Why('%(%q%)'), '%q is reserved')
call s:Check('group: valid', s:Why('%(%{hsl:c}%)'), '')

"more of the validation
call s:Check('model: comma in hwb', s:Why('%{hwb:c}'), '%{hwb}: modifier not allowed')
call s:Check('model: precision in rgb', s:Why('%{rgb:.1}'), '%{rgb}: modifier not allowed')
call s:Check('model: a format of a whole', s:Why('%{hsl:p}'), '%{hsl}: modifier not allowed')
call s:Check('model: omitting a whole', s:Why('%{hsl:o}'), '%{hsl}: modifier not allowed')
call s:Check('model: a percent of a hue', s:Why('%{hsl.h:p}'), '%{hsl.h}: modifier not allowed')
call s:Check('model: a hex of a value', s:Why('%{hsl.s:x}'), '%{hsl.s}: modifier not allowed')
call s:Check('model: omitting a value', s:Why('%{hsl.s:o}'), '%{hsl.s}: modifier not allowed')
call s:Check('model: comma of a value', s:Why('%{hsl.s:c}'), '%{hsl.s}: modifier not allowed')
call s:Check('model: not a value', s:Why('%{hsl.q}'), '%{hsl.q} is not known')
call s:Check('model: not a model', s:Why('%{foo.r}'), '%{foo.r} is not known')
call s:Check('model: an upper case model', s:Why('%{HSL}'), '%{HSL} is not known')
call s:Check('model: the same value in another model', s:Why('%{hwb.b} %{hsv.v} %{cmyk.k}'), '')
call s:Check('model: comma is not a modifier of the rest', s:Why('%r:c'), '%r: modifier not allowed')
call s:Check('model: comma is for models', s:Why('%x:c'), '%x: modifier not allowed')
call s:Check('highlight: a group', s:Why('%#Error#x%*'), '')
call s:Check('highlight: a group with a dot and an at', s:Why('%#@.a-b_1#x'), '')
call s:Check('highlight: no name', s:Why('%##x'), '%# needs a group name and a closing #')
call s:Check('highlight: not closed', s:Why('%#Error'), '%# needs a group name and a closing #')
call s:Check('highlight: a space', s:Why('%#a b#'), '%# needs a group name and a closing #')

"highlights: the parts of the text that have one, as [first, after the last,
"group] of the segments of the lines
function s:Spans(template, ...)
  let lines=s:Fn('Expand')(a:template, a:0 >= 1 ? a:1 : s:orange, 'SRC', 1)
  return map(lines, 'map(copy(v:val), "[v:val.t, v:val.h]")')
endfunction
call s:Check('highlight: none', s:Spans('abc'), [[['abc', []]]])
call s:Check('highlight: a span', s:Spans('a%#Error#bc%*d'), [[['abcd', [[1, 3, 'Error']]]]])
call s:Check('highlight: to the end', s:Spans('a%#Error#bc'), [[['abc', [[1, 3, 'Error']]]]])
call s:Check('highlight: two', s:Spans('%#A#a%#B#b'), [[['ab', [[0, 1, 'A'], [1, 2, 'B']]]]])
call s:Check('highlight: the same one is one span', s:Spans('%#A#a%#A#b'), [[['ab', [[0, 2, 'A']]]]])
call s:Check('highlight: items in it', s:Spans('%#A#%r %g%*'), [[['255 136', [[0, 7, 'A']]]]])
call s:Check('highlight: an empty item in it', s:Spans('x%#A#%a:o%*y'), [[['xy', []]]])
call s:Check('highlight: across a line break', s:Spans('%#A#a%nb'), [[['a', [[0, 1, 'A']]]], [['b', [[0, 1, 'A']]]]])
call s:Check('highlight: across a soft break', s:Spans('%#A#a%Nb'), [[['a', [[0, 1, 'A']]], ['b', [[0, 1, 'A']]]]])
call s:Check('highlight: reset', s:Spans('%#A#a%*%nb'), [[['a', [[0, 1, 'A']]]], [['b', []]]])
call s:Check('highlight: multibyte text', s:Spans('%#A#é%*ü%#B#ö'), [[['éüö', [[0, 1, 'A'], [2, 3, 'B']]]]])
call s:Check('highlight: a group of items', s:Spans('%#A#%(<%t>%)%*'), [[['<SRC>', [[0, 5, 'A']]]]])

"cutting and joining keep the highlights
let s:Wrap=s:Fn('Wrap')
function s:Wrapped(template, width)
  let lines=s:Wrap(s:Fn('Expand')(a:template, s:orange, 'SRC', 1), a:width)
  return map(lines, '[v:val.t, v:val.h]')
endfunction
call s:Check('wrap: joined with the highlights moved',
\            s:Wrapped('%#A#ab%N%*cd%N%#B#ef', 6), [['abcdef', [[0, 2, 'A'], [4, 6, 'B']]]])
call s:Check('wrap: broken', s:Wrapped('%#A#ab%N%*cd%N%#B#ef', 4), [['abcd', [[0, 2, 'A']]], ['ef', [[0, 2, 'B']]]])
call s:Check('wrap: cut with an ellipsis in the highlight', s:Wrapped('%#A#abcdef', 4), [['abc…', [[0, 4, 'A']]]])
call s:Check('wrap: cut, the highlight of what it follows', s:Wrapped('ab%#A#cdef', 4), [['abc…', [[2, 4, 'A']]]])
call s:Check('wrap: cut before the highlight', s:Wrapped('abcdef%#A#gh', 4), [['abc…', []]])
call s:Check('wrap: cut in the middle of one', s:Wrapped('%#A#ab%#B#cdef', 4), [['abc…', [[0, 2, 'A'], [2, 4, 'B']]]])
call s:Check('wrap: not cut', s:Wrapped('%#A#ab', 4), [['ab', [[0, 2, 'A']]]])
call s:Check('wrap: nothing fits', s:Wrapped('%#A#ab', 0), [['', []]])
call s:Check('wrap: one cell', s:Wrapped('%#A#ab', 1), [['…', []]])

"layouts: the rows, and the regions as [first row, first column, last row,
"last column]; empty if the layout is not valid
let s:ParseLayout=s:Fn('ParseLayout')
function s:Layout(mode)
  silent! messages clear
  let layout=s:ParseLayout(a:mode)
  if empty(layout)
    return []
  endif
  return [layout.rows, map(copy(layout.regions), '[v:val.r0, v:val.c0, v:val.r1, v:val.c1]'), layout.alternating]
endfunction
call s:Check('layout: single', s:Layout('k'), [[['k']], [], 0])
call s:Check('layout: rows', s:Layout('kw|t'), [[['k', 'w'], ['t']], [], 0])
call s:Check('layout: alternating', s:Layout('k2|3'), [[['k', '2'], ['3']], [], 1])
call s:Check('layout: only a detail', s:Layout('d'), [[['d']], [[0, 0, 0, 0]], 0])
call s:Check('layout: details in a row are one', s:Layout('dd'), [[['d', 'd']], [[0, 0, 0, 1]], 0])
call s:Check('layout: details in a column are one', s:Layout('d|d'), [[['d'], ['d']], [[0, 0, 1, 0]], 0])
call s:Check('layout: a square of details', s:Layout('dd|dd'), [[['d', 'd'], ['d', 'd']], [[0, 0, 1, 1]], 0])
call s:Check('layout: a detail next to a block', s:Layout('kd'), [[['k', 'd']], [[0, 1, 0, 1]], 0])
call s:Check('layout: a . splits details', s:Layout('d.d'), [[['d', 'd']], [[0, 0, 0, 0], [0, 1, 0, 1]], 0])
call s:Check('layout: a . takes no room', s:Layout('k.w'), [[['k', 'w']], [], 0])
call s:Check('layout: several . are one', s:Layout('d...d'), [[['d', 'd']], [[0, 0, 0, 0], [0, 1, 0, 1]], 0])
call s:Check('layout: a . at the ends', s:Layout('.d.'), [[['d']], [[0, 0, 0, 0]], 0])
call s:Check('layout: a row of . splits details', s:Layout('d|.|d'), [[['d'], ['d']], [[0, 0, 0, 0], [1, 0, 1, 0]], 0])
call s:Check('layout: a row of . takes no room', s:Layout('k|.|w'), [[['k'], ['w']], [], 0])
call s:Check('layout: two rows of .', s:Layout('d|.|.|d'), [[['d'], ['d']], [[0, 0, 0, 0], [1, 0, 1, 0]], 0])
call s:Check('layout: td|d.d', s:Layout('td|d.d'), [[['t', 'd'], ['d', 'd']], [[0, 1, 1, 1], [1, 0, 1, 0]], 0])
call s:Check('layout: td|.|dd', s:Layout('td|.|dd'), [[['t', 'd'], ['d', 'd']], [[0, 1, 0, 1], [1, 0, 1, 1]], 0])
call s:Check('layout: td|d', s:Layout('td|d'), [[['t', 'd'], ['d']], [[0, 1, 0, 1], [1, 0, 1, 0]], 0])
call s:Check('layout: regions in reading order', s:Layout('kd|dk|kd')[1], [[0, 1, 0, 1], [1, 0, 1, 0], [2, 1, 2, 1]])
call s:Check('layout: an L is not valid', s:Layout('td|dd'), [])
call s:Check('layout: an L the other way is not valid', s:Layout('dd|dt'), [])
call s:Check('layout: a T is not valid', s:Layout('ddd|kdk'), [])
call s:Check('layout: first row of .', s:Layout('.|d'), [])
call s:Check('layout: last row of .', s:Layout('d|.'), [])
call s:Check('layout: only .', s:Layout('.'), [])
call s:Check('layout: doubled bar', s:Layout('k||w'), [])
call s:Check('layout: trailing bar', s:Layout('k|'), [])
call s:Check('layout: leading bar', s:Layout('|k'), [])
call s:Check('layout: renamed block', s:Layout('b'), [])
call s:Check('layout: unknown block', s:Layout('x'), [])
call s:Check('layout: not a string', s:Layout(5), [])
call s:Check('layout: empty', s:Layout(''), [])
call s:Check('layout: no color for ragged rows', len(s:Layout('kwt|d')[1]), 1)

"what is drawn: the lines of the popup for a code, with ' ' as . and a half block
"as H, for a layout and a detail format
function s:Rendered(mode, format, code)
  let g:pastel_color_mode=a:mode
  let g:pastel_detail_format=a:format
  enew!
  let &filetype='css'
  call setline(1, a:code)
  call cursor(1, 1)
  call s:Fn('OnCursorMove')()
  let popup=popup_list()[0]
  let lines=getbufline(winbufnr(popup), 1, '$')
  return map(lines, 'substitute(substitute(v:val, "▀", "H", "g"), " ", ".", "g")')
endfunction
let s:blank10=repeat('.', 10)
call s:Check('detail: alone',
\            s:Rendered('d', '%x', '#ff8800'), ['#ff8800...', s:blank10, s:blank10, s:blank10, s:blank10])
call s:Check('detail: the default format', s:Rendered('d', '%x', '#ff8800')[0], '#ff8800...')
call s:Check('detail: popup size', [popup_getpos(popup_list()[0]).width, popup_getpos(popup_list()[0]).height], [10, 5])
call s:Check('detail: rgb grows to the right', s:Rendered('d', 'rgb(%r %g %b)', '#ff8800'),
\            ['rgb(255.136.0)'] + repeat([repeat('.', 14)], 4))
call s:Check('detail: alpha', s:Rendered('d', '%x', '#ff8800cc')[0], '#ff8800cc.')
call s:Check('detail: broken where permitted', s:Rendered('d', 'rgb(%N%r %N%g %N%b)', '#ff8800'),
\            ['rgb(255...', '136.0)....', s:blank10, s:blank10, s:blank10])
call s:Check('detail: lines', s:Rendered('d', '%x%n%r:p %g:p %b:p%nsrc %t', 'rgb(255 136 0)'),
\            ['#ff8800...........', '100%.53%.0%.......', 'src.rgb(255.136.0)', repeat('.', 18), repeat('.', 18)])
call s:Check('detail: under a block', s:Rendered('t|d', '%x', '#ff8800'),
\            ['HHHHHHHHHH', 'HH......HH', 'HH......HH', 'HH......HH', 'HHHHHHHHHH', '#ff8800...']
\            + repeat([s:blank10], 4))
call s:Check('detail: next to a block', s:Rendered('td', '%x', '#ff8800cc')[0], 'HHHHHHHHHH#ff8800cc.')
call s:Check('detail: two regions, the second is named',
\            s:Rendered('td|d', '%x', '#ff8800')[5:6], ['Region.2............', '#ff8800.............'])
call s:Check('detail: two regions, a list',
\            s:Rendered('td|d.d', ['A%n%x', 'B', 'C'], '#ff8800')[0:1],
\            ['HHHHHHHHHHA.........', 'HH......HH#ff8800...'])
call s:Check('detail: two regions, the second of a list',
\            s:Rendered('td|d.d', ['A%n%x', 'B', 'C'], '#ff8800')[5], 'B...................')
call s:Check('detail: separated regions',
\            s:Rendered('td|.|dd', ['one', 'two'], '#ff8800')[0] . '/'
\            . s:Rendered('td|.|dd', ['one', 'two'], '#ff8800')[5],
\            'HHHHHHHHHHone......./two.................')
call s:Check('detail: a short list names the rest',
\            s:Rendered('d.d.d', ['x'], '#ff8800')[0], 'x.........Region.2..Region.3..')
call s:Check('detail: a list of nothing names all', s:Rendered('d', [], '#ff8800')[0], 'Region.1..')
call s:Check('detail: a long list is not a problem', s:Rendered('d', ['a', 'b'], '#ff8800')[0], 'a.........')

"growth: to the right before down, only into what is free, else cut
call s:Check('growth: both want the cell, the right one has it',
\            s:Rendered('td|d', ['1%n2%n3%n4%n5%n6%n7%n8', 'wide-wide-wide-wide-wide'], '#ff8800')[0:5],
\            ['HHHHHHHHHH1.............', 'HH......HH2.............', 'HH......HH3.............',
\             'HH......HH4.............', 'HHHHHHHHHH5…............', 'wide-wide-wide-wide-wide'])
let s:tall='1%n2%n3%n4%n5%n6%n7%n8'
call s:Check('growth: free down in a ragged layout', s:Rendered('td|k', [s:tall], '#ff8800')[0:7],
\            ['HHHHHHHHHH1.........', 'HH......HH2.........', 'HH......HH3.........', 'HH......HH4.........',
\             'HHHHHHHHHH5.........', '..........6.........', '..........7.........', '..........8.........'])
call s:Check('growth: a row of . stops it', s:Rendered('td|.|k', [s:tall], '#ff8800')[4], 'HHHHHHHHHH5…........')
call s:Check('growth: a row of . stops it, the size', popup_getpos(popup_list()[0]).height, 10)
call s:Check('growth: a . stops it to the right',
\            s:Rendered('d.', 'abcdefghijklmnopqrstuvwxyz', '#ff8800')[0], 'abcdefghi…')
call s:Check('growth: without the . it does not',
\            s:Rendered('d', 'abcdefghijklmnopqrstuvwxyz', '#ff8800')[0], 'abcdefghijklmnopqrstuvwxyz')
call s:Check('growth: a . elsewhere does not',
\            s:Rendered('.d', 'abcdefghijklmnopqrstuvwxyz', '#ff8800')[0], 'abcdefghijklmnopqrstuvwxyz')
call s:Check('growth: the claim of the one above is cancelled',
\            s:Rendered('td|.|d', [s:tall, 'wide-wide-wide-wide-wide'], '#ff8800')[4:5],
\            ['HHHHHHHHHH5…............', 'wide-wide-wide-wide-wide'])
call s:Check('growth: blocked to the right, cut',
\            s:Rendered('dk', 'abcdefghijklmnopqrstuvwxyz', '#ff8800')[0], 'abcdefghi…..........')
call s:Check('growth: free to the right',
\            s:Rendered('kd', 'abcdefghijklmnopqrstuvwxyz', '#ff8800')[0], '..........abcdefghijklmnopqrstuvwxyz')
call s:Check('growth: blocked down, cut',
\            s:Rendered('d|k', '1%n2%n3%n4%n5%n6%n7%n8', '#ff8800')[0:5],
\            ['1.........', '2.........', '3.........', '4.........', '5…........', s:blank10])
call s:Check('growth: free down',
\            s:Rendered('k|d', '1%n2%n3%n4%n5%n6%n7%n8', '#ff8800')[5:12],
\            ['1.........', '2.........', '3.........', '4.........', '5.........', '6.........', '7.........',
\             '8.........'])
call s:Check('growth: free down, the size',
\            [popup_getpos(popup_list()[0]).width, popup_getpos(popup_list()[0]).height], [10, 13])
call s:Check('growth: breaking instead',
\            s:Rendered('kd|dk', ['a%Nb%Nc', 'x%Ny%Nz'], '#ff8800')[0]
\            . s:Rendered('kd|dk', ['a%Nb%Nc', 'x%Ny%Nz'], '#ff8800')[5],
\            '..........abc.......xyz.................')
call s:Check('growth: wider than the layout', popup_getpos(popup_list()[0]).width, 20)

"odd sizes: a region has the lines that are whole in it, and at the bottom also
"the one the padding of the odd height completes
let g:pastel_color_size=3
let g:pastel_bg_size=1
call s:Check('odd: popup size',
\            [s:Rendered('d', 'a%nb%nc', '#ff8800')[0], popup_getpos(popup_list()[0]).width,
\             popup_getpos(popup_list()[0]).height],
\            ['a....', 5, 3])
call s:Check('odd: the lines at the bottom', s:Rendered('d', 'a%nb%nc', '#ff8800'), ['a....', 'b....', 'c....'])
call s:Check('odd: the shared line is not for the text',
\            s:Rendered('d|k', 'a%nb%nc', '#ff8800')[0:2], ['a....', 'b…...', 'HHHHH'])
let g:pastel_color_size=6
let g:pastel_bg_size=2

"the detail's pixels and highlight
call s:Rendered('td|d', '%x', '#ff8800')
let s:Pixel=s:Fn('Pixel')
call s:Check('pixels: a detail cell', s:Pixel(10, 0), 'e')
call s:Check('pixels: a detail cell, bottom', s:Pixel(19, 9), 'e')
call s:Check('pixels: the other detail cell', s:Pixel(0, 10), 'e')
call s:Check('pixels: not a detail cell', s:Pixel(0, 0), 'l')
call s:Check('pixels: outside', s:Pixel(10, 10), 'n')
call s:Rendered('kd', 'abcdefghijklmnopqrstuvwxyz', '#ff8800')
call s:Check('pixels: grown region', s:Pixel(35, 4), 'e')
call s:Check('pixels: not grown further', s:Pixel(36, 4), 'n')
let s:popup=popup_list()[0]
call s:Check('detail text has its own highlight',
\            map(prop_list(1, {'bufnr': winbufnr(s:popup)}), 'v:val.type'), ['pastelpkk', 'pasteldetail'])
call s:Check('detail highlight exists', hlexists('PastelDetail'), 1)
call s:Check('detail highlight is linked to Normal', synIDattr(synIDtrans(hlID('PastelDetail')), 'name'), 'Normal')
call s:Check('detail property type exists', !empty(prop_type_get('pasteldetail')), 1)

"highlighted text has its own property types, as a user's groups are used as
"they are, and a group that does not exist is warned about once
function s:Props(mode, format, code)
  call s:Rendered(a:mode, a:format, a:code)
  let buf=winbufnr(popup_list()[0])
  return map(prop_list(1, {'bufnr': buf}), '[v:val.type, v:val.col, v:val.length]')
endfunction
call s:Check('highlight: the properties',
\            s:Props('d', '%#ErrorMsg#ab%*cd', '#ff8800'), [['pasteldetail:ErrorMsg', 1, 2], ['pasteldetail', 3, 8]])
call s:Check('highlight: the text', s:Rendered('d', '%#ErrorMsg#ab%*cd', '#ff8800')[0], 'abcd......')
call s:Check('highlight: two groups',
\            s:Props('d', '%#ErrorMsg#a%#WarningMsg#b', '#ff8800'),
\            [['pasteldetail:ErrorMsg', 1, 1], ['pasteldetail:WarningMsg', 2, 1], ['pasteldetail', 3, 8]])
call s:Check('highlight: multibyte text',
\            s:Props('d', '%#ErrorMsg#é%*x', '#ff8800'), [['pasteldetail:ErrorMsg', 1, 2], ['pasteldetail', 3, 9]])
call s:Check('highlight: cut with an ellipsis',
\            s:Props('dk', '%#ErrorMsg#abcdefghijklmnop', '#ff8800'),
\            [['pasteldetail:ErrorMsg', 1, 12], ['pastelpkk', 13, 10]])
call s:Check('highlight: its property type exists', !empty(prop_type_get('pasteldetail:ErrorMsg')), 1)
call s:Check('highlight: the type uses the group', prop_type_get('pasteldetail:ErrorMsg').highlight, 'ErrorMsg')
let s:before=len(filter(split(execute('messages'), "\n"), 'v:val =~# "^pastel: no highlight group NoSuchGroupX"'))
call s:Check('highlight: a missing group is the detail one',
\            s:Props('d', '%#NoSuchGroupX#ab', '#ff8800')[0], ['pasteldetail', 1, 10])
call s:Rendered('d', '%#NoSuchGroupX#ab', '#ff8800')
call s:Check('highlight: a missing group is warned about once',
\            len(filter(split(execute('messages'), "\n"),
\                       'v:val =~# "^pastel: no highlight group NoSuchGroupX"'))-s:before,
\            1)
highlight NoSuchGroupX guifg=#123456
call s:Check('highlight: a group that is defined later is used',
\            s:Props('d', '%#NoSuchGroupX#ab', '#ff8800')[0], ['pasteldetail:NoSuchGroupX', 1, 2])

"the groups of the red, green and blue, their inverses and the alpha are
"defined as the color changes, if a template uses them: the color's value of
"it as the background, and black or white text, whichever is easier to read
let s:swatches=['PastelRed', 'PastelGreen', 'PastelBlue', 'PastelCyan', 'PastelMagenta', 'PastelYellow', 'PastelAlpha']
let s:all=join(map(copy(s:swatches), '"%#".v:val."#x"'), '')
function s:Swatches()
  return map(copy(s:swatches), '[s:Attr(v:val, "bg#"), s:Attr(v:val, "fg#")]')
endfunction
for s:group in s:swatches
  execute 'highlight clear' s:group
endfor
call s:Rendered('d', '%#PastelRed#x', '#ff8800cc')
call s:Check('swatches: the ones not used are not defined',
\            [s:Attr('PastelGreen', 'bg#'), s:Attr('PastelMagenta', 'bg#')], ['', ''])
call s:Check('swatches: the one used is', s:Attr('PastelRed', 'bg#'), '#ff0000')
call s:Rendered('d', s:all, '#ff8800cc')
call s:Check('swatches: all of an orange, half transparent', s:Swatches(),
\            [['#ff0000', '#ffffff'], ['#008800', '#ffffff'], ['#000000', '#ffffff'], ['#000000', '#ffffff'],
\             ['#770077', '#ffffff'], ['#ffff00', '#000000'], ['#cccccc', '#000000']])
call s:Rendered('d', s:all, '#0000ff')
call s:Check('swatches: they follow the color', s:Swatches(),
\            [['#000000', '#ffffff'], ['#000000', '#ffffff'], ['#0000ff', '#ffffff'], ['#00ffff', '#000000'],
\             ['#ff00ff', '#ffffff'], ['#000000', '#ffffff'], ['#ffffff', '#000000']])
call s:Rendered('d', s:all, '#00ff00')
call s:Check('swatches: a green one gets black text',
\            [s:Attr('PastelGreen', 'bg#'), s:Attr('PastelGreen', 'fg#')], ['#00ff00', '#000000'])
call s:Rendered('d', s:all, '#808080')
call s:Check('swatches: gray',
\            s:Swatches()[0:2], [['#800000', '#ffffff'], ['#008000', '#ffffff'], ['#000080', '#ffffff']])
execute 'highlight clear PastelRed'
call s:Rendered('d', '%#PastelRed#x', '#808080')
call s:Check('swatches: the same color does not redefine', s:Attr('PastelRed', 'bg#'), '')
doautocmd ColorScheme
call s:Rendered('d', '%#PastelRed#x', '#808080')
call s:Check('swatches: a color scheme does', s:Attr('PastelRed', 'bg#'), '#800000')
call s:Check('swatches: the properties of them',
\            s:Props('d', '%#PastelRed#a%#PastelAlpha#b', '#808080'),
\            [['pasteldetail:PastelRed', 1, 1], ['pasteldetail:PastelAlpha', 2, 1], ['pasteldetail', 3, 8]])

"the detail format is an option: invalid values warn and the default is used,
"it is overridden per buffer, and a string is for the first region only
let g:pastel_color_mode='d'
let g:pastel_detail_format='%x'
for s:value in ['%q', '%', 5, {}, [5], ['%x', '%q'], '%{lab.l}', '%r:q', '%t:p', '%{r', '%#', '%(%n%)', '%{hwb:c}']
  let s:before=s:Warnings()
  let g:pastel_detail_format=s:value
  let s:shown=s:Rendered('d', s:value, '#ff8800')
  call s:Check('format '.string(s:value).': the default is used', s:shown[0], '#ff8800...')
  call s:Check('format '.string(s:value).': a warning', s:Warnings()-s:before, 1)
endfor
let g:pastel_detail_format='%x'
call s:Check('format: the reason is in the warning',
\            len(filter(split(execute('messages'), "\n"),
\                       'v:val =~# "^pastel: g:pastel_detail_format: %t: modifier not allowed$"')),
\            1)
let s:before=s:Warnings()
call s:Check('format: valid list', s:Rendered('d', ['%r'], '#ff8800')[0], '255.......')
call s:Check('format: no warning for valid values', s:Warnings(), s:before)
let g:pastel_detail_format='%x'
let g:pastel_color_mode='d'
enew!
let &filetype='css'
let b:pastel_detail_format='[%t]'
call setline(1, '#ff8800')
call cursor(1, 1)
call s:Fn('OnCursorMove')()
call s:Check('format: buffer-local', getbufline(winbufnr(popup_list()[0]), 1)[0][:8], '[#ff8800]')
enew!
call setline(1, '#ff8800')
call cursor(1, 1)
call s:Fn('OnCursorMove')()
call s:Check('format: buffer-local does not leak', getbufline(winbufnr(popup_list()[0]), 1)[0][:6], '#ff8800')
call s:Check('format: no detail_mode', exists('g:pastel_detail_mode'), 0)
let g:pastel_color_mode='k'
let g:pastel_detail_format='%x'

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
