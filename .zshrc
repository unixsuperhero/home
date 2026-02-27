setopt EXTENDED_GLOB
setopt PROMPT_VARS
disable -p '#'

export NOTES_DIR="$HOME/notes"
export HISTSIZE=99999

export OLD_WORDCHARS="*?_-.[]~=&;!#$%^(){}<>"
export WORDCHARS="*?[]~&;!#$%^(){}<>"
export BC_ENV_ARGS="-l"

. $(brew --prefix)/etc/profile.d/z.sh

export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export PATH="$HOME/bin:$HOME/go/bin:$HOME/.ghcup/bin:$PATH:/Applications/Ghostty.app/Contents/MacOS"
export EDITOR=$HOME/bin/safe_nvim

bindkey -e # after setting editor, reset terminal to emacs mode
alias vim="$HOME/bin/safe_nvim"

zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
autoload -Uz compinit && compinit

autoload -U edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line

alias ezs="vim ~/.zshrc"
alias .zs="source ~/.zshrc"
alias pclaude="claude --permission-mode plan"
alias dclaude="claude --dangerously-skip-permissions"
alias gorb="test \$? -eq 0 && say good || say bad"
alias yorn="test \$? -eq 0 && echo yes || echo no"

alias gane="git commit --amend --no-edit"
alias gb="git branch -i --sort=authordate"
alias gbr="git branch -i --sort=authordate | tail -15"
alias gbs="git branch -i --sort=authordate | tac | sed 's/^[^[:alnum:]-]*//' | sk -m"
alias gbs2="git branch -i --sort=authordate | sed 's/^[^[:alnum:]-]*//' | sk --tac -m"
alias gc="git commit"
alias gco="git checkout"
alias gcb="git cb"
alias glob="echo -n origin/\$(git cb)"
alias glb="echo -n origin/\$(git cb)"
alias grob="echo -n origin \$(git cb)"
alias grb="git rebase"
alias glom="echo -n origin/\$(git master)"
alias glm="echo -n origin/\$(git master)"
alias grom="echo -n origin \$(git master)"
alias grm="echo -n origin \$(git master)"
alias gfo="git fetch origin"
alias gfb="git fetch origin \$(git cb)"
alias gfm="git fetch origin \$(git master):\$(git master)"
alias gfom="git fetch origin \$(git master)"
alias grbom="git rebase origin/\$(git master)"
alias gd="git diff"
alias gdc="git diff --cached"
alias gdr="git diff --relative"
alias gkl="git clean -fd"
alias glod="git log --oneline --decorate"
alias glodd="git log --oneline --decorate -10"
alias glodm="git log --oneline --decorate HEAD...master~"
alias glodr="git log --oneline --decorate HEAD...origin/\$(git cb)~"
alias glodiff="git log --oneline --decorate --left-right HEAD...origin/HEAD"
alias glrm="git log --oneline --decorate HEAD...master~"
alias glrom="git log --oneline --decorate HEAD...origin/master~"
alias gp="git push"
alias gph="git push origin HEAD"
alias gpod="git pull origin development"
alias gpom="git pull origin master"
alias gpr="git pull --rebase"
alias greset="git checkout .; git clean -fd"
alias gss="git add --all -N; git diff head --name-only --diff-filter=d"
alias gss="git status -s | sed 's/...//;s/.* -> //'"
alias gst="git status -s"
alias st="git status -s"
alias gfpm="git merge-base --fork-point \$(git master)"
alias gfpom="git merge-base --fork-point origin/\$(git master)"
alias gdfp="git diff NON REL \$(git merge-base --fork-point origin/\$(git master))"
alias gdfpa="git diff NON \$(git merge-base --fork-point origin/\$(git master))"
alias gdfpr="git diff NON \$(git merge-base --fork-point origin/\$(git master)) | sed \"s@^@\$(git rev-parse --show-cdup)@\""
alias gdfpar="git diff NON \$(git merge-base --fork-point origin/\$(git master)) | sed \"s@^@\$(git rev-parse --show-cdup)@\""
alias gdfps="git diff NS REL \$(git merge-base --fork-point origin/\$(git master))"
alias gdfpsa="git diff NS \$(git merge-base --fork-point origin/\$(git master))"
alias gdfpas="git diff NS \$(git merge-base --fork-point origin/\$(git master))"
alias glfp="git log 1L DEC HEAD...\$(git merge-base --fork-point origin/\$(git master))~"
alias glfps="git log 1L DEC NS HEAD...\$(git merge-base --fork-point origin/\$(git master))~"
alias gia="git merge-base --is-ancestor"
alias giam="git merge-base --is-ancestor \$(git master) HEAD; yorn"
alias giaom="git merge-base --is-ancestor origin/\$(git master) HEAD; yorn"

alias im=safe_nvim

# alias skf="sk --cmd 'git ls-files' -f"

alias bex="bundle exec"
alias ber="bundle exec rspec"
alias bers="bundle exec rspec \$(gdfp | specs)"
alias berof="bundle exec rspec --only-failures"
alias beru="bundle exec rubocop"
alias bera="bundle exec rake"
alias rg="rg -PS"
alias dirty="bundle exec rspec \$(gss | specs)"

alias rubies="rg '[.](rb|rake)$'"
alias norubies="rg -v '[.](rb|rake)$'"
alias jsfiles="rg '[.][tj]sx?$'"
alias nojsfiles="rg -v '[.][tj]sx?$'"
alias specs="rg '\\b(spec/.*_spec.rb|__tests__/.*[.]spec[.][tj]sx?)'"
alias nospecs="rg -v '\\b(spec/.*_spec.rb|__tests__/.*[.]spec[.][tj]sx?)'"
alias noimages="rg -v '[.](png|jpe?g|gif|ai)$'"
alias uspecs="gdm | specs"
alias lspecs="gss | rg 'spec/.*_spec.rb'"
alias noansi='sed "s/[0-9_:;\\[-]*m//g"'

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

export TERM=xterm-color

autoload -Uz add-zsh-hook

update_git_vars() {
  if git rev-parse --git-dir &>/dev/null; then
    export groot=`git rev-parse --show-toplevel`
    export cb=$(git cb)
    export rb="origin/$cb"
    export ocb="origin/$cb"
    export cbo="origin/$cb"
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

alias ll="ls -Al"
alias llr="ls -Altr"
alias lltr="ls -Altr"
alias ls="ls -A"
alias lsr="ls -A1tr"
alias lt="ls -Altr"
alias rg="rg -PS"


export PS1=$'\n'"%~ \$(git_prompt_info)"$'\n'"%#> "

export STARSHIP_CONFIG=$HOME/.config/starship/starship.toml
source <(starship init zsh --print-full-init)

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


eval "$(rbenv init -)"
export PATH="/opt/homebrew/opt/node@14/bin:$PATH"

[[ -n $SSH_CONNECTION && -z $VIM && -z $TMUX ]] && tmux new -A -s remote

export TERM=screen-256color

alias -g NS="--name-status"
alias -g NON="--name-only"
alias -g REL="--relative"
alias -g GG="--graph"
alias -g LR="--left-right"
alias -g 1L="--oneline"
alias -g DEC="--decorate"

alias gl="git log"
alias gd="git diff"

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
  if [[ "${BUFFER: -6}" == ' $(!!)' ]]; then
    BUFFER="${BUFFER:0:-6} \$(!-2)"
  elif [[ "$BUFFER" =~ ' \$\(!-([0-9]+)\)$' ]]; then
    local num=${match[1]}
    local suffix_len=$((6 + ${#num}))
    ((num++))
    BUFFER="${BUFFER:0:-$suffix_len} \$(!-${num})"
  else
    BUFFER+=" \$(!!)"
  fi
  CURSOR=${#BUFFER}
}

zle -N insert_last_output
bindkey '^[ ' insert_last_output
