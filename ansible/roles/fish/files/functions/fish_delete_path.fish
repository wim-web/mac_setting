function fish_delete_path
    set p $argv[1]
    set index $(show_fish_paths | awk -v p=$p '$2==p{print $1}')
    set -e fish_user_paths[$index]
end
