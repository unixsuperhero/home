setopt EXTENDED_GLOB
setopt PROMPT_VARS

. /opt/homebrew/opt/asdf/libexec/asdf.sh
. $(brew --prefix)/etc/profile.d/z.sh

export HOMEBREW_NO_ENV_HINTS=1
export PATH="$HOME/bin:$HOME/.ghcup/bin:$PATH"

export EDITOR=$HOME/bin/safe_nvim
export DADE_NEXT=1
bindkey -e # after setting editor, reset terminal to emacs mode
alias vim="$HOME/bin/safe_nvim"

zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
autoload -Uz compinit && compinit

autoload -U edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line

alias ls="ls -l"
alias mdb="rake db:migrate; RAILS_ENV=test rake db:migrate"

alias g="git"
alias gaa="git add --all"
alias gb="git branch -i"
alias gbr="git branch -i --sort=authordate"
alias gc="git commit"
alias gco="git checkout"
alias gd="git diff"
alias gdc="git diff --cached"
alias gkl="git clean -fd"
alias glod="git log --oneline --decorate"
alias glodd="git log --oneline --decorate -10"
alias glodiff="git log --oneline --decorate --left-right HEAD...origin/HEAD"
alias gp="git push"
alias gph="git push origin HEAD"
alias gpod="git pull origin development"
alias gpr="git pull --rebase"
alias gst="git status -s"
alias st="git status -s"

alias greset="git checkout .; git clean -fd"

# alias skf="sk --cmd 'git ls-files' -f"

alias specs="rg _spec"
alias rubies="rg '[.]rb$'"
alias ber="bundle exec rspec"
alias bers="bundle exec rspec \$(gddev | specs)"
alias dirty="bundle exec rspec \$(gss | specs)"

function gddev {
  if [[ $PWD == *postprocessors* ]]; then
    git diff master --name-only --diff-filter=d | sed 's/.*[[:space:]]//'
  else
    git diff development --name-only --diff-filter=d | sed 's/.*[[:space:]]//'
  fi
}

alias gbs="gb | sed 's/.*[[:space:]]//' | sk"

alias sc="bin/rails c"
alias ss="bin/rails s -p 3000"
alias ssp="bin/rails s -p"
alias wkr='(unset DADE_NEXT; QUEUE=* bundle exec rake resque:work)'

alias ezs="vim ~/.zshrc"
alias .zs="source ~/.zshrc"

alias rg="rg -S"
alias cat="bat"

function gss() {
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

# Homebrew
# export PATH=/opt/homebrew/bin:$PATH
# export PATH="/opt/homebrew/sbin:$PATH"
# rbenv
# export RBENV_ROOT=/opt/homebrew/opt/rbenv
# export PATH=$RBENV_ROOT/bin:$PATH
eval "$(rbenv init -)"
# openssl
export PATH="/opt/homebrew/opt/openssl@1.1/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/openssl@1.1/lib"
export CPPFLAGS="-I/opt/homebrew/opt/openssl@1.1/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@1.1/lib/pkgconfig"
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=/opt/homebrew/opt/openssl@1.1"
