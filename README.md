Nostatoo
========

The *Non-Steam App Toolkit*.

* * *

## Features

Manage non-steam apps.

 - List apps
 - Edit existing app
 - Edit assets for app
 - Add new app

* * *

## Usage

```
Usage: nostatoo <command> [args...]

Commands:
  list-non-steam-games      Lists non-steam games
  show-non-steam-game       Show a given non-steam game by appid
  edit-non-steam-game       Edit a given non-steam game

  dump-non-steam-games      Dumps all non-steam games as JSON
  import-non-steam-games    Imports (replaces) all non-steam games from JSON
```

### Listing non-steam games

```
 $ nostatoo list-non-steam-games
0: 2317857074, itch 
1: 2721447904, PCSX2 
2: 3245514289, Dolphin Emulator 
3: 2511686724, PPSSPP 
4: 2470680888, Video Player
```

### Adding non-steam games

```
 $ nostatoo add-non-steam-game
nostatoo add-non-steam-game <name> <executable> [start_directory]

 - name is the pretty name of the app
 - executable is the executable to run (can be searched in PATH)
 - start_directory, optional, will default to '"./"'

To edit other fields, use `edit-non-steam-game`.

The new appid will be the only output.

 $ nostatoo add-non-steam-game "App name" "/run/current-system/sw/bin/ten-foot-ui"
3143231757
```

### Editing non-steam games

```
 $ nostatoo edit-non-steam-game
nostatoo edit-non-steam-game <appid> [args]

args are given as key/value elements, separated by the first equal sign.

NOTE: There is no validation for fields. Non-existant fields will be added blindly.
NOTE: Tags cannot be edited this way yet.

For example:

  nostatoo edit-non-steam-game 1234564400 "appname=Nice app"
  nostatoo edit-non-steam-game 1234564400 'Executable="/run/current-system/sw/bin/nice-app"'

Known useful field names:
  - Name: appname
  - Steam appid: appid
  - Executable: Exe
  - Start directory: StartDir
  - Launch options: LaunchOptions
  - Desktop file: ShortcutPath

See also field names for extra data in `show-non-steam-game`

 $ nostatoo edit-non-steam-game 3143231757 "appname=Renamed app"
```

### Adding assets

```
 $ nostatoo add-asset
nostatoo add-asset <appid> <type> <file|url>

Type is either

  - horizontal_capsule (${APPID}.png)
  - vertical_capsule (${APPID}p.png)
  - logo (${APPID}_logo.png)
  - hero (${APPID}_hero.png)

If a file is given, it is copied over.
If an URL is given, the image is downloaded

Existing assets are overwritten.

 $ nostatoo add-asset 3613214400 logo htts://example.com/logo.png
Downloading "htts://example.com/logo.png" to "/Users/samuel/.local/share/Steam/userdata/32323380/config/grid/3613214400_logo.png"
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 16125  100 16125    0     0  23837      0 --:--:-- --:--:-- --:--:-- 23818
```

### Batch operations

It's possible to do batch operations and *more shenanigans* by using
`dump-non-steam-games` and `import-non-steam-games`.

The format of `import-non-steam-games` is the format of `dump-non-steam-games`.

Importing an unmodified dump should be a no-op, though it **will** rewrite
the database.


* * *

License
-------

This is published under the GPLv3 License **only**.

