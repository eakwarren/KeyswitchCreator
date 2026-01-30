# Keyswitch Creator
A MuseScore Studio (v4.7+) plugin that creates keyswitches based on articulation symbols and technique text in the score. These notes then drive articulation changes in VST instruments.


The plugin has two parts
1. A robust settings dialog that allows assignment of keyswitch sets per staff, displays an intuitive map of keyswitch sets, and provides editors for set creation and global customization.

2. A runtime plugin that scans a selection (or entire score) and applies keyswitches to the staff _directly below_ the played staff, within the same instrument/part.

(insert image with score in background)

Developed with ❤️ by Eric Warren


## Setup
1. Download the latest release version on the right. Unzip to your MuseScore Plugins directory.
   * Windows: [USER]\Documents\MuseScore4\Plugins
   * Mac: [USER]/Documents/MuseScore4/Plugins
   * Linux: [USER]/Documents/MuseScore4/Plugins
2. Open a score and add keyswitch staves to the bottom of each VST instrument in the Layout panel. Here, I've customized a flute keyswitch staff's size, color, and clef for better recognition.

    <img width="551" height="121" alt="keyswitch_staff_example" src="https://github.com/user-attachments/assets/d4a9f38f-5941-4de1-a17e-bcf10626bbdf" />

   For extremely low or high keyswitches, add 15ma bassa / alta lines to reduce ledger lines. _Note: Place and extend lines prior to running Keyswitch Creator, or adjust note octaves after applying pitch modifications so notes remain at values written by Keyswitch Creator._

   (pic)

3. Open Plugins > Manage Plugins and enable both Keyswitch Creator and Keyswitch Creator Settings.

    <img width="1248" height="441" alt="plugins_enabled" src="https://github.com/user-attachments/assets/2248db16-c155-49d1-b96e-6473b0bd2ab1" />

4. Open the Keyswitch Creator Settings plugin to create and assign sets to each staff.  Shift-clicking selects a range of staves and Cmd/Ctrl-clicking selects multiple staves. Cmd/Ctrl+A selects all staves.

    <img width="1386" height="840" alt="settings" src="https://github.com/user-attachments/assets/1825d6f6-cfee-487b-bf8d-4f01fef4a576" />

5. Make a selection in the score (leave blank for entire score) and run the Keyswitch Creator plugin. (I set Cmd/Ctrl+Shift+K as a shortcut.)

(pic)


## Extended Score Text Features
Add any of the following text tags to the score to customize keyswitch creation.

#### KS:Set
Activates a set on that staff from that point onward. Helpful when you change instruments mid-score.

`KS:Set="Default Low"` or `KS:Set BBCSO_Strings` 


#### KS:Text
Assigns custom keyswitches based on entries in the set's `techniqueKeyMap`. Define multiple tags in one text element. 

`KS:Text=CustomTechnique` or `KS:Text="con sord" KS:Text=legato`


#### KS:Scope
In range selections, `part` processes all staves of each touched part; `staff` restricts to the touched staves only. First tag found in the range wins.

`KS:Scope=part` or `KS:Scope=staff` 


#### KS:Parts
In range selections, `all` processes every touched part; `anchor` restricts to the part of the selection’s starting staff. Without a tag, multi‑part selections auto‑widen to `all`.
`KS:Parts=all` or `KS:SParts=anchor`


## Settings Window

(pic) with callouts

#### Set Registry
Each top‑level key is a set name. Map values accept a number (midi note) or string (midi note|velocity). Velocity defautls to 64 if omitted. Per set durationPolicy and techniqueAliases can override Global settings.
```
{
    "Default Low": {
        "articulationKeyMap": {"staccato": 0, "accent": 3, "marcato": 4, "tenuto": "2|80"},
        "techniqueKeyMap": {"normal": 14, "pizz": 16, "tremolo": 17, "con sord": "18|20", "legato": 24},
        "durationPolicy": "source"          // OPTIONAL
    },
    "My Library": {
        "articulationKeyMap": {"staccato": 36, "accent": 37, "marcato": 38},
        "techniqueKeyMap": {"arco": 60, "pizz": "61\n1", "sul pont": 62, "senza sord": 63},
        "durationPolicy": "fixed",          //OPTIONAL
        "techniqueAliases": {
            "pizz": ["pizz.", "pizzicato"]  // OPTIONAL
        }
    }
}
```


#### Global Settings
The global `durationPolicy` specifies if keyswitch notes mirror the duration of their `source` note, or if each has a `fixed` value. (Defaults to 16th notes, but editable in the plugin code.)

Global `techniqueAliases` allow for matching slight variations on technique spelling.

```
{
    "durationPolicy":"source",
    "techniqueAliases":{
        "legato":["legato","leg.","slur","slurred"],
        "normal":["normal","normale","norm.","nor.","ordinary","ord.","standard","std.","arco"],
        "con sord":["con sord","con sord.","con sordino","with mute","muted","sord."],
        "senza sord":["senza sord","senza sord.","senza sordino","open","without mute"],
        "sul pont":["sul pont","sul pont.","sul ponticello"],
        "sul tasto":["sul tasto","sul tast.","flautando"],
        "col legno":["col legno","col l.","c.l."],
        "harmonic":["harmonic","harm.","harmonics","natural harmonic","artificial harmonic"],
        "spiccato":["spiccato","spicc.","spic."],
        "pizz":["pizz","pizz.","pizzicato"],
        "tremolo":["tremolo","trem.","tremolando"]
    }
}
```


#### JSON Error Highlighting
Pinpoint bad JSON with heuristics for common faults like missing quotation marks or commas in the editor windows.

<img width="1155" height="429" alt="registry error" src="https://github.com/user-attachments/assets/745673f2-5627-4368-885a-f2f9c48cca6c" />



## Keyswitch Sets
(Links to files on Github to add to registry. Place in Plugin/Sets folder to add to Github.)


## Known Issues
View known issues on [GitHub](https://github.com/eakwarren/KeyswitchCreator/issues)


## To Do
If you have a suggestion, or find a bug, please report it on [GitHub](https://github.com/eakwarren/KeyswitchCreator/issues). I don’t promise a fix or tech support, but I’m happy to take a look. 🙂


## Special Thanks
_“If I have seen further, it is by standing on the shoulders of Giants.” ~Isaac Newton_

MuseScore Studio and VST instrument developers, wherever they may roam.


## Release Notes
v0.9.6 1/29/26 Initial beta release.
