#!/usr/bin/env -S uv run -q --with mido python
"""Open a Groove MIDI file in Qtractor, played by DrumGizmo (DRSKit).

Usage: groove.py FILE.mid [--no-launch]

Writes a Qtractor session (~/Audio/drums/sessions/<name>/<name>.qtr) holding one
MIDI track with the groove as a clip and the DrumGizmo LV2 plugin already set up
with DRSKit and the Groove MIDI midimap, then starts `pw-jack qtractor` on it.

DrumGizmo has one output per microphone (13 for DRSKit). Qtractor would only keep
the first two (room mics), so the plugin feeds a dedicated 16-channel "Drums" bus
whose ports are then linked to the default sink, each mic panned left, right or
centre (PipeWire sums the links).
"""
import shutil
import subprocess
import sys
import time
from pathlib import Path
from xml.sax.saxutils import escape

import mido

HERE = Path(__file__).resolve().parent
KIT = Path.home() / "Audio/drums/drumgizmo/DRSKit/DRSKit_full.xml"
MIDIMAP = HERE / "Midimap_groove.xml"
SESSIONS = Path.home() / "Audio/drums/sessions"
SRATE = 48000
TPB = 960  # Qtractor session ticks per beat
DRUMS_GAIN = 1.0

# DRSKit output (1-based) -> sides of the stereo mix
PAN = {
    1: "L",    # AmbL
    2: "R",    # AmbR
    3: "LR",   # Kdrum_back
    4: "LR",   # Kdrum_front
    5: "L",    # Hihat
    6: "L",    # OHL
    7: "R",    # OHR
    8: "R",    # Ride
    9: "LR",   # Snare_bottom
    10: "LR",  # Snare_top
    11: "L",   # Tom1
    12: "LR",  # Tom2
    13: "R",   # Tom3
}

DG_CONFIG = f"""<config version="1.0">
  <value name="drumkitfile">{KIT}</value>
  <value name="midimapfile">{MIDIMAP}</value>
  <value name="enable_velocity_modifier">false</value>
</config>"""


def groove_info(path):
    mid = mido.MidiFile(path)
    tempo = 500000
    for msg in mid.tracks[0]:
        if msg.type == "set_tempo":
            tempo = msg.tempo
            break
    # Qtractor clip "track-channel": the MIDI channel for SMF format 0,
    # the track index for format 1.
    if mid.type == 0:
        chan = next(m.channel for m in mid.tracks[0] if m.type == "note_on")
    else:
        chan = next(i for i, t in enumerate(mid.tracks)
                    if any(m.type == "note_on" for m in t))
    return round(mido.tempo2bpm(tempo), 3), mid.length, chan


def session_xml(name, midi_name, bpm, seconds, chan):
    length = int(seconds * SRATE) + SRATE  # one extra second for the tails
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE qtractorSession>
<session version="Qtractor 0.9.39" name="{escape(name)}">
 <properties>
  <description>Groove MIDI: {escape(midi_name)}</description>
  <sample-rate>{SRATE}</sample-rate>
  <tempo>{bpm}</tempo>
  <ticks-per-beat>{TPB}</ticks-per-beat>
  <beats-per-bar>4</beats-per-bar>
  <beat-divisor>2</beat-divisor>
 </properties>
 <state>
  <loop-start>0</loop-start>
  <loop-end>{length}</loop-end>
  <punch-in>0</punch-in>
  <punch-out>0</punch-out>
 </state>
 <devices>
  <audio-engine>
   <audio-bus name="Master" mode="duplex">
    <monitor>false</monitor>
    <channels>2</channels>
    <auto-connect>true</auto-connect>
   </audio-bus>
   <audio-bus name="Drums" mode="output">
    <monitor>false</monitor>
    <channels>16</channels>
    <auto-connect>false</auto-connect>
    <output-gain>{DRUMS_GAIN}</output-gain>
   </audio-bus>
  </audio-engine>
 </devices>
 <tracks>
  <track name="Drums" type="midi">
   <properties>
    <input-bus>Master</input-bus>
    <output-bus>Master</output-bus>
    <midi-omni>false</midi-omni>
    <midi-channel>9</midi-channel>
    <midi-drums>true</midi-drums>
   </properties>
   <state>
    <mute>false</mute>
    <solo>false</solo>
    <record>false</record>
    <monitor>false</monitor>
    <gain>1</gain>
    <panning>0</panning>
   </state>
   <clips>
    <clip name="{escape(name)}">
     <properties>
      <name>{escape(name)}</name>
      <start>0</start>
      <offset>0</offset>
      <length>{length}</length>
      <gain>1</gain>
      <panning>0</panning>
      <mute>false</mute>
     </properties>
     <midi-clip>
      <filename>{escape(midi_name)}</filename>
      <track-channel>{chan}</track-channel>
     </midi-clip>
    </clip>
   </clips>
   <plugins>
    <plugin type="LV2">
     <filename>http://drumgizmo.org/lv2</filename>
     <index>0</index>
     <label>DrumGizmo</label>
     <activated>true</activated>
     <configs>
      <config key="http://drumgizmo.org/lv2/atom#config" type="http://lv2plug.in/ns/ext/atom#String">{escape(DG_CONFIG)}</config>
     </configs>
     <params/>
    </plugin>
    <audio-output-bus>false</audio-output-bus>
    <audio-output-bus-name>Drums</audio-output-bus-name>
    <audio-output-auto-connect>false</audio-output-auto-connect>
   </plugins>
  </track>
 </tracks>
</session>
"""


def link_drums(timeout=60):
    """Link Qtractor:Drums/out_N to the default sink, panned as in PAN."""
    info = subprocess.run(["wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"],
                          capture_output=True, text=True).stdout
    sink = next(l.split('"')[1] for l in info.splitlines() if "node.name" in l)
    side = {"L": f"{sink}:playback_FL", "R": f"{sink}:playback_FR"}
    deadline = time.time() + timeout
    while "Qtractor:Drums/out_13" not in subprocess.run(
            ["pw-link", "-o"], capture_output=True, text=True).stdout:
        if time.time() > deadline:
            sys.exit("groove: Qtractor:Drums ports not found, mics not linked")
        time.sleep(1)
    for out, sides in PAN.items():
        for s in sides:
            subprocess.run(["pw-link", f"Qtractor:Drums/out_{out}", side[s]],
                           stderr=subprocess.DEVNULL)
    print(f"groove: 13 mics linked to {sink}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1:
        sys.exit(__doc__)
    src = Path(args[0]).expanduser().resolve()
    name = src.stem
    bpm, seconds, chan = groove_info(src)
    sdir = SESSIONS / name
    sdir.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, sdir / src.name)
    qtr = sdir / f"{name}.qtr"
    qtr.write_text(session_xml(name, src.name, bpm, seconds, chan))
    print(f"{qtr}  ({bpm} bpm, {seconds:.0f} s)")
    if "--no-launch" not in sys.argv:
        subprocess.Popen(["pw-jack", "qtractor", str(qtr)], cwd=sdir,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        link_drums()


if __name__ == "__main__":
    main()
