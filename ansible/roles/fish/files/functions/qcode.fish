function qcode
    set s (ghq list -p | peco)
    if test -z "$s"
        return 1
    end
    code $s
end
