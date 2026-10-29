# dockhop: app launching for cool cats

This utility binds numeric hotkeys to launch or focus the apps in your macOS dock.
By default, CMD+N is used to launch/focus, so if your dock looks like the one below,
pressing CMD+1 will run Safari, CMD+2 Ghostty, and so on.

<img src="screenshot.jpg" alt="a macOS dock showing Finder, Safari, Ghostty, VSCode, Slack, and Mail" width="600">

That's basically all you need to know. Some extra details:
* The modifier(s) can be changed: shift, option, control, command
* Finder can be included as MODIFIER+1. (disabled by default)
* Only pinned apps are included (called `persistent-apps` in the dock configuration). Spacers, separators, folders, etc. are ignored.

One benefit of this simplicity is the program has a very small footprint; I've observed around ~5 MB of RAM usage on my machine.

## Homebrew

You can install via `brew`:

```sh
brew install malensek/brew/dockhop

# Optionally enable the service:
brew services start malensek/brew/dockhop
```

Or build it yourself (see below).

## Build and Run from Source

```sh
make
./dockhop

# To install to your $PREFIX:
make install

# Enable the login item at startup:
make install-launchagent

# If you decide you want to remove the login item:
make remove-launchagent

# Or, run the program with a different config:
DOCKHOP_CONFIG=config.example.json ./dockhop
```

## Configuration

The default CMD+N shortcut can collide with other programs' keybindings (usually used for switching tabs directly -- I've never found it to be too big of a loss).
So, if you'd like to change the defaults:

```sh
mkdir -p ~/.config/dockhop

# If built from source:
cp config.example.json ~/.config/dockhop/config.json

# If using the homebrew installed version:
cp -n "$(brew --prefix dockhop)/share/dockhop/config.example.json" ~/.config/dockhop/config.json
```

Config precedence:
* Path in `DOCKHOP_CONFIG` environment variable
* `~/.config/dockhop/config.json`
* If no config is found, the defaults are used (`modifiers`: command, `includeFinder`: false)

### Options (config.json)

* `modifiers`: `command`, `option`, `control`, `shift` (note that `shift` must be combined with one of the other modifiers)
* `includeFinder`: `true` / `false`

<br>


```
                
     /\_/\    +- outta sight, daddy-o! -+
    ( o.o )
     > ^ <

```
