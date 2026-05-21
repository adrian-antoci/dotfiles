export GIT_EDITOR="nvim"

# Suggest from history first, fall back to tab-completion (files, dirs, flags)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# eza (modern ls with icons + git status)
alias ls="eza --icons --git"
alias ll="eza -l --icons --git"
alias la="eza -la --icons --git"
alias lt="eza --tree --icons --level=2"

# zoxide (smart cd) — `z foo` jumps to any visited dir matching "foo"
eval "$(zoxide init zsh)"

alias gaa="git add --all"
alias gsa="git stash"

alias gs="git status"

unalias gp 2>/dev/null
alias gp="git push"

unalias gsf 2>/dev/null
alias gsf="git push --force"

unalias gpl 2>/dev/null
alias gpl="git pull"

unalias gcp 2>/dev/null
gcp() {
    git commit -m "$1" || return 1
    if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
        git push
    else
        git push --set-upstream origin "$(git branch --show-current)"
    fi
}

unalias gcc 2>/dev/null
gcc() {
    echo "$(git rev-list --count main..HEAD) commits ahead of main:"
    git --no-pager log --oneline main..HEAD
}

alias grm="git rebase main"

unalias grh 2>/dev/null
grh() { git reset --soft "$(git merge-base main HEAD)" && git commit -m "$1"; }

unalias gc 2>/dev/null
gc() {
    if git show-ref --verify --quiet "refs/heads/$1"; then
        git checkout "$1"
    else
        git checkout -b "$1"
    fi
}

unalias greset 2>/dev/null
alias greset="git reset --hard"