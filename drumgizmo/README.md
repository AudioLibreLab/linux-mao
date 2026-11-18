# Grooves de vrais batteurs : Groove MIDI + DrumGizmo + Qtractor

Jouer les enregistrements MIDI de vrais batteurs (Groove MIDI Dataset de Google)
avec un kit acoustique échantillonné (DrumGizmo, DRSKit), pour un son moins
mécanique que les patterns Hydrogen calés sur la grille.

## Installation

```shell
sudo apt install qtractor drumgizmo

# Grooves : ~1 150 fichiers MIDI, 13 h de jeu, licence CC BY 4.0 (3 Mo)
mkdir -p ~/Audio/drums/groove-midi && cd ~/Audio/drums/groove-midi
curl -LO https://storage.googleapis.com/magentadata/datasets/groove/groove-v1.0.0-midionly.zip
unzip groove-v1.0.0-midionly.zip

# Kit DrumGizmo DRSKit (2,8 Go)
mkdir -p ~/Audio/drums/drumgizmo && cd ~/Audio/drums/drumgizmo
curl -LO https://drumgizmo.org/kits/DRSKit/DRSKit2_1.zip
unzip DRSKit2_1.zip && rm DRSKit2_1.zip
```

`groove/info.csv` donne pour chaque fichier le batteur, le style
(rock, funk, jazz, latin, hiphop, soul…), le tempo et le type (`beat` ou `fill`) :

```shell
grep -E 'funk.*beat' ~/Audio/drums/groove-midi/groove/info.csv | head
```

## Jouer un groove dans Qtractor

```shell
./groove.py ~/Audio/drums/groove-midi/groove/drummer9/session1/23_rock_120_beat_4-4.mid
```

Le script écrit une session `~/Audio/drums/sessions/<nom>/<nom>.qtr` (tempo repris
du fichier MIDI, une piste MIDI avec le groove, DrumGizmo déjà réglé sur DRSKit et
`Midimap_groove.xml`) puis lance `pw-jack qtractor` dessus. `--no-launch` écrit la
session sans lancer Qtractor. Attendre la fin du chargement du kit (quelques
secondes, des XRUN peuvent apparaître pendant ce temps), puis Espace.

## Midimap_groove.xml

Les grooves ont été joués sur une Roland TD-11 : numéros de notes proches du General
MIDI, mais pas identiques, et la midimap livrée avec DRSKit ne suit pas non plus le GM
(chez elle, 58 = charleston ouverte). `Midimap_groove.xml` relie les notes TD-11 aux
instruments DRSKit :

| Note | TD-11                    | DRSKit               |
|------|--------------------------|----------------------|
| 36   | grosse caisse            | Kdrum_with_contact   |
| 38 / 40 / 37 | caisse claire / rimshot / cross-stick | Snare / Snare_rim / Snare_rest |
| 48, 50 / 45, 47 / 43, 58 | toms aigu / médium / basse (peau, bord) | Tom1 / Tom2 / Tom3 |
| 42 / 22 | charleston fermée (corps / bord) | Hihat_closed / Hihat_closed_shank |
| 46 / 26 | charleston ouverte (corps / bord) | Hihat_open_tip / Hihat_open |
| 44   | charleston au pied       | Hihat_foot           |
| 49, 55 / 57, 52 | crash 1 / crash 2 (corps, bord) | Crash_left_* / Crash_right_* |
| 51 / 59 / 53 | ride (corps / bord / cloche) | Ride_tip / Ride_shank / Ride_tip_bell |

Les notes 22 et 26 (bord de charleston) n'existent pas en GM et représentent près
de la moitié des coups de charleston : sans elles, la charleston a des trous.

## Pièges rencontrés

- **Canal du clip Qtractor** : pour un fichier MIDI de type 0 (le cas des Groove
  MIDI), `<track-channel>` d'un clip est le *canal* MIDI à lire, pas le numéro de
  piste. La batterie est sur le canal 10 (9 en base 0) : avec 0, le clip est vide et
  on n'entend rien. `groove.py` détecte le canal.
- **Réglages DrumGizmo dans la session** : le plugin LV2 stocke son état sous la clé
  `http://drumgizmo.org/lv2/atom#config` (un XML `<config>` avec `drumkitfile` et
  `midimapfile`), écrit en type `atom#String` dans le `.qtr`.
- **`drumgizmo` en ligne de commande joue les fichiers MIDI deux fois trop
  lentement** (v0.9.20) : ajouter `speed=2` pour un rendu hors ligne. Le plugin dans
  Qtractor n'est pas concerné.

  ```shell
  drumgizmo -i midifile -I file=groove.mid,speed=2,midimap=Midimap_groove.xml \
    -o wavfile -O file=/tmp/rendu,srate=48000 -e 1440000 \
    ~/Audio/drums/drumgizmo/DRSKit/DRSKit_full.xml   # un .wav par micro
  ```

- **Comparer avec l'original** : l'archive complète (`groove-v1.0.0.zip`, 4,8 Go)
  contient l'audio de chaque groove joué par la TD-11. Ce n'est pas une banque de sons
  (les sons sont ceux de Roland), seulement une référence d'écoute.
