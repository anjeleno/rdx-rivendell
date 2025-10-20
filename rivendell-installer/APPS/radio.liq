#!/usr/bin/liquidsoap

set("log.file.path", "/home/rd/logs/soap.log")

# Set sample rate to 48kHz
set("frame.audio.samplerate", 48000)

# Enable ICY metadata globally
set("icy.metadata", true)

# Grab JACK input
radio = input.jack(id="liquidsoap")

# Ensure stream stability
radio = mksafe(radio)

# Icecast output
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

# password="hackm3", (must match icecast source password)