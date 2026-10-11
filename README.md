# Relic Song

Show the lyrics of the song currently playing on Spotify, right in your terminal.

Relic Song watches Spotify and, whenever the song changes, clears the screen and prints the new lyrics. It was born on Linux and also runs on macOS.

![Screenshot](/Assets/SSRelicSong.png)

## Features

- Works on **Linux** (through D-Bus/MPRIS) and **macOS** (through AppleScript).
- Lyrics from [LRCLIB](https://lrclib.net): free, no API key needed.
- Falls back to a broader search when there is no exact match (useful for titles like "… - Remastered 2007").
- Shows the current song in your terminal's window title.
- Only queries LRCLIB when the song changes.

## Requirements

- Ruby 2.6 or newer. No extra gems on macOS.
- The Spotify desktop app.

### Linux

Install the `ruby-dbus` gem:

```
gem install ruby-dbus
```

### macOS

The first time you run Relic Song, macOS asks whether your terminal may control Spotify. Allow it. If you denied it by mistake, turn it back on in **System Settings -> Privacy & Security -> Automation**. Otherwise Relic Song will keep saying that nothing is playing.

## Usage

```
ruby relicsong.rb
```

Or make it executable and run it directly:

```
chmod +x relicsong.rb
./relicsong.rb
```

Press `Ctrl+C` to quit.

## How it works

1. **Find the current song.** On Linux, Relic Song reads Spotify's metadata from the `org.mpris.MediaPlayer2.spotify` D-Bus service. On macOS, it asks Spotify through AppleScript and never launches Spotify if it is closed. Any system other than macOS uses D-Bus.
2. **Fetch the lyrics.** It asks LRCLIB for an exact match first and falls back to a search. Requests time out after 5 seconds, so a slow server never freezes the script.
3. **Print them safely.** Song names and lyrics come from outside sources, so control characters are stripped before printing. That way they cannot send escape sequences to your terminal.

## Credits

- Inspired by [spotify-lyrics](https://github.com/cjlh/spotify-lyrics) by [cjlh](https://github.com/cjlh), a Python script that does the same thing.
- Lyrics provided by [LRCLIB](https://lrclib.net).
- The name is a nod to Relic Song, the signature move of a certain melodious Mythical Pokémon. 🎶
