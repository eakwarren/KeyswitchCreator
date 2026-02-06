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
import Muse.Ui 1.0
import Muse.UiComponents 1.0
import MuseScore 3.0

MuseScore {
    id: root

    categoryCode: "Keyswitch Creator"
    description: qsTr("Keyswitch Creator settings.")
    height: 810
    pluginType: "dialog"
    thumbnailName: "keyswitch_creator_settings.png"
    title: qsTr("Keyswitch Creator Settings")
    version: "0.9.7"
    width: 1385

    property bool _globUserInteracted: false
    property bool _globalsErrorRevealScheduled: false
    property var _pendingGlobalsText: undefined

    // Pending editor text (used if loadData() runs before editors exist)
    property var _pendingRegistryText: undefined

    // Interaction flags: used to avoid drawing a bogus top-of-file overlay on first open
    property bool _regUserInteracted: false
    property bool _registryErrorRevealScheduled: false
    property int currentStaffIdx: -1

    // Debug
    property bool debugEnabled: true

    // Mode selector: 0 = registry, 1 = globals
    property int editorModeIndex: 0

    // Select the style for the red highlight:
    //   "line"   -> highlight the whole row (left margin to right edge)
    //   "fromPos"-> highlight from the error character to right edge
    property string errorHighlightStyle: "line"
    property var globalSettings: ({})
    property color globalsBorderColor: themeSeparator
    property int globalsBorderWidth: 1
    property int globalsErrorLine: 0
    property int globalsErrorPos: 0
    property bool hasGlobalsJsonError: false

    // Error state flags (used to suppress auto-scrolling while JSON is invalid)
    property bool hasRegistryJsonError: false

    // Data state
    property var keyswitchSets: ({})
    property int lastAnchorIndex: -1

    // Shared left text margin to align editor with 'Assign set to...' title
    property int leftTextMargin: 12

    // Per-editor border state (each tab can reflect its own validity)
    property color registryBorderColor: themeSeparator
    property int registryBorderWidth: 1
    property int registryErrorLine: 0

    // Error character positions (used with positionToRectangle())
    property int registryErrorPos: 0
    property int selectedCountProp: 0
    property var selectedStaff: ({})
    property string setFilterText: ""
    property bool showGlobalsErrorOverlay: false

    // Error overlays (line index -> y = lineIndex * lineHeight)
    property bool showRegistryErrorOverlay: false
    property var staffToSet: ({})
    property string staffToSetMetaTagKey: "keyswitch_creator.staffToSet"

    // Theme colors (safe fallbacks)
    readonly property color themeAccent: (ui && ui.theme && ui.theme.accentColor) ? ui.theme.accentColor : "#2E7DFF"
    readonly property color themeSeparator: (ui && ui.theme && ui.theme.separatorColor) ? ui.theme.separatorColor : "#D0D0D0"
    readonly property color warningColor: (ui && ui.theme && ui.theme.warningColor) ? ui.theme.warningColor : "#E57373"

    // Heuristic for common "missing comma" faults: look for } "<nextKey>" or ] "<nextItem>"
    function _heuristicMissingCommaPos(text) {
        var s = String(text || "")
        var m = /\}\s*"/.exec(s)
        if (m)
            return m.index + m[0].indexOf('"')
        // at the offending quote
        m = /\]\s*(?=["{\[\]])/.exec(s)
        if (m)
            return m.index + 1
        // at the quote/bracket after ]
        return -1
    }

    // Return start-index of the line containing 'i'
    function _lineStart(text, i) {
        var s = String(text || "")
        var j = Math.min(Math.max(0, i), s.length)
        while (j > 0 && s.charAt(j - 1) !== '\n')
            j--
        return j
    }

    // Return index of last non-whitespace char at/left of 'i'
    function _skipWsLeft(text, i) {
        var s = String(text || "")
        var j = Math.min(Math.max(0, i), s.length - 1)
        while (j >= 0) {
            var ch = s.charAt(j)
            if (ch !== ' ' && ch !== '\t' && ch !== '\r' && ch !== '\n')
                return j
            j--
        }
        return -1
    }

    function activeMidiFromRegistryText(jsonText, setName) {
        var reg = parseRegistrySafely(jsonText)
        if (reg && reg.hasOwnProperty(setName))
            return activeMidiFromSetObj(reg[setName])

        // fallback to already-parsed in-memory registry
        if (keyswitchSets && keyswitchSets[setName])
            return activeMidiFromSetObj(keyswitchSets[setName])
        return []
    }

    function activeMidiFromSetObj(setObj) {
        if (!setObj)
            return []
        var arr = []

        if (setObj.articulationKeyMap) {
            for (var k in setObj.articulationKeyMap) {
                var p = pitchFromKsMapValue(setObj.articulationKeyMap[k])
                if (p !== null)
                    arr.push(p)
            }
        }

        if (setObj.techniqueKeyMap) {
            for (var t in setObj.techniqueKeyMap) {
                var p2 = pitchFromKsMapValue(setObj.techniqueKeyMap[t])
                if (p2 !== null)
                    arr.push(p2)
            }
        }
        return uniqMidi(arr)
    }

    function activeNamesMapFromRegistryText(jsonText, setName) {
        var reg = parseRegistrySafely(jsonText)
        if (reg && reg.hasOwnProperty(setName))
            return namesMapFromSetObj(reg[setName])

        // fallback to already-parsed in-memory registry
        if (keyswitchSets && keyswitchSets[setName])
            return namesMapFromSetObj(keyswitchSets[setName])

        return ({})
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
        // multi-select: if all selected staves share the same explicit mapping, return it
        var first = null
        for (var i = 0; i < keys.length; ++i) {
            var nm = staffToSet[keys[i]]
            if (!nm)
                nm = "__none__"
            if (first === null)
                first = nm
            else if (nm !== first)
                return "__none__"
        }
        return first
    }

    function bumpSelection() {
        selectedCountProp = Object.keys(selectedStaff).length
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

    function clearHighlight(editor) {
        if (!editor)
            return
        // clear selection and revert text color to default
        if (typeof editor.deselect === "function")
            editor.deselect()
        else
            editor.select(0, 0)
        try {
            editor.selectedTextColor = ui && ui.theme ? ui.theme.fontPrimaryColor : "#000000";
            // leave selectionColor alone; default is fine
        } catch (e) {}
    }

    function clearSelection() {
        selectedStaff = ({})
        bumpSelection()
        refreshUISelectedSet()
    }

    // Returns -1 if valid, else the best-effort character position for the error
    function computeJsonErrorPos(text) {
        try {
            JSON.parse(text)
            return -1
        } catch (e) {
            // first: try to decode whatever message the engine gave us
            var pos = jsonErrorPosFromMessage(String(e), text)
            if (typeof pos === "number" && pos >= 0 && isFinite(pos))
                return pos

            // fallback: guess a likely comma-missing site
            return _heuristicMissingCommaPos(text)
        }
    }

    function decodeHtmlEntities(s) {
        var t = String(s || "");
        // common named entities
        t = t.replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(
                    /&#39;/g, "'");

        // numeric entities (decimal & hex)
        t = t.replace(/&#([0-9]+);/g, function (_, n) {
            return String.fromCharCode(parseInt(n, 10) || 0)
        })
        t = t.replace(/&#x([0-9a-fA-F]+);/g, function (_, h) {
            return String.fromCharCode(parseInt(h, 16) || 0)
        })
        return t
    }

    function dbg(msg) {
        if (debugEnabled)
            console.log("[KS] " + msg)
    }

    function dbg2(k, v) {
        if (debugEnabled)
            console.log("[KS] " + k + ": " + v)
    }

    //--------------------------------------------------------------------------------
    // Defaults
    //--------------------------------------------------------------------------------

    function defaultGlobalSettingsObj() {
        return {
            "durationPolicy": "source",
            "formatKeyswitchStaff": "true",
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
                "articulationKeyMap": {
                    "staccato": 0,
                    "staccatissimo": 1,
                    "tenuto": 2,
                    "accent": 3,
                    "marcato": 4,
                    "sforzato": 5,
                    "loure": 6,
                    "fermata": 7,
                    "trill": 8,
                    "mordent": 9,
                    "mordent inverted": 10,
                    "turn": 11,
                    "harmonics": 12,
                    "mute": 13
                },
                "techniqueKeyMap": {
                    "normal": 14,
                    "arco": 15,
                    "pizz": 16,
                    "tremolo": 17,
                    "con sord": 18,
                    "senza sord": 19,
                    "sul pont": 20,
                    "sul tasto": 21,
                    "harmonic": 22,
                    "col legno": 23,
                    "legato": 24,
                    "spiccato": 25
                }
            },
            "Default High": {
                "articulationKeyMap": {
                    "staccato": 127,
                    "staccatissimo": 126,
                    "tenuto": 125,
                    "accent": 124,
                    "marcato": 123,
                    "sforzato": 122,
                    "loure": 121,
                    "fermata": 120,
                    "trill": 119,
                    "mordent": 118,
                    "mordent inverted": 117,
                    "turn": 116,
                    "harmonics": 115,
                    "mute": 114
                },
                "techniqueKeyMap": {
                    "normal": 113,
                    "arco": 112,
                    "pizz": 111,
                    "tremolo": 110,
                    "con sord": 109,
                    "senza sord": 108,
                    "sul pont": 107,
                    "sul tasto": 106,
                    "harmonic": 105,
                    "col legno": 104,
                    "legato": 103,
                    "spiccato": 102
                }
            }
        }
    }

    // Adjust the raw engine position to the line that *caused* the error.
    // If the engine points at the next key (e.g., missing comma), jump to the line
    // that ends with '}' or ']' right above it. Otherwise, snap to the raw line.
    function displayPosForError(text, rawPos) {
        var s = String(text || "")
        if (!(typeof rawPos === "number" && isFinite(rawPos) && rawPos >= 0))
            return 0
        if (rawPos > s.length)
            rawPos = s.length;

        // look left of the raw position for the nearest non-WS char
        var left = _skipWsLeft(s, rawPos - 1);

        // if that left char is a quote, step left again to find what precedes the quote.
        var beforeLeft = left
        if (left >= 0 && s.charAt(left) === '"')
            beforeLeft = _skipWsLeft(s, left - 1);

        // if the char immediately preceding the next token is '}' or ']',
        // the *real* fault is "missing comma after that block".
        if (beforeLeft >= 0) {
            var ch = s.charAt(beforeLeft)
            if (ch === '}' || ch === ']') {
                return _lineStart(s, beforeLeft)
                // snap to the offending block line
            }
        }

        // otherwise, just snap to the raw line start.
        return _lineStart(s, rawPos)
    }

    function formatGlobalsCompact(glob) {
        var lines = ['{']
        lines.push('    "durationPolicy":' + JSON.stringify(glob.durationPolicy || "source") + ',')
        var fks = (glob.formatKeyswitchStaff !== undefined) ? glob.formatKeyswitchStaff : "true"
        lines.push('    "formatKeyswitchStaff":' + JSON.stringify(fks) + ',')
        lines.push('    "techniqueAliases":{')
        var alias = glob.techniqueAliases || {}
        var ak = Object.keys(alias)
        for (var i = 0; i < ak.length; ++i) {
            var k = ak[i]
            lines.push('        ' + JSON.stringify(k) + ':' + JSON.stringify(alias[k]) + (i < ak.length - 1 ? ',' : ''))
        }
        lines.push('    }')
        lines.push('}')
        return lines.join('
')
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
            lines.push('    ' + JSON.stringify(name) + ':{')
            var innerLines = []
            var innerKeys = Object.keys(setObj)
            for (var j = 0; j < innerKeys.length; ++j) {
                var k = innerKeys[j]
                var v = setObj[k]
                innerLines.push('        ' + JSON.stringify(k) + ':' + JSON.stringify(v))
            }
            if (innerLines.length)
                lines.push(innerLines.join(',
'))
            lines.push('    }' + (i < setNames.length - 1 ? ',' : ''))
        }
        lines.push('}')
        return lines.join('
')
    }

    // Select and color (accent) the line containing 'pos' in 'editor', then scroll that line into view.
    // NOTE: We color the *text* (selectedTextColor) and keep selection background transparent,
    // so the accent color is applied to the glyphs themselves.
    function highlightErrorAtPos(editor, flick, pos) {
        if (!editor || !flick)
            return

        // guard against NaN/undefined/inf
        if (typeof pos !== "number" || !isFinite(pos))
            pos = 0
        var txt = String(editor.text || "")
        var len = txt.length
        pos = Math.max(0, Math.min(pos, len));

        // compute line start/end
        var start = pos
        while (start > 0 && txt.charAt(start - 1) !== '\n')
            start--
        var end = pos
        while (end < len && txt.charAt(end) !== '\n')
            end++

        try {
            // use a background highlight instead of recoloring glyphs
            editor.selectionColor = (ui && ui.theme && ui.theme.accentColor) ? ui.theme.accentColor : "#2E7DFF";

            // no-op check to avoid redundant selection churn
            var sameSel = (editor.selectionStart === start && editor.selectionEnd === end && editor.cursorPosition === start)
            if (!sameSel) {
                editor.select(start, end)
                editor.cursorPosition = start
            }
        } catch (e) {}

        // defer scrolling twice to outrun other queued scrolls.
        Qt.callLater(function () {
            var caret = editor.cursorRectangle
            var topPad = 6
            var targetY = Math.max(0, (caret ? caret.y : 0) - topPad)

            Qt.callLater(function () {
                var maxY = Math.max(0, (flick.contentHeight || 0) - (flick.height || 0))
                flick.contentY = Math.max(0, Math.min(targetY, maxY))
                try {
                    editor.forceActiveFocus()
                } catch (e) {}
            })
        })
    }

    function indexForStaff(staffIdx) {
        for (var i = 0; i < staffListModel.count; ++i) {
            var item = staffListModel.get(i)
            if (item && item.idx === staffIdx)
                return i
        }
        return 0
    }

    function isRowSelected(rowIndex) {
        if (rowIndex < 0 || rowIndex >= staffListModel.count)
            return false
        var sIdx = staffListModel.get(rowIndex).idx
        return !!selectedStaff[sIdx]
    }

    // JSON error highlighting helpers

    // Try to extract a numeric position from a JSON.parse error message.
    // Supports multiple engine variants: "at position N", "at line X column Y", "at character N".
    function jsonErrorPosFromMessage(msg, text) {
        var s = String(msg || "")
        var m;

        // "... at position 123" (with or without a ":" and extra spaces)
        m = /position\s*:?\s*([0-9]+)/i.exec(s)
        if (m && m[1])
            return parseInt(m[1], 10)

        // "... at character 123" / "... char 123"
        m = /(?:character|char)\s+([0-9]+)/i.exec(s)
        if (m && m[1])
            return parseInt(m[1], 10)

        // "... line X column Y" (0- or 1-based depends on engine; we treat column as 1-based)
        m = /line\s+([0-9]+)\s*(?:,|\s+)?column\s+([0-9]+)/i.exec(s)
        if (m && m[1] && m[2]) {
            var line = parseInt(m[1], 10);
            // 1-based in most messages
            var col = parseInt(m[2], 10);
            // also 1-based
            var t = String(text || "")
            var idx = 0, currentLine = 1;
            // convert line/column to flat index
            for (var i = 0; i < t.length && currentLine < line; i++) {
                if (t.charAt(i) === '\n') {
                    currentLine++
                    idx = i + 1
                }
            }
            return Math.max(0, Math.min(idx + Math.max(0, col - 1), t.length))
        }

        return -1
    }

    // Treat printable chars and common text-edit/navigation keys as editor-owned
    function shouldEditorAcceptKey(event) {
        // Accept any printable character (ASCII printable or any 1-char text),
        // regardless of AltGr, etc. Ctrl/Cmd combos typically yield empty text.
        var txt = (event && typeof event.text === "string") ? event.text : ""
        var isPrintable = (txt.length === 1 && txt >= " " && txt !== "\u007f")
        if (isPrintable)
            return true

        // also accept common text-edit controls with no Ctrl/Cmd/Alt shortcut intent.
        var mods = event ? event.modifiers : 0
        var ctrlOrCmd = !!(mods & (Qt.ControlModifier | Qt.MetaModifier))
        var alt = !!(mods & Qt.AltModifier)

        if (!ctrlOrCmd && !alt) {
            switch (event.key) {
            case Qt.Key_Space:
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Delete:
            case Qt.Key_Backspace:
            case Qt.Key_Left:
            case Qt.Key_Right:
            case Qt.Key_Up:
            case Qt.Key_Down:
                return true
            }
        }
        return false
    }

    // Count '\n' before pos to get a 0-based line index
    function lineIndexForPos(text, pos) {
        var s = String(text || "")
        if (typeof pos !== "number" || !isFinite(pos) || pos < 0)
            pos = 0
        if (pos > s.length)
            pos = s.length
        var count = 0
        for (var i = 0; i < pos; ++i)
            if (s.charAt(i) === '\n')
                count++
        return count
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
            if (jsonArea)
                jsonArea.text = rawSets
            else
                _pendingRegistryText = rawSets
        } else {
            keyswitchSets = defaultRegistryObj()
            var defRegText = formatRegistryCompact(keyswitchSets)
            if (jsonArea)
                jsonArea.text = defRegText
            else
                _pendingRegistryText = defRegText
        }

        if (rawGlobals.length > 0) {
            if (globalsArea)
                globalsArea.text = rawGlobals
            else
                _pendingGlobalsText = rawGlobals
        } else {
            globalSettings = defaultGlobalSettingsObj()
            var defGlobText = formatGlobalsCompact(globalSettings)
            if (globalsArea)
                globalsArea.text = defGlobText
            else
                _pendingGlobalsText = defGlobText
        }

        // decide the error state for Globals NOW (before any later UI scrolls)
        var _tmpParsedGlobals = null
        try {
            _tmpParsedGlobals = JSON.parse(globalsArea.text)
        } catch (e) {
            _tmpParsedGlobals = null
        }
        root.hasGlobalsJsonError = (_tmpParsedGlobals === null)
        setGlobalsBorder(!_tmpParsedGlobals ? false : true);

        // parse in-memory objects (never clobber the editor if parse fails)
        var parsedSets = parseRegistrySafely(jsonArea.text)
        root.hasRegistryJsonError = !parsedSets

        if (parsedSets) {
            keyswitchSets = parsedSets
            setRegistryBorder(true)
        } else {
            keyswitchSets = defaultRegistryObj()
            setRegistryBorder(false)
        }

        // if globals JSON invalid on open, schedule a "late" error reveal
        if (root.hasGlobalsJsonError) {
            // scheduleGlobalsErrorReveal();
        }

        // quick visibility check in the console
        dbg("[KS] staffListModel.count =", staffListModel.count);

        // staffToSet (safe parse)
        try {
            staffToSet = (ksPrefs.staffToSetJSON && ksPrefs.staffToSetJSON.length) ? JSON.parse(ksPrefs.staffToSetJSON) : {}
        } catch (e2) {
            staffToSet = {}
        }

        // rebuild lists (from the in-memory object, not the text)
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
                    staffListModel.append({
                                              idx: staffIdx,
                                              name: display
                                          })
                }
            }
        }

        var initIndex = indexForStaff(0)
        selectSingle(initIndex)

        setsListModel.clear()
        for (var k in keyswitchSets)
            setsListModel.append({
                                     name: k
                                 })

        setFilterText = ""
        rebuildFilteredSets()

        refreshUISelectedSet()
        updateKeyboardActiveNotes()

        validateRegistryText()
        validateGlobalsText()
        loadStaffAssignmentsFromScore();

        // quick visibility check in the console
        dbg("[KS] staffListModel.count =", staffListModel.count)
        dbg("[KS] setsListModel.count  =", setsListModel.count)
    }

    function nameForPart(p, tick) {
        if (!p)
            return ''
        var nm = (p.longName && p.longName.length) ? p.longName : (p.partName && p.partName.length) ? p.partName : (p.shortName
                                                                                                                    && p.shortName.length)
                                                                                                      ? p.shortName : ''
        if (!nm && p.instrumentAtTick) {
            var inst = p.instrumentAtTick(tick || 0)
            if (inst && inst.longName && inst.longName.length)
                nm = inst.longName
        }
        return normalizeUiText(nm)
    }

    // Build a midi->names map for tooltips based on the active set.
    // Supports values like 26 or "26|127" (we only care about pitch).
    function namesMapFromSetObj(setObj) {
        var map = ({})
        if (!setObj)
            return map

        function addName(pitch, name) {
            if (pitch === null || pitch === undefined)
                return
            pitch = parseInt(pitch, 10)
            if (isNaN(pitch) || pitch < 0 || pitch > 127)
                return
            if (!map[pitch])
                map[pitch] = []
            // avoid duplicates if both technique/articulation map share names (rare, but safe)
            if (map[pitch].indexOf(name) === -1)
                map[pitch].push(name)
        }

        if (setObj.articulationKeyMap) {
            for (var k in setObj.articulationKeyMap) {
                var p = pitchFromKsMapValue(setObj.articulationKeyMap[k])
                if (p !== null)
                    addName(p, k)
            }
        }

        if (setObj.techniqueKeyMap) {
            for (var t in setObj.techniqueKeyMap) {
                var p2 = pitchFromKsMapValue(setObj.techniqueKeyMap[t])
                if (p2 !== null)
                    addName(p2, t)
            }
        }

        return map
    }

    function activeVelocityMapFromRegistryText(jsonText, setName) {
        var reg = parseRegistrySafely(jsonText)
        if (reg && reg.hasOwnProperty(setName))
            return velocitiesMapFromSetObj(reg[setName])
        // fallback to already-parsed in-memory registry
        if (keyswitchSets && keyswitchSets[setName])
            return velocitiesMapFromSetObj(keyswitchSets[setName])
        return ({})
    }

    // Build a midi -> velocity map for the active set.
    // If multiple entries map to the same MIDI note with different velocities,
    // we keep the first discovered velocity (consistent & deterministic).
    function velocitiesMapFromSetObj(setObj) {
        var map = ({})
        if (!setObj)
            return map

        function consider(v) {
            var p = pitchFromKsMapValue(v)
            var vel = velocityFromKsMapValue(v)
            if (p === null || vel === null)
                return
            p = parseInt(p, 10)
            vel = parseInt(vel, 10)
            if (isNaN(p) || isNaN(vel) || p < 0 || p > 127 || vel < 0 || vel > 127)
                return
            if (map[p] === undefined)
                map[p] = vel
        }

        if (setObj.articulationKeyMap) {
            for (var k in setObj.articulationKeyMap)
                consider(setObj.articulationKeyMap[k])
        }
        if (setObj.techniqueKeyMap) {
            for (var t in setObj.techniqueKeyMap)
                consider(setObj.techniqueKeyMap[t])
        }
        return map
    }

    function normalizeUiText(s) {
        return cleanName(decodeHtmlEntities(stripHtmlTags(s)))
    }

    function parseRegistrySafely(jsonText) {
        try {
            return JSON.parse(jsonText)
        } catch (e) {
            return null
        }
    }

    function partForStaff(staffIdx) {
        if (!curScore || !curScore.parts)
            return null
        var t = staffBaseTrack(staffIdx)
        for (var i = 0; i < curScore.parts.length; ++i) {
            var p = curScore.parts[i]
            if (t >= p.startTrack && t < p.endTrack)
                return p
        }
        return null
    }

    //--------------------------------------------------------------------------------
    // Active set note utilities
    //--------------------------------------------------------------------------------

    // Registry values may now be either:
    //   26       (number)
    //   "26|127"  (string: pitch|velocity)
    //   We only care about pitch for keyboard highlighting.
    function pitchFromKsMapValue(v) {
        if (typeof v === "number")
            return parseInt(v, 10)
        if (typeof v === "string") {
            var s = v.trim();
            // Support "26|127" and "26\n127"
            var sep = s.indexOf('|')
            if (sep >= 0)
                s = s.substring(0, sep)
            var nl = s.indexOf("\n")
            if (nl >= 0)
                s = s.substring(0, nl)
            var n = parseInt(s, 10)
            return isNaN(n) ? null : n
        }
        if (v && typeof v === "object") {
            // not advertised yet, but harmless if someone uses it
            if (v.pitch !== undefined) {
                var p = parseInt(v.pitch, 10)
                return isNaN(p) ? null : p
            }
            if (v.note !== undefined) {
                var p2 = parseInt(v.note, 10)
                return isNaN(p2) ? null : p2
            }
            if (Array.isArray(v) && v.length > 0) {
                var p3 = parseInt(v[0], 10)
                return isNaN(p3) ? null : p3
            }
        }
        return null
    }

    // Extract velocity from a KS value.
    // Supports:
    //   number        -> null (no velocity specified)
    //   "26|127"      -> 127
    //   "26\n127"     -> 127
    //   {velocity:..} -> that number
    //   {vel:..}      -> that number
    //   [26,127]      -> 127
    function velocityFromKsMapValue(v) {
        if (typeof v === "number")
            return null
        if (typeof v === "string") {
            var s = v.trim();
            // Accept "26|127" and "26\n127"
            var pos = s.indexOf('|')
            if (pos < 0)
                pos = s.indexOf("\n")
            if (pos >= 0) {
                var right = s.substring(pos + 1).trim()
                var n = parseInt(right, 10)
                return isNaN(n) ? null : Math.max(0, Math.min(127, n))
            }
            return null
        }
        if (v && typeof v === "object") {
            if (v.velocity !== undefined) {
                var a = parseInt(v.velocity, 10)
                return isNaN(a) ? null : Math.max(0, Math.min(127, a))
            }
            if (v.vel !== undefined) {
                var b = parseInt(v.vel, 10)
                return isNaN(b) ? null : Math.max(0, Math.min(127, b))
            }
            if (Array.isArray(v) && v.length > 1) {
                var c = parseInt(v[1], 10)
                return isNaN(c) ? null : Math.max(0, Math.min(127, c))
            }
        }
        return null
    }

    // Rebuild filteredSetsModel from setsListModel using setFilterText (case-insensitive)
    function rebuildFilteredSets() {
        filteredSetsModel.clear()
        var q = (setFilterText || "").trim().toLowerCase();

        // show all if no query
        if (q.length === 0) {
            for (var i = 0; i < setsListModel.count; ++i) {
                var nm = setsListModel.get(i).name
                filteredSetsModel.append({
                                             name: nm
                                         })
            }
            return
        }

        for (var j = 0; j < setsListModel.count; ++j) {
            var name = (setsListModel.get(j).name || "")
            if (name.toLowerCase().indexOf(q) !== -1) {
                filteredSetsModel.append({
                                             name: name
                                         })
            }
        }
    }

    function refreshUISelectedSet() {
        if (setButtonsFlow)
            setButtonsFlow.uiSelectedSet = activeSetForCurrentSelection()
    }

    function saveData() {
        // persist raw strings
        ksPrefs.setsJSON = jsonArea.text
        ksPrefs.globalJSON = globalsArea.text
        if (ksPrefs.sync) {
            try {
                ksPrefs.sync()
            } catch (e) {}
        } // flush if available

        // try to parse the registry text so we can refresh UI immediately
        var parsed = parseRegistrySafely(jsonArea.text);
        // returns null on error
        if (parsed) {
            // update in-memory registry
            keyswitchSets = parsed;

            // rebuild the list used by the buttons
            var prevSelected = (setButtonsFlow && setButtonsFlow.uiSelectedSet) ? setButtonsFlow.uiSelectedSet : "__none__"
            setsListModel.clear()
            for (var k in keyswitchSets) {
                if (keyswitchSets.hasOwnProperty(k))
                    setsListModel.append({
                                             name: k
                                         })
            }

            // rebuild the filtered view (respect current filter text)
            rebuildFilteredSets();

            // restore a reasonable selected set for the buttons row
            // keep previous if it still exists; else derive from current selection
            if (!prevSelected || !keyswitchSets.hasOwnProperty(prevSelected)) {
                setButtonsFlow.uiSelectedSet = activeSetForCurrentSelection()
            } else {
                setButtonsFlow.uiSelectedSet = prevSelected
            }
            // refresh keyboard highlights and border
            updateKeyboardActiveNotes()
            setRegistryBorder(true);

            // ensure the editor shows the active set's JSON after saving
            if (!root.hasRegistryJsonError && setButtonsFlow.uiSelectedSet && setButtonsFlow.uiSelectedSet !== "__none__")
                scrollToSetInRegistry(setButtonsFlow.uiSelectedSet)
        } else {
            // still saved the raw text, but it's not valid JSON yet -> keep warning
            setRegistryBorder(false)
        }
    }

    // Write current staffToSet mapping into this score's Project Properties meta tag
    function writeStaffAssignmentsToScore() {
        if (!curScore || !curScore.setMetaTag)
            return false
        curScore.startCmd()
        try {
            curScore.setMetaTag(staffToSetMetaTagKey, JSON.stringify(staffToSet))
            curScore.endCmd()
            dbg("[KS] wrote staffToSet to score meta tag")
            return true
        } catch (e) {
            try {
                curScore.endCmd(true)
            } catch (e2) {}
            dbg("[KS] failed to write staffToSet to score meta tag: " + String(e))
            return false
        }
    }

    // Load staffToSet mapping from this score's Project Properties (if present)
    function loadStaffAssignmentsFromScore() {
        if (!curScore || !curScore.metaTag)
            return false
        try {
            var raw = curScore.metaTag(staffToSetMetaTagKey)
            if (!raw || !raw.length)
                return false
            var parsed = JSON.parse(raw)
            if (!parsed || typeof parsed !== "object")
                return false
            staffToSet = parsed
            refreshUISelectedSet()
            updateKeyboardActiveNotes()
            dbg("[KS] loaded staffToSet from score meta tag")
            return true
        } catch (e) {
            dbg("[KS] failed to load staffToSet from score meta tag: " + String(e))
            return false
        }
    }

    function scheduleGlobalsErrorReveal() {
        if (_globalsErrorRevealScheduled)
            return
        _globalsErrorRevealScheduled = true
        Qt.callLater(function () {
            Qt.callLater(function () {
                _globalsErrorRevealScheduled = false
                if (!root.hasGlobalsJsonError)
                    return
                var pos = computeJsonErrorPos(globalsArea.text)
            })
        })
    }

    // Defer highlight/scroll twice so it runs AFTER any queued palette/set scrolls
    function scheduleRegistryErrorReveal() {
        if (_registryErrorRevealScheduled)
            return
        _registryErrorRevealScheduled = true
        Qt.callLater(function () {
            Qt.callLater(function () {
                _registryErrorRevealScheduled = false
                if (!root.hasRegistryJsonError)
                    return
                var pos = computeJsonErrorPos(jsonArea.text)
            })
        })
    }

    // Scroll a Flickable so that lineIndex is near the top (uses FontMetrics height)
    function scrollToLine(flick, lineIndex, lineHeight) {
        if (!flick || !isFinite(lineIndex) || !isFinite(lineHeight))
            return
        var topPad = 6
        var targetY = Math.max(0, lineIndex * lineHeight - topPad)
        Qt.callLater(function () {
            var maxY = Math.max(0, (flick.contentHeight || 0) - (flick.height || 0))
            flick.contentY = Math.max(0, Math.min(targetY, maxY))
        })
    }

    function scrollToPosByCaret(editor, flick, pos, topPad) {
        if (!editor || !flick)
            return
        var textLen = (editor.length !== undefined ? editor.length : (editor.text || "").length)
        var p = Math.max(0, Math.min(pos, textLen))
        editor.cursorPosition = p
        // put caret at error
        Qt.callLater(function () { // wait for cursorRectangle
            var caret = editor.cursorRectangle
            if (!caret)
                return
            var pad = (typeof topPad === "number") ? topPad : 6
            var targetY = Math.max(0, caret.y - pad)
            Qt.callLater(function () { // ensure flick metrics are final
                var maxY = Math.max(0, (flick.contentHeight || 0) - (flick.height || 0))
                flick.contentY = Math.max(0, Math.min(targetY, maxY))
            })
        })
    }

    function scrollToSetInRegistry(setName, opts) {
        // opts: { focus: boolean } — default false (don’t steal focus on passive updates)
        var focusEditor = !!(opts && opts.focus)
        if (root.hasRegistryJsonError)
            return
        // cancel any queued "scroll to set" while an error is present
        if (!setName || setName === "__none__")
            return
        if (editorModeIndex !== 0)
            return
        var txt = jsonArea.text || ""

        // prefer compact formatter pattern: "Name":{
        var needle = JSON.stringify(setName) + ":{"
        var pos = txt.indexOf(needle);

        // fallback: just the quoted name (if user reformatted)
        if (pos < 0) {
            var q = JSON.stringify(setName)
            pos = txt.indexOf(q)
            if (pos < 0)
                return
        }

        // snap caret to start of containing line – stable anchor
        var lineStart = pos
        while (lineStart > 0) {
            var ch = txt.charAt(lineStart - 1)
            if (ch === '\n' || ch === '\r')
                break
            lineStart--
        }
        jsonArea.cursorPosition = lineStart;

        // 1st defer: let cursorRectangle update to new caret position
        Qt.callLater(function () {
            var caretRect
            try {
                caretRect = jsonArea.cursorRectangle
            } catch (e) {
                caretRect = null
            }
            if (!caretRect)
                return
            var topPad = 6
            var targetY = Math.max(0, caretRect.y - topPad);

            // 2nd defer: ensure Flickable metrics (contentHeight/height) are final
            Qt.callLater(function () {
                var flk = registryFlick
                if (!flk)
                    return
                var maxY = Math.max(0, (flk.contentHeight || 0) - (flk.height || 0))
                var clamped = Math.max(0, Math.min(targetY, maxY))

                flk.contentY = clamped
                if (focusEditor && !(staffList && (staffList.activeFocus || stavesScroll.activeFocus))) {
                    jsonArea.forceActiveFocus()
                    try {
                        jsonArea.cursorVisible = true
                    } catch (e) {}
                }
            })
        })
    }

    function selectAll() {
        clearSelection()
        for (var r = 0; r < staffListModel.count; ++r)
            setRowSelected(r, true)
        if (staffList.currentIndex >= 0)
            lastAnchorIndex = staffList.currentIndex
        refreshUISelectedSet()
    }

    function selectRange(rowIndex) {
        if (lastAnchorIndex < 0) {
            selectSingle(rowIndex)
            return
        }
        var a = Math.min(lastAnchorIndex, rowIndex)
        var b = Math.max(lastAnchorIndex, rowIndex)
        clearSelection()
        for (var r = a; r <= b; ++r)
            setRowSelected(r, true)
        currentStaffIdx = staffListModel.get(rowIndex).idx
        refreshUISelectedSet()
    }

    function selectSingle(rowIndex) {
        clearSelection()
        setRowSelected(rowIndex, true)
        lastAnchorIndex = rowIndex
        currentStaffIdx = staffListModel.get(rowIndex).idx
        refreshUISelectedSet()
    }

    function setGlobalsBorder(valid) {
        root.globalsBorderColor = valid ? themeSeparator : warningColor
    }

    function setRegistryBorder(valid) {
        root.registryBorderColor = valid ? themeSeparator : warningColor
    }

    function setRowSelected(rowIndex, on) {
        if (rowIndex < 0 || rowIndex >= staffListModel.count)
            return
        var sIdx = staffListModel.get(rowIndex).idx
        var ns = Object.assign({}, selectedStaff)
        if (on)
            ns[sIdx] = true
        else
            delete ns[sIdx]
        selectedStaff = ns
        bumpSelection()
        refreshUISelectedSet()
    }

    function staffBaseTrack(staffIdx) {
        return staffIdx * 4
    }

    function staffNameByIdx(staffIdx) {
        for (var i = 0; i < staffListModel.count; ++i) {
            var item = staffListModel.get(i)
            if (item && item.idx === staffIdx)
                return cleanName(item.name)
        }
        var base = nameForPart(partForStaff(staffIdx), 0) || 'Unknown instrument'
        return cleanName(base + ': ' + qsTr('Staff %1 (%2)').arg(1).arg('Treble'))
    }

    // Decode/strip for UI-safe display of part/staff names
    function stripHtmlTags(s) {
        return String(s || "").replace(/<[^>]*>/g, "")
    }

    function toggleRow(rowIndex) {
        var wasSelected = isRowSelected(rowIndex)
        setRowSelected(rowIndex, !wasSelected)
        lastAnchorIndex = rowIndex
        currentStaffIdx = staffListModel.get(rowIndex).idx
        if (selectedCountProp === 0)
            setRowSelected(rowIndex, true)
        refreshUISelectedSet()
    }

    function uniqMidi(list) {
        var seen = {}, out = []
        for (var i = 0; i < list.length; ++i) {
            var v = parseInt(list[i], 10)
            if (isNaN(v))
                continue
            if (v >= 0 && v <= 127 && !seen[v]) {
                seen[v] = true
                out.push(v)
            }
        }
        return out
    }

    function updateKeyboardActiveNotes() {
        // prefer the explicit UI-selected set if present, otherwise derive
        var setName = (setButtonsFlow && setButtonsFlow.uiSelectedSet) ? setButtonsFlow.uiSelectedSet : activeSetForCurrentSelection();

        // no explicit set selected/assigned → clear keyboard highlights
        if (!setName || setName === "__none__") {
            if (kbroot) {
                kbroot.activeNotes = []
                kbroot.noteLabelsMap = ({})
                kbroot.noteVelocityMap = ({})
            }
            return
        }

        if (kbroot) {
            kbroot.activeNotes = activeMidiFromRegistryText(jsonArea.text, setName)
            kbroot.noteLabelsMap = activeNamesMapFromRegistryText(jsonArea.text, setName)
            kbroot.noteVelocityMap = activeVelocityMapFromRegistryText(jsonArea.text, setName)
        }
    }

    function validateGlobalsText() {
        var ok = true, raw = -1, pos = -1
        try {
            JSON.parse(globalsArea.text)
        } catch (e) {
            ok = false
            raw = computeJsonErrorPos(globalsArea.text)
            // -1 if unknown
            var candidate = (raw >= 0) ? displayPosForError(globalsArea.text, raw) : -1;
            // if parser gave us nothing usable (<=0) and user hasn't interacted yet,
            // don't draw a misleading overlay on row 1.
            if (candidate <= 0 && !root._globUserInteracted) {
                root.showGlobalsErrorOverlay = false
                setGlobalsBorder(false)
                root.hasGlobalsJsonError = true
                return
            }
            // otherwise pick parser's position if >0, else use caret (user moved/typed)
            pos = (candidate > 0) ? candidate : globalsArea.cursorPosition

            root.globalsErrorPos = Math.max(0, Math.min(pos, (globalsArea.text || "").length))
            root.globalsErrorLine = lineIndexForPos(globalsArea.text, root.globalsErrorPos)
            dbg("[KS] globals JSON error:", String(e), "rawPos=", raw, "candidate=", candidate, "chosen=", root.globalsErrorPos)
        }
        setGlobalsBorder(ok)
        root.hasGlobalsJsonError = !ok
        root.showGlobalsErrorOverlay = !ok
    }

    function validateRegistryText() {
        var ok = true, raw = -1, pos = -1
        try {
            JSON.parse(jsonArea.text)
        } catch (e) {
            ok = false
            raw = computeJsonErrorPos(jsonArea.text)
            // -1 if unknown
            var candidate = (raw >= 0) ? displayPosForError(jsonArea.text, raw) : -1;
            // if parser gave us nothing usable (<=0) and user hasn't interacted yet,
            // don't draw a misleading overlay on row 1.
            if (candidate <= 0 && !root._regUserInteracted) {
                root.showRegistryErrorOverlay = false
                setRegistryBorder(false)
                root.hasRegistryJsonError = true
                return
            }
            // otherwise pick parser's position if >0, else use caret (user moved/typed)
            pos = (candidate > 0) ? candidate : jsonArea.cursorPosition

            root.registryErrorPos = Math.max(0, Math.min(pos, (jsonArea.text || "").length))
            root.registryErrorLine = lineIndexForPos(jsonArea.text, root.registryErrorPos)
            dbg("[KS] registry JSON error:", String(e), "rawPos=", raw, "candidate=", candidate, "chosen=", root.registryErrorPos)
        }
        setRegistryBorder(ok)
        root.hasRegistryJsonError = !ok
        root.showRegistryErrorOverlay = !ok
    }

    onRun: {
        // defer until the next frame to ensure child items (globalsArea/jsonArea) exist
        Qt.callLater(function () {
            loadData()
            // ensure initial focus goes to staves list for keyboard shortcuts
            staffList.forceActiveFocus()
            refreshUISelectedSet()
        })
    }
    onSetFilterTextChanged: rebuildFilteredSets()

    Settings {
        id: ksPrefs

        property string globalJSON: ""
        property string setsJSON: ""
        property string staffToSetJSON: ""

        category: "Keyswitch Creator"
    }

    // { idx, name }
    ListModel {
        id: staffListModel
    }

    // { name }
    ListModel {
        id: setsListModel
    }

    // filtered view for "Assign set to..." buttons
    ListModel {
        id: filteredSetsModel
    }

    //--------------------------------------------------------------------------------
    // UI
    //--------------------------------------------------------------------------------
    ColumnLayout {

        // root-level safety net for staff-list shortcuts
        Keys.priority: Keys.BeforeItem
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Keys.onPressed: function (event) {
            // do not interfere with text editors or the set filter
            if ((jsonArea && jsonArea.activeFocus) || (globalsArea && globalsArea.activeFocus) || (setSearchField
                                                                                                   && setSearchField.activeFocus)) {
                // leave to the child control
                return
            }

            // only act when the staves panel is the focus target
            var stavesFocused = (staffList && staffList.activeFocus) || (stavesScroll && stavesScroll.activeFocus)
            if (!stavesFocused)
                return
            var shift = (event.modifiers & Qt.ShiftModifier)
            var ctrlOrCmd = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier));

            // Ctrl/Cmd + A  → select all staves
            if (ctrlOrCmd && event.key === Qt.Key_A) {
                selectAll()
                if (staffList.currentIndex < 0 && staffListModel.count > 0)
                    staffList.currentIndex = 0
                event.accepted = true

                return
            }

            // Shift + Up/Down → extend selection from current anchor
            if (shift && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                var idx = staffList.currentIndex >= 0 ? staffList.currentIndex : 0
                if (event.key === Qt.Key_Up)
                    idx = Math.max(0, idx - 1)
                if (event.key === Qt.Key_Down)
                    idx = Math.min(staffListModel.count - 1, idx + 1)
                selectRange(idx)
                staffList.currentIndex = idx
                event.accepted = true

                return
            }
        }

        // Application-level shortcuts (fallbacks across focus transitions)
        Shortcut {
            id: scSelectAllStaves

            context: Qt.WindowShortcut
            enabled: (staffListModel.count > 0) && !(jsonArea && jsonArea.activeFocus) && !(globalsArea && globalsArea.activeFocus) && !(
                         setSearchField && setSearchField.activeFocus)
            // keep StandardKey for ⌘A on macOS; add "Ctrl+A" as an alternative
            sequences: ["Meta+A", "Ctrl+A"]

            onActivated: {
                dbg("[KS] Shortcut fired: SelectAll (Meta/Ctrl+A)")
                selectAll()
                if (staffList.currentIndex < 0 && staffListModel.count > 0)
                    staffList.currentIndex = 0
            }
        }

        // Shift+Up and Shift+Down as a safety net:
        // Only enable these when the staves list does not have focus.
        // When the list has focus, its own Keys.onPressed already handles Shift+Arrows.
        // This prevents double-handling if both fired.
        Shortcut {
            id: scShiftUp

            context: Qt.WindowShortcut
            enabled: (staffListModel.count > 0) && !(jsonArea && jsonArea.activeFocus) && !(globalsArea && globalsArea.activeFocus) && !(
                         setSearchField && setSearchField.activeFocus)
            sequences: ["Shift+Up"]

            onActivated: {
                var cur = (staffList.currentIndex >= 0) ? staffList.currentIndex : 0
                var next = Math.max(0, cur - 1)
                if (root.lastAnchorIndex < 0)
                    root.lastAnchorIndex = cur
                // establish anchor immediately
                selectRange(next)
                staffList.currentIndex = next
            }
        }
        Shortcut {
            id: scShiftDown

            context: Qt.WindowShortcut
            enabled: (staffListModel.count > 0) && !(jsonArea && jsonArea.activeFocus) && !(globalsArea && globalsArea.activeFocus) && !(
                         setSearchField && setSearchField.activeFocus)
            sequences: ["Shift+Down"]

            onActivated: {
                var cur = (staffList.currentIndex >= 0) ? staffList.currentIndex : 0
                var last = Math.max(0, staffListModel.count - 1)
                var next = Math.min(last, cur + 1)
                if (root.lastAnchorIndex < 0)
                    root.lastAnchorIndex = cur
                // establish anchor immediately
                selectRange(next)
                staffList.currentIndex = next
            }
        }
        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 12

            // Left: Staves list
            GroupBox {
                Layout.fillHeight: true
                // title: qsTr('Staves')
                Layout.preferredWidth: 216

                background: Rectangle {
                    color: ui.theme.textFieldColor
                }

                ScrollView {
                    id: stavesScroll

                    // forward any key events to the staves list (ensures shortcuts work if ScrollView gets focus)
                    Keys.forwardTo: [staffList]
                    anchors.fill: parent
                    focus: true

                    ListView {
                        id: staffList

                        activeFocusOnTab: true
                        clip: true
                        focus: true
                        model: staffListModel
                        spacing: 2

                        delegate: ItemDelegate {
                            id: rowDelegate

                            width: ListView.view.width

                            background: Rectangle {
                                anchors.fill: parent
                                color: isRowSelected(index) ? themeAccent : "transparent"
                                opacity: isRowSelected(index) ? 0.65 : 1.0
                                radius: 6
                            }

                            // render the row label as literal text (no mnemonics / HTML)
                            contentItem: Text {
                                color: ui.theme.fontPrimaryColor
                                elide: Text.ElideRight
                                text: cleanName(model.name)
                                textFormat: Text.PlainText
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                acceptedButtons: Qt.LeftButton
                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: function (mouse) {
                                    var idx = index
                                    var ctrlOrCmd = (mouse.modifiers & Qt.ControlModifier) || (mouse.modifiers & Qt.MetaModifier)
                                    var isShift = (mouse.modifiers & Qt.ShiftModifier)
                                    if (isShift)
                                        selectRange(idx)
                                    else if (ctrlOrCmd)
                                        toggleRow(idx)
                                    else
                                        selectSingle(idx)
                                    staffList.currentIndex = idx
                                    setSearchField.focus = false;

                                    // ensure the staves list has active focus
                                    staffList.forceActiveFocus()
                                }
                            }
                        }

                        // Final fallback: handle ⌘/Ctrl + A right here if Shortcut didn't fire
                        Keys.onPressed: function (event) {
                            const isCmd = !!(event.modifiers & Qt.MetaModifier);
                            // ⌘ on macOS
                            const isCtrl = !!(event.modifiers & Qt.ControlModifier);
                            // sometimes delivered instead
                            const isShift = !!(event.modifiers & Qt.ShiftModifier)
                            if ((isCmd || isCtrl) && event.key === Qt.Key_A) {
                                dbg("[KS] Keys.onPressed fallback: SelectAll")
                                selectAll()
                                if (staffList.currentIndex < 0 && staffListModel.count > 0)
                                    staffList.currentIndex = 0
                                event.accepted = true

                                return
                            }
                            if (event.key === Qt.Key_Up) {
                                var idx = Math.max(0, staffList.currentIndex - 1)
                                if (isShift)
                                    selectRange(idx)
                                else
                                    selectSingle(idx)
                                staffList.currentIndex = idx
                                event.accepted = true
                                return
                            }
                            if (event.key === Qt.Key_Down) {
                                var idx2 = Math.min(staffListModel.count - 1, staffList.currentIndex + 1)
                                if (isShift)
                                    selectRange(idx2)
                                else
                                    selectSingle(idx2)
                                staffList.currentIndex = idx2
                                event.accepted = true
                                return
                            }
                        }

                        // Grab these chords *before* app/global shortcuts see them
                        // Accept only the chords we want to force into the normal KeyPress path.
                        // Shift+Up / Shift+Down: ensure range-select isn't stolen by ScrollView/Flickable
                        // Cmd/Ctrl + A         : ensure the list handles Select All locally
                        // Do NOT accept when an editor/search field has focus (so those get ⌘A as text select).
                        Keys.onShortcutOverride: function (event) {
                            dbg("[KS] override:", event.key, "mods:", event.modifiers, "accepted?", event.accepted)

                            if ((jsonArea && jsonArea.activeFocus) || (globalsArea && globalsArea.activeFocus) || (setSearchField
                                                                                                                   && setSearchField.activeFocus)) {
                                return
                            }
                            const isShift = !!(event.modifiers & Qt.ShiftModifier)
                            const isCmd = !!(event.modifiers & Qt.MetaModifier);
                            // ⌘ (sometimes not set)
                            const isCtrl = !!(event.modifiers & Qt.ControlModifier);
                            // in log: 67108864
                            const isA = (event.key === Qt.Key_A)
                            const shUp = isShift && (event.key === Qt.Key_Up)
                            const shDown = isShift && (event.key === Qt.Key_Down);

                            // accept the chords we want to handle as normal key presses on the list.
                            if (shUp || shDown || (isA && (isCmd || isCtrl))) {
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            // Right: Assign set to ...
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: 6

                // Hidden icon-size probe using a standard icon button to get canonical metrics
                FlatButton {
                    id: _iconProbe

                    icon: IconCode.SAVE
                    visible: false
                }

                // Piano keyboard
                Item {
                    id: kbroot

                    property color accent: themeAccent // use app/theme accent
                    property var activeMap: ({}) // { 96:true, 97:true, ... }

                    // active highlighting
                    property var activeNotes: [] // [96,97,98]
                    property real activeOverlayOpacityBlack: 0.80
                    property real activeOverlayOpacityWhite: 0.65
                    readonly property color blackBorder: "#000000"
                    readonly property color blackColor: "#111111"
                    readonly property real blackH: Math.round(whiteH * 0.65)
                    readonly property real blackW: Math.round(whiteW * 0.70)
                    readonly property int endMidi: startMidi + keyCount - 1
                    property int keyCount: 128 // total keys to draw
                    property bool middleCIsC4: true
                    // map midi -> ["pizz", "staccato", ...] for tooltip line 2
                    property var noteLabelsMap: ({}) // { 26:["pizz"], 25:["staccato"], ... }
                    property var noteVelocityMap: ({}) // { 26:127, 25:64, ... }

                    property int startMidi: 0 // inclusive
                    property string view: "small" // "small" | "medium" | "large"
                    readonly property color whiteBorder: "#202020"
                    readonly property color whiteColor: "#FAFAFA"
                    readonly property real whiteH: (view === "small" ? 65 : view === "medium" ? 70 : 80)

                    // Size presets to mimic MuseScore's compact look
                    readonly property real whiteW: (view === "small" ? 15 : view === "medium" ? 20 : 22)

                    // Offset for placing black keys centered above the gap between whites.
                    function blackXFor(n) {
                        var pc = n % 12
                        // for a black key, it sits between two white indices; compute base white index
                        // pattern within an octave: W W B W W B W B W W B W (W=white slot)
                        // anchor each black key relative to the white on its left.
                        var leftWhiteMidi = n - 1
                        while (leftWhiteMidi >= kbroot.startMidi && isBlack(leftWhiteMidi % 12)) {
                            leftWhiteMidi--
                        }
                        var leftIdx = whiteIndexFor(leftWhiteMidi);
                        // position: left white x + whiteW - (blackW/2)
                        return leftIdx * whiteW + (whiteW - blackW / 2)
                    }

                    // active highlighting
                    function isBlack(pc) {
                        // C=0, C#=1, D=2, D#=3, E=4, F=5, F#=6, G=7, G#=8, A=9, A#=10, B=11
                        return (pc === 1 || pc === 3 || pc === 6 || pc === 8 || pc === 10)
                    }

                    function noteName(m) {
                        var names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
                        var pc = ((m % 12) + 12) % 12
                        return names[pc] + octaveFor(m)
                    }

                    // Helpers
                    // Tooltip helpers (pitch name, octave, tooltip text)
                    function octaveFor(m) {
                        // MIDI 60 => 4 if C4 standard (subtract 1)
                        // MIDI 60 => 3 if C3 standard (subtract 2)
                        return Math.floor(m / 12) - (kbroot.middleCIsC4 ? 1 : 2)
                    }

                    function tooltipText(m) {
                        // Line 1: MIDI 0 (C-1) or MIDI 0|vel (C-1)
                        var vel = (noteVelocityMap && noteVelocityMap[m] !== undefined) ? noteVelocityMap[m] : null
                        var line1 = vel === null ? ("MIDI " + m + " (" + noteName(m) + ")") : ("MIDI " + m + "|" + vel + " (" + noteName(m)
                                                                                               + ")");

                        // Line 2: keyswitch names, if any
                        var labels = (noteLabelsMap && noteLabelsMap[m]) ? noteLabelsMap[m] : null
                        if (labels && labels.length) {
                            return line1 + "\n" + labels.join(", ")
                        }
                        return line1
                    }

                    function whiteIndexFor(n) {
                        // count white keys up to midi n
                        var count = 0
                        for (var i = kbroot.startMidi; i <= n; ++i) {
                            var pc = i % 12
                            if (!isBlack(pc))
                                count++
                        }
                        return count - 1
                        // zero-based index of this white key (if white)
                    }

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

                    onActiveNotesChanged: {
                        var m = {}
                        for (var i = 0; i < activeNotes.length; ++i)
                            m[activeNotes[i]] = true
                        activeMap = m
                    }

                    // White keys (draw left-to-right)
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
                            id: whiteKeyRect

                            readonly property bool active: !!kbroot.activeMap[midi]
                            readonly property int midi: whiteKeys.model[index]
                            readonly property int whiteIndex: kbroot.whiteIndexFor(midi)

                            border.color: active ? 0 : kbroot.whiteBorder
                            border.width: 1
                            color: kbroot.whiteColor
                            height: kbroot.whiteH
                            radius: 1
                            width: kbroot.whiteW
                            x: whiteIndex * kbroot.whiteW
                            y: 0

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
                                focusPolicy: Qt.NoFocus
                                opacity: 0
                                toolTipTitle: kbroot.tooltipText(midi)

                                // If the key should react to clicks, wire them here or forward them:
                                // onPressed:  kbroot.notePressed(midi)
                                // onReleased: kbroot.noteReleased(midi)
                                transparent: true
                                z: 100
                            }
                        }
                    }

                    // Black keys (draw left-to-right above whites with proper x-offset)
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
                            readonly property bool active: !!kbroot.activeMap[midi]
                            readonly property int midi: blackKeys.model[index]

                            border.color: active ? 0 : kbroot.blackBorder
                            border.width: 1
                            color: kbroot.blackColor
                            height: kbroot.blackH
                            radius: Math.max(1, Math.round(kbroot.blackW * 0.12))
                            width: kbroot.blackW
                            x: kbroot.blackXFor(midi)
                            y: 0
                            z: 10

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
                                focusPolicy: Qt.NoFocus
                                opacity: 0
                                toolTipTitle: kbroot.tooltipText(midi)

                                // If the key should react to clicks, wire them here or forward them:
                                // onPressed:  kbroot.notePressed(midi)
                                // onReleased: kbroot.noteReleased(midi)
                                transparent: true
                                z: 100
                            }
                        }
                    }

                    // transparent MouseArea to capture clicks => midi note number
                    // MouseArea { anchors.fill: parent; enabled: false }
                }

                // Title row with dynamic text + filter search
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledTextLabel {
                        id: assignTitle

                        Layout.alignment: Qt.AlignVCenter
                        text: (selectedCountProp === 1 && currentStaffIdx >= 0) ? qsTr('Assign set to ') + cleanName(staffNameByIdx(
                                                                                                                         currentStaffIdx)) :
                                                                                  qsTr('Assign set to %1 staves').arg(selectedCountProp)
                        textFormat: Text.PlainText // render literally, no mnemonics
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    FlatButton {
                        id: clearAssignmentsRef

                        text: qsTr('Clear all staff assignments')

                        onClicked: {
                            // clear in-memory
                            staffToSet = {};

                            // clear persisted JSON (explicitly to "{}" for clarity)
                            ksPrefs.staffToSetJSON = "{}"
                            if (ksPrefs.sync) {
                                try {
                                    ksPrefs.sync()
                                } catch (e) {}
                            }

                            // reset UI state
                            setButtonsFlow.uiSelectedSet = "__none__"
                            refreshUISelectedSet()
                            updateKeyboardActiveNotes()
                        }
                    }

                    SearchField {
                        id: setSearchField

                        // Defensive read of whatever this SearchField exposes
                        function _readSearchText() {
                            // try common property names without assuming they exist
                            // accessing a missing prop yields 'undefined' (no crash)
                            var v = setSearchField.text !== undefined ? setSearchField.text : setSearchField.value !== undefined
                                                                        ? setSearchField.value : setSearchField.displayText !== undefined
                                                                          ? setSearchField.displayText : ""

                            // ensure a string
                            return (typeof v === "string") ? v : ""
                        }

                        Layout.preferredWidth: 160
                        hint: "Filter sets"

                        // fallback: pressing Enter/Return still rebuilds explicitly
                        Keys.onReturnPressed: rebuildFilteredSets()

                        // some builds pass the new value as a parameter, some don't.
                        onTextChanged: function (val) {
                            setFilterText = (typeof val === "string") ? val : _readSearchText()
                        }
                        onTextEdited: function (val) {
                            setFilterText = (typeof val === "string") ? val : _readSearchText()
                        }
                    }
                }

                // Articulation set buttons box
                GroupBox {
                    id: assignBox

                    Layout.fillWidth: true
                    Layout.preferredHeight: 260
                    title: ""

                    background: Rectangle {
                        color: ui.theme.textFieldColor
                    }

                    // Size probe to match FlatButton metrics (use the exact component type)
                    FlatButton {
                        id: _sizeProbe

                        accentButton: true
                        text: qsTr('Save')
                        visible: false
                    }
                    ScrollView {
                        id: setsScroll

                        anchors.fill: parent
                        clip: true

                        Flow {
                            id: setButtonsFlow

                            // local UI-selected set; updated by refreshUISelectedSet() and on clicks
                            property string uiSelectedSet: "__none__"

                            flow: Flow.LeftToRight
                            spacing: 8
                            width: setsScroll.availableWidth

                            Repeater {
                                model: filteredSetsModel

                                delegate: FlatButton {
                                    id: setBtn

                                    // active state = highlighted button
                                    property bool isActive: setButtonsFlow.uiSelectedSet === model.name

                                    accentButton: isActive
                                    height: _sizeProbe.implicitHeight
                                    text: model.name
                                    transparent: false
                                    width: _sizeProbe.implicitWidth

                                    onClicked: {
                                        var keys = Object.keys(selectedStaff)
                                        var hasSelection = keys.length > 0
                                        var targetStaffIds = []

                                        if (hasSelection) {
                                            targetStaffIds = keys
                                        } else if (currentStaffIdx >= 0) {
                                            targetStaffIds = [currentStaffIdx.toString()]
                                        }

                                        var togglingOff = (setButtonsFlow.uiSelectedSet === model.name)

                                        if (togglingOff) {
                                            for (var i = 0; i < targetStaffIds.length; ++i)
                                                delete staffToSet[targetStaffIds[i]];

                                            // no button selected
                                            setButtonsFlow.uiSelectedSet = "__none__"
                                        } else {
                                            // first click: assign this set
                                            for (var j = 0; j < targetStaffIds.length; ++j)
                                                staffToSet[targetStaffIds[j]] = model.name;

                                            // this button selected
                                            setButtonsFlow.uiSelectedSet = model.name
                                            scrollToSetInRegistry(model.name, {
                                                                      focus: true
                                                                  })
                                        }

                                        updateKeyboardActiveNotes();

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
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        id: tabsHeaderRow

                        Layout.fillWidth: true
                        spacing: 8

                        StyledTabBar {
                            id: editorTabs

                            Layout.fillWidth: true
                            spacing: 36

                            background: Item {
                                implicitHeight: 32
                            }

                            StyledTabButton {
                                text: qsTr('Set registry')

                                onClicked: editorModeIndex = 0
                            }
                            StyledTabButton {
                                text: qsTr('Global settings')

                                onClicked: editorModeIndex = 1
                            }
                        }
                    }
                    StackLayout {
                        id: navTabPanel

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.topMargin: 0
                        currentIndex: editorModeIndex

                        Item {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            Layout.leftMargin: leftTextMargin

                            Rectangle {
                                id: registryFrame

                                anchors.fill: parent
                                border.color: root.registryBorderColor
                                border.width: root.registryBorderWidth
                                color: "transparent"
                                radius: 4

                                Flickable {
                                    id: registryFlick

                                    anchors.fill: parent
                                    anchors.margins: root.registryBorderWidth
                                    clip: true

                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AlwaysOn
                                    }
                                    TextArea.flickable: TextArea {
                                        id: jsonArea

                                        font.family: "monospace"
                                        width: registryFlick.width
                                        wrapMode: TextArea.NoWrap

                                        background: Rectangle {
                                            color: ui.theme.textFieldColor
                                        }

                                        Component.onCompleted: {
                                            if (root._pendingRegistryText !== undefined) {
                                                jsonArea.text = root._pendingRegistryText
                                                root._pendingRegistryText = undefined
                                            }
                                            root.validateRegistryText()
                                        }
                                        Keys.onPressed: root._regUserInteracted = true
                                        onActiveFocusChanged: if (activeFocus)
                                                                  root._regUserInteracted = true
                                        onCursorPositionChanged: root._regUserInteracted = true
                                        onTextChanged: {
                                            root.updateKeyboardActiveNotes()
                                            root.validateRegistryText()
                                        }

                                        // Ensure edit shortcuts work AND let the editor keep Space, Return, Delete
                                        // so MuseScore's app-level shortcuts don't steal them on Linux/Ubuntu.
                                        Keys.onShortcutOverride: function (event) {
                                            // 1) Let the editor keep *text* keys and Return/Delete/etc.
                                            if (root.shouldEditorAcceptKey(event)) {
                                                event.accepted = true
                                                return
                                            }

                                            // 2) Editing shortcuts we want to own at the editor level
                                            const mods = event.modifiers
                                            const ctrlOrCmd = !!(mods & (Qt.ControlModifier | Qt.MetaModifier))
                                            const shift = !!(mods & Qt.ShiftModifier)
                                            if ((ctrlOrCmd && (event.key === Qt.Key_V    // Paste
                                                               || event.key === Qt.Key_C    // Copy
                                                               || event.key === Qt.Key_X    // Cut
                                                               || event.key === Qt.Key_A))  // Select All
                                                    || (shift && event.key === Qt.Key_Insert)                       // Paste (Shift+Insert)
                                                    || ((mods & Qt.ControlModifier) && event.key === Qt.Key_Insert) // Copy  (Ctrl+Insert)
                                                    || (shift && event.key === Qt.Key_Delete)) {                    // Cut   (Shift+Delete)
                                                event.accepted = true
                                                return
                                            }
                                        }

                                        // local, widget-scoped shortcuts that only fire when this TextArea has focus
                                        Shortcut {
                                            // paste: cover platform standard key + Linux alternate
                                            sequences: [StandardKey.Paste, "Ctrl+V", "Shift+Insert"]
                                            context: Qt.WidgetShortcut
                                            onActivated: jsonArea.paste()
                                        }
                                        Shortcut {
                                            // copy: cover platform standard key + Linux alternate
                                            sequences: [StandardKey.Copy, "Ctrl+C", "Ctrl+Insert"]
                                            context: Qt.WidgetShortcut
                                            onActivated: jsonArea.copy()
                                        }
                                        Shortcut {
                                            // cut: cover platform standard key + Linux alternate
                                            sequences: [StandardKey.Cut, "Ctrl+X", "Shift+Delete"]
                                            context: Qt.WidgetShortcut
                                            onActivated: jsonArea.cut()
                                        }
                                        Shortcut {
                                            sequences: [StandardKey.SelectAll, "Ctrl+A"]
                                            context: Qt.WidgetShortcut
                                            onActivated: jsonArea.selectAll()
                                        }
                                    }

                                    // Line height probe for consistent Y mapping
                                    FontMetrics {
                                        id: regFM

                                        font: jsonArea.font
                                    }

                                    // Error overlay for registry (positioned by the error character rectangle)
                                    Rectangle {
                                        id: registryErrorOverlay

                                        // where the error character sits inside jsonArea (local coords)
                                        property rect _errRect: (function () {
                                            try {
                                                return jsonArea.positionToRectangle(root.registryErrorPos)
                                            } catch (e) {
                                                return Qt.rect(0, root.registryErrorLine * regFM.height, jsonArea.width, regFM.height)
                                            }
                                        })()

                                        // start-of-line position/rectangle for this line
                                        property int _lineStartPos: (function () {
                                            return _lineStart(jsonArea.text || "", root.registryErrorPos)
                                        })()
                                        property rect _lineStartRect: (function () {
                                            try {
                                                return jsonArea.positionToRectangle(_lineStartPos)
                                            } catch (e) {
                                                return Qt.rect(0, root.registryErrorLine * regFM.height, jsonArea.width, regFM.height)
                                            }
                                        })()

                                        color: root.warningColor
                                        height: Math.max(1, _errRect.height || regFM.height)
                                        opacity: 0.25
                                        // put the overlay in the same stack as the text to ensure it draws above it
                                        parent: jsonArea
                                        radius: 0
                                        visible: root.showRegistryErrorOverlay && (editorModeIndex === 0)
                                        width: (root.errorHighlightStyle === "line") ? jsonArea.width : Math.max(1, jsonArea.width
                                                                                                                 - _errRect.x)

                                        // choose "line" or "fromPos" behavior
                                        x: (root.errorHighlightStyle === "line") ? 0 : _errRect.x
                                        y: _lineStartRect.y
                                        z: 1000
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            Layout.leftMargin: leftTextMargin

                            Rectangle {
                                id: globalsFrame

                                anchors.fill: parent
                                border.color: root.globalsBorderColor
                                border.width: root.globalsBorderWidth
                                color: "transparent"
                                radius: 4

                                Flickable {
                                    id: globalsFlick

                                    anchors.fill: parent
                                    anchors.margins: root.globalsBorderWidth
                                    clip: true

                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AlwaysOn
                                    }
                                    TextArea.flickable: TextArea {
                                        id: globalsArea

                                        font.family: "monospace"
                                        width: globalsFlick.width
                                        wrapMode: TextArea.NoWrap

                                        background: Rectangle {
                                            color: ui.theme.textFieldColor
                                        }

                                        Component.onCompleted: {
                                            if (root._pendingGlobalsText !== undefined) {
                                                globalsArea.text = root._pendingGlobalsText
                                                root._pendingGlobalsText = undefined
                                            }
                                            root.validateGlobalsText()
                                        }
                                        Keys.onPressed: root._globUserInteracted = true
                                        onActiveFocusChanged: if (activeFocus)
                                                                  root._globUserInteracted = true
                                        onCursorPositionChanged: root._globUserInteracted = true
                                        onTextChanged: {
                                            root.updateKeyboardActiveNotes()
                                            root.validateGlobalsText()
                                        }

                                        Keys.onShortcutOverride: function (event) {
                                            if (root.shouldEditorAcceptKey(event)) {
                                                event.accepted = true
                                                return
                                            }
                                            const mods = event.modifiers
                                            const ctrlOrCmd = !!(mods & (Qt.ControlModifier | Qt.MetaModifier))
                                            const shift = !!(mods & Qt.ShiftModifier)
                                            if ((ctrlOrCmd && (event.key === Qt.Key_V || event.key === Qt.Key_C || event.key === Qt.Key_X
                                                               || event.key === Qt.Key_A)) || (shift && event.key === Qt.Key_Insert) || ((
                                                                                                                                             mods & Qt.ControlModifier)
                                                                                                                                         && event.key
                                                                                                                                         === Qt.Key_Insert)
                                                    || (shift && event.key === Qt.Key_Delete)) {
                                                event.accepted = true
                                                return
                                            }
                                        }

                                        Shortcut {
                                            sequences: [StandardKey.Paste, "Ctrl+V", "Shift+Insert"]
                                            context: Qt.WidgetShortcut
                                            onActivated: globalsArea.paste()
                                        }
                                        Shortcut {
                                            sequences: [StandardKey.Copy, "Ctrl+C", "Ctrl+Insert"]
                                            context: Qt.WidgetShortcut
                                            onActivated: globalsArea.copy()
                                        }
                                        Shortcut {
                                            sequences: [StandardKey.Cut, "Ctrl+X", "Shift+Delete"]
                                            context: Qt.WidgetShortcut
                                            onActivated: globalsArea.cut()
                                        }
                                        Shortcut {
                                            sequences: [StandardKey.SelectAll, "Ctrl+A"]
                                            context: Qt.WidgetShortcut
                                            onActivated: globalsArea.selectAll()
                                        }
                                    }

                                    FontMetrics {
                                        id: globFM

                                        font: globalsArea.font
                                    }
                                    Rectangle {
                                        id: globalsErrorOverlay

                                        // where the error character sits inside jsonArea (local coords)
                                        property rect _errRect: (function () {
                                            try {
                                                return globalsArea.positionToRectangle(root.globalsErrorPos)
                                            } catch (e) {
                                                return Qt.rect(0, root.globalsErrorLine * globFM.height, globalsArea.width, globFM.height)
                                            }
                                        })()

                                        // start-of-line position/rectangle for this line
                                        property int _lineStartPos: (function () {
                                            return _lineStart(globalsArea.text || "", root.globalsErrorPos)
                                        })()
                                        property rect _lineStartRect: (function () {
                                            try {
                                                return globalsArea.positionToRectangle(_lineStartPos)
                                            } catch (e) {
                                                return Qt.rect(0, root.globalsErrorLine * globFM.height, globalsArea.width, globFM.height)
                                            }
                                        })()

                                        color: root.warningColor
                                        height: Math.max(1, _errRect.height || globFM.height)
                                        opacity: 0.25
                                        parent: globalsArea
                                        radius: 0
                                        visible: root.showGlobalsErrorOverlay && (editorModeIndex === 1)
                                        width: (root.errorHighlightStyle === "line") ? globalsArea.width : Math.max(1, globalsArea.width
                                                                                                                    - _errRect.x)

                                        // choose "line" or "fromPos" behavior
                                        x: (root.errorHighlightStyle === "line") ? 0 : _errRect.x
                                        y: _lineStartRect.y
                                        z: 1000
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.preferredWidth: 222

                Text {
                    id: version

                    Layout.alignment: Qt.AlignVCenter
                    color: ui.theme.fontPrimaryColor
                    text: "v." + root.version
                }
            }

            FlatButton {
                id: resetButtonRef

                text: qsTr('Reset editor to default')

                onClicked: {
                    if (editorModeIndex === 0)
                        jsonArea.text = formatRegistryCompact(defaultRegistryObj())
                    else
                        globalsArea.text = formatGlobalsCompact(defaultGlobalSettingsObj())
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Animated "Settings Saved" label
            Text {
                id: saveToast

                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 8 // small gap before Save button
                color: ui.theme.fontPrimaryColor
                font.bold: true
                opacity: 0.0
                text: qsTr("Settings Saved")
                visible: false
            }

            // Settings Saved animation
            SequentialAnimation {
                id: saveToastAnim

                running: false

                PropertyAction {
                    property: "visible"
                    target: saveToast
                    value: true
                }
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.InOutSine
                    from: 0.0
                    property: "opacity"
                    target: saveToast
                    to: 1.0
                }
                PauseAnimation {
                    duration: 3000
                }
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutSine
                    from: 1.0
                    property: "opacity"
                    target: saveToast
                    to: 0.0
                }
                ScriptAction {
                    script: saveToast.visible = false
                }
            }
            FlatButton {
                id: saveButtonRef

                accentButton: true
                text: qsTr('Save')

                onClicked: {
                    saveData()
                    writeStaffAssignmentsToScore()
                    writeStaffAssignmentsToScore()
                    saveToastAnim.restart()
                    // quit()
                }
            }
            FlatButton {
                id: cancelButtonRef

                text: qsTr('Close')

                onClicked: quit()
            }
        }
    }

    // On JSON error or selected set button change, refresh active keys, scroll editor to error or set
    Connections {
        function onUiSelectedSetChanged() {
            updateKeyboardActiveNotes()
            // error takes precedence, do not fight the error scroll
            if (root.hasRegistryJsonError)
                return
            if (setButtonsFlow.uiSelectedSet && setButtonsFlow.uiSelectedSet !== "__none__")
                scrollToSetInRegistry(setButtonsFlow.uiSelectedSet, {
                                          focus: false
                                      })
        }

        target: setButtonsFlow
    }
}
