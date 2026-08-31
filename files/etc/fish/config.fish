if status is-interactive
  set fish_greeting
  fzf_configure_bindings --variables=\e\cv --directory=\cf
  set --universal pure_enable_single_line_prompt true
  set PATH "/usr/sbin:$HOME/.local/bin:$PATH:$HOME/.scripts"
  alias g=sgpt
  alias c=oco
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
  alias p=python3
  alias pt=ptpython
  alias v=nvim
  alias vim=nvim
  alias l=lazygit
  alias cp='rsync -ah --info=progress2'
  alias mv='rsync -ah --info=progress2 --remove-source-files'
  alias t='trans -b :en'
  alias tp='trans -b :pl'
  alias s=screen
  alias d='docker compose'
  alias du='docker compose up -d'
  alias dd='docker compose down'
  alias dr='docker compose restart'
  alias dev='docker compose -f docker-compose.dev.yml up -d'
  alias devd='docker compose -f docker-compose.dev.yml down'
  alias devr='docker compose -f docker-compose.dev.yml restart'
  alias box='rclone mount box: ~/box --vfs-cache-mode full --daemon'
  alias syncbox='rsync -av --size-only --delete --progress -e ssh box:Muzyka/ Muzyka/'
  export PATH="$PATH:/opt/nvim/"
  export ASDF_DATA_DIR="$HOME/.local/share/asdf"
  export PATH="$ASDF_DATA_DIR/shims:$PATH"
  export PATH="$HOME/.local/share/pypoetry/bin:$PATH"
  export EDITOR=nvim
  export TERM=xterm-256color
  export ZK_NOTEBOOK_DIR="$HOME/notes"
end
