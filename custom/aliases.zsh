export GIT_EDITOR="nvim"

alias gaa="git add --all"
alias gsa="git stash"
alias gs="git status"
alias gps="git push"
alias gpu="git push"
unalias gcp 2>/dev/null
gcp() { git commit -m "$1" && git push; }
alias grm="git rebase main"
unalias grh 2>/dev/null
grh() { git rebase -i HEAD~"${1:-1}"; }
alias gcb="git checkout -b"


