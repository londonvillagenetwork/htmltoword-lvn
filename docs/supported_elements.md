# Supported elements 

`<Work in progress>`

## Unsupported elements

The following elements are explicitly not supported (they will be removed, before doing any transformation)

- applet
- area
- audio
- base
- basefont
- canvas
- command
- details/summary
- font
- iframe
- img
- isindex
- map
- noframes
- noscript
- object
- param
- script
- source
- style
- video

All form related elements (form, fieldset, input, label, etc.) hasn't been implemented nor deleted.
The outcome is unclear yet and it is highly probably that it will generate an invalid document.

All other elements not specified below 

## Supported elements/tags
### Inline

[a](#a),  
[abbr](#abbr-acronym-bdo-bdi), 
[acronym](#abbr-acronym-bdo-bdi), 
[b](#b-strong), 
[bdi](#abbr-acronym-bdo-bdi), 
[bdo](#abbr-acronym-bdo-bdi), 
[big](#big-small), 
[cite](#cite-dfn-em-i),
[code](#code-kbd-samp-tt-var),
[del](#del-s-strike),
[dfn](#cite-dfn-em-i),
[em](#cite-dfn-em-i),
[i](#cite-dfn-em-i),
[ins](#ins-u)
[kbd](#code-kbd-samp-tt-var),
[mark](#mark),
[q](#q),
[s](#del-s-strike),
[samp](#code-kbd-samp-tt-var),
[small](#big-small),
[span](#span),
[strike](#del-s-strike),
[strong](#b-strong),
[sub](#sub-sup),
[sup](#sub-sup)
[tt](#code-kbd-samp-tt-var),
[u](#ins-u),
[var](#code-kbd-samp-tt-var)

### Blocks
[article](#div)
[div](#div)
[p](#p)
[section](#div)
[table](#table)
[ul/ol](#lists)

#### a
Links to anchors in the same document are displayed as normal text. 
Links to references starting with `http://` or `https://` will be displayed and behave as links. 

#### abbr, acronym, bdo, bdi
Displayed as normal text

#### b, strong
Displayed as normal text, styled bold

#### big, small
Displayed as normal text. 
Future implementation: Make the text bigger or smaller than the normal one.

#### cite, dfn, em, i
Displayed as normal text, styled italic

#### code, kbd, samp, tt, var
Displayed as normal text. 
Future implementation: Assign a monospaced style, most likely using *Courier New* since it's one of the few monospaced fonts shipped with word

#### del, s, strike
Displayed as normal text with Strikethrough effect.

#### div
Divs, sections and articles are displayed as paragraphs.
Only style supported at the moment is alignment. See the wiki on [styles](https://github.com/karnov/htmltoword/wiki/Styles-and-classes) for more

#### ins, u
Displayed as normal text, using single underline style.

#### lists
Lists support is very basic. . See the wiki on [styles](https://github.com/karnov/htmltoword/wiki/Styles-and-classes) for more
Tables inside lists are NOT supported

#### mark
Displayed as normal text highlighted in yellow. See [span](#span) for more colors. 

#### q
Text within `<q>text</q>` will be wrapped with double quotes `"text"`

#### span
Displayed as normal text. 
When using `class="h" data-color="selected_color"` The text will be highlighted in the color specified. See the wiki on [styles](https://github.com/karnov/htmltoword/wiki/Styles-and-classes) for a list of colors
 
#### sub, sup
Displayed as normal text with subscript or superscript effect.

#### p
Displayed as paragraphs.
Only style supported at the moment is alignment. See the wiki on [styles](https://github.com/karnov/htmltoword/wiki/Styles-and-classes) for more

#### table
Basic support for tables. See the wiki on [styles](https://github.com/karnov/htmltoword/wiki/Styles-and-classes) for more
