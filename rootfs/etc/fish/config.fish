if status is-interactive
  set fish_greeting
  set --universal pure_enable_single_line_prompt true
  fzf_configure_bindings --variables=\e\cv --directory=\cf
  if not set -q SSH_AUTH_SOCK; or not test -S "$SSH_AUTH_SOCK"
      eval (ssh-agent -c | string collect) >/dev/null 2>&1
  end
  ssh-add -l >/dev/null 2>&1; or ssh-add -q ~/.ssh/id_ed25519 >/dev/null 2>&1
  export EDITOR=nvim
  export ZK_NOTEBOOK_DIR="$HOME/notes"
  alias c=oco
  alias wiremix='wiremix --config /etc/wiremix/wiremix.toml'
  alias mix=wiremix
  alias lazygit='lazygit --use-config-dir /etc/lazygit'
  alias l=lazygit
  alias v=nvim
  alias vim=nvim
  alias p=python3
  alias d='docker compose'
  alias du='docker compose up -d'
  alias dd='docker compose down'
  alias dr='docker compose restart'
  alias dev='docker compose -f docker-compose.dev.yml up -d'
  alias devd='docker compose -f docker-compose.dev.yml down'
  alias devr='docker compose -f docker-compose.dev.yml restart'
  alias cp='rsync -ah --info=progress2'
  alias mv='rsync -ah --info=progress2 --remove-source-files'
  alias t='trans -b :en'
  alias tp='trans -b :pl'
  alias box='rclone mount box: ~/box --vfs-cache-mode full --daemon'
  alias syncbox='rsync -av --size-only --delete --progress -e ssh box:Muzyka/ Muzyka/'

  alias w=wifitui
  alias b=bluetoothctl
  # Connect to Headphones
  alias bh='b power off && b power on && b connect F4:0E:11:78:E7:F3'
  # Connect to Speaker
  alias bs='b power off && b power on && b connect 08:F0:B6:F6:1C:C5'
  # Connect to small speaker
  alias bss='b power off && b power on && b connect 00:02:3C:65:84:E1'
  alias bd='b disconnect'
  # Restart Pipewire
  alias pw='systemctl --user restart wireplumber pipewire pipewire-pulse'

  function g
    set -l common_args --ephemeral --skip-git-repo-check --sandbox read-only

    if test (count $argv) -gt 0
      set -l prompt (string join ' ' -- $argv)
      codex exec $common_args "$prompt" 2>/dev/null
    else
      codex exec $common_args - 2>/dev/null
    end
  end
end
