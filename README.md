# Keyswitch Creator
A MuseScore Studio (v4.7+) plugin that automates the creation of keyswitch notes for VST instruments based on articulation symbols and technique text in the score.


Keyswitch Creator has two parts:
1. A settings panel to manage assigning keyswitch sets to staves, including a map of keyswitches and editors for set creation and global customization.
   
   <img width="1387" height="840" alt="legato" src="https://github.com/user-attachments/assets/893a6429-4d0d-4e0b-89de-2737f07a8e85" />
    
2. A headless plugin that scans a selection (or entire score) and applies keyswitches to the staff **_directly below_** the main staff, within the same instrument/part.

   <img width="220" height="124" alt="updated keyswitches added" src="https://github.com/user-attachments/assets/8ed0803c-d7f2-49ec-92c5-28d602ec013c" /> 




## Setup
1. Download the latest release from the panel on the right. Unzip to your MuseScore Plugins directory ([USER]/Documents/MuseScore4/Plugins)

2. Open a score and expand each VST instrument in the Layout panel. Click **Add staff** at the bottom of each VST instrument. Open the Staff properties by double-click on the instrument name in the score. Use the arrows at the bottom left to select the _last staff_ in the instrument. Customize the staff to your liking. Here, I've set the keyswitch staff's number of lines to 1 so it's easy to see in the score. Use with `formatKeyswitchStaff` below to create a tidy appearance. Hide the keyswitch staff when not working with them.

    <img width="558" height="113" alt="updated staff customization" src="https://github.com/user-attachments/assets/e367f4ac-f6b5-4e35-b8a2-27b3015d47c1" />

3. Click Home > Plugins and enable both Keyswitch Creator and Keyswitch Creator Settings.

    <img width="1248" height="441" alt="plugins_enabled" src="https://github.com/user-attachments/assets/2248db16-c155-49d1-b96e-6473b0bd2ab1" />

4. Open the Keyswitch Creator Settings plugin from the Plugins menu. Select a staff in the left column, then select a keyswitch set in the right column to assign/unassign it. Click **Save** to apply the changes.

> [!IMPORTANT]  
> Do not assign keyswitch sets to the last staff in VST instruments (created in Step 2 above).

> [!TIP]
> Select multiple staves quickly to assign them to the same keyswitch set. Shift-click selects a range of staves. Cmd/Ctrl-click selects multiple staves. Cmd/Ctrl+A selects all staves.

    <img width="961" height="360" alt="assign" src="https://github.com/user-attachments/assets/f2c491e9-957b-49e6-8fea-5c49631205e2" />

5. Make a selection in the score (no selection runs on the entire score) and run the Keyswitch Creator plugin.

> [!TIP]
> Set a keyboard shortcut in MuseScore's Preferences > Shortcuts panel. Search for "keyswitch" and define a shortcut. For example, ⌘⇧+K.

    <img width="220" height="124" alt="updated keyswitches added" src="https://github.com/user-attachments/assets/8ed0803c-d7f2-49ec-92c5-28d602ec013c" />




## Additional Text Tags
Add any of the following text tags (Cmd/Ctrl+T) to the score to customize keyswitch behavior.

#### KS:Set
Activates a certain keyswitch set on an instrument from that point forward. (Helpful when changing instruments.)
`KS:Set="English Horn"` or `KS:Set Custom-Set` 

#### KS:Text
Assigns custom keyswitches based on matching entries in the set's `techniqueKeyMap`.
`KS:Text=CustomTechnique` or `KS:Text="con sord" KS:Text=legato`

#### KS:Scope
In range selections, `staff` restricts keyswitch processing to the selected staff only (default), `part` processes all staves of an instrument (like a grand staff). The first tag found at a particular time wins.
`KS:Scope=part` or `KS:Scope=staff` 

~~#### KS:Parts
In range selections, `all` processes every selected instrument. `anchor` restricts selection’s starting staff. Without a tag, multi‑part selections auto‑widen to `all`.
`KS:Parts=all` or `KS:Parts=anchor`~~




## Settings plugin features

#### Piano Keyboard
The piano keyboard shows keyswitches in the active set. Hover a key to view midi note info and keyswitch name.
> [!NOTE]
> MuseScore displays midi note 60 as C4 (full range is C-1 to G9). To change note 60 to display as C3 (C-2 to G8) in Keyswitch Creator, set `property bool middleCIsC4: false` in the settings plugin file.

#### Set Registry
Keyswitch sets are implemented as structured json. This makes creating keyswitch sets much faster than a manual interface. Each set name is a top‑level key. Values are either a midi note number (0-127), or string "midi note|velocity". Per set `durationPolicy` and `techniqueAliases` can override Global settings.
```
{
    "My Library": {
        "articulationKeyMap": {
            "staccato": 2,
            "tenuto": 3,
            "marcato": 4
        },
        "techniqueKeyMap": {
            "normal": 1,
            "pizz.": 5,
            "sul pont.": "6|99",
            "sul tasto": "6|100"
        },
        "durationPolicy": "fixed",      // OPTIONAL OVERRIDE
        "techniqueAliases": {
            "pizz.": ["pizz", "pluck"]  // OPTIONAL OVERRIDE
        }
    }
}
```




#### Global Settings
The global settings editor allows customization of various options that affect keyswitch creation. 

`durationPolicy` Specifies the duration of keyswitch notes. `source` uses the source note's value (default). `fixed` uses a fixed 16th note value. (Configurable in the plugin file.)

`formatKeyswitchStaff` Auto-format the keyswitch staff for a compact view. (Note name in head, remove stem, and attach to a single staff line) Use the status bar in the bottom left corner of the score window to see the keyswitch octave.

> [!IMPORTANT]
> Because the lines property is read-only in the plugin api, set Lines: 1 in Staff properties for keyswitch staves manually.

<img width="220" height="104" alt="formatKeyswitchStaff=true (default)" src="https://github.com/user-attachments/assets/f00bfa87-a41d-4818-a52e-92764b32fa59" />

With auto-formatting (true)

<img width="220" height="235" alt="formatKeyswitchStaff=false" src="https://github.com/user-attachments/assets/9c534e08-40f4-4b97-a297-5e5f139549d8" />

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
The **Reset editor to default** button will reset the active editor window to default values. This only affects the current editor on screen.

The **Save** button writes the registry and global settings values to the computer file system. It also saves the staff => set assignments to the score.

The **Close** button just closes the Settings window. It doesn't save any changes.


## Additional Keyswitch Sets
The Keyswitch Sets folder contains a few example sets to copy/paste into the Registry editor. There's also a Python script that converts Logic Pro articulation set .plist files to .json sets.
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
