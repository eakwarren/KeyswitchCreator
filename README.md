# Keyswitch Creator
A MuseScore Studio (v4.7+) plugin that automates keyswitch creation based on articulation symbols and technique text in the score. These notes then drive articulation changes in VST instruments.


The plugin has two parts:
1. A robust settings dialog that allows assignment of keyswitch sets per staff, displays an intuitive map of keyswitches in sets, and provides editors for set creation and global customization.
   
   <img width="1387" height="840" alt="legato" src="https://github.com/user-attachments/assets/893a6429-4d0d-4e0b-89de-2737f07a8e85" />
    
3. A runtime plugin that scans a selection (or entire score) and applies keyswitches to the staff **_directly below_** the played staff, within the same instrument/part.

   <img width="220" height="124" alt="updated keyswitches added" src="https://github.com/user-attachments/assets/8ed0803c-d7f2-49ec-92c5-28d602ec013c" /> 




## Setup
1. Download the latest release version on the right. Unzip to your MuseScore Plugins directory. Usually at [USER]/Documents/MuseScore4/Plugins

2. Open a score and add keyswitch staves to the bottom of each VST instrument in the Layout panel. Here, I've customized a flute keyswitch staff's number of lines to help it stand out from the score. Use with `formatKeyswitchStaff` below to create a tidy appearance. Close the staff when not working with keyswitches.

    <img width="558" height="113" alt="updated staff customization" src="https://github.com/user-attachments/assets/e367f4ac-f6b5-4e35-b8a2-27b3015d47c1" />

3. Open Plugins > Manage Plugins and enable both Keyswitch Creator and Keyswitch Creator Settings.

    <img width="1248" height="441" alt="plugins_enabled" src="https://github.com/user-attachments/assets/2248db16-c155-49d1-b96e-6473b0bd2ab1" />

4. Open the Keyswitch Creator Settings plugin to create and assign sets to each staff.  Shift-clicking selects a range of staves and Cmd/Ctrl-clicking selects multiple staves. Cmd/Ctrl+A selects all staves.

    <img width="961" height="360" alt="assign" src="https://github.com/user-attachments/assets/f2c491e9-957b-49e6-8fea-5c49631205e2" />

5. Make a selection in the main score (leave blank for entire score) and run the Keyswitch Creator plugin. (I set ⌘⇧+K as a shortcut.)

    <img width="220" height="124" alt="updated keyswitches added" src="https://github.com/user-attachments/assets/8ed0803c-d7f2-49ec-92c5-28d602ec013c" />


## Extended Score Text Features
Add any of the following text tags to the main score to customize keyswitch creation.

#### KS:Set
Activates a set on a staff from that point onward. Helpful when you change instruments mid-score.

`KS:Set="Default Low"` or `KS:Set BBCSO_Strings` 


#### KS:Text
Assigns custom keyswitches based on entries in the set's `techniqueKeyMap`. Define multiple tags in one text element. 

`KS:Text=CustomTechnique` or `KS:Text="con sord" KS:Text=legato`


#### KS:Scope
In range selections, `staff` restricts to the selected staff only (default), `part` processes all staves of each selected part/instrument. First tag found in the range wins.

`KS:Scope=part` or `KS:Scope=staff` 


#### KS:Parts
In range selections, `all` processes every selected part/instrument; `anchor` restricts to the part of the selection’s starting staff. Without a tag, multi‑part selections auto‑widen to `all`.

`KS:Parts=all` or `KS:SParts=anchor`


## Settings Window

<img width="961" height="360" alt="assign" src="https://github.com/user-attachments/assets/f2c491e9-957b-49e6-8fea-5c49631205e2" />

#### Staff List
The column on the left lists all the staves in the score. Click a staff to activate it and then select a Keyswitch Set button to assign the set to the staff.

Cmd/Ctrl+A will select all staves. Shift+click will select a range of staves, while Cmd/Ctrl+click will multi-select staves. Shift+up/down arrows are additional shortcuts to quickly select a range of staves.

#### Keyswitch Set Button Panel
The panel of buttons to the right of the Staff List each represent a keyswitch set. With one or more staves selected, click to assign the keyswitch set to a staff. Click again to un-assign.

The piano keyboard at the top shows what keyswitches are part of the active set. Hover over the keys to see the midi note, velocity (if any), and name.

Clear all staff assignments with the button at the top. (Helpful when setting up a new template.) Filter large numbers of sets to focus on desired sets.

#### Set Registry
Each top‑level key is a set name. Map values accept a number (midi note) or string (midi note|velocity). Velocity defautls to 64 if omitted. Per set `durationPolicy` and `techniqueAliases` can override Global settings.
```
{
    "Default Low": {
        "articulationKeyMap": {"staccato": 0, "accent": 3, "marcato": 4, "tenuto": "2|80"},
        "techniqueKeyMap": {"normal": 14, "pizz": 16, "tremolo": 17, "con sord": "18|20", "legato": 24},
    },
    "My Library": {
        "articulationKeyMap": {"staccato": 36, "accent": 37, "marcato": 38},
        "techniqueKeyMap": {"arco": 60, "pizz": "61\n1", "sul pont": 62, "senza sord": 63},
        "durationPolicy": "fixed",      // OPTIONAL OVERRIDE
        "techniqueAliases": {
            "pizz": ["pizz.", "pluck"]  // OPTIONAL OVERRIDE
        }
    }
}
```


#### Global Settings
The global settings editor allows customization of various options that affect keyswitch creation. 

`durationPolicy` Specifies if keyswitch notes mirror the duration of their `source` note (default), or if each has a `fixed` value. (Fixed to 16th notes, but editable in the plugin code.)

`formatKeyswitchStaff` Auto-format the keyswitch staff to show note names on note heads, remove stems, and attach the note to a single staff line. Use the status bar in the bottom left corner of the score window to inspect the keyswitch octave.

> [!IMPORTANT]
> Because certain staff properties are read-only in the plugin api, set Lines to 1 in Staff/Part properties manually in each keyswitch staff to optimize the view.

<img width="407" height="193" alt="formatKeyswitchStaff=true (default)" src="https://github.com/user-attachments/assets/f00bfa87-a41d-4818-a52e-92764b32fa59" />

With auto-formatting (true)

<img width="411" height="439" alt="formatKeyswitchStaff=false" src="https://github.com/user-attachments/assets/9c534e08-40f4-4b97-a297-5e5f139549d8" />

Without auto-formatting (false)

`techniqueAliases` Match slight variations on technique spelling.

```
{
    "durationPolicy":"source",
    "formatKeyswitchStaff": "true",
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
Pinpoint bad JSON with heuristics for common faults like missing quotation marks, braces, or commas in the editor windows.

<img width="387" height="177" alt="json error" src="https://github.com/user-attachments/assets/ec4315b0-c8c7-4af6-ac17-6b32fbbf62f6" />

#### Reset, Save, and Close Buttons
The Reset editor to default button will reset the active editor window to default values. This only affects the current editor on screen.

The Save button writes the registry and global settings values to the computer file system. It also saves the staff => set assignments to the score.

The Close button closes the Settings window.


## Additional Keyswitch Sets
The Keyswitch Sets folder contains a few sets that you can copy/paste into the Registry editor.
> [!IMPORTANT]
> When adding sets, use proper json formatting rules with commas and brackets in the right places. The error highlighting should help identify any issues.


## Known Issues
View known issues on [GitHub](https://github.com/eakwarren/KeyswitchCreator/issues)


## To Do
If you have a suggestion, or find a bug, please report it on [GitHub](https://github.com/eakwarren/KeyswitchCreator/issues). I don’t promise a fix or tech support, but I’m happy to take a look. 🙂


## Special Thanks
_“If I have seen further, it is by standing on the shoulders of Giants.” ~Isaac Newton_

MuseScore Studio and VST instrument developers, wherever they may roam.


## Release Notes
v0.9.7 2/6/26 Initial release.
