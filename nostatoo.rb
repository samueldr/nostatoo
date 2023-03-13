# frozen_string_literal: true

require "json"
require_relative "lib/vdf"

def app_fail(msg)
  $stderr.puts("Error: #{msg}")
  exit 1
end

STEAM_DIR = File.join(Dir.home(), ".local/share/Steam")
# Unclear how to get the userdata directory correctly.
# For now it will only work when a single user is present.
# Alternatively we could force shortcuts to all users.
USERDATA_DIR = Dir.glob(File.join(STEAM_DIR, "userdata/*")).tap do |dirs|
  if dirs.empty?
    app_fail "You must log into a steam account once before using this."
  elsif dirs.length > 1
    $stderr.puts "nostatoo currently works only when a single steam account is connected."
    exit 60
  end
end.first

# Module for the app.
module Nostatoo
  extend self

  def usage()
    puts <<~DESC
      Usage: nostatoo <command> [args...]

      Commands:
        list-non-steam-games      Lists non-steam games
        show-non-steam-game       Show a given non-steam game by appid

        dump-non-steam-games      Dumps all non-steam games as JSON
        import-non-steam-games    Imports all non-steam games from JSON
    DESC
  end

  def select_appid(appid, shortcuts)
    appid = appid.to_i
    shortcuts.find do |_, item|
      item["appid"] == appid
    end
  end

  def show_non_steam_game(appid = nil, *_)
    app_fail "No appid given to show-non-steam-game" unless appid

    shortcuts = VDF::Binary.read(File.join(USERDATA_DIR, "config/shortcuts.vdf"))
    id, shortcut = select_appid(appid, shortcuts["shortcuts"])
    app_fail "No game found for appid #{appid}." unless shortcut

    puts "(##{id}) #{shortcut["appname"].to_json}"
    fields = {
      "appname" => "Name",
      "appid" => "Steam appid",
      "Exe" => "Executable",
      "StartDir" => "Start directory",
      "LaunchOptions" => "Launch options",
      "ShortcutPath" => "Desktop file",
    }

    fields.each do |name, pretty|
      puts "  #{pretty}: #{shortcut[name].to_json}"
    end

    puts ""
    puts "Extra data:"
    shortcut.each do |key, value|
      next if fields.keys.include?(key)

      puts "  - #{key}: #{value.to_json}"
    end
  end

  def dump_non_steam_games(*_)
    shortcuts = VDF::Binary.read(File.join(USERDATA_DIR, "config/shortcuts.vdf"))
    puts JSON.pretty_generate(shortcuts)
  end

  def list_non_steam_games(*_)
    shortcuts = VDF::Binary.read(File.join(USERDATA_DIR, "config/shortcuts.vdf"))
    shortcuts["shortcuts"].each do |key, value|
      puts "#{key}: #{value["appid"]}, #{value["appname"]} "
    end
    puts ""
  end
end

if ARGV.empty?
  Nostatoo.usage()
  exit 1
end

command = ARGV.shift

case command
when "show-non-steam-game"
  Nostatoo.show_non_steam_game(*ARGV)
when "dump-non-steam-games"
  Nostatoo.dump_non_steam_games(*ARGV)
when "list-non-steam-games"
  Nostatoo.list_non_steam_games(*ARGV)
else
  $stderr.puts "Unexpected command #{command.dump}"
  Nostatoo.usage()
  exit 2
end
