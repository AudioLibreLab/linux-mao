# Jam session

`./jam.sh start` lance la session stompbox `bossa` (Carla, Hydrogen,
SooperLooper, patchbay) et le serveur web JamCapture (`serve -v3`).

```shell
./jam.sh start [session] [url-youtube]   # défaut: bossa
./jam.sh stop [session]
./jam.sh restart [session] [url-youtube]
./jam.sh status [session]  # état des unités + URL du serveur JamCapture
./jam.sh logs              # journal de JamCapture
./jam.sh board [url-youtube]   # la fenêtre splittée seule
```

`start` ouvre aussi `jamboard.html` dans une fenêtre Chrome : lecteur
YouTube à gauche, JamCapture à droite, séparateur déplaçable à la souris
(double-clic pour revenir à 50/50). GNOME sous Wayland refusant de placer
les fenêtres, le split se fait dans une seule fenêtre plutôt qu'avec deux.
`JAM_BOARD=0` pour ne pas l'ouvrir.

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