function fish_show_paths
    echo $fish_user_paths | sed 's/ /\n/g' | nl
end
