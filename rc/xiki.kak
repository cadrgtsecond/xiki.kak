# Xiki
define-command -docstring "Execute the current line as a Xiki command" \
xiki-execute %{
    evaluate-commands -itersel -draft -save-regs 'aicwr' %{
        execute-keys 'x<a-:><a-;>'
        set-register i ''
        set-register c
        try %{ execute-keys -draft 's^\h+<ret>"iy' }
        echo -debug %sh{
            while true; do
                cat >"$kak_command_fifo" <<________________END
                    set-register w ''
                    try %{ execute-keys -draft 's\A\h+<ret>"wy' }
                    try %{ execute-keys -draft '<a-:><a-;>;x_"ay' }
                    set-register c %reg{a} %reg{c}
                    echo -to-file $kak_response_fifo "%reg{w}"
________________END
                spaces=$(wc -c <"$kak_response_fifo")
                if [ "$spaces" -eq 0 ]; then
                    break
                fi
                next_spaces=$(( spaces - 1))
                cat >"$kak_command_fifo" <<________________END
                    try %{
                        execute-keys '<a-:><a-;>'
                        execute-keys '<a-?>^\h{0,$next_spaces}[^\h\n]<ret>x'
                        echo -to-file $kak_response_fifo 1
                    } catch %{
                        echo -to-file $kak_response_fifo 0
                    }
________________END
                status=$(cat "$kak_response_fifo")
                if [ "$status" -eq 0 ]; then
                    break
                fi
            done
        }
        set-register r %sh{
            eval set -- "$kak_quoted_reg_c"
            xiki "$@" | sed "s/^/  $kak_reg_i/"
            printf '\n'
        }
        execute-keys -draft '<a-:>"rp'
    }
}

define-command -docstring "Clear the output of the current line" \
xiki-clear %{
    evaluate-commands -itersel -draft -save-regs i %{
        execute-keys 'x<a-:>'
        set-register i ''
        try %{ execute-keys -draft 's^\s+<ret>"iy' }
        # There is a difference between failing to select at least one
        # and successfully selecting nothing. Hence (...)*
        execute-keys 'h/(?S)(\n<c-r>i\h.*)*$<ret>_xd'
    }
}
define-command -docstring "Execute the current line as a Xiki command, or clear it if already executed" \
xiki %{
    try %{
        xiki-clear
    } catch %{
        xiki-execute
    }
}
