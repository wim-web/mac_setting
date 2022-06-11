function qcd
    set s (ghq list -p | peco)
    if test -z "$s"
        return 1
    end
    cd $s
end
