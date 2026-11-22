# Voices

1. `python3 lines.py GODOT_DIR lines.json` collects every scripted line and who says it.
2. Get Piper (`pip install piper-tts`) and the LibriTTS voice from the Piper GitHub release:
   `https://github.com/rhasspy/piper/releases/download/v0.0.2/voice-en-us-libritts-high.tar.gz`
   (unpack next to lines.json).
3. `f0.json` (each sampled speaker's median pitch) picks men's and women's voices; it was made by synthesising one
   sentence per fourth speaker and measuring its pitch by autocorrelation.
4. `python3 gen.py lines.json f0.json GODOT_DIR/voice 2` writes `voice/<who>/<key>.ogg` (and voices.json, the
   speaker, pace and effect each character got). ffmpeg does the effects, loudness and Ogg Vorbis encoding.

At run time `main.speak(text, who)` looks for `voice/<who>/<key>.ogg` (`main.voice_key`: md5 of the line's
letters and digits, lower case, with the player's name put back as `{name}`) and otherwise uses the device's
text-to-speech.
