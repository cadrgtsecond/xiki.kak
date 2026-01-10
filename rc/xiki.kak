# Xiki
define-command -params 0..1 -docstring %{
    xiki-execute [-fifo]: execute the current line as a Xiki command
} \
xiki-execute %{
    evaluate-commands -itersel -draft -save-regs 'aicwtsr^' %{
        execute-keys -save-regs '' '<a-:><a-;>Z'
        set-register i ''
        set-register c
        try %{ execute-keys -draft 's\A\h+<ret>"iy' }
        echo -debug %sh{
            while true; do
                cat >"$kak_command_fifo" <<END
                    set-register w '  '
                    try %{ execute-keys -draft '_"ay' }
                    set-register c %reg{a} %reg{c}

                    try %{
                        execute-keys -draft 's\A\h+<ret>"wy'
                        execute-keys '<a-?>^<c-r>w<backspace><backspace>[^\h\n]<ret>;x'
                        echo -to-file $kak_response_fifo 1
                    } catch %{
                        echo -to-file $kak_response_fifo 0
                    }
END
                status=$(cat "$kak_response_fifo")
                if [ "$status" -eq 0 ]; then
                    break
                fi
            done
        }
        execute-keys -save-regs '' 'z<a-:>;'
        set-register t %val{timestamp}
        set-register s %val{selection_desc}
        evaluate-commands -draft %sh{
            # $kak_client
            # $kak_session
            if [ -z "$1" ]; then
                eval set -- "$kak_quoted_reg_c"
                IFS='
                '
                {
                    xiki "$@" 2>&1 | awk 1 | \
                        while read -r line; do
                            line=$(printf %s "$line" | sed "s/^/  $kak_reg_i/;s/%/%%/g;s/↕/↕↕/g")
                            kak -p "$kak_session" <<KAKOUNE
                              evaluate-commands -client $kak_client -draft -save-regs a %↕
                                  select -timestamp $kak_reg_t $kak_reg_s
                                  set-register a %%
$line%
                                  execute-keys i<c-r>a
                              ↕
KAKOUNE
                        done
                } >/dev/null 2>&1 </dev/null &
            else
                tmpdir=$(mktemp -td xiki_fifo.XXXXXX)
                mkfifo "$tmpdir/fifo"
                eval set -- "$kak_quoted_reg_c"
                ( xiki "$@" 2>&1 >"$tmpdir/fifo" ) >/dev/null 2>&1 </dev/null &
                cat <<END
                    hook global -once NormalIdle .* %{ edit -scroll -fifo "$tmpdir/fifo" *xiki* }
END
            fi
        }
    }
}

define-command -docstring "Clear the output of the current line" \
xiki-clear %{
    evaluate-commands -itersel -draft -save-regs i %{
        execute-keys 'x<a-:>'
        set-register i ''
        try %{ execute-keys -draft 's\A\s+<ret>"iy' }
        execute-keys ';Ges(?S)\A(\n<c-r>i .*|\s)+<ret>_xd'
    }
}
define-command -docstring "Execute the current line as a Xiki command, or clear it if already executed" \
xiki %{
    try %{ xiki-clear } catch %{ xiki-execute }
}

hook global WinSetOption filetype=xiki %{
    hook -group xiki window InsertChar '\n' %{
        try %{ execute-keys -draft 'kxs^\h+<ret>yj<a-h>P' }
    }
    add-highlighter window/xiki group
    add-highlighter window/xiki/dirs regex '^\h*([^\n]*/|\.|\.\.|[~/][^\n]*)$' 1:blue
    add-highlighter window/xiki/comment regex '^\h*# [^\n]*' 0:comment
    hook -once -always window WinSetOption filetype=.* %{
        remove-hooks window xiki
    }
}

hook global WinCreate '.*\.menu' %{
    set-option window filetype xiki
}
hook global WinCreate \*doc-xiki\* %{
    map window normal <ret> 'x<a-:><a-;>: xiki<ret>;'
    map window normal <a-ret> 'x: xiki-execute -fifo<ret>'
    hook window -once NormalIdle .* %{
        set-option buffer readonly false
    }
    hook -group xiki window InsertChar '\n' %{
        try %{ execute-keys -draft 'kxs^\h+<ret>yj<a-h>P' }
    }
}
