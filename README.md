# Jam session

`./jam.sh start` lance la session stompbox `bossa` (Carla, Hydrogen,
SooperLooper, patchbay) et le serveur web JamCapture (`serve -v3`).

```shell
./jam.sh start [session]   # défaut: bossa
./jam.sh stop [session]
./jam.sh restart [session]
./jam.sh status [session]  # état des unités + URL du serveur JamCapture
./jam.sh logs              # journal de JamCapture
```

Les deux outils lisent leur configuration dans `~/.config`
(`~/.config/stompbox/stompbox.yaml`, lien créé par `stomp apply`, et
`~/.config/jamcapture.yaml`), donc le script marche depuis n'importe où.


# Add audio user to audio group and restart the computer
sudo adduser $USER audio

# Start guitarix
PIPEWIRE_LATENCY="512/48000" pw-jack guitarix
# Set IN/OUT in Engine -> Jack Ports

# Start Ardour
PIPEWIRE_LATENCY="512/48000" pw-jack ardour

# Pipewire utility
qpwgraph


# Midi

WARN: start rosegarden, then qsynth

```shell
pw-jack rosegarden
qsynth
```

# Websites

https://www.fr.wikiloops.com/

## Groove Scribe

https://www.mikeslessons.com/groove/?TimeSig=4/4&Div=16&Tempo=80&Measures=1&H=|xxxxxxxxxxxxxxxx|&S=|----O-------O---|&K=|o-------o-------|


# AI
https://suno.com/create
https://www.lalal.ai/

# Fretboard.js
https://moonwave99.github.io/fretboard.js/index.html