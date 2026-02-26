setopt EXTENDED_GLOB
setopt PROMPT_VARS
disable -p '#'

export HISTSIZE=99999

export OLD_WORDCHARS="*?_-.[]~=&;!#$%^(){}<>"
export WORDCHARS="*?[]~&;!#$%^(){}<>"
export BC_ENV_ARGS="-l"

. $(brew --prefix)/etc/profile.d/z.sh

export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export PATH="$HOME/bin:$HOME/go/bin:$HOME/.ghcup/bin:$PATH"

export EDITOR=$HOME/bin/safe_nvim

bindkey -e # after setting editor, reset terminal to emacs mode
alias vim="$HOME/bin/safe_nvim"

zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
autoload -Uz compinit && compinit

autoload -U edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line

alias mdb="rake db:migrate; RAILS_ENV=test rake db:migrate"

alias g="git"
alias gaa="git add --all"
alias gane="git commit --amend --no-edit"
alias gb="git branch -i --sort=authordate"
alias gbr="git branch -i --sort=authordate | tail -15"
alias gbs="git branch -i --sort=authordate | tac | sed 's/^[^[:alnum:]-]*//' | sk -m"
alias gc="git commit"
alias gco="git checkout"
alias gd="git diff"
alias gdm="git diff --name-only \$(git master)"
alias gdom="git diff --name-only origin/\$(git master)"
alias gdc="git diff --cached"
alias gdd="gddev"
alias gkl="git clean -fd"
alias glod="git log --oneline --decorate"
alias glodd="git log --oneline --decorate -10"
alias glodiff="git log --oneline --decorate --left-right HEAD...origin/HEAD"
alias glodm="git log --oneline --decorate HEAD...master~"
alias glodr="git log --oneline --decorate HEAD...origin/\$(git cb)~"
alias gp="git push"
alias gph="git push origin HEAD"
alias gpod="git pull origin development"
alias gpom="git pull origin master"
alias gpr="git pull --rebase"
alias greset="git checkout .; git clean -fd"
alias gss="git add --all -N; git diff head --name-only --diff-filter=d"
alias gss="git status -s | sed 's/...//;s/.* -> //'"
alias gst="git status -s"
alias spring="bin/spring"
alias st="git status -s"
alias im=safe_nvim
alias spring="bin/spring"
alias webpack="bin/webpack"

# alias skf="sk --cmd 'git ls-files' -f"

alias rubies="rg '[.](rb|rake)$'"
alias bex="bundle exec"
alias ber="bundle exec rspec"
alias bers="bundle exec rspec \$(gddev | specs)"
alias berof="bundle exec rspec --only-failures"
alias dirty="bundle exec rspec \$(gss | specs)"
alias specs="rg '\\b(spec/.*_spec.rb|__tests__/.*[.]spec[.][tj]sx?)'"
alias nospecs="rg -v '\\b(spec/.*_spec.rb|__tests__/.*[.]spec[.][tj]sx?)'"

alias pclaude="\\claude --permission-mode plan"
alias claude="claude --dangerously-skip-permissions"
alias gorb="test \$? -eq 0 && say good || say bad"
alias yorn="test \$? -eq 0 && echo yes || echo no"

function file_exists {
  while read fn
  do
    test -f $fn && echo $fn
  done
}

function gddev {
  if [[ $PWD == *postprocessors* ]]; then
    git diff master --name-only --diff-filter=d | sed 's/.*[[:space:]]//'
  else
    git diff development --name-only --diff-filter=d | sed 's/.*[[:space:]]//'
  fi
}


autoload -Uz add-zsh-hook

update_git_vars() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    export groot=`git rev-parse --show-toplevel`
    export cb=$(git cb)
    export ocb="origin/$cb"
    export cbo="origin/$cb"
    export rb="origin/$cb"
    export m=$(git master)
    export om="origin/$m"
    export rom="origin $m"
  else
    unset groot cb ocb cbo rb m om rom
  fi
}

add-zsh-hook precmd update_git_vars

alias sc="bin/rails c"
alias ss="bin/rails s -p 3000"
alias ssp="bin/rails s -p"
alias wkr='QUEUE=* bundle exec rake resque:work'

alias ezs="vim ~/.zshrc"
alias .zs="source ~/.zshrc"

alias rg="rg -PS"
alias ls="ls -A1"
alias ll="ls -Al"
alias lsr="ls -A1tr"
alias llr="ls -Altr"

function _gss() {
  if test $# -gt 0; then
    git status -s | sed 's/...//;s/.* -> //' | rg -i "$*"
  else
    git status -s | sed 's/...//;s/.* -> //'
  fi
}

function glink() {
  git symbolic-ref refs/heads/$1 refs/heads/$2
}

function glinkcb() {
  git symbolic-ref refs/heads/$1 refs/heads/$(git cb)
}

function cpb() {
  git branch -i --list $1
}

function pad() {
  blanklines
  while read a; do
    echo "$a"
  done
  blanklines
}

export PS1=$'\n'"%~ \$(git_prompt_info)"$'\n'"%#> "

export STARSHIP_CONFIG=$HOME/.config/starship/starship.toml


source <(starship init zsh --print-full-init)

eval "$(rbenv init -)"
export PATH="/opt/homebrew/opt/node@14/bin:$PATH"

[[ -n $SSH_CONNECTION && -z $VIM && -z $TMUX ]] && tmux new -A -s remote

export TERM=screen-256color

alias -g GG="--graph"
alias -g NS="--name-status"
alias -g NON="--name-only"
alias -g REL="--relative"
alias -g 1L="--oneline"
alias -g LR="--left-right"
alias -g DEC="--decorate"

alias gl="git log"
alias gd="git diff"

alias ls="ls -A"
alias ll="ls -Al"
alias lt="ls -Altr"
alias lltr="ls -Altr"

# Task Management

alias ht="h task"
alias hs="h subtask"

source $HOME/.config/broot/launcher/bash/br
export PATH="$HOME/.local/bin:$PATH"

# DaVinci Resolve MCP Server environment variables
export RESOLVE_SCRIPT_API="/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting"
export RESOLVE_SCRIPT_LIB="/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
export PYTHONPATH="$PYTHONPATH:$RESOLVE_SCRIPT_API/Modules/"

export ns="--name-status"
export nonly="--name-only"

alias ht="h task"
alias hs="h subtask"

function insert_last_output() {
  zle -U ' $(!!)'
}

zle -N insert_last_output

bindkey '^[ ' insert_last_output

source <(fzf --zsh)
