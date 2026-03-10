# Home Manager Reference

User-level configuration management.

## Basic Structure

```nix
{ config, pkgs, ... }:
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";

  # Packages
  home.packages = with pkgs; [ vim git ];

  # Programs with configuration
  programs.git.enable = true;

  # User services
  systemd.user.services.myservice = { ... };

  # Dotfiles
  home.file.".config/app/config".text = "...";
}
```

## Installation Modes

### As NixOS Module (Recommended)

In flake.nix:

```nix
home-manager.nixosModules.home-manager {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.user = import ./home.nix;
  home-manager.extraSpecialArgs = {
    inherit pkgs-unstable;
  };
}
```

Rebuild with:

```bash
sudo nixos-rebuild switch --flake .#hostname
```

### Standalone

```nix
homeConfigurations.user = home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [ ./home.nix ];
};
```

Switch with:

```bash
home-manager switch --flake .#user
```

## Programs Configuration

Enable and configure applications:

```nix
programs.git = {
  enable = true;
  userName = "Your Name";
  userEmail = "you@example.com";
  extraConfig = {
    init.defaultBranch = "main";
    pull.rebase = true;
  };
};

programs.neovim = {
  enable = true;
  package = pkgs-unstable.neovim-unwrapped;
  extraPackages = [ pkgs.luajitPackages.jsregexp ];
};

programs.fish.enable = true;
programs.zoxide.enable = true;
programs.starship.enable = true;
```

## Packages

Install user packages:

```nix
home.packages = with pkgs; [
  ripgrep
  fd
  stylua
  wezterm
];
```

## File Management

### home.file

Create files in home directory:

```nix
home.file = {
  ".config/myapp/config.toml".text = ''
    [settings]
    theme = "dark"
  '';

  ".local/bin/script".source = ./scripts/script.sh;
  ".local/bin/script".executable = true;

  # Recursive directory
  ".config/nvim".source = ./nvim;
  ".config/nvim".recursive = true;
};
```

### xdg.configFile

XDG-compliant config files:

```nix
xdg.configFile = {
  "myapp/config.toml".text = ''
    [settings]
    theme = "dark"
  '';
};
# Creates ~/.config/myapp/config.toml
```

## User Services

Systemd user units:

```nix
systemd.user.services.myservice = {
  Unit = {
    Description = "My background service";
    After = [ "graphical-session.target" ];
  };
  Service = {
    ExecStart = "${pkgs.mypackage}/bin/myservice";
    Restart = "on-failure";
    RestartSec = 5;
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
};
```

## Session Variables

Environment variables:

```nix
home.sessionVariables = {
  EDITOR = "nvim";
  VISUAL = "nvim";
  MY_CUSTOM_VAR = "value";
};
```

## Shell Aliases

```nix
home.shellAliases = {
  ll = "ls -la";
  g = "git";
  v = "nvim";
};
```

## dconf Settings (GNOME)

Configure GNOME via dconf:

```nix
dconf.settings = {
  "org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };

  "org/gnome/desktop/wm/keybindings" = {
    close = [ "<Super>q" ];
    switch-to-workspace-left = [ "<Super>h" ];
    switch-to-workspace-right = [ "<Super>l" ];
  };
};
```

## Imports

Split configuration into modules:

```nix
{ config, pkgs, ... }:
{
  imports = [
    ./home-modules/neovim.nix
    ./home-modules/shell.nix
  ];

  home.username = "user";
  home.homeDirectory = "/home/user";
}
```

## State Version

**Important**: Don't change after initial setup:

```nix
home.stateVersion = "24.11";
```

This affects migration behavior, not the installed software versions.

## Activation Scripts

Run scripts on activation:

```nix
home.activation = {
  myActivationAction = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p $HOME/.local/share/myapp
  '';
};
```

## Combining with NixOS Options

Some settings need both NixOS and Home Manager:

```nix
# In configuration.nix (system-level)
programs.fish.enable = true;  # Install system-wide

# In home.nix (user-level)
programs.fish = {
  enable = true;
  shellAliases = { ... };
  interactiveShellInit = "...";
};
```
