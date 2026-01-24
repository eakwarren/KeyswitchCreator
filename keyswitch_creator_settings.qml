//===============================================================================
// Keyswitch Creator Settings for MuseScore Studio articulation & technique text
// Creates keyswitch notes on the staff below based on articulation symbols &
// technique text in the current selection/entire score.
//
// Copyright (C) 2026 Eric Warren (eakwarren)
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License version 3
// as published by the Free Software Foundation and appearing in
// the file LICENSE
//===============================================================================

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1
import Muse.Ui 1.0
import Muse.UiComponents 1.0
import MuseScore 3.0

MuseScore {
  id: root
  version: "0.9.3"
  title: qsTr("Keyswitch Creator Settings")
  description: qsTr("Assign keyswitch sets to staves")
  pluginType: "dialog"
  categoryCode: "Keyswitch Creator"
  width: 1385
  height: 810

  Settings {
    id: ksPrefs
    category: "Keyswitch Creator"
    property string setsJSON: ""
    property string staffToSetJSON: ""
    property string globalJSON: ""
  }

  // Data state
  property var keyswitchSets: ({})
  property var staffToSet: ({})
  property var globalSettings: ({})
  property int currentStaffIdx: -1
  property int lastAnchorIndex: -1
  property var selectedStaff: ({})
  property int selectedCountProp: 0

  // Mode selector: 0 = registry, 1 = globals
  property int editorModeIndex: 0

  // Theme colors (safe fallbacks)
  readonly property color themeAccent: (ui && ui.theme && ui.theme.accentColor) ? ui.theme.accentColor : "#2E7DFF"
  readonly property color themeSeparator: (ui && ui.theme && ui.theme.separatorColor) ? ui.theme.separatorColor : "#D0D0D0"
  readonly property color warningColor: (ui && ui.theme && ui.theme.warningColor) ? ui.theme.warningColor : "#E57373"

  // Per-editor border state (each tab can reflect its own validity)
  property color registryBorderColor: themeSeparator
  property int   registryBorderWidth: 1
  property color globalsBorderColor: themeSeparator
  property int   globalsBorderWidth: 1


  // Shared left text margin to align editor with 'Assign set to...' title
  property int leftTextMargin: 12

  ListModel { id: staffListModel } // { idx, name }
  ListModel { id: setsListModel }  // { name }


  // search additions (filtered model + state + helper)
  ListModel { id: filteredSetsModel }   // filtered view for "Assign set to..." buttons
  property string setFilterText: ""
  onSetFilterTextChanged: rebuildFilteredSets()

  // Rebuild filteredSetsModel from setsListModel using setFilterText (case-insensitive)
  function rebuildFilteredSets() {
      filteredSetsModel.clear();
      var q = (setFilterText || "").trim().toLowerCase();

      // Show all if no query
      if (q.length === 0) {
          for (var i = 0; i < setsListModel.count; ++i) {
              var nm = setsListModel.get(i).name;
              filteredSetsModel.append({ name: nm });
          }
          return;
      }

      for (var j = 0; j < setsListModel.count; ++j) {
          var name = (setsListModel.get(j).name || "");
          if (name.toLowerCase().indexOf(q) !== -1) {
              filteredSetsModel.append({ name: name });
          }
      }
  }




  //--------------------------------------------------------------------------------
  // Defaults
  //--------------------------------------------------------------------------------
  function defaultGlobalSettingsObj() {
    return {
      "priority":   ["accent", "staccato", "tenuto", "marcato", "legato"],
      "durationPolicy": "source",
      "techniqueAliases": {
        "legato":   ["legato", "leg.", "slur", "slurred"],
        "normal":   ["normal", "norm.", "nor.", "ordinary", "ord.", "std.", "arco"],
        "pizz":     ["pizz", "pizz.", "pizzicato"],
        "con sord": ["con sord", "con sord.", "con sordino"],
        "sul pont": ["sul pont", "sul pont.", "sul ponticello"]
      }
    }
  }

  function defaultRegistryObj() {
    return {
      "Default Low": {
        "articulationKeyMap": { "staccato": 0, "tenuto": 1, "accent": 2, "marcato": 3 },
        "techniqueKeyMap": { "pizz": 4, "normal": 5, "harmonic": 6, "con sord": 7, "senza sord": 5, "sul pont": 8 }
      },
      "Default High": {
        "articulationKeyMap": { "staccato": 127, "tenuto": 126, "accent": 125, "marcato": 124 },
        "techniqueKeyMap": { "pizz": 123, "normal": 122, "harmonic": 121, "con sord": 120, "senza sord": 122, "sul pont": 119 }
      }
    }
  }

  //--------------------------------------------------------------------------------
  // Compact JSON formatters
  //--------------------------------------------------------------------------------
  function formatRegistryCompact(reg) {
    var setNames = Object.keys(reg)
    var lines = ['{']
    for (var i = 0; i < setNames.length; ++i) {
      var name = setNames[i]
      var setObj = reg[name] || {}
      lines.push(' ' + JSON.stringify(name) + ':{')
      var innerLines = []
      var innerKeys = Object.keys(setObj)
      for (var j = 0; j < innerKeys.length; ++j) {
        var k = innerKeys[j]
        var v = setObj[k]
        innerLines.push('  ' + JSON.stringify(k) + ':' + JSON.stringify(v))
      }
      if (innerLines.length)
        lines.push(innerLines.join(',
'))
      lines.push(' }' + (i < setNames.length - 1 ? ',' : ''))
    }
    lines.push('}')
    return lines.join(' 
')
  }

  function formatGlobalsCompact(glob) {
    var lines = ['{']
    lines.push(' "priority":' + JSON.stringify(glob.priority || []) + ',')
    lines.push(' "durationPolicy":' + JSON.stringify(glob.durationPolicy || "source") + ',')
    lines.push(' "techniqueAliases":{')
    var alias = glob.techniqueAliases || {}
    var ak = Object.keys(alias)
    for (var i = 0; i < ak.length; ++i) {
      var k = ak[i]
      lines.push('  ' + JSON.stringify(k) + ':' + JSON.stringify(alias[k]) + (i < ak.length - 1 ? ',' : ''))
    }
    lines.push(' }')
    lines.push('}')
    return lines.join(' 
')
  }

  //--------------------------------------------------------------------------------
  // Active set note utilities
  //--------------------------------------------------------------------------------
  function uniqMidi(list) {
      var seen = {}, out = []
      for (var i = 0; i < list.length; ++i) {
          var v = (list[i] | 0)
          if (v >= 0 && v <= 127 && !seen[v]) { seen[v] = true; out.push(v) }
      }
      return out
  }

  function activeMidiFromSetObj(setObj) {
      if (!setObj) return []
      var arr = []
      if (setObj.articulationKeyMap) {
          for (var k in setObj.articulationKeyMap) arr.push(setObj.articulationKeyMap[k])
      }
      if (setObj.techniqueKeyMap) {
          for (var t in setObj.techniqueKeyMap)   arr.push(setObj.techniqueKeyMap[t])
      }
      return uniqMidi(arr)
  }

  function parseRegistrySafely(jsonText) {
      try { return JSON.parse(jsonText) } catch (e) { return null }
  }

  function activeMidiFromRegistryText(jsonText, setName) {
      var reg = parseRegistrySafely(jsonText)
      if (reg && reg.hasOwnProperty(setName)) return activeMidiFromSetObj(reg[setName])
      // fallback to already-parsed in-memory registry
      if (keyswitchSets && keyswitchSets[setName]) return activeMidiFromSetObj(keyswitchSets[setName])
      return []
  }

  function updateKeyboardActiveNotes() {
      // Prefer the explicit UI-selected set if present, otherwise derive
      var setName = (setButtonsFlow && setButtonsFlow.uiSelectedSet) ? setButtonsFlow.uiSelectedSet
                     : activeSetForCurrentSelection()
      // normalize non-selection to something meaningful if possible
      if (!setName || setName === "__none__") setName = "Default Low"
      if (kbroot) kbroot.activeNotes = activeMidiFromRegistryText(jsonArea.text, setName)
  }


  //--------------------------------------------------------------------------------
  // Selection helpers & UI-selected set tracking
  //--------------------------------------------------------------------------------
  function activeSetForCurrentSelection() {
    var keys = Object.keys(selectedStaff)
    if (keys.length === 0) {
      if (currentStaffIdx >= 0) {
        var nm0 = staffToSet[currentStaffIdx.toString()]
        return nm0 ? nm0 : "Default Low"
      }
      return "__none__"
    }
    var first = null
    for (var i = 0; i < keys.length; ++i) {
      var nm = staffToSet[keys[i]]
      if (!nm) nm = "Default Low"
      if (first === null) first = nm
      else if (nm !== first) return "__none__"
    }
    return first
  }

  function refreshUISelectedSet() {
    if (setButtonsFlow) setButtonsFlow.uiSelectedSet = activeSetForCurrentSelection()
  }

  function bumpSelection() { selectedCountProp = Object.keys(selectedStaff).length }
  function clearSelection() { selectedStaff = ({}); bumpSelection(); refreshUISelectedSet() }

  function setRowSelected(rowIndex, on) {
    if (rowIndex < 0 || rowIndex >= staffListModel.count) return
    var sIdx = staffListModel.get(rowIndex).idx
    var ns = Object.assign({}, selectedStaff)
    if (on) ns[sIdx] = true
    else delete ns[sIdx]
    selectedStaff = ns
    bumpSelection()
    refreshUISelectedSet()
  }

  function isRowSelected(rowIndex) {
    if (rowIndex < 0 || rowIndex >= staffListModel.count) return false
    var sIdx = staffListModel.get(rowIndex).idx
    return !!selectedStaff[sIdx]
  }

  function selectSingle(rowIndex) {
    clearSelection()
    setRowSelected(rowIndex, true)
    lastAnchorIndex = rowIndex
    currentStaffIdx = staffListModel.get(rowIndex).idx
    refreshUISelectedSet()
  }

  function toggleRow(rowIndex) {
    var wasSelected = isRowSelected(rowIndex)
    setRowSelected(rowIndex, !wasSelected)
    lastAnchorIndex = rowIndex
    currentStaffIdx = staffListModel.get(rowIndex).idx
    if (selectedCountProp === 0) setRowSelected(rowIndex, true)
    refreshUISelectedSet()
  }

  function selectRange(rowIndex) {
    if (lastAnchorIndex < 0) { selectSingle(rowIndex); return }
    var a = Math.min(lastAnchorIndex, rowIndex)
    var b = Math.max(lastAnchorIndex, rowIndex)
    clearSelection()
    for (var r = a; r <= b; ++r) setRowSelected(r, true)
    currentStaffIdx = staffListModel.get(rowIndex).idx
    refreshUISelectedSet()
  }

  function selectAll() {
    clearSelection()
    for (var r = 0; r < staffListModel.count; ++r) setRowSelected(r, true)
    if (staffList.currentIndex >= 0) lastAnchorIndex = staffList.currentIndex
    refreshUISelectedSet()
  }

  //--------------------------------------------------------------------------------
  // Name helpers (strip CR/LF)
  //--------------------------------------------------------------------------------
  function cleanName(s) {
    var t = String(s || '')
    t = t.split('
').join(' ')
    t = t.split('
').join(' ')
    return t
  }

  function staffBaseTrack(staffIdx) { return staffIdx * 4 }

  function partForStaff(staffIdx) {
    if (!curScore || !curScore.parts) return null
    var t = staffBaseTrack(staffIdx)
    for (var i = 0; i < curScore.parts.length; ++i) {
      var p = curScore.parts[i]
      if (t >= p.startTrack && t < p.endTrack) return p
    }
    return null
  }

  function nameForPart(p, tick) {
    if (!p) return ''
    var nm = (p.longName && p.longName.length) ? p.longName
            : (p.partName && p.partName.length) ? p.partName
            : (p.shortName && p.shortName.length) ? p.shortName
            : ''
    if (!nm && p.instrumentAtTick) {
      var inst = p.instrumentAtTick(tick || 0)
      if (inst && inst.longName && inst.longName.length) nm = inst.longName
    }
    return cleanName(nm)
  }

  function indexForStaff(staffIdx) {
    for (var i = 0; i < staffListModel.count; ++i) {
      var item = staffListModel.get(i)
      if (item && item.idx === staffIdx) return i
    }
    return 0
  }

  function staffNameByIdx(staffIdx) {
    for (var i = 0; i < staffListModel.count; ++i) {
      var item = staffListModel.get(i)
      if (item && item.idx === staffIdx) return cleanName(item.name)
    }
    var base = nameForPart(partForStaff(staffIdx), 0) || 'Unknown instrument'
    return cleanName(base + ': ' + qsTr('Staff %1 (%2)').arg(1).arg('Treble'))
  }

  //--------------------------------------------------------------------------------
  // Load / Save
  //--------------------------------------------------------------------------------
  function loadData() {
      // 1) Raw strings from settings
      var rawSets = ksPrefs.setsJSON || ""
      var rawGlobals = ksPrefs.globalJSON || ""

      // 2) Show EXACTLY what is saved (do not reformat unless empty)
      if (rawSets.length > 0) {
          jsonArea.text = rawSets
      } else {
          keyswitchSets = defaultRegistryObj()
          jsonArea.text = formatRegistryCompact(keyswitchSets)
      }

      if (rawGlobals.length > 0) {
          globalsArea.text = rawGlobals
      } else {
          globalSettings = defaultGlobalSettingsObj()
          globalsArea.text = formatGlobalsCompact(globalSettings)
      }

      // 3) Parse in-memory objects (never clobber the editor if parse fails)

      var parsedSets = parseRegistrySafely(jsonArea.text);
      if (parsedSets) {
          keyswitchSets = parsedSets;
          setRegistryBorder(true);     // good JSON
      } else {
          keyswitchSets = defaultRegistryObj();
          setRegistryBorder(false);    // bad JSON
      }

      // staffToSet (safe parse)
      try {
          staffToSet = (ksPrefs.staffToSetJSON && ksPrefs.staffToSetJSON.length) ? JSON.parse(ksPrefs.staffToSetJSON) : {}
      } catch (e2) {
          staffToSet = {}
      }

      // Rebuild lists (from the in-memory object, not the text)
      staffListModel.clear()

      if (curScore && curScore.parts) {
          for (var pIdx = 0; pIdx < curScore.parts.length; ++pIdx) {
              var p = curScore.parts[pIdx]
              var baseStaff = Math.floor(p.startTrack / 4)
              var numStaves = Math.floor((p.endTrack - p.startTrack) / 4)
              var partName = nameForPart(p, 0)
              var cleanPart = cleanName(partName)
              for (var sOff = 0; sOff < numStaves; ++sOff) {
                  var staffIdx = baseStaff + sOff
                  var display = cleanPart + ': ' + qsTr('Staff %1 (%2)').arg(sOff + 1).arg(sOff === 1 ? 'Bass' : 'Treble')
                  staffListModel.append({ idx: staffIdx, name: display })
              }
          }
      }

      var initIndex = indexForStaff(0)
      selectSingle(initIndex)

      setsListModel.clear()
      for (var k in keyswitchSets) setsListModel.append({ name: k })

      setFilterText = ""
      rebuildFilteredSets()

      refreshUISelectedSet()
      updateKeyboardActiveNotes()

      validateRegistryText()
      validateGlobalsText()

      // quick visibility check in the console
      console.log("[KS] staffListModel.count =", staffListModel.count)
      console.log("[KS] setsListModel.count  =", setsListModel.count)

  }

  function saveData() {
    ksPrefs.setsJSON = jsonArea.text
    ksPrefs.globalJSON = globalsArea.text
    ksPrefs.staffToSetJSON = JSON.stringify(staffToSet)
    if (ksPrefs.sync) { try { ksPrefs.sync() } catch(e) {} }  // flush if available
  }

  function setRegistryBorder(valid) {
      root.registryBorderColor = valid ? themeSeparator : warningColor
      root.registryBorderWidth = valid ? 1 : 2
  }
  function setGlobalsBorder(valid) {
      root.globalsBorderColor = valid ? themeSeparator : warningColor
      root.globalsBorderWidth = valid ? 1 : 2
  }
  function validateRegistryText() {
      var ok = true
      try { JSON.parse(jsonArea.text) } catch(e) { ok = false }
      setRegistryBorder(ok)
  }
  function validateGlobalsText() {
      var ok = true
      try { JSON.parse(globalsArea.text) } catch(e) { ok = false }
      setGlobalsBorder(ok)
  }

  onRun: {
    loadData()
    // Ensure initial focus goes to staves list for keyboard shortcuts
    staffList.forceActiveFocus()
    refreshUISelectedSet()
  }

  //--------------------------------------------------------------------------------
  // UI
  //--------------------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 12

      // Left: Staves list
      GroupBox {
        // title: qsTr('Staves')
        Layout.preferredWidth: 216
        Layout.fillHeight: true
        background: Rectangle {
          color: ui.theme.textFieldColor
        }

        ScrollView {
          id: stavesScroll
          anchors.fill: parent
          focus: true

          // Forward any key events to the staves list (ensures shortcuts work if ScrollView gets focus)
          Keys.forwardTo: [staffList]

          ListView {
            id: staffList
            clip: true
            model: staffListModel
            spacing: 2
            focus: true
            activeFocusOnTab: true

            Keys.onPressed: function (event) {
              var ctrlOrCmd = (event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.MetaModifier)
              var isShift = (event.modifiers & Qt.ShiftModifier)
              if (ctrlOrCmd && event.key === Qt.Key_A) { selectAll(); event.accepted = true; return }
              if (event.key === Qt.Key_Up) {
                var idx = Math.max(0, staffList.currentIndex - 1)
                if (isShift) selectRange(idx); else selectSingle(idx)
                staffList.currentIndex = idx
                event.accepted = true
                return
              }
              if (event.key === Qt.Key_Down) {
                var idx2 = Math.min(staffListModel.count - 1, staffList.currentIndex + 1)
                if (isShift) selectRange(idx2); else selectSingle(idx2)
                staffList.currentIndex = idx2
                event.accepted = true
                return
              }
            }

            delegate: ItemDelegate {
              id: rowDelegate
              width: ListView.view.width
              text: cleanName(model.name)
              background: Rectangle {
                anchors.fill: parent
                radius: 6
                color: isRowSelected(index) ? themeAccent : "transparent"
                opacity: isRowSelected(index) ? 0.65 : 1.0
              }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onClicked: function (mouse) {
                  var idx = index
                  var ctrlOrCmd = (mouse.modifiers & Qt.ControlModifier) || (mouse.modifiers & Qt.MetaModifier)
                  var isShift = (mouse.modifiers & Qt.ShiftModifier)
                  if (isShift) selectRange(idx)
                  else if (ctrlOrCmd) toggleRow(idx)
                  else selectSingle(idx)
                  staffList.currentIndex = idx
                  setSearchField.focus = false
                }
              }
            }
          }
        }
      }

      // Right: Assign set to ...
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        // Hidden icon-size probe using a standard icon button to get canonical metrics
        FlatButton { id: _iconProbe; visible: false; icon: IconCode.SAVE }

        // Piano keyboard
        Item {
            id: kbroot
            property int startMidi: 0              // inclusive
            property int keyCount: 128             // total keys to draw
            property string view: "small"          // "small" | "medium" | "large"
            readonly property int endMidi: startMidi + keyCount - 1
            property bool middleCIsC4: true

            // active highlighting
            property var   activeNotes: []                 // e.g., [96,97,98]
            property var   activeMap:   ({})               // { 96:true, 97:true, ... }
            property color accent:      themeAccent        // use app/theme accent
            property real  activeOverlayOpacityWhite: 0.65
            property real  activeOverlayOpacityBlack: 0.80

            onActiveNotesChanged: {
              var m = {}
              for (var i = 0; i < activeNotes.length; ++i) m[activeNotes[i]] = true
              activeMap = m
            }

            // --- Size presets to mimic MuseScore's compact look ---
            readonly property real whiteW: (view === "small" ? 15 :
                                           view === "medium" ? 20 : 22)
            readonly property real whiteH: (view === "small" ? 65 :
                                           view === "medium" ? 70 : 80)
            readonly property real blackW: Math.round(whiteW * 0.70)
            readonly property real blackH: Math.round(whiteH * 0.65)
            readonly property color whiteColor: "#FAFAFA"
            readonly property color whiteBorder: "#202020"
            readonly property color blackColor: "#111111"
            readonly property color blackBorder: "#000000"

            implicitHeight: whiteH
            implicitWidth: {
                // width = number of white keys * whiteW
                var whites = 0
                for (var n = kbroot.startMidi; n <= kbroot.endMidi; ++n) {
                    var pc = n % 12
                    if (pc !== 1 && pc !== 3 && pc !== 6 && pc !== 8 && pc !== 10)
                        whites++
                }
                return whites * whiteW
            }

            // --- Helpers ---
            // Tooltip helpers (pitch name, octave, tooltip text)
            function octaveFor(m) {
              // MIDI 60 => 4 if C4 standard (subtract 1)
              // MIDI 60 => 3 if C3 standard (subtract 2)
              return Math.floor(m / 12) - (kbroot.middleCIsC4 ? 1 : 2)
            }

            function noteName(m) {
              var names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
              var pc = ((m % 12) + 12) % 12
              return names[pc] + octaveFor(m)
            }

            function tooltipText(m) {
              return "MIDI " + m + "\n" + noteName(m)
            }

            // NEW: active highlighting
            function isBlack(pc) {
                // C=0, C#=1, D=2, D#=3, E=4, F=5, F#=6, G=7, G#=8, A=9, A#=10, B=11
                return (pc === 1 || pc === 3 || pc === 6 || pc === 8 || pc === 10)
            }

            function whiteIndexFor(n) {
                // count white keys up to midi n
                var count = 0
                for (var i = kbroot.startMidi; i <= n; ++i) {
                    var pc = i % 12
                    if (!isBlack(pc)) count++
                }
                return count - 1 // zero-based index of this white key (if white)
            }

            // Offset for placing black keys centered above the gap between whites.
            function blackXFor(n) {
                var pc = n % 12
                // For a black key, it sits between two white indices; compute base white index
                // pattern within an octave: W W B W W B W B W W B W (W=white slot)
                // anchor each black key relative to the white on its left.
                var leftWhiteMidi = n - 1
                while (leftWhiteMidi >= kbroot.startMidi && isBlack(leftWhiteMidi % 12)) {
                    leftWhiteMidi--
                }
                var leftIdx = whiteIndexFor(leftWhiteMidi)
                // position: left white x + whiteW - (blackW/2)
                return leftIdx * whiteW + (whiteW - blackW / 2)
            }

            // --- WHITE KEYS LAYER ---
            // Draw all white keys left-to-right
            Repeater {
                id: whiteKeys
                model: (function () {
                    var arr = []
                    for (var n = kbroot.startMidi; n <= kbroot.endMidi; ++n) {
                        var pc = n % 12
                        if (!kbroot.isBlack(pc)) {
                            arr.push(n)
                        }
                    }
                    return arr
                })()

                Rectangle {
                    id:whiteKeyRect
                    readonly property int midi: whiteKeys.model[index]
                    readonly property int whiteIndex: kbroot.whiteIndexFor(midi)
                    readonly property bool active: !!kbroot.activeMap[midi]

                    x: whiteIndex * kbroot.whiteW
                    y: 0
                    width: kbroot.whiteW
                    height: kbroot.whiteH
                    color: kbroot.whiteColor
                    // border.color: active ? kbroot.accent : kbroot.whiteBorder
                    border.color: active ? 0 : kbroot.whiteBorder
                    // border.width: active ? 2 : 1
                    border.width: 1
                    radius: 1

                    // accent overlay (subtle fill), keeps the key visible
                    Rectangle {
                      anchors.fill: parent
                      color: kbroot.accent
                      opacity: active ? kbroot.activeOverlayOpacityWhite : 0
                      radius: parent.radius
                    }

                    // MuseScore-styled tooltip via FlatButton overlay
                    FlatButton {
                      id: whiteKeyTip
                      anchors.fill: parent
                      z: 100
                      transparent: true // don't draw background
                      focusPolicy: Qt.NoFocus
                      opacity: 0
                      toolTipTitle: kbroot.tooltipText(midi)

                      // If the key should react to clicks, wire them here or forward them:
                      // onPressed:  kbroot.notePressed(midi)
                      // onReleased: kbroot.noteReleased(midi)
                    }
                }
            }

            // --- BLACK KEYS LAYER (overlay) ---
            // Draw all black keys above whites with proper x-offset
            Repeater {
                id: blackKeys
                model: (function () {
                    var arr = []
                    for (var n = kbroot.startMidi; n <= kbroot.endMidi; ++n) {
                        var pc = n % 12
                        if (kbroot.isBlack(pc)) {
                            // skip black keys that would straddle outside range at very edges
                            // (safe enough for 0..127 full range)
                            arr.push(n)
                        }
                    }
                    return arr
                })()

                Rectangle {
                    readonly property int midi: blackKeys.model[index]
                    readonly property bool active: !!kbroot.activeMap[midi]

                    z: 10
                    x: kbroot.blackXFor(midi)
                    y: 0
                    width: kbroot.blackW
                    height: kbroot.blackH
                    color: kbroot.blackColor
                    // border.color: active ? kbroot.accent : kbroot.blackBorder
                    border.color: active ? 0 : kbroot.blackBorder
                    // border.width: active ? 2 : 1
                    border.width: 1
                    radius: Math.max(1, Math.round(kbroot.blackW * 0.12))

                    // accent overlay for black keys (slightly stronger opacity)
                    Rectangle {
                      anchors.fill: parent
                      color: kbroot.accent
                      opacity: active ? kbroot.activeOverlayOpacityBlack : 0
                      radius: parent.radius
                    }

                    // MuseScore-styled tooltip via FlatButton overlay
                    FlatButton {
                      id: blackKeyTip
                      anchors.fill: parent
                      z: 100
                      transparent: true // don't draw background
                      focusPolicy: Qt.NoFocus
                      opacity: 0
                      toolTipTitle: kbroot.tooltipText(midi)

                      // If the key should react to clicks, wire them here or forward them:
                      // onPressed:  kbroot.notePressed(midi)
                      // onReleased: kbroot.noteReleased(midi)
                    }

                }
            }

            // Optional: transparent MouseArea to capture clicks => midi note number
            // MouseArea { anchors.fill: parent; enabled: false }
        }

        // Title row with dynamic text + filter search
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          StyledTextLabel {
            id: assignTitle
            Layout.alignment: Qt.AlignVCenter
            text: (selectedCountProp === 1 && currentStaffIdx >= 0)
                  ? qsTr('Assign set to ') + cleanName(staffNameByIdx(currentStaffIdx))
                  : qsTr('Assign set to %1 staves').arg(selectedCountProp)
          }

          Item { Layout.fillWidth: true }

          Item {
            id: searchBox
            Layout.preferredWidth: 285
            Layout.minimumWidth: 240
            Layout.maximumWidth: 320
            height: ui.theme.defaultButtonSize

            TextField {
              id: setSearchField
              anchors.fill: parent
              leftPadding: 28 //for icon
              placeholderText: qsTr("Filter sets…")

              background: Rectangle {
                anchors.fill: parent
                radius: 4
                // color: "transparent"
                color: ui.theme.textFieldColor
                border.width: 1
                border.color: setSearchField.text.length > 0 ? ui.theme.accentColor
                              : ui.theme.strokeColor
              }

              // When types, rebuild the filtered view
              onTextChanged: {
                setFilterText = text
                rebuildFilteredSets()
              }

              Keys.onReturnPressed: rebuildFilteredSets()
            }

            FlatButton {
              anchors.verticalCenter: setSearchField.verticalCenter
              anchors.left: parent.left
              transparent: true
              focusPolicy: Qt.NoFocus
              onClicked: {}
              backgroundItem: Item {}
              enabled: true
              iconColor: ui.theme.fontPrimaryColor
              icon: IconCode.SEARCH
            }
          }

        }

        // Articulation set buttons box
        GroupBox {
          id: assignBox
          title: ""
          Layout.fillWidth: true
          Layout.preferredHeight: 260
          background: Rectangle {
            color: ui.theme.textFieldColor
          }

          // Size probe to match FlatButton metrics (use the exact component type)
          FlatButton { id: _sizeProbe; visible: false; text: qsTr('Save'); accentButton: true }

          ScrollView {
            id: setsScroll
            anchors.fill: parent
            clip: true

            Flow {
              id: setButtonsFlow
              width: setsScroll.availableWidth
              spacing: 8
              flow: Flow.LeftToRight

              // Local UI-selected set; updated by refreshUISelectedSet() and on clicks
              property string uiSelectedSet: "__none__"

              Repeater {
                // model: setsListModel
                model: filteredSetsModel
                delegate: FlatButton {
                  id: setBtn
                  text: model.name
                  width: _sizeProbe.implicitWidth
                  height: _sizeProbe.implicitHeight
                  property bool isActive: setButtonsFlow.uiSelectedSet === model.name
                  accentButton: isActive
                  transparent: false
                  onClicked: {
                    var keys = Object.keys(selectedStaff)
                    if (keys.length === 0 && currentStaffIdx >= 0) {
                      staffToSet[currentStaffIdx.toString()] = model.name
                    } else {
                      for (var i = 0; i < keys.length; ++i) staffToSet[keys[i]] = model.name
                    }
                    setButtonsFlow.uiSelectedSet = model.name
                    setSearchField.focus = false
                  }
                }
              }
            }
          }
        }

        // Editors
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 0


          // tabs
          RowLayout {
            id: tabsHeaderRow
            Layout.fillWidth: true
            spacing: 8

            StyledTabBar {
              id: editorTabs
              Layout.fillWidth: true
              spacing: 36
              background: Item { implicitHeight: 32 }

              StyledTabButton { text: qsTr('Edit set registry'); onClicked: editorModeIndex = 0 }
              StyledTabButton { text: qsTr('Global settings');   onClicked: editorModeIndex = 1 }
            }
          }

          StackLayout {
            id: navTabPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 0
            currentIndex: editorModeIndex

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.leftMargin: leftTextMargin

              Rectangle {
                id: registryFrame
                anchors.fill: parent
                color: "transparent"
                border.width: root.registryBorderWidth
                border.color: root.registryBorderColor
                radius: 4

                ScrollView {
                  anchors.fill: parent
                  anchors.margins: root.registryBorderWidth

                  TextArea {
                    id: jsonArea
                    wrapMode: TextArea.NoWrap
                    font.family: 'monospace'
                    background: Rectangle { color: ui.theme.textFieldColor }
                    onTextChanged: {
                        root.updateKeyboardActiveNotes()
                        root.validateRegistryText()         // live validation
                    }
                  }
                }
              }
            }

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.leftMargin: leftTextMargin

              Rectangle {
                id: globalsFrame
                anchors.fill: parent
                color: "transparent"
                border.width: root.globalsBorderWidth
                border.color: root.globalsBorderColor
                radius: 4

                ScrollView {
                  anchors.fill: parent
                  anchors.margins: root.registryBorderWidth

                  TextArea {
                    id: globalsArea
                    wrapMode: TextArea.NoWrap
                    font.family: 'monospace'
                    background: Rectangle { color: ui.theme.textFieldColor }
                    onTextChanged: root.validateGlobalsText()   // live validation
                  }
                }
              }
            }
          }
        }
      }
    }

    // bottom buttons
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Item {
        Layout.preferredWidth: 222

        Text {
          id: version
          color: ui.theme.fontPrimaryColor
          Layout.alignment: Qt.AlignVCenter
          text: "v." + root.version
        }
      }

      FlatButton {
        id: resetButtonRef
        text: qsTr('Reset to Default')
        onClicked: {
          if (editorModeIndex === 0)
            jsonArea.text = formatRegistryCompact(defaultRegistryObj())
          else
            globalsArea.text = formatGlobalsCompact(defaultGlobalSettingsObj())
        }
      }

      Item { Layout.fillWidth: true }

      FlatButton { id: saveButtonRef; text: qsTr('Save'); accentButton: true; onClicked: { saveData(); /*quit()*/ } }
      FlatButton { id: cancelButtonRef; text: qsTr('Close'); onClicked: quit() }
    }

  }

  // On selected set button change, refresh active keys
  Connections {
      target: setButtonsFlow
      function onUiSelectedSetChanged() { updateKeyboardActiveNotes() }
  }

  // While editing the registry text, update highlights live
  Connections {
      target: jsonArea
      function onTextChanged() { updateKeyboardActiveNotes() }
  }

}
