function avl
    set --local p (aws-vault list --profiles | peco)
    open -na "Google Chrome" --args --user-data-dir=$HOME/Library/Application\ Support/Google/Chrome/aws-vault/"$p" $(aws-vault login "$p" --stdout)
end
