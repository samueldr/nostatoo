#!/usr/bin/env ruby
# frozen_string_literal: true

require "shellwords"
require "json"
require "fileutils"
require_relative "lib/vdf"

def app_fail(msg)
  $stderr.puts(
    msg.split("\n").map.with_index do |line, i|
      if i == 0
        "Error: #{line}"
      else
        "       #{line}"
      end
    end
      .join("\n")
  )
  exit 1
end

UINT32_MAX = (1<<32) - 1

STEAM_DIR = File.join(Dir.home(), ".local/share/Steam")
# Unclear how to get the userdata directory correctly.
# For now it will only work when a single user is present.
# Alternatively we could force shortcuts to all users.
USERDATA_DIR = Dir.glob(File.join(STEAM_DIR, "userdata/*"))
  .select { |dir| !dir.match(%r{/0$}) }
  .tap do |dirs|
    if dirs.empty?
      app_fail "You must log into a steam account once before using this."
    elsif dirs.length > 1
      $stderr.puts "nostatoo currently works only when a single steam account is connected."
      exit 60
    end
  end.first

# HTTP utils
module HTTP
  def self.download(url, dest)
    cmd = [
      "curl",
      "-L",
      "-o", dest,
      url
    ]
    system(*cmd)
  end
end

# Module for the app.
module Nostatoo
  extend self

  FIELDS = {
    "appname" => "Name",
    "appid" => "Steam appid",
    "Exe" => "Executable",
    "StartDir" => "Start directory",
    "LaunchOptions" => "Launch options",
    "ShortcutPath" => "Desktop file",
  }.freeze

  #
  # Anything lower is invalid and will be “sanitized” by steam.
  # ```
  # [2024-10-17 03:18:59] sanitize shortcut app id "env": replacing 1 with 2680746172, reason: k_unLocalAppIDFlag not set
  # ```
  #
  # The meaning for the seemingly arbitrary `5000` here is unknown.
  #
  APPID_MIN = (1 << 31) | 5000

  def shortcut_appid_valid?(id)
    id = id.to_i if id.respond_to?(:to_i)
    id >= APPID_MIN && id <= UINT32_MAX
  end

  def assert_appid(id)
    unless shortcut_appid_valid?(id)
      app_fail [
        "The given appid (#{id}) is not in the valid range for appids.",
        "Hint: appids need to be in the range [#{APPID_MIN}..#{UINT32_MAX}]",
      ].join("\n")
    end
  end

  def usage()
    puts <<~DESC
      Usage: nostatoo <command> [args...]

      Commands:
        list-non-steam-games      Lists non-steam games
        show-non-steam-game       Show a given non-steam game by appid
        edit-non-steam-game       Edit a given non-steam game
        add-non-steam-game        Edit a given non-steam game
        add-asset                 Assign assets to a given non-steam game

        dump-non-steam-games      Dumps all non-steam games as JSON
        import-non-steam-games    Imports (replaces) all non-steam games from JSON
    DESC
  end

  def get_new_unused_appid(shortcuts)
    appid = rand(APPID_MIN..UINT32_MAX)
    appid = rand(APPID_MIN..UINT32_MAX) while select_appid(appid, shortcuts)
    appid
  end

  def config_dir()
    File.join(USERDATA_DIR, "config")
  end

  def grid_dir()
    File.join(config_dir, "grid")
  end

  def shortcuts_vdf()
    File.join(config_dir, "shortcuts.vdf")
  end

  def asset_names_for_appid(appid)
    {
      "horizontal_capsule" => "#{appid}.png",
      "vertical_capsule" => "#{appid}p.png",
      "logo" => "#{appid}_logo.png",
      "hero" => "#{appid}_hero.png",
    }
  end

  def select_appid(appid, shortcuts)
    appid = appid.to_i
    shortcuts.find do |_, item|
      item["appid"] == appid
    end
  end

  def write_shortcuts(shortcuts)
    FileUtils.mkdir_p(config_dir)
    VDF::Binary.write(shortcuts_vdf, shortcuts)
  end

  def read_shortcuts()
    if File.exist?(shortcuts_vdf)
      VDF::Binary.read(shortcuts_vdf)
    else
      {
        "shortcuts" => {},
      }
    end
  end

  def show_non_steam_game(appid = nil, *_)
    app_fail "No appid given to show-non-steam-game" unless appid

    shortcuts = read_shortcuts()
    id, shortcut = select_appid(appid, shortcuts["shortcuts"])
    app_fail "No game found for appid #{appid}." unless shortcut

    appid = shortcut["appid"]

    puts "(##{id}) #{shortcut["appname"].to_json}"

    FIELDS.each do |name, pretty|
      puts "  #{pretty}: #{shortcut[name].to_json}"
    end

    puts ""
    puts "Assets:"
    asset_names_for_appid(appid).each_value do |asset|
      present =
        if File.exist?(File.join(grid_dir, asset))
          "yes"
        else
          "NO"
        end
      puts "  - #{asset}: #{present}"
    end

    puts ""
    puts "Extra data:"
    shortcut.each do |key, value|
      next if FIELDS.keys.include?(key)

      puts "  - #{key}: #{value.to_json}"
    end
  end

  def edit_non_steam_game(appid = nil, *args)
    if !appid || args.empty?
      puts <<~DESC
        nostatoo edit-non-steam-game <appid> [args]

        args are given as key/value elements, separated by the first equal sign.

        NOTE: There is no validation for fields. Non-existant fields will be added blindly.
        NOTE: Tags cannot be edited this way yet.

        For example:

          nostatoo edit-non-steam-game 1234564400 "appname=Nice app"
          nostatoo edit-non-steam-game 1234564400 'Executable="/run/current-system/sw/bin/nice-app"'

        Known useful field names:
        #{FIELDS.map { |k, v| "  - #{v}: #{k}" }.join("\n")}

        See also field names for extra data in `show-non-steam-game`
      DESC
      exit 1
    end

    shortcuts = read_shortcuts()
    id, shortcut = select_appid(appid, shortcuts["shortcuts"])
    app_fail "No game found for appid #{appid}." unless shortcut

    edited = shortcuts["shortcuts"][id].dup

    args.each do |arg|
      name, value = arg.split("=", 2)
      if name == "appid"
        assert_appid(value)
      end
      edited[name] = value
    end

    shortcuts["shortcuts"][id] = edited

    write_shortcuts(shortcuts)

    puts "Edited..."
    puts ""
    show_non_steam_game(appid)
  end

  def add_asset(*args)
    if args.length != 3
      puts <<~DESC
        nostatoo add-asset <appid> <type> <file|url>

        Type is either

          - horizontal_capsule (${APPID}.png)
          - vertical_capsule (${APPID}p.png)
          - logo (${APPID}_logo.png)
          - hero (${APPID}_hero.png)

        If a file is given, it is copied over.
        If an URL is given, the image is downloaded

        Existing assets are overwritten.
      DESC
      exit 1
    end

    appid, type, url = args
    image_name = asset_names_for_appid(appid)[type]

    # Assert just in case, so we don't break assumptions.
    # NOTE: we may want to warn, in the future, if writing assets for lower IDs has any use.
    assert_appid(appid)

    unless image_name
      $stderr.puts "Image type '#{type}' unknown."
      exit 1
    end

    dest = File.join(grid_dir, image_name)
    FileUtils.mkdir_p(grid_dir)

    case url
    when %r{^https?://}
      puts "Downloading #{url.to_json} to #{dest.to_json}"
      HTTP.download(url, dest)
    when %r{^[a-zA-Z0-9]+://}
      $stderr.puts "Protocol not supported."
      exit 1
    else
      puts "Copying #{url.to_json} to #{dest.to_json}"
      FileUtils.cp(url, dest)
    end
  end

  def add_non_steam_game(*args)
    if args.length < 2 || args.length > 3
      puts <<~DESC
        nostatoo add-non-steam-game <name> <executable> [start_directory]

         - name is the pretty name of the app
         - executable is the executable to run (can be searched in PATH)
         - start_directory, optional, will default to '"./"'

        To edit other fields, use `edit-non-steam-game`.

        The new appid will be the only output.
      DESC
      exit 1
    end

    name, exe, start_dir = args
    start_dir ||= '"./"'

    shortcuts = read_shortcuts()
    appid = get_new_unused_appid(shortcuts)
    key = (shortcuts["shortcuts"].keys.last.to_i + 1).to_s

    shortcuts["shortcuts"][key] = {
      "appid" => appid,
      "appname" => name,
      "Exe" => exe,
      "StartDir" => start_dir,
      "icon" => "",
      "ShortcutPath" => "",
      "LaunchOptions" => "",
      "IsHidden" => 0,
      "AllowDesktopConfig" => 1,
      "AllowOverlay" => 1,
      "OpenVR" => 0,
      "Devkit" => 0,
      "DevkitGameID" => "",
      "DevkitOverrideAppID" => 0,
      "LastPlayTime" => 0,
      "FlatpakAppID" => "",
      "tags" => {},
    }

    write_shortcuts(shortcuts)

    puts appid
  end

  def list_non_steam_games(*_)
    shortcuts = read_shortcuts()
    shortcuts["shortcuts"].each do |key, value|
      puts "#{key}: #{value["appid"]}: #{value["appname"]} "
    end
    puts ""
  end

  def dump_non_steam_games(*_)
    shortcuts = read_shortcuts()
    puts JSON.pretty_generate(shortcuts)
  end

  def import_non_steam_games(*args)
    if args.length != 1
      puts <<~DESC
        nostatoo import-non-steam-games <file>

        All non-steam games are overwritten.

        No validation of the structure is done.
      DESC
      exit 1
    end

    path = args.first
    shortcuts = JSON.parse(File.read(path))

    # Validate for bogus appid on import.
    shortcuts["shortcuts"].each do |id, shortcut|
      puts "Validating entry #{id}... (#{shortcut["appname"].inspect})"
      assert_appid(shortcut["appid"])
      puts " ... ok"
    end

    write_shortcuts(shortcuts)
  end
end

if ARGV.empty?
  Nostatoo.usage()
  exit 1
end

command = ARGV.shift

case command
when "list-non-steam-games"
  Nostatoo.list_non_steam_games(*ARGV)
when "show-non-steam-game"
  Nostatoo.show_non_steam_game(*ARGV)
when "add-non-steam-game"
  Nostatoo.add_non_steam_game(*ARGV)
when "edit-non-steam-game"
  Nostatoo.edit_non_steam_game(*ARGV)
when "add-asset"
  Nostatoo.add_asset(*ARGV)
when "dump-non-steam-games"
  Nostatoo.dump_non_steam_games(*ARGV)
when "import-non-steam-games"
  Nostatoo.import_non_steam_games(*ARGV)
else
  $stderr.puts "Unexpected command #{command.dump}"
  Nostatoo.usage()
  exit 2
end
