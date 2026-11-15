if exists('g:loaded_pastel')
  finish
endif
let g:loaded_pastel=1

"has('popupwin') only exists since 8.1.2371, before it popups were a part of
"+textprop, so the function is what is looked for
if !exists('*popup_create') || !has('textprop')
  finish
endif
"a Vim built without the feature has no such option, and so no true colors
if !has('gui_running') && !(exists('+termguicolors') && &termguicolors)
  finish
endif

"internal
let s:pastel_win=0
let s:warned=0

"options are read every time they are used, so changes take effect at once; all
"but the layout and the colors can be overridden per buffer by b:pastel_<name>;
"an invalid value is warned about, once per value, and the default is used
"instead, as s:Opt(name) does; the checks return [value] or [] if invalid
let s:defaults={}
let s:checks={}
let s:whats={}
let s:invalid={}
"why the last value was found invalid, if the check says so
let s:why=''

"a:value as a whole number in a:low..a:high, or []; a numeric string is fine
function s:Whole(value, low, high)
  if type(a:value) == v:t_string && a:value =~ '^[+-]\?\d\+$'
    let number=str2nr(a:value)
  elseif type(a:value) == v:t_number
    let number=a:value
  else
    return []
  endif
  return number >= a:low && number <= a:high ? [number] : []
endfunction

"a:value as a whole number of any sensible size, or []
function s:Offset(value)
  return s:Whole(a:value, -1000000, 1000000)
endfunction

"a:value, if it is a number or a numeric string
function s:Seconds(value)
  let numeric=type(a:value) == v:t_number || type(a:value) == v:t_float
  if numeric || type(a:value) == v:t_string && a:value =~ '^\d\+\(\.\d\+\)\?$'
    return [a:value]
  endif
  return []
endfunction

"a:value, if it is a color a highlight group can have, a #RRGGBB one or a name
function s:ColorOption(value)
  if type(a:value) != v:t_string
    return []
  elseif a:value =~ '^#'
    return a:value =~? '^#\x\{6}$' ? [a:value] : []
  elseif a:value !~ '^\a\+$'
    return []
  endif
  try
    execute 'silent highlight pastelpcheck guibg='.a:value
    highlight clear pastelpcheck
  catch
    return []
  endtry
  return [a:value]
endfunction

"a:value, if it is one of a:allowed
function s:OneOf(value, allowed)
  return type(a:value) == v:t_string && index(a:allowed, a:value) >= 0
\        ? [a:value] : []
endfunction

"a:value, if it is a list of strings
function s:Strings(value)
  if type(a:value) == v:t_list
\    && empty(filter(copy(a:value), 'type(v:val) != v:t_string'))
    return [a:value]
  endif
  return []
endfunction

"templates, as in g:pastel_detail_format: text with these % items
"  %%        a literal %
"  %n  %N    a line break; a place where a line may be broken if it is too
"            long (spaces are never broken)
"  %r %g %b  the red, green and blue of the color, 0 to 255
"  %a        its alpha, 0 to 1
"  %x  %X    the color as #rrggbb, followed by the alpha as two more hex
"            digits if it is not 1, in lower and upper case
"  %t        the color code as it is written in the buffer
"  %{id}     the number of the detail region
"  %{rgb} %{hsl} %{hwb} %{hsv} %{cmyk}
"            the color as a whole, eg. hsl(32 100% 50%)
"  %{hsl.s}  one of its values, in the same models: rgb r g b, hsl h s l,
"            hsv h s v, hwb h w b, cmyk c m y k
"  %#Group#  the text after it is highlighted with Group, until %*
"  %(  %)    text that is left out if an item in it is empty
"an item with a number may be followed by modifiers, each after a colon: p for
"a percent, P for a percent without the sign, f for a fraction, x or X for two
"hex digits, .N for N decimals (of p, P and f, and of the values of the models
"and the hue), o omits an opaque alpha, a makes %x, %X and the models always
"have the alpha, c makes them use the old comma notation; a colon and a letter
"after an item are thus always a modifier, so to have them as text it is
"written %{r}:x
"all other letters and some symbols are reserved for later; an item that is not
"known is an error and not text, so that its meaning can be added later
let s:fallback='Region %{id}%n%x'
"names that may be used later
let s:future_names=['rgba', 'hex', 'hsla', 'hwba', 'hsva', 'cmy', 'lab', 'lch',
\                   'oklab', 'oklch', 'color', 'name', 'xyz', 'gray']
"the models: their values, in the order of their notation
let s:models={'rgb': ['r', 'g', 'b'], 'hsl': ['h', 's', 'l'],
\             'hsv': ['h', 's', 'v'], 'hwb': ['h', 'w', 'b'],
\             'cmyk': ['c', 'm', 'y', 'k']}

"[tokens, why] of the item a:name with the modifiers a:mods; why is '' if it
"is valid
function s:Item(name, mods)
  let shown='%'.(len(a:name) == 1 ? a:name : '{'.a:name.'}')
  let [model, value]=[matchstr(a:name, '^\a*'), matchstr(a:name, '\.\zs.*')]
  let composite=has_key(s:models, a:name)
  let component=a:name =~# '\.' && has_key(s:models, model)
\                && index(s:models[model], value) >= 0
  if index(['r', 'g', 'b', 'a', 'x', 'X', 't', 'id'], a:name) < 0
\    && !composite && !component
    if a:name =~# '^\a$'
      return [[], shown.' is reserved']
    elseif index(s:future_names, model) >= 0
      return [[], shown.' is unsupported']
    endif
    return [[], shown.' is not known']
  endif
  let format=''
  let precision=-1
  let omit=0
  let force=0
  let comma=0
  for mod in a:mods
    if mod =~# '^[pPfxX]$'
      if format !=# ''
        return [[], shown.' has two formats']
      endif
      let format=mod
    elseif mod =~# '^\.\d\+$'
      if precision >= 0
        return [[], shown.' has two precisions']
      endif
      let precision=str2nr(mod[1:])
    elseif mod ==# 'o'
      let omit=1
    elseif mod ==# 'a'
      let force=1
    elseif mod ==# 'c'
      let comma=1
    else
      return [[], shown.':'.mod.' is not a modifier']
    endif
  endfor
  let any=format !=# '' || precision >= 0 || omit || force || comma
  if a:name =~# '^[xX]$'
    let ok=format ==# '' && precision < 0 && !omit && !comma
  elseif a:name ==# 'a'
    let ok=!force && !comma && (precision < 0 || format !~# '[xX]')
  elseif a:name =~# '^[rgb]$' || a:name =~# '^rgb\.'
    let ok=!omit && !force && !comma
\          && (precision < 0 || format =~# '[pPf]')
  elseif composite
    let ok=format ==# '' && !omit && (precision < 0 || a:name !=# 'rgb')
\          && !(comma && a:name ==# 'hwb')
  elseif component
    let ok=format !~# '[xX]' && !omit && !force && !comma
\          && (value !=# 'h' || format !~# '[pP]')
  else
    let ok=!any
  endif
  if !ok
    return [[], shown.': modifier not allowed']
  endif
  if a:name =~# '^[xX]$'
    let hex=a:name ==# 'X' ? 'X' : 'x'
    return [[{'t': 'text', 's': '#'},
\            {'t': 'value', 'n': 'r', 'f': hex, 'p': -1, 'o': 0},
\            {'t': 'value', 'n': 'g', 'f': hex, 'p': -1, 'o': 0},
\            {'t': 'value', 'n': 'b', 'f': hex, 'p': -1, 'o': 0},
\            {'t': 'value', 'n': 'a', 'f': hex, 'p': -1, 'o': !force}], '']
  elseif composite
    return [[{'t': 'whole', 'n': a:name, 'p': precision, 'force': force,
\             'comma': comma}], '']
  endif
  let name=a:name =~# '^rgb\.' ? value : a:name
  "a value that is a part of a whole is by default shown as in it
  if format ==# '' && component && value !=# 'h' && model !=# 'rgb'
    let format='p'
  endif
  return [[{'t': 'value', 'n': name, 'f': format, 'p': precision,
\           'o': omit}], '']
endfunction

"[tokens, why] of a:template, why being '' if it is valid and what is wrong
"with it if not; a group of items is a token of its own, in which only text
"and numbers can be
function s:ParseTemplate(template)
  let tokens=[]
  let group=[]
  let ingroup=0
  let pos=0
  while pos < len(a:template)
    let percent=stridx(a:template, '%', pos)
    if percent < 0
      call add(ingroup ? group : tokens,
\              {'t': 'text', 's': strpart(a:template, pos)})
      break
    elseif percent > pos
      call add(ingroup ? group : tokens,
\              {'t': 'text', 's': strpart(a:template, pos, percent-pos)})
    endif
    let pos=percent+1
    let char=strpart(a:template, pos, 1)
    let mods=[]
    if char ==# ''
      return [[], 'a % at the end, write %%']
    elseif char ==# '%'
      call add(ingroup ? group : tokens, {'t': 'text', 's': '%'})
      let pos+=1
      continue
    elseif char =~# '^[nN#*(]$' && ingroup
      return [[], '%'.char.' is not allowed in %( %)']
    elseif char ==# '('
      let ingroup=1
      let pos+=1
      continue
    elseif char ==# ')'
      if !ingroup
        return [[], '%) without a %(']
      endif
      call add(tokens, {'t': 'group', 'tokens': group})
      let [group, ingroup]=[[], 0]
      let pos+=1
      continue
    elseif char ==# 'n'
      call add(tokens, {'t': 'break'})
      let pos+=1
      continue
    elseif char ==# 'N'
      call add(tokens, {'t': 'soft'})
      let pos+=1
      continue
    elseif char ==# '*'
      call add(tokens, {'t': 'highlight', 'g': ''})
      let pos+=1
      continue
    elseif char ==# '#'
      let close=stridx(a:template, '#', pos+1)
      let name=close < 0 ? '' : strpart(a:template, pos+1, close-pos-1)
      if name !~# '^[A-Za-z0-9_.@-]\+$'
        return [[], '%# needs a group name and a closing #']
      endif
      call add(tokens, {'t': 'highlight', 'g': name})
      let pos=close+1
      continue
    elseif char ==# '{'
      let close=stridx(a:template, '}', pos)
      if close < 0
        return [[], 'a %{ without a }']
      endif
      let parts=split(strpart(a:template, pos+1, close-pos-1), ':', 1)
      let name=parts[0]
      let mods=parts[1:]
      let pos=close+1
    elseif char =~# '^[rgbaxXt]$'
      let name=char
      let pos+=1
      while 1
        let mod=matchstr(a:template, '^:\zs\%(\a\|\.\d\+\)', pos)
        if empty(mod)
          break
        endif
        call add(mods, mod)
        let pos+=len(mod)+1
      endwhile
    else
      return [[], '%'.char.' is '.(char =~# '^\a$' ? 'reserved'
\                                                   : 'not known')]
    endif
    let [items, why]=s:Item(name, mods)
    if why !=# ''
      return [[], why]
    endif
    call extend(ingroup ? group : tokens, items)
  endwhile
  if ingroup
    return [[], 'a %( without a %)']
  endif
  return [tokens, '']
endfunction

let s:templates={}

function s:Template(template)
  if !has_key(s:templates, a:template)
    if len(s:templates) > 100
      let s:templates={}
    endif
    let s:templates[a:template]=s:ParseTemplate(a:template)
  endif
  return s:templates[a:template]
endfunction

"a number without trailing zeros, as a:fraction with a:decimals at most
function s:Decimal(number, decimals)
  let text=printf('%.'.a:decimals.'f', a:number)
  return a:decimals > 0 ? substitute(text, '\.\?0\+$', '', '') : text
endfunction

"a:text without a minus if it is a zero, as rounding can make it
function s:Unsigned(text)
  return substitute(a:text, '^-\(0\+\(\.0\+\)\?\)$', '\1', '')
endfunction

"[hue in degrees, saturation, lightness] and so on, 0 to 1 except the hue, of
"a:color, as {'hsl': [...], ...}, by the models of s:models
function s:Models(color)
  let [r, g, b]=map(a:color[:2], 'float2nr(round(v:val))')
  let high=max([r, g, b])
  let low=min([r, g, b])
  let delta=high-low
  if delta == 0
    let hue=0.0
  elseif high == r
    let hue=60.0*(g-b)/delta
  elseif high == g
    let hue=60.0*((b-r)/(delta+0.0)+2)
  else
    let hue=60.0*((r-g)/(delta+0.0)+4)
  endif
  let hue=hue < 0 ? hue+360 : hue
  let lightness=(high+low)/510.0
  let chroma=255.0-abs(high+low-255)
  let cyan=high == 0 ? 0.0 : (high-r)/(high+0.0)
  let magenta=high == 0 ? 0.0 : (high-g)/(high+0.0)
  let yellow=high == 0 ? 0.0 : (high-b)/(high+0.0)
  return {'rgb': [r, g, b],
\         'hsl': [hue, delta == 0 ? 0.0 : delta/chroma, lightness],
\         'hsv': [hue, high == 0 ? 0.0 : delta/(high+0.0), high/255.0],
\         'hwb': [hue, low/255.0, 1-high/255.0],
\         'cmyk': [cyan, magenta, yellow, 1-high/255.0]}
endfunction

"the models of the color last asked for, as [color, s:Models(color)]
let s:models_of=['', {}]

"[number, kind] of the value a:name of a:color, kind being 'byte' for the 0 to
"255 of the channels, 'unit' for a 0 to 1 and 'degrees' for the hue
function s:Quantity(name, color)
  if a:name ==# 'a'
    return [a:color[3], 'unit']
  elseif a:name =~# '^[rgb]$'
    return [a:color[stridx('rgb', a:name)], 'byte']
  endif
  let [model, value]=split(a:name, '\.')
  let key=join(a:color)
  if s:models_of[0] !=# key
    let s:models_of=[key, s:Models(a:color)]
  endif
  let number=s:models_of[1][model][index(s:models[model], value)]
  return [number, value ==# 'h' ? 'degrees' : 'unit']
endfunction

"the text of a number with a:format and a:precision (-1 if none), of the
"kind a:kind, SEE s:Quantity
function s:Format(number, kind, format, precision)
  let fraction=a:kind ==# 'byte' ? a:number/255.0
\            : a:kind ==# 'degrees' ? a:number/360.0 : a:number
  if a:format =~# '[xX]'
    let text=printf('%02x', float2nr(round(fraction*255)))
    return a:format ==# 'X' ? toupper(text) : text
  elseif a:format ==# 'p' || a:format ==# 'P'
    let text=printf('%.'.max([a:precision, 0]).'f', fraction*100)
    return s:Unsigned(text).(a:format ==# 'p' ? '%' : '')
  elseif a:format ==# 'f' || a:kind ==# 'unit' && a:format ==# ''
    return s:Unsigned(a:precision >= 0 ? printf('%.'.a:precision.'f', fraction)
\                                      : s:Decimal(fraction, 2))
  elseif a:kind ==# 'degrees'
    return s:Unsigned(printf('%.'.max([a:precision, 0]).'f', a:number))
  endif
  return string(float2nr(round(a:number)))
endfunction

"the text of a token with a number, of a:color
function s:Number(token, color)
  let [number, kind]=s:Quantity(a:token.n, a:color)
  if a:token.n ==# 'a' && a:token.o && number >= 1.0
    return ''
  endif
  return s:Format(number, kind, a:token.f, a:token.p)
endfunction

"the text of a whole model, a token of the type 'whole', of a:color
function s:Notation(token, color)
  let model=a:token.n
  let numbers=[]
  for index in range(len(s:models[model]))
    let name=model.'.'.s:models[model][index]
    let [number, kind]=s:Quantity(name, a:color)
    call add(numbers, model ==# 'rgb' ? s:Format(number, kind, '', -1)
\      : s:Format(number, kind, kind ==# 'unit' ? 'p' : '', a:token.p))
  endfor
  let alpha=a:color[3]
  let shown=a:token.force || alpha < 1.0
  let text=a:token.p >= 0 ? printf('%.'.a:token.p.'f', alpha)
\                         : s:Decimal(alpha, 2)
  if a:token.comma
    let name=shown && model =~# '^\%(rgb\|hsl\|hsv\)$' ? model.'a' : model
    return name.'('.join(numbers, ', ').(shown ? ', '.text : '').')'
  endif
  return model.'('.join(numbers, ' ').(shown ? ' / '.text : '').')'
endfunction

"the text of a group of items, empty if one of them is
function s:Group(tokens, color, text, id)
  let result=''
  for token in a:tokens
    let part=token.t ==# 'text' ? token.s : s:Piece(token, a:color, a:text,
\                                                    a:id)
    if part ==# ''
      return ''
    endif
    let result.=part
  endfor
  return result
endfunction

"the text of a token that is a value
function s:Piece(token, color, text, id)
  if a:token.t ==# 'whole'
    return s:Notation(a:token, a:color)
  elseif a:token.n ==# 't'
    return a:text
  elseif a:token.n ==# 'id'
    return a:id
  endif
  return s:Number(a:token, a:color)
endfunction

"a piece of a line, a segment, as {'t': its text, 'h': its highlights, each
"[first character, after the last character, group]}, with a:text added in
"the highlight a:group, if any
function s:Add(segment, text, group)
  if a:text ==# ''
    return
  endif
  let first=strchars(a:segment.t)
  let a:segment.t.=a:text
  if a:group !=# ''
    let spans=a:segment.h
    if !empty(spans) && spans[-1][1] == first && spans[-1][2] ==# a:group
      let spans[-1][1]=first+strchars(a:text)
    else
      call add(spans, [first, first+strchars(a:text), a:group])
    endif
  endif
endfunction

"a:template expanded for the color a:color of the code a:text, in the region
"number a:id, as a list of lines, each a list of segments, the pieces
"between the places where it may be broken
function s:Expand(template, color, text, id)
  let lines=[]
  let segments=[{'t': '', 'h': []}]
  let group=''
  for token in s:Template(a:template)[0]
    if token.t ==# 'text'
      call s:Add(segments[-1], token.s, group)
    elseif token.t ==# 'break'
      call add(lines, segments)
      let segments=[{'t': '', 'h': []}]
    elseif token.t ==# 'soft'
      call add(segments, {'t': '', 'h': []})
    elseif token.t ==# 'highlight'
      let group=token.g
    elseif token.t ==# 'group'
      call s:Add(segments[-1], s:Group(token.tokens, a:color, a:text, a:id),
\                group)
    else
      call s:Add(segments[-1], s:Piece(token, a:color, a:text, a:id), group)
    endif
  endfor
  call add(lines, segments)
  return lines
endfunction

"whether a:value is a template or a list of them
function s:Templates(value)
  let list=type(a:value) == v:t_list ? a:value : [a:value]
  for template in list
    if type(template) != v:t_string
      let s:why='not a string'
      return []
    endif
    let why=s:Template(template)[1]
    if why !=# ''
      let s:why=why
      return []
    endif
  endfor
  return [a:value]
endfunction

"short, as a longer message in a cursor movement is truncated by the ruler or
"asks for a keypress
function s:Warn(message)
  echohl WarningMsg
  echom strcharpart(a:message, 0, &columns-22)
  echohl None
endfunction

"set g:pastel_<name> to a:default if it is not set, and have it checked by
"a:Check; a:what says what a valid value is, for the warning
function s:Define(name, default, Check, what)
  let s:defaults[a:name]=a:default
  let s:checks[a:name]=a:Check
  let s:whats[a:name]=a:what
  let g:['pastel_'.a:name]=get(g:, 'pastel_'.a:name, a:default)
endfunction

"the value a:value of the variable a:variable, if valid for the option a:name,
"else a:fallback, with a warning unless this value was already warned about;
"it does not say what is used instead, to leave room for what is wrong
function s:Checked(name, variable, value, fallback)
  let s:why=''
  let checked=s:checks[a:name](a:value)
  if !empty(checked)
    return checked[0]
  endif
  if get(s:invalid, a:variable, '') !=# string(a:value)
    let s:invalid[a:variable]=string(a:value)
    if s:why !=# ''
      call s:Warn('pastel: '.a:variable.': '.s:why)
    else
      call s:Warn('pastel: '.a:variable.' '
\                 .strcharpart(string(a:value), 0, 20)
\                 .' is not '.s:whats[a:name])
    endif
  endif
  return a:fallback
endfunction

"the options that b:pastel_<name> overrides in a buffer; not the layout and
"the colors, as there is only one popup, shared by all buffers
let s:buffer_local=['alpha_position', 'alpha_first_filetypes',
\                   'ignore_filetypes', 'color_timer', 'color_size',
\                   'bg_size', 'offset_x', 'offset_y', 'detail_format']

"the value of the option g:pastel_<name>, or of b:pastel_<name> if the buffer
"has a valid one; an invalid one leaves the global value in effect
function s:Opt(name)
  let value=s:Checked(a:name, 'g:pastel_'.a:name,
\                     get(g:, 'pastel_'.a:name, s:defaults[a:name]),
\                     s:defaults[a:name])
  if exists('b:pastel_'.a:name) && index(s:buffer_local, a:name) >= 0
    return s:Checked(a:name, 'b:pastel_'.a:name, b:['pastel_'.a:name], value)
  endif
  return value
endfunction

"options
"a definition of color blocks to show, from left to right
"  combination of the following as a string:
"  w - color on white background
"  k - color on black background
"  t - color on checkered "transparent" background
"  2 - k and w alternating
"  3 - k, t and w alternating (in that order)
"  d - details: text, SEE g:pastel_detail_format; d cells next to each other
"      are one region, which must be a rectangle, and grows to the right and
"      down, if there is room, to fit its text
"  . - separates what is on its two sides: d cells there are not one region;
"      it has no size; a row of it alone, between rows, is an unsized row
"  | - put the blocks following it in a new row
"
"blocks are of the same size (see below), each with its own margin
" "t" is sharkdp/pastel's look,
" other suggested combinations are "k", "2t", "t|kw" and "3"
let g:pastel_color_mode=get(g:, 'pastel_color_mode', 't')

"alternate between backgrounds every n seconds in "2" and "3" blocks, 0.1 or
"more; less than that turns alternating off, showing the first background
call s:Define('color_timer', 5, function('s:Seconds'), 'a number')

"what the detail regions, the d cells of g:pastel_color_mode, show: a template
"(SEE above), for the first region, or a list of them, one for each; a region
"without one shows its number and the color
call s:Define('detail_format', '%x', function('s:Templates'),
\             'a format or a list of them')

"where the alpha is in 8-digit hexadecimal codes:
"  last  - #RRGGBBAA, as in CSS
"  first - #AARRGGBB, as in Android
"  auto  - first in the filetypes listed below, last in the others, with a
"          one-time note per buffer about the guess
"4-digit codes are always #RGBA
call s:Define('alpha_position', 'auto',
\             {value -> s:OneOf(value, ['auto', 'first', 'last'])},
\             'auto, first or last')
call s:Define('alpha_first_filetypes', ['java', 'kotlin'],
\             function('s:Strings'), 'a list of strings')

"filetypes where no colors are looked for, as glob patterns: sql and its
"variants for their very long lines, gitcommit where #123 is an issue and not
"a color; lines longer than 'synmaxcol' are never looked at, if it is not 0
call s:Define('ignore_filetypes', ['gitcommit', '*sql*'],
\             function('s:Strings'), 'a list of strings')

"size is measured vertically in half-chars, horizontally in chars
"6/2 is how sharkdp/pastel looks
call s:Define('color_size', 6, {value -> s:Whole(value, 1, 1000)}, '1..1000')
call s:Define('bg_size', 2, {value -> s:Whole(value, 0, 1000)}, '0..1000')

"popup placement relative to the color code, in characters; positive means
"right/below, negative left/above, 0 centered; if the popup would not fit
"on the screen, the offset is inverted
"  x: 2 puts the popup's left edge 2 columns after the code's last column
"  y: 0 centers the popup on the cursor line
call s:Define('offset_x', 2, function('s:Offset'), 'a whole number')
call s:Define('offset_y', 0, function('s:Offset'), 'a whole number')

"these are better left alone but you may want to change trans colors
call s:Define('white_bg', '#FFFFFF', function('s:ColorOption'), 'a color')
"75% gray
call s:Define('trans_fg', '#BFBFBF', function('s:ColorOption'), 'a color')
"25% gray
call s:Define('trans_bg', '#404040', function('s:ColorOption'), 'a color')
call s:Define('black_bg', '#000000', function('s:ColorOption'), 'a color')

"[regions, owners, why] of the d cells of a layout: the regions are lists of
"their [row, column] cells in reading order, as {'id', 'r0', 'c0', 'r1', 'c1'}
"rectangles, the owners are the region numbers by 'row,column' of their
"cells; cells in contact, not through a break (a:hbreak[row][column] is
"whether there is one after the cell, a:vbreak[row] whether there is one
"before the row), are one region; why is '' if they are all rectangles
function s:Regions(rows, hbreak, vbreak)
  let regions=[]
  let owners={}
  for row in range(len(a:rows))
    for col in range(len(a:rows[row]))
      if a:rows[row][col] !=# 'd' || has_key(owners, row.','.col)
        continue
      endif
      let id=len(regions)+1
      let cells=[]
      let todo=[[row, col]]
      let owners[row.','.col]=id
      while !empty(todo)
        let [r, c]=remove(todo, -1)
        call add(cells, [r, c])
        let next=[]
        if c+1 < len(a:rows[r]) && !a:hbreak[r][c]
          call add(next, [r, c+1])
        endif
        if c > 0 && !a:hbreak[r][c-1]
          call add(next, [r, c-1])
        endif
        if r+1 < len(a:rows) && c < len(a:rows[r+1]) && !a:vbreak[r+1]
          call add(next, [r+1, c])
        endif
        if r > 0 && c < len(a:rows[r-1]) && !a:vbreak[r]
          call add(next, [r-1, c])
        endif
        for [nr, nc] in next
          if a:rows[nr][nc] ==# 'd' && !has_key(owners, nr.','.nc)
            let owners[nr.','.nc]=id
            call add(todo, [nr, nc])
          endif
        endfor
      endwhile
      let rs=map(copy(cells), 'v:val[0]')
      let cs=map(copy(cells), 'v:val[1]')
      let region={'id': id, 'r0': min(rs), 'c0': min(cs), 'r1': max(rs),
\                 'c1': max(cs)}
      if len(cells) != (region.r1-region.r0+1)*(region.c1-region.c0+1)
        return [[], {}, 'the d cells from row '.(region.r0+1).', column '
\               .(region.c0+1).' are not a rectangle; separate them with a .'
\               .' or a row of only .']
      endif
      call add(regions, region)
    endfor
  endfor
  return [regions, owners, '']
endfunction

"the layout of a g:pastel_color_mode value, as a dict: 'rows' are the cells of
"each row, a list of w, k, t, 2, 3 and d, 'regions' and 'owners' those of the
"d cells (SEE s:Regions), 'hbreak' and 'vbreak' the breaks (the same), and
"'alternating' whether there are 2 or 3 cells; empty (and a warning is shown)
"if the value is not supported
function s:ParseLayout(mode)
  let why=''
  if string(a:mode) !~# '^''[wkt23d.]\+\(|[wkt23d.]\+\)*''$'
    let why=', only w, k, t, 2, 3, d, . and | (not leading, trailing or'
\          .' doubled) are supported'
    if string(a:mode) =~# 'b'
      let why.=' (the black block was renamed from b to k)'
    endif
  else
    let lines=split(a:mode, '|')
    if lines[0] =~# '^\.\+$' || lines[-1] =~# '^\.\+$'
      let why=', a row of only . cannot be the first or the last'
    endif
  endif
  if why ==# ''
    let rows=[]
    let hbreak=[]
    let vbreak=[]
    let pending=0
    for line in split(a:mode, '|')
      if line =~# '^\.\+$'
        let pending=1
        continue
      endif
      let cells=[]
      let breaks=[]
      for char in split(line, '\zs')
        if char !=# '.'
          call add(cells, char)
          call add(breaks, 0)
        elseif !empty(breaks)
          let breaks[-1]=1
        endif
      endfor
      call add(rows, cells)
      call add(hbreak, breaks)
      call add(vbreak, pending)
      let pending=0
    endfor
    let [regions, owners, why]=s:Regions(rows, hbreak, vbreak)
    if why !=# ''
      let why=', '.why
    else
      return {'rows': rows, 'regions': regions, 'owners': owners,
\              'hbreak': hbreak, 'vbreak': vbreak,
\              'alternating': string(rows) =~# '[23]'}
    endif
  endif
  echohl WarningMsg
  echom 'pastel: unsupported g:pastel_color_mode '.string(a:mode).why
  echohl None
  return {}
endfunction

let s:layout=s:ParseLayout(g:pastel_color_mode)
if empty(s:layout)
  finish
endif
"the value s:layout was made from
let s:mode=g:pastel_color_mode

"follow changes of g:pastel_color_mode; an unsupported value is warned about
"once and the previous layout stays
function s:UpdateLayout()
  if string(g:pastel_color_mode) !=# string(s:mode)
    let s:mode=g:pastel_color_mode
    let layout=s:ParseLayout(s:mode)
    if !empty(layout)
      let s:layout=layout
    endif
  endif
endfunction

"the popup is drawn as a grid of pixels, a pixel being 1 column wide and half
"a line high; each pixel has one of these colors:
"  k - black, w - white, d - dark and l - light checker,
"  1, 2, 3 and 4 - the color shown, on the background k, w, d or l,
"  n - none, the default color, only used to pad an odd height to full lines,
"  e - the same, but in a detail region, so it is not transparent
"a character cell is 2 pixels high, drawn as a space if both have the same
"color and as an upper half block (fg: upper, bg: lower) if they differ
let s:colors=['k', 'w', 'd', 'l', '1', '2', '3', '4', 'n']
"the pixel showing the color on a background, by the background's letter
let s:over={'k': '1', 'w': '2', 'd': '3', 'l': '4'}
"you should not see this, ever
let s:color=[255, 0, 255, 1.0]
"the colors of the pixels, by their letters above
let s:hex={}

"a color, [red, green, blue, alpha], with the channels 0 to 255 and the alpha
"0.0 to 1.0, as a #RRGGBB string
function s:ToHex(color)
  return printf('#%02X%02X%02X', a:color[0], a:color[1], a:color[2])
endfunction

"a:color shown over a:background, a #rrggbb color, as a #RRGGBB string; the
"alpha is ignored if the background is not a #rrggbb color
function s:Blend(color, background)
  let alpha=a:color[3]
  if alpha >= 1.0 || a:background !~? '^#\x\{6}$'
    return s:ToHex(a:color)
  endif
  let blended=[]
  for i in range(3)
    let over=a:color[i]
    let under=str2nr(a:background[2*i+1:2*i+2], 16)
    call add(blended, float2nr(round(alpha*over+(1-alpha)*under)))
  endfor
  return s:ToHex(blended)
endfunction

function s:UpdateHex()
  let s:hex={'k': s:Opt('black_bg'), 'w': s:Opt('white_bg'),
\            'd': s:Opt('trans_bg'), 'l': s:Opt('trans_fg'), 'n': 'NONE',
\            'e': 'NONE'}
  for background in ['k', 'w', 'd', 'l']
    let s:hex[s:over[background]]=s:Blend(s:color, s:hex[background])
  endfor
endfunction

function s:DefineHighlight(upper, lower)
  execute 'highlight pastelp'.a:upper.a:lower
\         .' guifg='.s:hex[a:upper].' guibg='.s:hex[a:lower]
endfunction

"the values of the color options the highlight groups were made from
let s:colorkey=''

function s:ColorKey()
  return join([s:Opt('black_bg'), s:Opt('white_bg'), s:Opt('trans_bg'),
\              s:Opt('trans_fg')])
endfunction

function s:DefineHighlights()
  highlight default link PastelDetail Normal
  let s:dynamic_for={}
  let s:colorkey=s:ColorKey()
  call s:UpdateHex()
  for upper in s:colors
    for lower in s:colors
      call s:DefineHighlight(upper, lower)
    endfor
  endfor
endfunction

function s:SetupPopupHilightStyles()
  call s:DefineHighlights()
  for upper in s:colors
    for lower in s:colors
      let name='pastelp'.upper.lower
      call prop_type_add(name, {'highlight': name})
    endfor
  endfor
  call prop_type_add('pasteldetail', {'highlight': 'PastelDetail'})
endfunction

"make a:color, a [red, green, blue, alpha] list, the color shown
function s:SetColor(color)
  if a:color == s:color
    return
  endif
  let s:color=a:color
  call s:UpdateHex()
  for upper in s:colors
    for lower in s:colors
      if upper =~ '\d' || lower =~ '\d'
        call s:DefineHighlight(upper, lower)
      endif
    endfor
  endfor
endfunction

"the margin and the color's size, g:pastel_bg_size and g:pastel_color_size,
"read once per drawing, as they are needed for every pixel
let s:margin=0
let s:inner=0

function s:ReadSizes()
  let s:margin=s:Opt('bg_size')
  let s:inner=s:Opt('color_size')
endfunction

"size of a block in pixels, both ways
function s:BlockSize()
  return 2*s:margin+s:inner
endfunction

"color of pixel (a:x, a:y), counted from 0 from the popup's top left; pixels
"outside the blocks, and so the padding of an odd height, are default colored
"how many timer ticks the alternating blocks have advanced
let s:phase=0

"the background, w, k or t, of a block of g:pastel_color_mode
function s:Background(block)
  if a:block == '2'
    return ['k', 'w'][s:phase % 2]
  elseif a:block == '3'
    return ['k', 't', 'w'][s:phase % 3]
  endif
  return a:block
endfunction

function s:Pixel(x, y)
  for area in s:frame.areas
    if a:x >= area[0] && a:x < area[1] && a:y >= area[2] && a:y < area[3]
      return 'e'
    endif
  endfor
  let bg=s:margin
  let size=s:inner
  let block=s:BlockSize()
  let row=a:y / block
  let col=a:x / block
  if row >= len(s:layout.rows) || col >= len(s:layout.rows[row])
    return 'n'
  endif
  let x=a:x % block
  let y=a:y % block
  let background=s:Background(s:layout.rows[row][col])
  if background == 't'
    let pixel=(x+y) % 2 ? 'd' : 'l'
  else
    let pixel=background == 'w' ? 'w' : 'k'
  endif
  if x >= bg && x < bg+size && y >= bg && y < bg+size
    return s:over[pixel]
  endif
  return pixel
endfunction

"what is shown for the detail regions, as built by s:BuildFrame: the regions,
"the pixel rectangles [x0, x1, y0, y1) they cover, the popup's size
let s:frame={'regions': [], 'areas': [], 'width': 0, 'lines': 0}
"the text of the color code the frame was built for
let s:detail_text=''

"[columns, lines] of the popup; an odd height in pixels gets an extra row of
"default colored pixels at the bottom, and the detail regions may have made
"it larger
function s:Size()
  return [s:frame.width, s:frame.lines]
endfunction

"a:line, a segment (SEE s:Add), cut to fit a:width cells, with an ellipsis,
"in the highlight of what it follows, if it was cut
function s:Ellipsize(line, width)
  if strdisplaywidth(a:line.t) <= a:width
    return a:line
  elseif a:width <= 0
    return {'t': '', 'h': []}
  endif
  let keep=a:width-1
  let spans=[]
  for span in a:line.h
    if span[0] < keep
      call add(spans, [span[0], min([span[1], keep]), span[2]])
    endif
  endfor
  if !empty(spans) && spans[-1][1] == keep
    let spans[-1][1]=keep+1
  endif
  return {'t': strcharpart(a:line.t, 0, keep).'…', 'h': spans}
endfunction

"a:line with an ellipsis added, in the highlight of its end, cut to a:width
function s:Ellipsis(line, width)
  let spans=deepcopy(a:line.h)
  if !empty(spans) && spans[-1][1] == strchars(a:line.t)
    let spans[-1][1]+=1
  endif
  return s:Ellipsize({'t': a:line.t.'…', 'h': spans}, a:width)
endfunction

"the segment of the segments a:first and a:second one after the other
function s:Join(first, second)
  let shift=strchars(a:first.t)
  let spans=deepcopy(a:first.h)
  for span in a:second.h
    call add(spans, [span[0]+shift, span[1]+shift, span[2]])
  endfor
  return {'t': a:first.t.a:second.t, 'h': spans}
endfunction

"the lines, each a segment, of a:segments, the lines of a template expanded,
"each a list of segments, as fit a:width cells: segments are put on a line as
"long as they fit, so a line is only broken where it is permitted
function s:Wrap(segments, width)
  let lines=[]
  for line in a:segments
    let current={'t': '', 'h': []}
    for segment in line
      if current.t ==# ''
        let current=segment
      elseif strdisplaywidth(current.t)+strdisplaywidth(segment.t) <= a:width
        let current=s:Join(current, segment)
      else
        call add(lines, current)
        let current=segment
      endif
    endfor
    call add(lines, current)
  endfor
  return map(lines, 's:Ellipsize(v:val, a:width)')
endfunction

"the template of the detail region number a:id of a:count: the one of
"g:pastel_detail_format if it is a string and the region the first, or the
"entry of the list, else the one telling the number and the color
function s:RegionTemplate(id, count)
  let format=s:Opt('detail_format')
  if type(format) == v:t_string
    return a:id == 1 ? format : s:fallback
  endif
  return a:id <= len(format) ? format[a:id-1] : s:fallback
endfunction

"the frame for the code a:text of the color a:color: what the detail regions
"show and how large they are, as a dict, SEE s:frame
"a region has as much room as the cells it is made of, in whole lines: those
"of which both pixels are in the cells, so not one shared with another row;
"where the text needs more, it grows to the right, by as many whole blocks as
"it needs, into what is not covered by a cell or another region, then down
"likewise, all the regions to the right before any is grown down, each in
"reading order, but not past a break; it is cut, with an ellipsis, where it
"can not grow
function s:BuildFrame(color, text)
  let rows=s:layout.rows
  let block=s:BlockSize()
  let frame={'regions': [], 'areas': [],
\           'width': max(map(copy(rows), 'len(v:val)'))*block,
\           'lines': (len(rows)*block+1)/2}
  if empty(s:layout.regions)
    return frame
  endif
  "[x0, x1, y0, y1, owner] rectangles in pixels that are taken, owner being
  "the number of the region (0 for the other cells)
  let claims=[]
  for row in range(len(rows))
    for col in range(len(rows[row]))
      call add(claims, [col*block, (col+1)*block, row*block, (row+1)*block,
\                       get(s:layout.owners, row.','.col, 0)])
    endfor
  endfor
  let total=len(s:layout.regions)
  for region in s:layout.regions
    let y1=(region.r1+1)*block
    call add(frame.regions, {'id': region.id, 'x0': region.c0*block,
\      'x1': (region.c1+1)*block, 'y0': region.r0*block, 'y1': y1,
\      'ks': (region.r0*block+1)/2,
\      'ke': y1/2,
\      'segments': s:Expand(s:RegionTemplate(region.id, total), a:color,
\                           a:text, region.id)})
  endfor
  "to the right, as far as the longest piece of the text that can not be broken
  for reg in frame.regions
    let need=0
    for line in reg.segments
      for segment in line
        let need=max([need, strdisplaywidth(segment.t)])
      endfor
    endfor
    "in whole blocks, as a region only takes the cells it needs, not a part
    let grow=(max([need-(reg.x1-reg.x0), 0])+block-1)/block
    let region=s:layout.regions[reg.id-1]
    for row in range(region.r0, region.r1)
      if s:layout.hbreak[row][region.c1]
        let grow=0
      endif
    endfor
    for claim in claims
      if grow > 0 && claim[4] != reg.id && claim[0] >= reg.x1
\       && claim[2] < reg.y1 && claim[3] > reg.y0
        let grow=min([grow, (claim[0]-reg.x1)/block])
      endif
    endfor
    if grow > 0
      call add(claims, [reg.x1, reg.x1+grow*block, reg.y0, reg.y1, reg.id])
      let reg.x1+=grow*block
    endif
    let reg.lines=s:Wrap(reg.segments, reg.x1-reg.x0)
  endfor
  "then down, as far as the lines need
  for reg in frame.regions
    "in whole blocks, as to the right
    let more=max([len(reg.lines)-max([reg.ke-reg.ks, 0]), 0])
    let more=(2*more+block-1)/block
    let edge=reg.y1
    let below=s:layout.regions[reg.id-1].r1+1
    if below < len(rows) && s:layout.vbreak[below]
      let more=0
    endif
    for claim in claims
      if more > 0 && claim[4] != reg.id && claim[2] >= edge
\       && claim[0] < reg.x1 && claim[1] > reg.x0
        let more=min([more, (claim[2]-edge)/block])
      endif
    endfor
    if more > 0
      call add(claims, [reg.x0, reg.x1, edge, edge+more*block, reg.id])
      let reg.y1+=more*block
      let reg.ke=reg.y1/2
    endif
    let fit=max([reg.ke-reg.ks, 0])
    if len(reg.lines) > fit
      let reg.lines=fit > 0 ? reg.lines[:fit-1] : []
      if fit > 0
        let reg.lines[-1]=s:Ellipsis(reg.lines[-1], reg.x1-reg.x0)
      endif
    endif
    let frame.lines=max([frame.lines, reg.ke])
  endfor
  for claim in claims
    if claim[4] > 0
      call add(frame.areas, claim[:3])
      let frame.width=max([frame.width, claim[1]])
      let frame.lines=max([frame.lines, (claim[3]+1)/2])
    endif
  endfor
  return frame
endfunction

"popup masks, which make the area no block covers transparent, need this;
"without them the text under that area is hidden
let s:has_mask=has('patch-8.1.1580')

"[col, endcol, line, endline] rectangles for the popup's mask, covering the
"character cells without any pixels, so that the text under them is not hidden;
"a run of such cells is added to the rectangle above it if it spans the same
"columns
function s:AddEmptyCells(rects, line, from, to)
  for rect in a:rects
    if rect[0] == a:from && rect[1] == a:to && rect[3] == a:line-1
      let rect[3]=a:line
      return
    endif
  endfor
  call add(a:rects, [a:from, a:to, a:line, a:line])
endfunction

"the swatch colors of the highlight groups that are defined as the color
"changes, by name: the red, green and blue of the color alone, their inverses
"(cyan, magenta and yellow, as additive colors) and its alpha as a gray
let s:dynamic={
\ 'PastelRed': {c -> [c[0], 0, 0]}, 'PastelGreen': {c -> [0, c[1], 0]},
\ 'PastelBlue': {c -> [0, 0, c[2]]},
\ 'PastelCyan': {c -> [0, 255-c[0], 255-c[0]]},
\ 'PastelMagenta': {c -> [255-c[1], 0, 255-c[1]]},
\ 'PastelYellow': {c -> [255-c[2], 255-c[2], 0]},
\ 'PastelAlpha': {c -> repeat([float2nr(round(c[3]*255))], 3)}}
"the colors the dynamic groups were last defined for, by name
let s:dynamic_for={}

"define the dynamic highlight group a:name for the color shown: the swatch is
"its background, and the text black or white, whichever is easier to read
function s:DefineDynamic(name)
  let key=join(s:color)
  if get(s:dynamic_for, a:name, '') ==# key
    return
  endif
  let s:dynamic_for[a:name]=key
  let swatch=s:dynamic[a:name](s:color)
  let luma=0.299*swatch[0]+0.587*swatch[1]+0.114*swatch[2]
  execute 'highlight '.a:name.' guibg='.s:ToHex(swatch)
\         .' guifg='.(luma < 127.5 ? '#FFFFFF' : '#000000')
endfunction

"the groups of templates that do not exist, warned about once
let s:missing={}

"the name of the text property type for text highlighted with a:group, ''
"being the detail text's own
function s:PropType(group)
  if a:group ==# ''
    return 'pasteldetail'
  elseif has_key(s:dynamic, a:group)
    call s:DefineDynamic(a:group)
  elseif !hlexists(a:group)
    if !has_key(s:missing, a:group)
      let s:missing[a:group]=1
      call s:Warn('pastel: no highlight group '.a:group)
    endif
    return 'pasteldetail'
  endif
  let type='pasteldetail:'.a:group
  if empty(prop_type_get(type))
    call prop_type_add(type, {'highlight': a:group})
  endif
  return type
endfunction

function s:SetPopupContent(popup)
  "what is beyond the screen is never seen, so the work is limited to it, as
  "sizes can be so large that drawing them all would hang Vim
  let [width, lines]=s:Size()
  let width=min([width, &columns])
  let lines=min([lines, &lines])
  let popuptext=[]
  let mask=[]
  for line in range(lines)
    "the characters of the detail regions' text on this line, by column
    let detail={}
    for reg in s:frame.regions
      if line >= reg.ks && line < reg.ke
        let shown=get(reg.lines, line-reg.ks, {'t': '', 'h': []})
        let chars=split(shown.t, '\zs')
        let groups=repeat([''], len(chars))
        for span in shown.h
          for index in range(span[0], span[1]-1)
            let groups[index]=span[2]
          endfor
        endfor
        for x in range(max([0, min([reg.x1, width])-reg.x0]))
          let detail[reg.x0+x]=[get(chars, x, ' '), get(groups, x, '')]
        endfor
      endif
    endfor
    let text=''
    let props=[]
    let runstart=0
    for x in range(width)
      if has_key(detail, x)
        let char=detail[x][0]
        let type=s:PropType(detail[x][1])
        let blank=0
      else
        let upper=s:Pixel(x, 2*line)
        let lower=s:Pixel(x, 2*line+1)
        let char=s:hex[upper] ==? s:hex[lower] ? ' ' : '▀'
        let type='pastelp'.(upper ==# 'e' ? 'n' : upper)
\                        .(lower ==# 'e' ? 'n' : lower)
        let blank=upper == 'n' && lower == 'n'
      endif
      if !empty(props) && props[-1].type == type
        let props[-1].length+=len(char)
      else
        call add(props, {'col': len(text)+1, 'length': len(char),
\                        'type': type})
      endif
      let text.=char
      if blank
        let runstart=runstart ? runstart : x+1
      elseif runstart
        call s:AddEmptyCells(mask, line+1, runstart, x)
        let runstart=0
      endif
    endfor
    if runstart
      call s:AddEmptyCells(mask, line+1, runstart, width)
    endif
    call add(popuptext, {'text': text, 'props': props})
  endfor
  call popup_settext(a:popup, popuptext)
  if s:has_mask
    call popup_setoptions(a:popup, {'mask': mask})
  endif
endfunction

"whether 8-digit codes in this buffer have the alpha first; if that is
"guessed, say so once per buffer
function s:AlphaFirst()
  let setting=s:Opt('alpha_position')
  if setting ==# 'first'
    return 1
  elseif setting !=# 'auto'
    return 0
  endif
  let filetypes=split(&filetype, '\.')
  let known=s:Opt('alpha_first_filetypes')
  let first=!empty(filter(filetypes,
\                        {_, filetype -> index(known, filetype) >= 0}))
  if !exists('b:pastel_alpha_noted')
    let b:pastel_alpha_noted=1
    let message='pastel: assuming '.(first ? '#AARRGGBB' : '#RRGGBBAA')
\               .', see README'
    call s:Warn(message)
  endif
  return first
endfunction

"the color of a #rgb, #rgba, #rrggbb or #rrggbbaa code, as [red, green, blue,
"alpha]
function s:ParseHex(code)
  let digits=a:code[1:]
  let alphafirst=0
  if len(digits) == 4 || len(digits) == 8
    let alphafirst=len(digits) == 8 && s:AlphaFirst()
  endif
  if len(digits) <= 4
    let digits=join(map(split(digits, '\zs'), 'v:val.v:val'), '')
  elseif alphafirst
    let digits=digits[2:].digits[:1]
  endif
  let color=map(range(3), 'str2nr(digits[2*v:val:2*v:val+1], 16)')
  let alpha=len(digits) == 8 ? str2nr(digits[6:7], 16)/255.0 : 1.0
  return color+[alpha]
endfunction

"a:value, a number or a float, limited to a:low to a:high
function s:Clamp(value, low, high)
  return a:value < a:low ? a:low : a:value > a:high ? a:high : a:value
endfunction

"[value, unit] of a:token, a CSS number with an optional unit (%, deg, grad,
"rad or turn), with the unit in lower case, or [0.0, 'none'] for the keyword
"none, or [] if it is neither
function s:CssToken(token)
  let number='[+-]\=\%(\d\+\%(\.\d\+\)\=\|\.\d\+\)\%(e[+-]\=\d\+\)\='
  let found=matchlist(a:token,
\                     '\c^\('.number.'\)\(%\|deg\|grad\|rad\|turn\)\=$')
  if !empty(found)
    return [str2float(found[1]), tolower(found[2])]
  endif
  return a:token ==? 'none' ? [0.0, 'none'] : []
endfunction

"a red, green or blue channel, 0 to 255, of a CSS token, or -1 if it is no
"channel
function s:CssChannel(token)
  let [value, unit]=a:token
  if unit == '%'
    let value=value*255/100.0
  elseif unit != '' && unit != 'none'
    return -1
  endif
  return float2nr(round(s:Clamp(value, 0.0, 255.0)))
endfunction

"a hue, 0.0 up to 360.0, of a CSS token, or -1.0 if it is no hue
function s:CssHue(token)
  let [value, unit]=a:token
  if unit == 'grad'
    let value=value*0.9
  elseif unit == 'rad'
    let value=value*180/(4*atan(1.0))
  elseif unit == 'turn'
    let value=value*360
  elseif unit != '' && unit != 'deg' && unit != 'none'
    return -1.0
  endif
  let hue=fmod(value, 360.0)
  return hue < 0 ? hue+360 : hue
endfunction

"a saturation, lightness, whiteness, blackness or value, 0.0 to 1.0, of a CSS
"token, or -1.0 if it is no such thing; a plain number is a percentage if
"a:plain is 100.0, and a fraction if it is 1.0
function s:CssFraction(token, plain)
  let [value, unit]=a:token
  if unit == '%'
    return s:Clamp(value/100, 0.0, 1.0)
  elseif unit != '' && unit != 'none'
    return -1.0
  endif
  return s:Clamp(value/a:plain, 0.0, 1.0)
endfunction

"the 0 to 255 channels of a:fractions, [red, green, blue] from 0.0 to 1.0
function s:Channels(fractions)
  return map(copy(a:fractions), 'float2nr(round(v:val*255))')
endfunction

"the color of the hue a:hue (0.0 up to 360.0), saturation a:saturation and
"lightness a:lightness (both 0.0 to 1.0), as [red, green, blue] from 0.0 to 1.0
function s:HslToFractions(hue, saturation, lightness)
  let range=a:saturation*(a:lightness < 0.5 ? a:lightness : 1-a:lightness)
  let color=[]
  for offset in [0, 8, 4]
    let k=fmod(offset+a:hue/30, 12.0)
    let ramp=k-3
    if 9-k < ramp
      let ramp=9-k
    endif
    let ramp=s:Clamp(ramp, -1.0, 1.0)
    call add(color, a:lightness-range*ramp)
  endfor
  return color
endfunction

"the color of the hue a:hue (0.0 up to 360.0), whiteness a:whiteness and
"blackness a:blackness (both 0.0 to 1.0), as [red, green, blue]; if they
"add up to 1.0 or more, it is a gray
function s:HwbToRgb(hue, whiteness, blackness)
  let total=a:whiteness+a:blackness
  if total >= 1
    return s:Channels(repeat([a:whiteness/total], 3))
  endif
  let color=[]
  for fraction in s:HslToFractions(a:hue, 1.0, 0.5)
    call add(color, fraction*(1-total)+a:whiteness)
  endfor
  return s:Channels(color)
endfunction

"the color of the hue a:hue (0.0 up to 360.0), saturation a:saturation and
"value a:value (both 0.0 to 1.0), as [red, green, blue]
function s:HsvToRgb(hue, saturation, value)
  let color=[]
  for offset in [5, 3, 1]
    let k=fmod(offset+a:hue/60, 6.0)
    let ramp=k
    if 4-k < ramp
      let ramp=4-k
    endif
    let ramp=s:Clamp(ramp, 0.0, 1.0)
    call add(color, a:value-a:value*a:saturation*ramp)
  endfor
  return s:Channels(color)
endfunction

"the color of a CSS rgb(), rgba(), hsl(), hsla(), hwb() or hwba() function, or
"a Less hsv() or hsva() one, in the comma notation or the space and slash one,
"as [red, green, blue, alpha], or [] if it is not valid; hwb() has no comma
"notation, as in CSS
function s:ParseCss(text)
  let found=matchlist(a:text,
\                     '\c^\(rgba\=\|hsla\=\|hwba\=\|hsva\=\)(\(.*\))$')
  if empty(found)
    return []
  endif
  let kind=substitute(tolower(found[1]), 'a$', '', '')
  let args=trim(found[2])
  let alpha=''
  if args =~ ','
    if kind == 'hwb' || args =~ '/' || args =~? 'none'
      return []
    endif
    let parts=map(split(args, ',', 1), 'trim(v:val)')
    if len(parts) < 3 || len(parts) > 4
      return []
    endif
    let channels=parts[:2]
    let alpha=get(parts, 3, '')
  else
    let sides=split(args, '/', 1)
    if len(sides) > 2
      return []
    endif
    let channels=split(sides[0])
    let alpha=len(sides) == 2 ? trim(sides[1]) : ''
    if len(sides) == 2 && alpha == ''
      return []
    endif
  endif
  if len(channels) != 3
    return []
  endif
  let tokens=map(copy(channels), 's:CssToken(v:val)')
  if index(tokens, []) >= 0
    return []
  endif
  let opacity=1.0
  if alpha != ''
    let token=s:CssToken(alpha)
    if empty(token) || token[1] != '' && token[1] != '%' && token[1] != 'none'
      return []
    endif
    let opacity=s:Clamp(token[1] == '%' ? token[0]/100 : token[0], 0.0, 1.0)
  endif
  if kind == 'rgb'
    let color=map(copy(tokens), 's:CssChannel(v:val)')
    return index(color, -1) >= 0 ? [] : color+[opacity]
  endif
  let hue=s:CssHue(tokens[0])
  let plain=kind == 'hsv' ? 1.0 : 100.0
  let second=s:CssFraction(tokens[1], plain)
  let third=s:CssFraction(tokens[2], plain)
  if hue < 0 || second < 0 || third < 0
    return []
  elseif kind == 'hsl'
    return s:Channels(s:HslToFractions(hue, second, third))+[opacity]
  elseif kind == 'hwb'
    return s:HwbToRgb(hue, second, third)+[opacity]
  endif
  return s:HsvToRgb(hue, second, third)+[opacity]
endfunction

"the notations of colors: the pattern finding them in a line, and the parser
"getting a found text's color, [red, green, blue, alpha], or [] if it is not
"one after all
let s:formats=[
\ {'pattern': '\v(\w)@<!#(\x{8}|\x{6}|\x{4}|\x{3})\w@!',
\  'parse': function('s:ParseHex')},
\ {'pattern': '\c\v(\w)@<!(rgba?|hsla?|hwba?|hsva?)\([^()]*\)',
\  'parse': function('s:ParseCss')},
\]

"whether not to look for colors on the current line: in a closed fold, in the
"filetypes matching g:pastel_ignore_filetypes, and on lines longer than
"'synmaxcol', as looking through a very long line at every cursor movement
"would be slow; checked before reading the line, which would copy it
function s:Ignored()
  "the code is not displayed in a closed fold
  if foldclosed('.') >= 0
    return 1
  endif
  for filetype in split(&filetype, '\.')
    for pattern in s:Opt('ignore_filetypes')
      if filetype =~# glob2regpat(pattern)
        return 1
      endif
    endfor
  endfor
  return &synmaxcol > 0 && col('$') > &synmaxcol+1
endfunction

"[color, start, end] of the color code under the cursor, the start and end
"being the byte range of the code in the line, or []; if several overlap,
"the first one, and of those the longest
function s:ColorAtCursor()
  if s:Ignored()
    return []
  endif
  let line=getline('.')
  let col=col('.')-1
  let found=[]
  for format in s:formats
    let start=0
    while 1
      let [text, mbeg, mend]=matchstrpos(line, format.pattern, start)
      if mbeg < 0 || mbeg > col
        break
      elseif col < mend
        let color=call(format.parse, [text])
        if !empty(color) && (empty(found) || mbeg < found[1]
\                            || mbeg == found[1] && mend > found[2])
          let found=[color, mbeg, mend]
        endif
        break
      endif
      let start=mend
    endwhile
  endfor
  return found
endfunction

"[start, fits] of a popup of a:size on one axis, placed relative to the anchor
"positions [a:first, a:last] by offset a:off (SEE g:pastel_offset_x/y);
"the offset is inverted if the popup would not fit in a:low..a:limit; if it
"fits neither way, it is moved into a:low..a:limit as far as possible and fits
"is 0
function s:Axis(first, last, size, off, low, limit)
  let starts=[]
  for off in [a:off, -a:off]
    if off > 0
      call add(starts, a:last+off)
    elseif off < 0
      call add(starts, a:first+off-a:size+1)
    else
      call add(starts, a:first+(a:last-a:first+1)/2-a:size/2)
    endif
  endfor
  for start in starts
    if start >= a:low && start+a:size-1 <= a:limit
      return [start, 1]
    endif
  endfor
  return [max([a:low, min([starts[0], a:limit-a:size+1])]), 0]
endfunction

"[first, last] screen lines the popup may cover: not the tabline, if there is
"one, nor the status line of the last window, nor the command line
function s:Rows()
  let tabline=&showtabline == 2 || &showtabline == 1 && tabpagenr('$') > 1
  if has('gui_running') && &guioptions =~# 'e'
    let tabline=0
  endif
  let status=&laststatus >= 2 || &laststatus == 1 && winnr('$') > 1
  return [1+tabline, &lines-&cmdheight-status]
endfunction

"[first, last] screen columns of a code a:length cells long, of which the
"character a:before cells from its start is at screen column a:scrcol; its
"characters are one cell wide; it is mirrored in right-to-left windows, where
"it starts at its right end
function s:CodeColumns(scrcol, before, length, rightleft)
  if a:rightleft
    let last=a:scrcol+a:before
    return [last-(a:length-1), last]
  endif
  let first=a:scrcol-a:before
  return [first, first+a:length-1]
endfunction

"popup position for the code at byte range [mbeg, mend); if there is no room
"on either side of the code, the popup goes above or below its line instead
function s:Position(mbeg, mend)
  let [w, h]=s:Size()
  let [minline, maxline]=s:Rows()
  if (w > &columns || h > maxline-minline+1) && !s:warned
    let s:warned=1
    echohl WarningMsg
    echom 'pastel: the popup ('.w.'x'.h.') is larger than the screen'
    echohl None
  endif
  let cur=col('.')-1
  let offset_y=s:Opt('offset_y')
  let [wrow, wcol]=win_screenpos(0)
  let scrcol=wcol+wincol()-1
  let scrrow=wrow+winline()-1
  let [first, last]=s:CodeColumns(scrcol, cur-a:mbeg, a:mend-a:mbeg, &rightleft)
  let [left, fits]=s:Axis(first, last, w, s:Opt('offset_x'), 1, &columns)
  if fits
    let [top, fits]=s:Axis(scrrow, scrrow, h, offset_y, minline, maxline)
  else
    let left=max([1, min([first, &columns-w+1])])
    let [top, fits]=s:Axis(scrrow, scrrow, h, offset_y ? offset_y : 1,
\                          minline, maxline)
  endif
  return {'line': top, 'col': left, 'pos': 'topleft'}
endfunction

"forget the popup if something else closed it
function s:CheckPopup()
  if s:pastel_win && empty(popup_getpos(s:pastel_win))
    let s:pastel_win=0
  endif
endfunction

"the timer advancing alternating blocks, only running while it is needed
let s:timer=0
let s:timer_ms=0

function s:StopTimer()
  if s:timer
    call timer_stop(s:timer)
    let s:timer=0
    let s:timer_ms=0
  endif
endfunction

function s:OnTimer(id)
  call s:CheckPopup()
  call s:ReadSizes()
  let s:frame=s:BuildFrame(s:color, s:detail_text)
  if !s:pastel_win || !popup_getpos(s:pastel_win).visible
    call s:StopTimer()
    return
  endif
  let s:phase+=1
  call s:SetPopupContent(s:pastel_win)
endfunction

"run the timer if the layout has alternating blocks and the interval is valid
"(it is read every time, so changes take effect), else stop it
function s:UpdateTimer()
  let ms=float2nr(str2float(string(s:Opt('color_timer')))*1000)
  if ms < 100 || !s:layout.alternating
    call s:StopTimer()
    let s:phase=0
  elseif !s:timer || ms != s:timer_ms
    call s:StopTimer()
    let s:timer=timer_start(ms, function('s:OnTimer'), {'repeat': -1})
    let s:timer_ms=ms
  endif
endfunction

function s:Hide()
  call s:StopTimer()
  call s:CheckPopup()
  if s:pastel_win
    call popup_hide(s:pastel_win)
  endif
endfunction

"the screen column of the cursor is not up to date during CursorMoved if there
"is concealed text on the line, so the popup is placed again after the redraw
let s:replace=0

function s:OnReplace(id) abort
  let s:replace=0
  call s:Update(0)
endfunction

function s:OnCursorMove() abort
  call s:Update(1)
endfunction

"show, move or hide the popup as the cursor requires; a:again says whether it
"may be placed again later
function s:Update(again) abort
  call s:CheckPopup()
  call s:ReadSizes()
  call s:UpdateLayout()
  if s:ColorKey() !=# s:colorkey
    call s:DefineHighlights()
  endif
  let hit=s:ColorAtCursor()
  if empty(hit)
    call s:Hide()
  else
    call s:SetColor(hit[0])
    let s:detail_text=strpart(getline('.'), hit[1], hit[2]-hit[1])
    let s:frame=s:BuildFrame(hit[0], s:detail_text)
    let pos=s:Position(hit[1], hit[2])
    if s:pastel_win
      call popup_show(s:pastel_win)
      call popup_move(s:pastel_win, pos)
    else
      let s:pastel_win=popup_create([], extend(pos,
\                                 {'highlight': 'Normal', 'wrap': 0}))
    endif
    call s:UpdateTimer()
    call s:SetPopupContent(s:pastel_win)
    if a:again && &conceallevel > 0 && !s:replace
      let s:replace=timer_start(0, function('s:OnReplace'))
    endif
  endif
endfunction

"folds are closed and opened without the cursor moving, which no event tells
"about, so whether the cursor line is in a closed fold is checked whenever Vim
"is idle, if it has the event
let s:folded=0

function s:OnSafeState() abort
  let folded=foldclosed('.') >= 0
  if folded != s:folded
    let s:folded=folded
    call s:OnCursorMove()
  endif
endfunction

call s:SetupPopupHilightStyles()

augroup pastel
  autocmd!
  autocmd CursorMoved * call s:OnCursorMove()
  autocmd InsertEnter,BufLeave,WinLeave * call s:Hide()
  autocmd InsertLeave,WinEnter * call s:OnCursorMove()
  autocmd ColorScheme * call s:DefineHighlights()
  "the events are not available in older Vims
  if exists('##WinScrolled')
    autocmd WinScrolled * call s:OnCursorMove()
  endif
  if exists('##SafeState')
    autocmd SafeState * call s:OnSafeState()
  endif
augroup end

"vim: sw=2 ts=2 et fdm=syntax
