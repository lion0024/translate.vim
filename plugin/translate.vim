" Version: 0.0.2
" Author : skanehira <sho19921005@gmail.com>
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

scriptencoding utf-8

if exists('g:loaded_translate')
    finish
endif

let g:loaded_translate = 1

let s:translate_bufname = "TRANSLATE RESULT"
" current window number
let s:currentw = ""
" command result
let s:result = []
" used in translate mode
let s:bang = ""
let s:current_mode = 0
let s:auto_trans_mode = 1

" translate
function! translate#translate(bang, line1, line2, ...) abort
    let ln = "\n"
    if &ff == "dos"
        let ln = "\r\n"
    endif

    let s:result = []
    let start = a:line1
    let end = a:line2

    if s:current_mode == s:auto_trans_mode
        let start = 1
        let end = getpos("$")[1]
        let cmd = s:create_cmd(s:getline(start, end, ln, a:000), s:bang)
    else
        let cmd = s:create_cmd(s:getline(start, end, ln, a:000), a:bang)
    endif

    echo "Translating..."
    let job = job_start(cmd, {
                \"callback": function("s:tran_out_cb"),
                \"exit_cb": function("s:tran_exit_cb"),
                \})
endfunction

" get text from selected lines or args
function! s:getline(start, end, ln, args) abort
    let text = getline(a:start, a:end)
    if !empty(a:args)
        let text = a:args
    endif

    if empty(text)
        finish
    endif

    return join(text, a:ln)
endfunction

" create gtran command with text and bang
function! s:create_cmd(text, bang) abort
    if a:text == ""
        return
    endif

    let source_ = get(g:, "translate_source", "en")
    let target = get(g:, "translate_target", "ja")

    let cmd = ["gtran", "-text=".a:text, "-source=".source_, "-target=".target]
    if a:bang == '!'
        let cmd = ["gtran", "-text=".a:text, "-source=".target, "-target=".source_]
    endif
    return cmd
endfunction

" get command result
function! s:tran_out_cb(ch, msg) abort
    call add(s:result, a:msg)
endfunction

" set command result to translate window buffer
function! s:tran_exit_cb(job, status) abort
    call s:create_tran_window()
    call setline(1, s:result)
    call s:focus_window(bufnr(s:currentw))
    echo ""
endfunction

" create translate result window
function! s:create_tran_window() abort
    let s:currentw = bufnr('%')

    let winsize_ = get(g:,"translate_winsize", 10)
    if !bufexists(s:translate_bufname)
        " create new buffer
        execute str2nr(winsize_).'new' s:translate_bufname
    else
        " focus translate window
        let tranw = bufnr(s:translate_bufname)
        if empty(win_findbuf(tranw))
            execute str2nr(winsize_).'new|e' s:translate_bufname
        endif
        call s:focus_window(tranw)
    endif

    silent % d _
endfunction

" close specified window
function! s:close_window(wn) abort
    if a:wn != ""
        let list = win_findbuf(a:wn)
        if !empty(list)
            execute win_id2win(list[0]) "close!"
            execute "bdelete!" a:wn
        endif
    endif
endfunction

" focus spcified window.
" wn arg is window number that can use bufnr to get.
function! s:focus_window(wn) abort
    if !empty(win_findbuf(a:wn))
        call win_gotoid(win_findbuf(a:wn)[0])
    endif
endfunction

" enable auto translate mode
function! translate#autoTranslateModeEnable(bang) abort
    if s:current_mode != s:auto_trans_mode
        inoremap <CR> <C-o>:Translate<CR><CR>
        let s:current_mode = s:auto_trans_mode
        call s:create_tran_window()
        call s:focus_window(bufnr(s:currentw))
        let s:bang = a:bang
    endif
endfunction

" disable auto translate mode
function! translate#autoTranslateModeDisable(bang) abort
    " set normal mode
    let s:current_mode = 0
    " reset result
    let s:result = []
    " unmap
    if !empty(maparg("\<CR\>", "i"))
        iunmap <CR>
    endif
    call s:close_window(bufnr(s:translate_bufname))
endfunction

" auto translate mode toggle
function! translate#autoTranslateModeToggle(bang) abort
    if s:current_mode == s:auto_trans_mode
        call translate#autoTranslateModeDisable(a:bang)
    else
        call translate#autoTranslateModeEnable(a:bang)
    endif
endfunction

command! -bang -range -nargs=? Translate call translate#translate("<bang>", <line1>, <line2>, <f-args>)
command! -bang -nargs=0 AutoTranslateModeEnable call translate#autoTranslateModeEnable("<bang>")
command! -bang -nargs=0 AutoTranslateModeDisable call translate#autoTranslateModeDisable("<bang>")
command! -bang -nargs=0 AutoTranslateModeToggle call translate#autoTranslateModeToggle("<bang>")

let &cpo = s:save_cpo
unlet s:save_cpo
