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

`start` ouvre aussi YouTube et JamCapture dans deux onglets Chrome ;
**Shift+Alt+N** (ou clic droit sur un onglet → vue partagée) les met côte
à côte avec le split natif de Chrome. `JAM_BOARD=0` n'ouvre pas le
navigateur.

`JAM_BOARD_MODE=board` utilise à la place `jamboard.html`, une page locale
déjà splittée (séparateur déplaçable, double-clic pour 50/50) : aucun
geste à faire, mais le panneau gauche est le lecteur *embed* de YouTube,
donc sans recherche ni compte connecté, et certaines vidéos y sont
interdites. Elle est servie par un serveur local (`jamboard.service`,
127.0.0.1:8181) car depuis une page `file://` le lecteur YouTube voit une
origine nulle et refuse de jouer (erreur 153).

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