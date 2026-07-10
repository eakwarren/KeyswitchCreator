# Keyswitch Creator
A MuseScore Studio (v4.7+) plugin that automates the creation of keyswitch notes for VST instruments based on articulation symbols and technique text in the score.



Keyswitch Creator has two parts:
1. A settings panel to manage assigning keyswitch sets to staves, including a map of keyswitches and editors for set creation and global customization.
    <img width="1385" height="838" alt="v0 9 8 Settings Window" src="https://github.com/user-attachments/assets/94860ef3-4c61-4cb0-b228-e7f01c06856d" />
2. A headless plugin that scans a selection (or entire score) and applies keyswitches to the staff **_directly below_** the main staff, within the same instrument/part.
    <img width="1497" height="448" alt="v0 9 8 Example Score" src="https://github.com/user-attachments/assets/f632c9eb-3046-4adb-8a6b-8ca9aad82fbc" />





## Setup
1. Download the latest release from the panel on the right. Unzip to your MuseScore Plugins directory. (Documents/MuseScore4/Plugins)
2. Open a score and expand each VST instrument in the Layout panel. Click **Add staff** at the bottom of each VST instrument.

    <img width="299" height="150" alt="add staff" src="https://github.com/user-attachments/assets/f387bf01-9d3f-4e50-988a-1249a8c2012a" />
3. Double-click the first VST instrument name in the score to open Staff/Part properties. Use the arrows at the bottom left to select the _last staff_ in each VST instrument. Customize the staff to your liking and click **Apply**. Next, use the arrows again to move to the next VST instrument's _last staff_ and apply the same customizations.
    <img width="751" height="670" alt="staff properties" src="https://github.com/user-attachments/assets/aadf10f2-7a35-4fae-9187-cfb593f8168e" />
4. Click Home > Plugins and enable both Keyswitch Creator and Keyswitch Creator Settings.
    <img width="1248" height="441" alt="plugins_enabled" src="https://github.com/user-attachments/assets/2248db16-c155-49d1-b96e-6473b0bd2ab1" />
5. Open the Keyswitch Creator Settings plugin from the Plugins menu. Select a staff in the left column, then select a keyswitch set on the right to assign/unassign it. Click **Save** to apply the changes.

    <img width="530" height="311" alt="assign staff to set" src="https://github.com/user-attachments/assets/900db4ad-3649-4635-90b5-bd63508dfb25" />

> [!IMPORTANT]  
> Do not assign keyswitch sets to the last staff in each VST instrument (created in Step 2 above).

> [!TIP]
> Select multiple staves with Cmd/Ctrl+click to quickly assign them to the same keyswitch set.

6. Select part of the score (no selection processes the entire score) with articulations or technique text and run the Keyswitch Creator plugin.

   Keyswitch notes may be red because they're outside the instrument's range. Uncheck **Preferences > Note input > Note colors > Color notes outside of usable pitch range** to turn this off globally, or adjust the usable pitch range per instrument in its Staff/Part properties panel.

    <img width="220" height="124" alt="updated keyswitches added" src="https://github.com/user-attachments/assets/8ed0803c-d7f2-49ec-92c5-28d602ec013c" />
    
> [!TIP]
> Set a keyboard shortcut in MuseScore's Preferences > Shortcuts panel. Search for "keyswitch" and define a shortcut. For example, ⌘⇧+K.




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




## Settings Plugin Features

#### Piano Keyboard
The piano keyboard shows keyswitches in the active set. Hover on a key to view midi note info and keyswitch name.
    
<img width="1155" height="117" alt="keyboard" src="https://github.com/user-attachments/assets/cbb9b0e9-23df-43ba-adce-e2f78fb77e35" />

> [!NOTE]
> MuseScore displays midi note 60 as C4 (full range is C-1 to G9). To change note 60 to display as C3 (C-2 to G8) in Keyswitch Creator, set `property bool middleCIsC4: false` in the Settings plugin file.

#### Set Registry
Keyswitch sets are implemented in the Set registry as structured json. This makes creating keyswitch sets much faster than a manual interface. Each set name is a top‑level key. Values are either a midi note number (0-127), or string "midi note|velocity". Per set `durationPolicy` and `techniqueAliases` can override Global settings.
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
The Global settings panel allows customization of various options that affect keyswitch creation. 

`durationPolicy` Specifies the duration of keyswitch notes. `source` uses the source note's value (default). `fixed` uses a fixed 16th note value. (Configurable in the plugin file.)

`formatKeyswitchStaff` Auto-format the keyswitch staff for a compact view. (Note name in head, remove stem and flag, and attach to a single staff line.) Use the status bar in the bottom left corner of the score window to see the keyswitch octave.

> [!IMPORTANT]
> Because the lines property is read-only in the MuseScore plugin api, set Lines: 1 in Staff properties for keyswitch staves manually, as described in step 3 above.

<img width="220" height="104" alt="formatKeyswitchStaff=true (default)" src="https://github.com/user-attachments/assets/f00bfa87-a41d-4818-a52e-92764b32fa59" />

With auto-formatting (true)

<img width="220" height="235" alt="formatKeyswitchStaff=false" src="https://github.com/user-attachments/assets/9c534e08-40f4-4b97-a297-5e5f139549d8" />

Without auto-formatting (false)

`techniqueAliases` Match variations on technique spelling.

```
    "techniqueAliases": {
        "legato": [
            "legato",
            "leg.",
            "slur",
            "slurred"
        ],
        "normal": [
            "normal",
            "normale",
            "norm.",
            "nor.",
            "ordinary",
            "ord.",
            "standard",
            "std."
        ]
    }
```




#### JSON Error Highlighting
Pinpoint bad JSON formatting like missing quotation marks, commas, or unmatched braces / brackets in the editor windows.

<img width="228" height="109" alt="json error" src="https://github.com/user-attachments/assets/215d0262-f8d8-4428-bc79-41102d15a380" />





#### Reset, Save, and Close Buttons
The **Reset editor to default** button will reset the active editor window to default values. _This only affects the current editor on screen._

The **Save** button writes the registry and global settings values to the computer file system. It also saves the staff => set assignments to the score. This button does not close the Settings window so that when additional sets are added, they become available to assign to a staff.

The **Close** button just closes the Settings window. It doesn't save any changes.


## Additional Keyswitch Sets
The Keyswitch Sets folder contains a few example sets to copy/paste into the Registry editor. There's also a Python script that converts Logic Pro articulation set .plist files to .json sets.
> [!IMPORTANT]
> When adding sets, use proper JSON formatting with quotation marks, commas, and matched braces / brackets. The error highlighting will help identify issues.




## Known Issues
View known issues on [GitHub](https://github.com/eakwarren/KeyswitchCreator/issues)




## To Do
If you have a suggestion, or find a bug, please report it on [GitHub](https://github.com/eakwarren/KeyswitchCreator/issues). I don’t promise a fix or tech support, but I’m happy to take a look. 🙂




## Special Thanks
_“If I have seen further, it is by standing on the shoulders of Giants.” ~Isaac Newton_

MuseScore Studio and VST instrument developers, wherever they may roam.




## Release Notes
v1.0 7/10/26 Initial release.

v0.9.8 2/14/26
- Add keyswitch update handling
- Skip processing unassigned staves
- Improve python script matching
- Auto-scroll to active set

v0.9.7 2/6/26 Beta release.
