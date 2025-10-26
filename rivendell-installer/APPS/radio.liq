#!/usr/bin/liquidsoap

# Log to the user's config directory
set("log.stdout", true)
set("log.file", false)

# Set sample rate to 48kHz
set("frame.audio.samplerate", 48000)

# Enable ICY metadata globally
set("icy.metadata", true)

# Grab JACK input
radio = input.jack(id="liquidsoap")

# Ensure stream stability
radio = mksafe(radio)

# Icecast output (MP3 example)
output.icecast(
  %mp3(bitrate=192),
  host="localhost",
  port=8000,
  password="hackm3",
  mount="/192",
  genre="Electronic",
  url="192",
  name=":: Station Name :: Your Slogan ::",
  description="",
  radio
)

# Icecast output (AAC example via FFmpeg; requires liquidsoap-plugin-ffmpeg)
# Note: In Liquidsoap 2.x, explicitly enable audio in %ffmpeg to avoid type errors.
# Mount uses ADTS/AAC; Icecast will advertise appropriate MIME automatically.
# Uncomment to use:
# output.icecast(
#   %ffmpeg(audio=true, video=false, format="adts", audio_codec="aac", audio_bitrate="64k"),
#   host="localhost",
#   port=8000,
#   password="hackm3",
#   mount="/aac64",
#   genre="Electronic",
#   url="aac64",
#   name=":: Station Name :: Your Slogan ::",
#   description="AAC+ stream at 64 kbps",
#   radio
# )

# password="hackm3", (must match icecast source password)