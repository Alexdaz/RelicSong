#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

Song = Struct.new(:artist, :title) do
  def to_s
    "#{artist} - #{title}"
  end
end

# Knows how to ask Spotify which song is playing.
module Spotify
  # Returns nil if Spotify is closed or has no song loaded.
  def self.current_song
    song = RUBY_PLATFORM.include?('darwin') ? from_applescript : from_dbus
    song unless song.nil? || song.title.to_s.empty?
  end

  # Linux: the original path. 'dbus' is only loaded here, so macOS doesn't need the gem.
  def self.from_dbus
    require 'dbus'

    service = DBus::SessionBus.instance.service('org.mpris.MediaPlayer2.spotify')
    player = service.object('/org/mpris/MediaPlayer2')['org.mpris.MediaPlayer2.Player']
    metadata = player['Metadata']

    Song.new(Array(metadata['xesam:artist']).first, metadata['xesam:title'])
  rescue LoadError
    abort 'Relic Song needs the ruby-dbus gem: gem install ruby-dbus'
  rescue DBus::Error
    nil
  end

  # macOS: thanks to "is running", AppleScript never launches Spotify if it's closed.
  def self.from_applescript
    script = <<~APPLESCRIPT
      if application "Spotify" is running then
        tell application "Spotify"
          return (artist of current track) & linefeed & (name of current track)
        end tell
      end if
    APPLESCRIPT

    output = IO.popen(['osascript', '-e', script], err: File::NULL, encoding: 'UTF-8', &:read)
    artist, title = output.lines.map(&:strip)
    Song.new(artist, title)
  end
end

module Lyrics
  API = 'https://lrclib.net/api'
  # LRCLIB asks every app to identify itself: name, version and a link to the project.
  USER_AGENT = 'Relic Song v1.1 (https://github.com/alexdaz/relicsong)'

  def self.find(song)
    lyrics = exact_match(song) || first_search_result(song)
    return lyrics if lyrics

    rate_limited? ? 'LRCLIB asked us to wait a bit, lyrics will be back with the next song.' : "Couldn't find the lyrics :("
  end

  def self.exact_match(song)
    result = request('get', artist_name: song.artist, track_name: song.title)
    lyrics_from(result)
  end

  def self.first_search_result(song)
    sleep 0.3 # LRCLIB recommends a short pause between requests.
    results = request('search', artist_name: song.artist, track_name: song.title) || []
    results.map { |result| lyrics_from(result) }.compact.first
  end

  def self.lyrics_from(result)
    return nil unless result.is_a?(Hash)
    return 'Instrumental 🎶' if result['instrumental']

    result['plainLyrics']
  end

  def self.request(endpoint, params)
    return nil if rate_limited?

    uri = URI("#{API}/#{endpoint}")
    uri.query = URI.encode_www_form(params)

    # If LRCLIB doesn't answer within 5 seconds, better to move on without lyrics.
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.request(Net::HTTP::Get.new(uri, 'User-Agent' => USER_AGENT))
    end
    wait_for(response['Retry-After']) if busy?(response)
    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    nil
  end

  # LRCLIB asks for a break with 429 (too many requests) or 503 (server overloaded).
  def self.busy?(response)
    response.is_a?(Net::HTTPTooManyRequests) || response.is_a?(Net::HTTPServiceUnavailable)
  end

  # While LRCLIB is busy, no requests are sent until Retry-After has passed.
  def self.wait_for(retry_after)
    seconds = retry_after.to_i
    seconds = 60 unless seconds.positive? # Missing or unreadable header: wait a minute.
    @retry_at = Time.now + seconds
  end

  def self.rate_limited?
    !@retry_at.nil? && Time.now < @retry_at
  end
end

# Strips control characters (like "\e") from text that comes from outside,
# so it can't send commands to the terminal. Only line breaks are kept.
def clean(text)
  text.to_s.scrub.gsub(/[[:cntrl:]&&[^\n]]/, '')
end

def show(song)
  name = clean(song)

  system('clear')
  print "\e]0;Singing: #{name}\a" # Terminal window title.
  puts "\e[1;4m#{name}\e[0m\n\n"
  puts clean(Lyrics.find(song))
end

def goodbye
  puts "\nBye!"
  exit
end

trap('INT') { goodbye }
trap('TERM') { goodbye }

last_song = nil

loop do
  song = Spotify.current_song

  if song.nil?
    puts 'Spotify is not playing anything... :(' unless last_song == :waiting
    last_song = :waiting
  elsif song != last_song
    show(song)
    last_song = song
  end

  sleep 1
end
