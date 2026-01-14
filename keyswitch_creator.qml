
//===============================================================================
//  Keyswitch Creator for MuseScore Studio articulation & technique text
//  Creates keyswitch notes on the staff below based on articulation symbols &
//  technique text in the current selection/entire score.
//
//  Copyright (C) 2026 Eric Warren (eakwarren)
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 3
//  as published by the Free Software Foundation and appearing in
//  the file LICENSE
//===============================================================================

import QtQuick
import MuseScore 3.0

MuseScore {
    title: qsTr("Keyswitch Creator")
    description: qsTr("Creates keyswitch notes (on the staff below) from articulations & technique text.")
    version: "0.10.3"  // micro patch: order Generic fields
    categoryCode: "Keyswitch Creator"
    thumbnailName: "keyswitch_creator.png"

    // ---------- DEBUG ----------
    property bool debugEnabled: true
    function dbg(msg)  { if (debugEnabled) console.log("[KS] " + msg) }
    function dbg2(k,v) { if (debugEnabled) console.log("[KS] " + k + ": " + v) }

    // ---------- GLOBAL DEFAULTS ----------
    property var defaultGlobalSettings: ({
        "priority": ["accent", "staccato", "tenuto", "marcato"],
        "durationPolicy": "source",
        "techniqueAliases": {
            "pizz": ["pizz", "pizz.", "pizzicato"],
            "con sord": ["con sord", "con sord.", "con sordino"],
            "sul pont": ["sul pont", "sul pont.", "sul ponticello"]
        }
    })
    property var globalSettings: defaultGlobalSettings

    // ---------- USER CONFIG (fallback maps for "Generic") ----------
    property var techniqueKeyMap: ({
        "pizz": 24, "arco": 25, "tremolo": 26, "con sord": 27, "sordino": 27,
        "senza sord": 28, "sul pont": 29, "sul tasto": 30, "harmonic": 31,
        "col legno": 32, "legato": 33, "spiccato": 34
    })
    property var articulationKeyMap: ({
        // Default articulation KS per user-provided mapping (Generic)
        "staccato": 31, "staccatissimo": 32, "tenuto": 37,
        "accent": 38, "marcato": 39, "loure": 40, "fermata": 41, "sforzato": 42
    })

    // Fixed KS duration (fallback)
    property int  ksNumerator: 1
    property int  ksDenominator: 16
    property bool useSourceDuration: true  // legacy fallback when policy missing
    property bool hideKeyswitchNotes: false
    property bool skipIfExists: true

    // Deduping & voice preference
    property bool dedupeAcrossVoices: true
    property int  preferVoiceForKSInsertion: 0
    property var  emittedCross: ({})
    property var  emittedKS:   ({})  // "staffIdx:tick:pitch" -> true

    // ---------- INTERNAL ----------
    property var savedSelection: false
    property var globalStart: fraction(0, 1)
    property var globalEnd:   fraction(0, 1)

    // ---------- Keyswitch set registry ----------
    property var defaultKeyswitchSets: ({
        "Generic": {
            articulationKeyMap: { "staccato": 31, "staccatissimo": 32, "tenuto": 37, "accent": 38, "marcato": 39 },
            techniqueKeyMap:    { "pizz": 24, "arco": 25, "harmonic": 31, "con sord": 27, "senza sord": 28, "sul pont": 29 }
        }
    })
    property var staffToSet: ({})
    property var setTagTimeline: ({})
    Settings {
        id: ksPrefs
        category: "Keyswitch Creator"
        property string setsJSON: ""
        property string staffToSetJSON: ""
        property string globalJSON: ""
    }
    property var keyswitchSets: defaultKeyswitchSets

    function loadRegistryAndAssignments() {
        var sets;   try { sets = ksPrefs.setsJSON ? JSON.parse(ksPrefs.setsJSON) : defaultKeyswitchSets } catch(e) { sets = defaultKeyswitchSets }
        keyswitchSets = sets
        var a;      try { a    = ksPrefs.staffToSetJSON ? JSON.parse(ksPrefs.staffToSetJSON) : {} } catch(e2)     { a = {} }
        staffToSet = a
        var g;      try { g    = ksPrefs.globalJSON ? JSON.parse(ksPrefs.globalJSON) : defaultGlobalSettings } catch(e3) { g = defaultGlobalSettings }
        globalSettings = g
        dbg2("registry keys", Object.keys(keyswitchSets).join(", "))
    }
    function saveRegistryAndAssignments() {
        ksPrefs.setsJSON       = JSON.stringify(keyswitchSets)
        ksPrefs.staffToSetJSON = JSON.stringify(staffToSet)
        ksPrefs.globalJSON     = JSON.stringify(globalSettings)
    }

    // ---------- Normalization + manual tag parsing ----------
    function normalizeTextBasic(s) {
        var t = (s || "").toString()
        // Smart quotes -> straight quotes; NBSP -> space; collapse whitespace
        t = t.replace(/“|”/g, '"').replace(/‘|’/g, "'")
        t = t.replace(/ /g, " ").replace(/\s+/g, " ")
        return t
    }

    function parseSetTag(rawText) {
        var s = normalizeTextBasic(rawText)
        // Case-insensitive find of 'KS:Set'
        var lower = s.toLowerCase()
        var idx = lower.indexOf("ks:set")
        if (idx < 0) return ""

        var i = idx + 6
        // skip spaces
        while (i < s.length && s[i] === " ") i++
        // optional '=' then spaces
        if (i < s.length && s[i] === "=") {
            i++
            while (i < s.length && s[i] === " ") i++
        }
        if (i >= s.length) return ""

        var ch = s[i]
        var name = ""
        if (ch === '"' || ch === "'") {
            var quote = ch
            i++
            var j = s.indexOf(quote, i)
            if (j === -1) name = s.substring(i).trim()
            else          name = s.substring(i, j).trim()
        } else {
            var j = i
            while (j < s.length && s[j] !== " ") j++
            name = s.substring(i, j).trim()
        }
        return name
    }

    // ---------- Score scanning ----------
    function staffBelowTrackOf(track) { return track + 4 }               // 4 tracks per staff
    function staffExistsForTrack(track) {
        var belowIdx = Math.floor(track / 4) + 1
        return belowIdx < curScore.staves.length
    }

    // Collect KS:Set tags from SCORE START to selection end (tags *before* range apply),
    // scanning both segment annotations and note-attached text.
    function collectSetTagsInRange() {
        setTagTimeline = {}

        var endTick = curScore.lastSegment ? (curScore.lastSegment.tick + 1) : 0
        // scan all staves to be safe; resolver still uses chord's staff timeline
        var staffStart = 0
        var staffEnd   = curScore.staves.length - 1

        if (curScore.selection && curScore.selection.isRange) {
            endTick = curScore.selection.endSegment ? curScore.selection.endSegment.tick : endTick
        }

        dbg("collectSetTagsInRange: scan staffs " + staffStart + "–" + staffEnd + ", ticks 0→" + endTick)

        for (var s = staffStart; s <= staffEnd; ++s) {
            var c = curScore.newCursor()
            c.track = s * 4
            c.rewind(Cursor.SCORE_START)

            while (c.segment && c.tick <= endTick) {
                var seg = c.segment

                // A) Segment annotations
                if (seg && seg.annotations) {
                    for (var ai in seg.annotations) {
                        var ann = seg.annotations[ai]
                        var annStaff = (ann.track == -1) ? s : Math.floor(ann.track/4) // accept system-level
                        var snippet = normalizeTextBasic(ann.text || "")
                        if (snippet.length) {
                            dbg("Text(annotation): staff " + annStaff + " tick " + seg.tick +
                                " type=" + ann.type + ' text="' + snippet.substring(0,80) + '"')
                        }
                        if ((ann.type == Element.STAFF_TEXT || ann.type == Element.SYSTEM_TEXT || ann.type == Element.EXPRESSION_TEXT)
                            && annStaff == s) {
                            var tName = parseSetTag(ann.text || "")
                            if (tName.length) {
                                if (!setTagTimeline[s]) setTagTimeline[s] = []
                                setTagTimeline[s].push({ tick: seg.tick, setName: tName })
                                dbg('Tag(annotation): staff ' + s + ' tick ' + seg.tick + ' -> ' + tName +
                                    (keyswitchSets[tName] ? ' (OK)' : ' (not in registry)'))
                            }
                        }
                    }
                }

                // B) Note-attached TEXT on the same segment for all voices on this staff
                for (var v = 0; v < 4; ++v) {
                    var el = seg.elementAt(s * 4 + v)
                    if (el && el.type == Element.CHORD && el.notes) {
                        for (var ni in el.notes) {
                            var note = el.notes[ni]
                            if (!note.elements) continue
                            for (var ei in note.elements) {
                                var nel = note.elements[ei]
                                if (nel.type == Element.TEXT) {
                                    var raw = nel.text || ""
                                    var snippet2 = normalizeTextBasic(raw)
                                    if (snippet2.length) {
                                        dbg('Text(note): staff ' + s + ' tick ' + seg.tick +
                                            ' voice ' + v + ' text="' + snippet2.substring(0,80) + '"')
                                    }
                                    var tn = parseSetTag(raw)
                                    if (tn.length) {
                                        if (!setTagTimeline[s]) setTagTimeline[s] = []
                                        setTagTimeline[s].push({ tick: seg.tick, setName: tn })
                                        dbg('Tag(note-text): staff ' + s + ' tick ' + seg.tick + ' -> ' + tn +
                                            (keyswitchSets[tn] ? ' (OK)' : ' (not in registry)'))
                                    }
                                }
                            }
                        }
                    }
                }

                if (!c.next()) break
            }

            if (setTagTimeline[s]) {
                setTagTimeline[s].sort(function(a,b){ return a.tick - b.tick })
                dbg2("timeline[" + s + "] count", setTagTimeline[s].length)
            }
        }
    }

    // Resolve active set: newest tag <= tick if present; else staff assignment; else "Generic".
    function activeSetNameFor(staffIdx, tick) {
        var tl = setTagTimeline[staffIdx] || []
        for (var i = tl.length - 1; i >= 0; --i) {
            if (tl[i].tick <= tick) {
                var name = tl[i].setName
                if (keyswitchSets[name]) return name
                dbg("activeSetNameFor: tag '" + name + "' not in registry, falling back")
                break
            }
        }
        var assigned = staffToSet[staffIdx.toString()]
        return (assigned && keyswitchSets[assigned]) ? assigned : "Generic"
    }

    // ---------- Selection I/O ----------
    function readSelection() {
        if (!curScore.selection.elements.length) return false
        if (curScore.selection.isRange) {
            var obj = {
                isRange: true,
                startSegment: curScore.selection.startSegment.tick,
                endSegment: curScore.selection.endSegment ? curScore.selection.endSegment.tick : curScore.lastSegment.tick + 1,
                startStaff: curScore.selection.startStaff,
                endStaff: curScore.selection.endStaff
            }
            dbg("readSelection: range ticks " + obj.startSegment + "→" + obj.endSegment + ", staffs " + obj.startStaff + "–" + obj.endStaff)
            return obj
        }
        var list = { isRange: false, elements: [] }
        for (var i in curScore.selection.elements)
            list.elements.push(curScore.selection.elements[i])
        dbg("readSelection: list with " + list.elements.length + " elements")
        return list
    }
    function writeSelection(sel) {
        if (sel == false) return
        if (sel.isRange) {
            dbg("writeSelection: restoring range")
            curScore.selection.selectRange(sel.startSegment, sel.endSegment, sel.startStaff, sel.endStaff)
            return
        }
        dbg("writeSelection: restoring list with " + sel.elements.length + " elements")
        for (var i in sel.elements)
            curScore.selection.select(sel.elements[i], true)
    }

    // ---------- Technique text & articulations ----------
    function sameStaff(trackA, trackB) { return Math.floor(trackA / 4) === Math.floor(trackB / 4) }

    function normalizeForTechnique(s) {
        var t = normalizeTextBasic(s)
        return t.toLowerCase().trim()
    }

    function segmentTechniqueTexts(chord) {
        var out = []
        var seg = chord.parent

        // Segment annotations
        if (seg && seg.annotations) {
            for (var i in seg.annotations) {
                var ann = seg.annotations[i]
                if (ann.type == Element.STAFF_TEXT || ann.type == Element.SYSTEM_TEXT || ann.type == Element.EXPRESSION_TEXT) {
                    if (ann.type != Element.STAFF_TEXT || sameStaff(ann.track, chord.track)) {
                        var norm = normalizeForTechnique(ann.text)
                        if (norm.indexOf("keyswitch creator:") === 0) continue
                        if (norm.length) out.push(norm)
                    }
                }
            }
        }
        // Note-attached TEXT on chord
        if (chord.notes) {
            for (var j in chord.notes) {
                var note = chord.notes[j]
                if (!note.elements) continue
                for (var k in note.elements) {
                    var nel = note.elements[k]
                    if (nel.type == Element.TEXT) {
                        var txt = normalizeForTechnique(nel.text)
                        if (txt.indexOf("keyswitch creator:") === 0) continue
                        if (txt.length) out.push(txt)
                    }
                }
            }
        }
        return out
    }

    function chordArticulationNames(chord) {
        var names = []
        if (!chord.articulations) return names
        for (var i in chord.articulations) {
            var a = chord.articulations[i]
            var an = (typeof a.articulationName === "function") ? a.articulationName() : ""
            var un = (typeof a.userName         === "function") ? a.userName()         : ""
            var sn = (typeof a.subtypeName      === "function") ? a.subtypeName()      : ""
            var rawLower = (an + " " + un + " " + sn).toLowerCase()
            var n = ""
            if (rawLower.indexOf("staccatissimo") >= 0) n = "staccatissimo"
            else if (rawLower.indexOf("staccat") >= 0)  n = "staccato"
            else if (rawLower.indexOf("tenuto")  >= 0)  n = "tenuto"
            else if (rawLower.indexOf("accent")  >= 0)  n = "accent"
            else if (rawLower.indexOf("marcato") >= 0)  n = "marcato"
            else if (rawLower.indexOf("sforzato")>= 0 || rawLower.indexOf("sfz") >= 0) n = "sforzato"
            if (!n) n = "unknown"
            names.push(n)
        }
        return names
    }

    function ensureWritableSlot(c, num, den) {
        var t = c.fraction
        c.setDuration(num, den)
        c.addRest()
        c.rewindToFraction(t)
    }

    // Safe regex-escape implementation
    function escapeRegex(s) {
        return s.replace(/[-\/\^$*+?.()|[\]{}]/g, '\$&')
    }

    function findTechniqueKeyswitches(texts, techMap, aliasMap) {
        var pitches = []
        if (!techMap) return pitches
        var aliasFor = aliasMap || {}
        for (var key in techMap) {
            var pitch = techMap[key]
            var aliases = aliasFor[key] || [key]
            // Build regexes once
            var regexes = []
            for (var i = 0; i < aliases.length; ++i) {
                var a = aliases[i]
                // word-boundary-ish match
                var r = new RegExp('\b' + escapeRegex(a) + '\b')
                regexes.push(r)
            }
            for (var ti = 0; ti < texts.length; ++ti) {
                var t = texts[ti]
                for (var ri = 0; ri < regexes.length; ++ri) {
                    if (regexes[ri].test(t)) { pitches.push(pitch); break }
                }
            }
        }
        return pitches
    }

    function findArticulationKeyswitches(artiNames, artiMap) {
        var pitches = []
        if (!artiMap) return pitches
        for (var i in artiNames) {
            var k = artiNames[i]
            if (artiMap.hasOwnProperty(k))      pitches.push(artiMap[k])
            else if (k.indexOf("tenuto") >= 0 && artiMap.tenuto)      pitches.push(artiMap.tenuto)
            else if (k.indexOf("stacc")  >= 0 && artiMap.staccato)    pitches.push(artiMap.staccato)
            else if (k.indexOf("accent") >= 0 && artiMap.accent)      pitches.push(artiMap.accent)
            else if (k.indexOf("marcato")>= 0 && artiMap.marcato)     pitches.push(artiMap.marcato)
        }
        return pitches
    }

    function keyswitchExistsAt(cursor, pitch) {
        if (!cursor.element || cursor.element.type != Element.CHORD) return false
        var chord = cursor.element
        for (var i in chord.notes) if (chord.notes[i].pitch == pitch) return true
        return false
    }

    function addKeyswitchNoteAt(sourceChord, pitch, firstOfChord, activeSet) {
        var track     = sourceChord.track
        var startFrac = sourceChord.fraction

        if (!staffExistsForTrack(track)) return false

        var c = curScore.newCursor()
        c.track = staffBelowTrackOf(track)
        c.rewindToFraction(startFrac)

        var sidx = c.staffIdx
        var tkey = c.tick

        var policy = (activeSet && activeSet.durationPolicy) ? activeSet.durationPolicy
                    : (globalSettings && globalSettings.durationPolicy) ? globalSettings.durationPolicy
                    : (useSourceDuration ? "source" : "fixed")

        var dur = sourceChord.actualDuration
        var num = (policy === "source" && dur) ? dur.numerator   : ksNumerator
        var den = (policy === "source" && dur) ? dur.denominator : ksDenominator

        // EXTRA GUARD: fallback if invalid
        if (!num || !den) { num = ksNumerator; den = ksDenominator }

        c.setDuration(num, den)

        if (dedupeAcrossVoices && firstOfChord && wasEmittedCross(sidx, tkey)) return false

        ensureWritableSlot(c, num, den)

        if (skipIfExists && keyswitchExistsAt(c, pitch)) return false

        // Keep second parameter (addToChord=false) per MU4.5 API
        c.addNote(pitch, false)

        if (dedupeAcrossVoices && firstOfChord) markEmittedCross(sidx, tkey)

        c.rewindToFraction(startFrac)

        // Safer hiding: hide only the inserted note(s)
        if (hideKeyswitchNotes && c.element && c.element.type == Element.CHORD) {
            var ch = c.element
            if (ch.notes) {
                for (var i in ch.notes) {
                    var nn = ch.notes[i]
                    if (nn.pitch == pitch) {
                        try { nn.visible = false } catch (e) {}
                    }
                }
            }
        }
        return true
    }

    function ksKey(staffIdx, tick, pitch)        { return staffIdx + ":" + tick + ":" + pitch }
    function wasEmitted(staffIdx, tick, pitch)    { return emittedKS.hasOwnProperty(ksKey(staffIdx,tick,pitch)) }
    function markEmitted(staffIdx, tick, pitch)   { emittedKS[ksKey(staffIdx,tick,pitch)] = true }
    function crossKey(staffIdx, tick)             { return staffIdx + ":" + tick }
    function wasEmittedCross(staffIdx, tick)      { return emittedCross.hasOwnProperty(crossKey(staffIdx,tick)) }
    function markEmittedCross(staffIdx, tick)     { emittedCross[crossKey(staffIdx,tick)] = true }

    function processSelection() {
        // Reset cross-run state maps
        emittedCross = ({})
        emittedKS    = ({})

        var chords = []
        // Sentinel init to avoid invalid Fraction ops
        globalStart = fraction(999999999, 1)
        globalEnd   = fraction(0, 1)

        // Collect chords
        if (curScore.selection.isRange) {
            var startTick  = curScore.selection.startSegment.tick
            var endTick    = curScore.selection.endSegment ? curScore.selection.endSegment.tick : curScore.lastSegment.tick + 1
            var startStaff = curScore.selection.startStaff
            var endStaff   = curScore.selection.endStaff

            for (var s = startStaff; s <= endStaff; ++s) {
                for (var v = 0; v < 4; ++v) {
                    var c = curScore.newCursor()
                    c.track = s * 4 + v
                    c.rewindToTick(startTick)

                    while (c.tick < endTick) {
                        var el = c.element
                        if (el && el.type == Element.CHORD && el.noteType == NoteType.NORMAL) {
                            if (typeof sourceVoicesForKeyswitches !== "undefined" &&
                                sourceVoicesForKeyswitches.indexOf(el.voice) === -1) {
                                // gated voice -> skip
                            } else {
                                chords.push(el)
                                var st = el.fraction
                                var et = st.plus(el.actualDuration)
                                if (st.lessThan(globalStart)) globalStart = st
                                if (et.greaterThan(globalEnd)) globalEnd   = et
                            }
                        }
                        if (!c.next()) break
                    }
                }
            }
        } else {
            for (var i in curScore.selection.elements) {
                var el = curScore.selection.elements[i]
                var chord = null
                if (el.type == Element.NOTE && el.parent && el.parent.type == Element.CHORD) chord = el.parent
                else if (el.type == Element.CHORD) chord = el
                else continue

                if (chord.noteType != NoteType.NORMAL) continue
                if (typeof sourceVoicesForKeyswitches !== "undefined" &&
                    sourceVoicesForKeyswitches.indexOf(chord.voice) === -1) continue

                chords.push(chord)
                var st2 = chord.fraction
                var et2 = st2.plus(chord.actualDuration)
                if (st2.lessThan(globalStart)) globalStart = st2
                if (et2.greaterThan(globalEnd)) globalEnd   = et2
            }
        }

        dbg2("chords collected", chords.length)
        dbg("globalStart " + globalStart.numerator + "/" + globalStart.denominator +
            "   globalEnd "   + globalEnd.numerator   + "/" + globalEnd.denominator)

        // Collect tags (from SCORE START; includes note-attached text)
        collectSetTagsInRange()

        // Sort by time (tie: prefer configured voice)
        chords.sort(function(a,b){
            if (a.fraction.lessThan(b.fraction)) return -1
            if (a.fraction.greaterThan(b.fraction)) return 1
            var pref = (typeof preferVoiceForKSInsertion !== "undefined") ? preferVoiceForKSInsertion : 0
            var da = Math.abs(a.voice - pref), db = Math.abs(b.voice - pref)
            if (da !== db) return da - db
            return a.track - b.track
        })

        // Emit KS
        var createdCount = 0
        for (var k in chords) {
            var chord    = chords[k]
            var tickHere = (chord.parent && chord.parent.tick) ? chord.parent.tick : 0
            var setName  = activeSetNameFor(chord.staffIdx, tickHere)
            var activeSet = keyswitchSets[setName] || keyswitchSets["Generic"]

            var texts     = segmentTechniqueTexts(chord)
            var artiNames = chordArticulationNames(chord)

            dbg("Chord track " + chord.track + ": texts=" + texts.length +
                " arts=" + artiNames.length + "  set=" + setName)

            var pitches = []
            // Techniques (with alias support)
            var techMap   = activeSet.techniqueKeyMap || techniqueKeyMap
            var aliasMap  = (activeSet.techniqueAliases) ? activeSet.techniqueAliases
                            : (globalSettings.techniqueAliases) ? globalSettings.techniqueAliases
                            : null
            if (!aliasMap) aliasMap = { "pizz": ["pizz","pizz.","pizzicato"], "con sord": ["con sord","con sord.","con sordino"], "sul pont": ["sul pont","sul pont.","sul ponticello"] }
            pitches = pitches.concat(findTechniqueKeyswitches(texts, techMap, aliasMap))
            // Articulations (keep multiples if present)
            pitches = pitches.concat(findArticulationKeyswitches(artiNames, activeSet.articulationKeyMap || articulationKeyMap))

            var seen = {}
            for (var j in pitches) {
                var p = pitches[j]
                if (seen[p]) continue
                var firstOfChord = (j == 0)
                if (addKeyswitchNoteAt(chord, p, firstOfChord, activeSet)) createdCount++
                seen[p] = true
            }
        }

        dbg2("processSelection: total keyswitches created", createdCount)
        return createdCount
    }

    onRun: {
        dbg("onRun: begin")
        loadRegistryAndAssignments()
        if (!curScore) { dbg("No score open; quitting"); quit(); return }

        if (!curScore.selection.elements.length) {
            dbg("No selection; selecting whole score")
            curScore.startCmd("Keyswitch Creator (whole score)")
            cmd("select-all")
        } else {
            dbg("Selection present (" + curScore.selection.elements.length + " elements)")
            curScore.startCmd("Keyswitch Creator (selection)")
        }

        try {
            savedSelection = readSelection()
            var count = processSelection()
            curScore.selection.clear()
            writeSelection(savedSelection)
            curScore.endCmd()
            dbg2("onRun: end, keyswitches added", count)
        } catch (e) {
            curScore.endCmd(true)
            dbg("ERROR: " + e.toString())
        }
        quit()
    }
}
