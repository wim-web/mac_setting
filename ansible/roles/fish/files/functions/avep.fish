function avep
    set --local profile (\
        aws-vault list --profiles | peco
    )
    aws-vault exec "$profile" -- $argv[..]
end
