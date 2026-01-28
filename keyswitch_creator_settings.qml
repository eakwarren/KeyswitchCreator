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
  version: "0.9.4"
  title: qsTr("Keyswitch Creator Settings")
  description: qsTr("Keyswitch Creator settings.")
  pluginType: "dialog"
  categoryCode: "Keyswitch Creator"
  thumbnailName: "keyswitch_creator_settings.png"

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

  // Pending editor text (used if loadData() runs before editors exist)
  property var _pendingRegistryText: undefined
  property var _pendingGlobalsText:  undefined

  // Error overlays (line index -> y = lineIndex * lineHeight)
  property bool showRegistryErrorOverlay: false
  property bool showGlobalsErrorOverlay: false
  property int  registryErrorLine: 0
  property int  globalsErrorLine: 0

  // error character positions (used with positionToRectangle())
  property int registryErrorPos: 0
  property int globalsErrorPos: 0

  // Error state flags (used to suppress auto-scrolling while JSON is invalid)
  property bool hasRegistryJsonError: false
  property bool hasGlobalsJsonError: false
  property bool _registryErrorRevealScheduled: false
  property bool _globalsErrorRevealScheduled: false

  // Interaction flags: used to avoid drawing a bogus top-of-file overlay on first open
  property bool _regUserInteracted: false
  property bool _globUserInteracted: false

  // Select the style for the red highlight:
  //   "line"   -> highlight the whole row (left margin to right edge)
  //   "fromPos"-> highlight from the error character to right edge
  property string errorHighlightStyle: "line"

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
      "durationPolicy": "source",
      "techniqueAliases": {
        // phrasing
        "legato": ["legato", "leg.", "slur", "slurred"],
        "normal": ["normal", "normale", "norm.", "nor.", "ordinary", "ord.", "standard", "std.", "arco"],
        // mutes
        "con sord": ["con sord", "con sord.", "con sordino", "with mute", "muted", "sord."],
        "senza sord": ["senza sord", "senza sord.", "senza sordino", "open", "without mute"],
        // position
        "sul pont": ["sul pont", "sul pont.", "sul ponticello"],
        "sul tasto": ["sul tasto", "sul tast.", "flautando"],
        // timbre/attack
        "col legno": ["col legno", "col l.", "c.l."],
        "harmonic": ["harmonic", "harm.", "harmonics", "natural harmonic", "artificial harmonic"],
        "spiccato": ["spiccato", "spicc.", "spic."],
        "pizz": ["pizz", "pizz.", "pizzicato"],
        "tremolo": ["tremolo", "trem.", "tremolando"]
      }
    }
  }


  function defaultRegistryObj() {
    return {
      "Default Low": {
         "articulationKeyMap": {"staccato": 0, "staccatissimo": 1, "tenuto": 2, "accent": 3, "marcato": 4, "sforzato": 5, "loure": 6, "fermata": 7, "trill": 8, "mordent": 9, "mordent inverted": 10, "turn": 11, "harmonics": 12, "mute": 13},
         "techniqueKeyMap": {"normal": 14, "arco": 15, "pizz": 16, "tremolo": 17, "con sord": 18, "senza sord": 19, "sul pont": 20, "sul tasto": 21, "harmonic": 22, "col legno": 23, "legato": 24, "spiccato": 25}
        },

        "Default High": {
         "articulationKeyMap": { "staccato": 127, "staccatissimo": 126, "tenuto": 125, "accent": 124, "marcato": 123, "sforzato": 122, "loure": 121, "fermata": 120, "trill": 119, "mordent": 118, "mordent inverted": 117, "turn": 116, "harmonics": 115, "mute": 114},
         "techniqueKeyMap": {"normal": 113, "arco": 112, "pizz": 111, "tremolo": 110, "con sord": 109, "senza sord": 108, "sul pont": 107, "sul tasto": 106, "harmonic": 105, "col legno": 104, "legato": 103, "spiccato": 102}
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

      // No explicit set selected/assigned → clear keyboard highlights
    if (!setName || setName === "__none__") {
      if (kbroot) kbroot.activeNotes = []
      return
    }

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
        return nm0 ? nm0 : "__none__"
      }
      return "__none__"
    }
    // Multi-select: if all selected staves share the same explicit mapping, return it
    var first = null
    for (var i = 0; i < keys.length; ++i) {
      var nm = staffToSet[keys[i]]
      if (!nm) nm = "__none__"
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

  // Decode/strip for UI-safe display of part/staff names
  function stripHtmlTags(s) {
    return String(s || "").replace(/<[^>]*>/g, "");
  }

  function decodeHtmlEntities(s) {
    var t = String(s || "");
    // common named entities
    t = t.replace(/&nbsp;/g, " ")
         .replace(/&amp;/g, "&")
         .replace(/&lt;/g, "<")
         .replace(/&gt;/g, ">")
         .replace(/&quot;/g, "\"")
         .replace(/&#39;/g, "'");
    // numeric entities (decimal & hex)
    t = t.replace(/&#([0-9]+);/g, function(_, n){ return String.fromCharCode(parseInt(n, 10) || 0); });
    t = t.replace(/&#x([0-9a-fA-F]+);/g, function(_, h){ return String.fromCharCode(parseInt(h, 16) || 0); });
    return t;
  }

  function normalizeUiText(s) {
    return cleanName(decodeHtmlEntities(stripHtmlTags(s)));
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
    return normalizeUiText(nm)   // decode entities + strip tags
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
      if (jsonArea) jsonArea.text = rawSets; else _pendingRegistryText = rawSets
    } else {
      keyswitchSets = defaultRegistryObj()
      var defRegText = formatRegistryCompact(keyswitchSets)
      if (jsonArea) jsonArea.text = defRegText; else _pendingRegistryText = defRegText
    }

    if (rawGlobals.length > 0) {
      if (globalsArea) globalsArea.text = rawGlobals; else _pendingGlobalsText = rawGlobals
    } else {
      globalSettings = defaultGlobalSettingsObj()
      var defGlobText = formatGlobalsCompact(globalSettings)
      if (globalsArea) globalsArea.text = defGlobText; else _pendingGlobalsText = defGlobText
    }

    // Decide the error state for Globals NOW (before any later UI scrolls)
    var _tmpParsedGlobals = null;
    try {
        _tmpParsedGlobals = JSON.parse(globalsArea.text);
    } catch (e) {
        _tmpParsedGlobals = null;
    }
    root.hasGlobalsJsonError = (_tmpParsedGlobals === null);
    setGlobalsBorder(!_tmpParsedGlobals ? false : true);

    // 3) Parse in-memory objects (never clobber the editor if parse fails)
    // NOTE: Decide the error flag *now*, before any scroll-to-set logic triggers.
    var parsedSets = parseRegistrySafely(jsonArea.text);
    root.hasRegistryJsonError = !parsedSets;

    if (parsedSets) {
      keyswitchSets = parsedSets;
      setRegistryBorder(true);
    } else {
      keyswitchSets = defaultRegistryObj();
      setRegistryBorder(false);
    }

    // If globals JSON invalid on open, schedule a "late" error reveal
    if (root.hasGlobalsJsonError) {
        // scheduleGlobalsErrorReveal();
    }

    // quick visibility check in the console
    console.log("[KS] staffListModel.count =", staffListModel.count)

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
      // 1) Persist raw strings
      ksPrefs.setsJSON = jsonArea.text
      ksPrefs.globalJSON = globalsArea.text
      ksPrefs.staffToSetJSON = JSON.stringify(staffToSet)
      if (ksPrefs.sync) { try { ksPrefs.sync() } catch (e) {} } // flush if available

      // 2) Try to parse the registry text so we can refresh UI immediately
      var parsed = parseRegistrySafely(jsonArea.text)  // returns null on error
      if (parsed) {
          // a) Update in-memory registry
          keyswitchSets = parsed

          // b) Rebuild the list used by the buttons
          var prevSelected = (setButtonsFlow && setButtonsFlow.uiSelectedSet) ? setButtonsFlow.uiSelectedSet : "__none__"
          setsListModel.clear()
          for (var k in keyswitchSets) {
              if (keyswitchSets.hasOwnProperty(k))
                  setsListModel.append({ name: k })
          }

          // c) Rebuild the filtered view (respect current filter text)
          rebuildFilteredSets()

          // d) Restore a reasonable selected set for the buttons row
          //    - keep previous if it still exists; else derive from current selection
          if (!prevSelected || !keyswitchSets.hasOwnProperty(prevSelected)) {
              setButtonsFlow.uiSelectedSet = activeSetForCurrentSelection()
          } else {
              setButtonsFlow.uiSelectedSet = prevSelected
          }
          // e) Refresh keyboard highlights and border
          updateKeyboardActiveNotes()
          setRegistryBorder(true)

          //ensure the editor shows the active set's JSON after saving
          if (!root.hasRegistryJsonError && setButtonsFlow.uiSelectedSet && setButtonsFlow.uiSelectedSet !== "__none__")
            scrollToSetInRegistry(setButtonsFlow.uiSelectedSet)
      } else {
          // Still saved the raw text, but it's not valid JSON yet -> keep warning
          setRegistryBorder(false)
      }
  }

  function scrollToSetInRegistry(setName) {
    if (root.hasRegistryJsonError)
      return; // cancel any queued "scroll to set" while an error is present
    if (!setName || setName === "__none__")
      return;
    if (editorModeIndex !== 0)
      return;
    var txt = jsonArea.text || "";

    // Prefer compact formatter pattern: "Name":{
    var needle = JSON.stringify(setName) + ":{";
    var pos = txt.indexOf(needle);

    // Fallback: just the quoted name (if user reformatted)
    if (pos < 0) {
      var q = JSON.stringify(setName);
      pos = txt.indexOf(q);
      if (pos < 0) return; // not found
    }

    // Snap caret to start of containing line – stable anchor
    var lineStart = pos;
    while (lineStart > 0) {
      var ch = txt.charAt(lineStart - 1);
      if (ch === '\n' || ch === '\r') break;
      lineStart--;
    }
    jsonArea.cursorPosition = lineStart;

    // 1st defer: let cursorRectangle update to new caret position
    Qt.callLater(function () {
      var caretRect;
      try { caretRect = jsonArea.cursorRectangle; } catch (e) { caretRect = null; }
      if (!caretRect) return;

      var topPad = 6;
      var targetY = Math.max(0, caretRect.y - topPad);

      // 2nd defer: ensure Flickable metrics (contentHeight/height) are final
      Qt.callLater(function () {
        var flk = registryFlick;
        if (!flk) return;

        var maxY = Math.max(0, (flk.contentHeight || 0) - (flk.height || 0));
        var clamped = Math.max(0, Math.min(targetY, maxY));

        flk.contentY = clamped;
        jsonArea.forceActiveFocus();
        try { jsonArea.cursorVisible = true; } catch (e) {}
      });
    });
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
    var ok = true, raw = -1, pos = -1
    try {
      JSON.parse(jsonArea.text)
    } catch (e) {
      ok = false
      raw = computeJsonErrorPos(jsonArea.text)                  // -1 if unknown
      var candidate = (raw >= 0) ? displayPosForError(jsonArea.text, raw) : -1
      // If parser gave us nothing usable (<=0) and user hasn't interacted yet,
      // don't draw a misleading overlay on row 1.
      if (candidate <= 0 && !root._regUserInteracted) {
        root.showRegistryErrorOverlay = false
        setRegistryBorder(false)
        root.hasRegistryJsonError = true
        return
      }
      // Otherwise pick parser's position if >0, else use caret (user moved/typed)
      pos = (candidate > 0) ? candidate : jsonArea.cursorPosition

      root.registryErrorPos  = Math.max(0, Math.min(pos, (jsonArea.text || "").length))
      root.registryErrorLine = lineIndexForPos(jsonArea.text, root.registryErrorPos)
      console.log("[KS] registry JSON error:", String(e),
                  "rawPos=", raw, "candidate=", candidate, "chosen=", root.registryErrorPos)
    }
    setRegistryBorder(ok)
    root.hasRegistryJsonError = !ok
    root.showRegistryErrorOverlay = !ok
  }

  function validateGlobalsText() {
    var ok = true, raw = -1, pos = -1
    try {
      JSON.parse(globalsArea.text)
    } catch (e) {
      ok = false
      raw = computeJsonErrorPos(globalsArea.text)                  // -1 if unknown
      var candidate = (raw >= 0) ? displayPosForError(globalsArea.text, raw) : -1
      // If parser gave us nothing usable (<=0) and user hasn't interacted yet,
      // don't draw a misleading overlay on row 1.
      if (candidate <= 0 && !root._globUserInteracted) {
        root.showGlobalsErrorOverlay = false
        setGlobalsBorder(false)
        root.hasGlobalsJsonError = true
        return
      }
      // Otherwise pick parser's position if >0, else use caret (user moved/typed)
      pos = (candidate > 0) ? candidate : globalsArea.cursorPosition

      root.globalsErrorPos  = Math.max(0, Math.min(pos, (globalsArea.text || "").length))
      root.globalsErrorLine = lineIndexForPos(globalsArea.text, root.globalsErrorPos)
      console.log("[KS] globals JSON error:", String(e),
                  "rawPos=", raw, "candidate=", candidate, "chosen=", root.globalsErrorPos)
    }
    setGlobalsBorder(ok)
    root.hasGlobalsJsonError = !ok
    root.showGlobalsErrorOverlay = !ok
  }

  // --- JSON error highlighting helpers ---------------------------------------

  // Try to extract a numeric position from a JSON.parse error message.
  // Supports multiple engine variants: "at position N", "at line X column Y", "at character N".
  function jsonErrorPosFromMessage(msg, text) {
      var s = String(msg || "");
      var m;

      // 1) "... at position 123" (with or without a ":" and extra spaces)
      m = /position\s*:?\s*([0-9]+)/i.exec(s);
      if (m && m[1]) return parseInt(m[1], 10);

      // 2) "... at character 123" / "... char 123"
      m = /(?:character|char)\s+([0-9]+)/i.exec(s);
      if (m && m[1]) return parseInt(m[1], 10);

      // 3) "... line X column Y" (0- or 1-based depends on engine; we treat column as 1-based)
      m = /line\s+([0-9]+)\s*(?:,|\s+)?column\s+([0-9]+)/i.exec(s);
      if (m && m[1] && m[2]) {
          var line = parseInt(m[1], 10);    // 1-based in most messages
          var col  = parseInt(m[2], 10);    // also 1-based
          var t = String(text || "");
          var idx = 0, currentLine = 1;     // convert line/column to flat index
          for (var i = 0; i < t.length && currentLine < line; i++) {
              if (t.charAt(i) === '\n') { currentLine++; idx = i + 1; }
          }
          return Math.max(0, Math.min(idx + Math.max(0, col - 1), t.length));
      }

      return -1;
  }

  // Heuristic for common "missing comma" faults: look for   } "<nextKey>"   or   ] "<nextItem>"
  function _heuristicMissingCommaPos(text) {
    var s = String(text || "");
    var m = /\}\s*"/.exec(s);
    if (m) return m.index + m[0].indexOf('"'); // at the offending quote
    m = /\]\s*(?=["{\[\]])/.exec(s);
    if (m) return m.index + 1;                 // at the quote/bracket after ]
    return -1;                                  // <— unknown (do NOT force top-of-file)
  }

  // Returns -1 if valid, else the best-effort character position for the error
  function computeJsonErrorPos(text) {
      try { JSON.parse(text); return -1; }
      catch (e) {
          // First: try to decode whatever message the engine gave us
          var pos = jsonErrorPosFromMessage(String(e), text);
          if (typeof pos === "number" && pos >= 0 && isFinite(pos)) return pos;

          // Fallback: guess a likely comma-missing site
          return _heuristicMissingCommaPos(text);
      }
  }

  // Select and color (accent) the line containing 'pos' in 'editor', then scroll that line into view.
  // NOTE: We color the *text* (selectedTextColor) and keep selection background transparent,
  // so the accent color is applied to the glyphs themselves.
  function highlightErrorAtPos(editor, flick, pos) {
      if (!editor || !flick) return;

      // Guard against NaN/undefined/inf
      if (typeof pos !== "number" || !isFinite(pos)) pos = 0;
      var txt = String(editor.text || "");
      var len = txt.length;
      pos = Math.max(0, Math.min(pos, len));

      // Compute line start/end
      var start = pos;
      while (start > 0 && txt.charAt(start - 1) !== '\n') start--;
      var end = pos;
      while (end < len && txt.charAt(end) !== '\n') end++;

      // Apply selection with accent-colored text

      // var accent = (ui && ui.theme && ui.theme.accentColor) ? ui.theme.accentColor : "#2E7DFF";
      try {
          // 1) Use a background highlight instead of recoloring glyphs (for the test)
          editor.selectionColor = (ui && ui.theme && ui.theme.accentColor) ? ui.theme.accentColor : "#2E7DFF";

          // 2) Comment this out temporarily (this can trigger the Fusion loop)
          // editor.selectedTextColor = accent;

          // Keep the no-op check to avoid redundant selection churn
          var sameSel = (editor.selectionStart === start &&
                         editor.selectionEnd   === end   &&
                         editor.cursorPosition === start);
          if (!sameSel) {
              editor.select(start, end);
              editor.cursorPosition = start;
          }
      } catch (e) {}

      // Defer scrolling twice to outrun other queued scrolls.
      Qt.callLater(function() {
          var caret = editor.cursorRectangle;
          var topPad = 6;
          var targetY = Math.max(0, (caret ? caret.y : 0) - topPad);

          Qt.callLater(function() {
              var maxY = Math.max(0, (flick.contentHeight || 0) - (flick.height || 0));
              flick.contentY = Math.max(0, Math.min(targetY, maxY));
              try { editor.forceActiveFocus(); } catch (e) {}
          });
      });
  }

  function clearHighlight(editor) {
      if (!editor) return;
      // Clear selection and revert text color to default
      if (typeof editor.deselect === "function") editor.deselect(); else editor.select(0, 0);
      try {
          editor.selectedTextColor = ui && ui.theme ? ui.theme.fontPrimaryColor : "#000000";
          // leave selectionColor alone; default is fine
      } catch (e) {}
  }

  // Count '\n' before pos to get a 0-based line index
  function lineIndexForPos(text, pos) {
      var s = String(text || "");
      if (typeof pos !== "number" || !isFinite(pos) || pos < 0) pos = 0;
      if (pos > s.length) pos = s.length;
      var count = 0;
      for (var i = 0; i < pos; ++i) if (s.charAt(i) === '\n') count++;
      return count;
  }

  // Scroll a Flickable so that lineIndex is near the top (uses FontMetrics height)
  function scrollToLine(flick, lineIndex, lineHeight) {
      if (!flick || !isFinite(lineIndex) || !isFinite(lineHeight)) return;
      var topPad = 6;
      var targetY = Math.max(0, lineIndex * lineHeight - topPad);
      Qt.callLater(function() {
          var maxY = Math.max(0, (flick.contentHeight || 0) - (flick.height || 0));
          flick.contentY = Math.max(0, Math.min(targetY, maxY));
      });
  }

  // Defer highlight/scroll twice so it runs AFTER any queued palette/set scrolls
  function scheduleRegistryErrorReveal() {
      if (_registryErrorRevealScheduled) return;
      _registryErrorRevealScheduled = true;
      Qt.callLater(function() {
          Qt.callLater(function() {
              _registryErrorRevealScheduled = false;
              if (!root.hasRegistryJsonError) return;
              var pos = computeJsonErrorPos(jsonArea.text);
              // highlightErrorAtPos(jsonArea, registryFlick, (pos >= 0 ? pos : 0));
          });
      });
  }

  function scheduleGlobalsErrorReveal() {
      if (_globalsErrorRevealScheduled) return;
      _globalsErrorRevealScheduled = true;
      Qt.callLater(function() {
          Qt.callLater(function() {
              _globalsErrorRevealScheduled = false;
              if (!root.hasGlobalsJsonError) return;
              var pos = computeJsonErrorPos(globalsArea.text);
              // highlightErrorAtPos(globalsArea, globalsFlick, (pos >= 0 ? pos : 0));
          });
      });
  }

  function scrollToPosByCaret(editor, flick, pos, topPad) {
      if (!editor || !flick) return;
      var textLen = (editor.length !== undefined ? editor.length : (editor.text || "").length);
      var p = Math.max(0, Math.min(pos, textLen));
      editor.cursorPosition = p;                    // put caret at error
      Qt.callLater(function() {                     // wait for cursorRectangle
          var caret = editor.cursorRectangle;
          if (!caret) return;
          var pad = (typeof topPad === "number") ? topPad : 6;
          var targetY = Math.max(0, caret.y - pad);
          Qt.callLater(function() {                 // ensure flick metrics are final
              var maxY = Math.max(0, (flick.contentHeight || 0) - (flick.height || 0));
              flick.contentY = Math.max(0, Math.min(targetY, maxY));
          });
      });
  }

  // Return index of last non-whitespace char at/left of 'i'
  function _skipWsLeft(text, i) {
      var s = String(text || "");
      var j = Math.min(Math.max(0, i), s.length - 1);
      while (j >= 0) {
          var ch = s.charAt(j);
          if (ch !== ' ' && ch !== '\t' && ch !== '\r' && ch !== '\n') return j;
          j--;
      }
      return -1;
  }

  // Return start-index of the line containing 'i'
  function _lineStart(text, i) {
      var s = String(text || "");
      var j = Math.min(Math.max(0, i), s.length);
      while (j > 0 && s.charAt(j - 1) !== '\n') j--;
      return j;
  }

  // Adjust the raw engine position to the line that *caused* the error.
  // If the engine points at the next key (e.g., missing comma), jump to the line
  // that ends with '}' or ']' right above it. Otherwise, snap to the raw line.
  function displayPosForError(text, rawPos) {
      var s = String(text || "");
      if (!(typeof rawPos === "number" && isFinite(rawPos) && rawPos >= 0))
          return 0;
      if (rawPos > s.length) rawPos = s.length;

      // 1) Look left of the raw position for the nearest non-WS char
      var left = _skipWsLeft(s, rawPos - 1);

      // If that left char is a quote, step left again to find what precedes the quote.
      var beforeLeft = left;
      if (left >= 0 && s.charAt(left) === '"')
          beforeLeft = _skipWsLeft(s, left - 1);

      // 2) If the char immediately preceding the next token is '}' or ']',
      //    the *real* fault is "missing comma after that block".
      if (beforeLeft >= 0) {
          var ch = s.charAt(beforeLeft);
          if (ch === '}' || ch === ']') {
              return _lineStart(s, beforeLeft);   // snap to the offending block line
          }
      }

      // 3) Otherwise, just snap to the raw line start.
      return _lineStart(s, rawPos);
  }


  onRun: {
      // Defer until the next frame to ensure child items (globalsArea/jsonArea) exist
      Qt.callLater(function () {
          loadData()
          // Ensure initial focus goes to staves list for keyboard shortcuts
          staffList.forceActiveFocus()
          refreshUISelectedSet()
      })
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

              // Render the row label as literal text (no mnemonics / HTML)
              contentItem: Text {
                text: cleanName(model.name)
                textFormat: Text.PlainText
                color: ui.theme.fontPrimaryColor
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
              }

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
            textFormat: Text.PlainText // render literally, no mnemonics
            text: (selectedCountProp === 1 && currentStaffIdx >= 0)
                  ? qsTr('Assign set to ') + cleanName(staffNameByIdx(currentStaffIdx))
                  : qsTr('Assign set to %1 staves').arg(selectedCountProp)
          }

          Item { Layout.fillWidth: true }

          FlatButton {
              id: clearAssignmentsRef
              text: qsTr('Clear all staff assignments')
              onClicked: {
                // Clear in-memory
                staffToSet = {}

                // Clear persisted JSON (explicitly to "{}" for clarity)
                ksPrefs.staffToSetJSON = "{}"
                if (ksPrefs.sync) { try { ksPrefs.sync() } catch(e) {} }

                // Reset UI state
                setButtonsFlow.uiSelectedSet = "__none__"
                refreshUISelectedSet()
                updateKeyboardActiveNotes()
              }
            }

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

                  // Active state = highlighted button
                  property bool isActive: setButtonsFlow.uiSelectedSet === model.name
                  accentButton: isActive
                  transparent: false

                  onClicked: {
                    var keys = Object.keys(selectedStaff)
                    var hasSelection = keys.length > 0
                    var targetStaffIds = []

                    if (hasSelection) {
                      targetStaffIds = keys       // array of staffIdx strings
                    } else if (currentStaffIdx >= 0) {
                      targetStaffIds = [ currentStaffIdx.toString() ]
                    }

                    var togglingOff = (setButtonsFlow.uiSelectedSet === model.name)

                    if (togglingOff) {
                      // Second click on the same button: unassign (clear mapping)
                      for (var i = 0; i < targetStaffIds.length; ++i)
                        delete staffToSet[targetStaffIds[i]]

                      // UI: no button selected
                      setButtonsFlow.uiSelectedSet = "__none__"
                    } else {
                      // First click: assign this set
                      for (var j = 0; j < targetStaffIds.length; ++j)
                        staffToSet[targetStaffIds[j]] = model.name

                      // UI: this button selected
                      setButtonsFlow.uiSelectedSet = model.name
                      scrollToSetInRegistry(model.name)
                    }


                    // Update helper visuals (keyboard)
                    updateKeyboardActiveNotes()

                    // persist immediately (uncomment to auto-save on click)
                    // saveData()

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

                Flickable {
                  id: registryFlick
                  anchors.fill: parent
                  anchors.margins: root.registryBorderWidth
                  clip: true

                  // line height probe for consistent Y mapping
                  FontMetrics { id: regFM; font: jsonArea.font }

                  // Error overlay for registry (positioned by the error character rectangle)
                  Rectangle {
                    id: registryErrorOverlay
                    // Put the overlay in the SAME stack as the text to ensure it draws above it
                    parent: jsonArea
                    z: 1000
                    visible: root.showRegistryErrorOverlay && (editorModeIndex === 0)
                    color: root.warningColor
                    opacity: 0.25

                    // Where the error character sits inside jsonArea (local coords)
                    property rect _errRect: (function() {
                      try { return jsonArea.positionToRectangle(root.registryErrorPos) }
                      catch(e) { return Qt.rect(0, root.registryErrorLine * regFM.height, jsonArea.width, regFM.height) }
                    })()

                    // Helper: start-of-line position/rectangle for this line
                    property int _lineStartPos: (function() {
                      return _lineStart(jsonArea.text || "", root.registryErrorPos);
                    })()

                    property rect _lineStartRect: (function() {
                      try { return jsonArea.positionToRectangle(_lineStartPos) }
                      catch(e) { return Qt.rect(0, root.registryErrorLine * regFM.height, jsonArea.width, regFM.height) }
                    })()

                    // Choose "line" or "fromPos" behavior
                    x: (root.errorHighlightStyle === "line") ? 0 : _errRect.x
                    y: _lineStartRect.y
                    width: (root.errorHighlightStyle === "line") ? jsonArea.width
                                                                 : Math.max(1, jsonArea.width - _errRect.x)
                    height: Math.max(1, _errRect.height || regFM.height)
                    radius: 0
                  }
                  TextArea.flickable: TextArea {
                    id: jsonArea
                    width: registryFlick.width
                    wrapMode: TextArea.NoWrap
                    font.family: "monospace"
                    background: Rectangle { color: ui.theme.textFieldColor }

                    onActiveFocusChanged: if (activeFocus) root._regUserInteracted = true
                    onCursorPositionChanged: root._regUserInteracted = true
                    Keys.onPressed: root._regUserInteracted = true
                    onTextChanged: {
                      root.updateKeyboardActiveNotes()
                      root.validateRegistryText()
                    }

                    Component.onCompleted: {
                        if (root._pendingRegistryText !== undefined) {
                            jsonArea.text = root._pendingRegistryText
                            root._pendingRegistryText = undefined
                        }
                        root.validateRegistryText()
                    }

                  }

                  ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
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

                Flickable {
                  id: globalsFlick
                  anchors.fill: parent
                  anchors.margins: root.globalsBorderWidth
                  clip: true

                  FontMetrics { id: globFM; font: globalsArea.font }

                  Rectangle {
                    id: globalsErrorOverlay
                    parent: globalsArea
                    z: 1000
                    visible: root.showGlobalsErrorOverlay && (editorModeIndex === 1)
                    color: root.warningColor
                    opacity: 0.25

                    // Where the error character sits inside jsonArea (local coords)
                    property rect _errRect: (function() {
                      try { return globalsArea.positionToRectangle(root.globalsErrorPos) }
                      catch(e) { return Qt.rect(0, root.globalsErrorLine * globFM.height, globalsArea.width, globFM.height) }
                    })()

                    // Helper: start-of-line position/rectangle for this line
                    property int _lineStartPos: (function() {
                      return _lineStart(globalsArea.text || "", root.globalsErrorPos);
                    })()

                    property rect _lineStartRect: (function() {
                      try { return globalsArea.positionToRectangle(_lineStartPos) }
                      catch(e) { return Qt.rect(0, root.globalsErrorLine * globFM.height, globalsArea.width, globFM.height) }
                    })()

                    // Choose "line" or "fromPos" behavior
                    x: (root.errorHighlightStyle === "line") ? 0 : _errRect.x
                    y: _lineStartRect.y
                    width: (root.errorHighlightStyle === "line") ? globalsArea.width
                                                                 : Math.max(1, globalsArea.width - _errRect.x)
                    height: Math.max(1, _errRect.height || globFM.height)

                    radius: 0
                  }
                  TextArea.flickable: TextArea {
                    id: globalsArea

                    width: globalsFlick.width
                    wrapMode: TextArea.NoWrap
                    font.family: "monospace"
                    background: Rectangle { color: ui.theme.textFieldColor }

                    onActiveFocusChanged: if (activeFocus) root._globUserInteracted = true
                    onCursorPositionChanged: root._globUserInteracted = true
                    Keys.onPressed: root._globUserInteracted = true
                    onTextChanged: {
                      root.updateKeyboardActiveNotes()
                      root.validateGlobalsText()
                    }

                    Component.onCompleted: {
                        if (root._pendingGlobalsText !== undefined) {
                            globalsArea.text = root._pendingGlobalsText
                            root._pendingGlobalsText = undefined
                        }
                        root.validateGlobalsText()
                    }

                  }

                  ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
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


      // --- animated "Settings Saved" label ---
      Text {
          id: saveToast
          text: qsTr("Settings Saved")
          color: ui.theme.fontPrimaryColor
          visible: false
          opacity: 0.0
          Layout.alignment: Qt.AlignVCenter
          Layout.rightMargin: 8    // small gap before Save button
          font.bold: true          // optional; remove if you prefer regular weight
      }

      // --- New: animation that fades the toast in, waits 3s, then fades it out ---
      SequentialAnimation {
          id: saveToastAnim
          running: false

          // Show it and snap to fully visible quickly
          PropertyAction   { target: saveToast; property: "visible"; value: true }
          NumberAnimation  { target: saveToast; property: "opacity"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.InOutSine }

          // Keep it visible for 3 seconds
          PauseAnimation   { duration: 3000 }

          // Fade out, then hide to avoid tab‑stop/focus issues
          NumberAnimation  { target: saveToast; property: "opacity"; from: 1.0; to: 0.0; duration: 250; easing.type: Easing.OutSine }
          ScriptAction     { script: saveToast.visible = false }
      }

      FlatButton { id: saveButtonRef; text: qsTr('Save'); accentButton: true; onClicked: { saveData(); saveToastAnim.restart(); /*quit()*/ } }
      FlatButton { id: cancelButtonRef; text: qsTr('Close'); onClicked: quit() }
    }

  }

  // On JSON error or selected set button change, refresh active keys, scroll editor to error or set
  Connections {
    target: setButtonsFlow
    function onUiSelectedSetChanged() {
      updateKeyboardActiveNotes()
      // ERROR TAKES PRECEDENCE: do not fight the error scroll
      if (root.hasRegistryJsonError)
        return;
      if (setButtonsFlow.uiSelectedSet && setButtonsFlow.uiSelectedSet !== "__none__")
        scrollToSetInRegistry(setButtonsFlow.uiSelectedSet)
    }
  }

}
