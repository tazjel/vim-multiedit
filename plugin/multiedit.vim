" *multiedit.txt* Multi-editing for Vim   
" 
" Version: 0.1.1
" Author: Felix Riedel <felix.riedel at gmail.com> 
" Maintainer: Henrik Lissner <henrik at lissner.net>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
" 
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}


" if exists('g:loadedMultiedit') || &cp
"     finish
" endif
" let g:loadedMultiedit = 1

"""""""""""""""""""""
" Settings {{

    if !exists('g:multiedit_no_mappings')
        let g:multiedit_no_mappings = 0
    endif
    if !exists('g:multiedit_no_mouse_mappings')
        let g:multiedit_no_mouse_mappings = 0
    endif

    if !exists('g:multiedit_auto_reset')
        let g:multiedit_auto_reset = 1
    endif

    if !exists('g:multiedit_mark_character')
        let g:multiedit_mark_character = '|'
    endif

" }}


"""""""""""""""""""""
" Utility {{

    hi default MultiSelections gui=reverse term=reverse cterm=reverse
    " TODO: hi default MultiSelectionsFirst gui=reverse term=reverse cterm=reverse

    function! s:highlight(line, start, end)
        " if b:first_selection.line == a:line && b:first_selection.col == a:start && b:first_selection.end == a:end
        "     let synid = "MultiSelectionsFirst"
        " else
        "     let synid = "MultiSelections"
        " endif
        execute "syn match MultiSelections '\\%".a:line."l\\%".a:start."c\\_.*\\%".a:line."l\\%".a:end."c' containedin=ALL"
        " execute "syn match ".synid." '\\%".a:line."l\\%".a:start."c\\_.*\\%".a:line."l\\%".a:end."c' containedin=ALL"
    endfunction

    function! s:rehighlight()
        syn clear MultiSelections
        " syn clear MultiSelectionsFirst

        for line in keys(b:selections)
            for sel in b:selections[line]
                call s:highlight(line, sel.col, sel.end)
            endfor
        endfor
    endfunction

    function! s:entrySort(a,b)
        return a:a.col == a:b.col ? 0 : a:a.col > a:b.col ? 1 : -1
    endfunction

" }}


"""""""""""""""""""""
" Core {{

    " addRegion()
    " Add selection to multiedit {{
    func! s:addRegion()
        if mode() != "v"
            normal! gv
        endif

        " get selection parameters
        let lnum = line('.')
        let startcol = col('v')
        let endcol = col('.')+1
        let line_end = col('$')

        " add selection to list
        let sel = { 'line': lnum, 'col': startcol, 'end': endcol, 'len': endcol-startcol, 'suffix_length': line_end-endcol }

        if !exists('b:selections')
            let b:selections = {}
            let b:first_selection = sel
        endif

        if has_key(b:selections, lnum)
            let b:selections[lnum] = b:selections[lnum] + [sel]
        else
            let b:selections[lnum] = [sel]
        endif

        call s:highlight(lnum, startcol, endcol)

        normal! v
    endfunc
    " }}

    " addMark()
    " Add an edit cursor {{
    func! s:addMark(mode)
        let mark = g:multiedit_mark_character

        exe "normal! ".a:mode.g:multiedit_mark_character."v"
        call <SID>addRegion()
    endfunc
    " }}

    " TODO: addMatch()
    " Add selection/word under the cursor and its occurrence {{
    func! s:addMatch(direction) 
        if a:direction != "/" && a:direction != "?"
            return
        endif

        normal! v

        let line = line(".")
        let col = col("v")
        let end = col(".")

        let text = join(getline(line), "")[col:end]

        " Move to next iteration and reselect it
        exe "normal! ".a:direction."\V".text."v".repeat("l", strlen(text)-1)

        " Add the region!
        call <SID>addRegion()
    endfunc
    " }}

    " startEdit(mode)
    " Begin editing all multiedit regions {{
    func! s:startEdit()
        if !exists('b:selections')
            return
        endif

        " let mode = input("Mode (i/a/c): ")
        " mode == i|a|c => determines where to put the cursor to start
        " editing
        let colno = b:first_selection.col + b:first_selection.len

        " call cursor(b:first_selection.line, b:first_selection.col)
        " normal! v
        call cursor(b:first_selection.line, colno)
        " if getline(b:first_selection.line)[b:first_selection.col:colno-1] == g:multiedit_mark_character
        "     normal! x
        " endif
        " normal! v

        call s:updateSelections()
        if col("$") == colno
            startinsert!
        else
            startinsert
        endif

        augroup multiedit 
            au!
            au CursorMovedI * call s:updateSelections()
            " au InsertEnter * call s:updateSelections(1)
            if g:multiedit_auto_reset == 1
                au InsertLeave * call s:reset()
            endif
            au InsertLeave * autocmd! multiedit
        augroup END
    endfunc
    " }}

    " clear()
    " Clears selected region {{
    func! s:clear()
        if !exists('b:selections')
            return
        endif

        " If there are no selections in the current line then ignore this call
        let line = line(".")
        if !has_key(b:selections, line)
            return
        endif

        let mode = mode()
        if mode == "V"
            " If in Visual Line mode, just remove all regions on this line
            unlet b:selections[line]
            return
        elseif mode != "v"
            " Not visual? Not anymore!
            normal! v
        endif
            let col = col("v")
            let end = col(".")

            " Go through all the selections...
            for sel in b:selections[line]
                " If this $sel is the first_selection, unlet first_selection
                " and wait for the next iteration for it to be reset.
                if !exists(b:first_selection)
                    let b:first_selection = sel
                elseif sel == b:first_selection
                    unlet b:first_selection
                endif

                " Check to see if this selection falls within the visual
                " selection. If so, clear it!
                if col == sel.col || col == sel.end 
                            \ || end == sel.col || end == sel.end
                            \ || (col > sel.col && end < sel.end)
                            \ || (col < sel.col && end > sel.end)
                    unlet b:selections[line]
                endfor
            endfor
        endif

        " Redo the highlights
        call s:rehighlight()
    endfunc
    " }}

    " reset()
    " Clears multiedit regions and highlights {{
    func! s:reset()
        if exists('b:selections')
            unlet b:selections
        endif
        if exists('b:first_selection')
            unlet b:first_selection
        endif
        syn clear MultiSelections
        " syn clear MultiSelectionsFirst
        silent! au! multiedit 
    endfunc
    " }}

    " updateSelections()
    " Enter changes into all regions {{
    func! s:updateSelections()
        " Save cursor position
        let b:save_cursor = getpos('.')

        if !exists('b:selections')
            return
        endif

        syn clear MultiSelections
        " syn clear MultiSelectionsFirst

        let editline = getline(b:first_selection.line)
        let line_length = len(editline)

        let newtext = editline[(b:first_selection.col-1): (line_length-b:first_selection.suffix_length-1)]

        for line in sort(keys(b:selections))
            let entries = b:selections[line]
            let entries = sort(entries, "s:entrySort")
            let s:offset = 0

            for entry in entries
                " skip the entry of the first selection
                if entry.line != b:first_selection.line || entry.col != b:first_selection.col 
                    " selection is moved by offset if this is not
                    " the first selection in the line
                    let entry.col = entry.col + s:offset
                    let oldline = getline(entry.line)
                    let prefix = ''
                    if entry.col > 1
                        let prefix = oldline[0:entry.col-2]
                    endif
                    let suffix = oldline[(entry.col+entry.len-1):]
            
                    " update the line
                    call setline(entry.line, prefix.newtext.suffix) 
                endif
                
                " update the offset for the next selection in this line
                let s:offset = s:offset + len(newtext) - entry.len 

                " update the length of the selection to fit the new content
                let entry.len = len(newtext)

                call s:highlight(entry.line, entry.col, entry.col+entry.len)
            endfor
        endfor

        let b:first_selection.suffix_length = col([b:first_selection.line, '$']) - b:first_selection.col - b:first_selection.len

        " restore cursor position
        call setpos('.', b:save_cursor)
    endfunc
    " }}

" }}


"""""""""""""""""""""
" Mappings {{

    map <Plug>MultiEditAddRegion :call <SID>addRegion()<CR>

    if g:multiedit_no_mappings != 1
        " [Adding markers]
        " After the cursor
        nmap <leader>ma :call <SID>addMark("a")<CR>
        " Before the cursor
        nmap <leader>mi :call <SID>addMark("i")<CR>

        " [Adding regions]
        vmap <leader>mm <Plug>MultiEditAddRegion  
        " Add the character under the cursor as a region
        nmap <leader>mm v<Plug>MultiEditAddRegion  
        " Add the word object under the cursor as a region
        nmap <leader>mw viw<Plug>MultiEditAddRegion  

        " Start edit mode!
        nmap <leader>M :call <SID>startEdit()<CR>

        " Mark <cword> as region, then jump to and mark the next instance
        " nmap <leader>mn viw:call <SID>addMatch('/')<CR>
        " Like ^ but previous
        " nmap <leader>mp viw:call <SID>addMatch('?')<CR>

        " [Resetting]
        " Clear region/marker under the cursor
        map <silent> <leader>md :<C-U>call <SID>clear()<CR>
        " Clear all regions and markers
        nmap <silent> <leader>mr :<C-U>call <SID>reset()<CR>
    endif 

    if g:multiedit_no_mouse_mappings != 1
        nmap <C-LeftClick> <LeftClick>:call <SID>addMark("i")<CR>
    endif

" }}

" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker
