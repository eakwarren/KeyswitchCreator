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
import QtQuick.Dialogs
import MuseScore 3.0

MuseScore {
    title: qsTr("Keyswitch Creator")
    description: qsTr("Creates keyswitch notes on a staff below in the same instrument.")
    version: "0.9.6"
    categoryCode: "Keyswitch Creator"
    thumbnailName: "keyswitch_creator.png"

    // ------------------ DEBUG ------------------
    property bool debugEnabled: true

    function dbg(msg)  { if (debugEnabled) console.log("[KS] " + msg) }

    function dbg2(k,v) { if (debugEnabled) console.log("[KS] " + k + ": " + v) }

    // ------------------ SETTINGS ------------------

    property var defaultGlobalSettings: ({
                                             "durationPolicy": "source",
                                             "techniqueAliases": {
                                                 // phrasing
                                                 "legato": ["legato", "leg.", "slur", "slurred"],
                                                 "normal": ["normal", "normale", "norm.", "nor.", "ordinary", "ord.", "standard", "std.", "arco"],
                                                 // mutes
                                                 "con sord":   ["con sord", "con sord.", "con sordino", "with mute", "muted", "sord."],
                                                 "senza sord": ["senza sord", "senza sord.", "senza sordino", "open", "without mute"],
                                                 // position
                                                 "sul pont":  ["sul pont", "sul pont.", "sul ponticello"],
                                                 "sul tasto": ["sul tasto", "sul tast.", "flautando"],
                                                 // timbre/attack
                                                 "col legno": ["col legno", "col l.", "c.l."],
                                                 "harmonic":  ["harmonic", "harm.", "harmonics", "natural harmonic", "artificial harmonic"],
                                                 "spiccato":  ["spiccato", "spicc.", "spic."],
                                                 "pizz":      ["pizz", "pizz.", "pizzicato"],
                                                 "tremolo":   ["tremolo", "trem.", "tremolando"]
                                             }
                                         })

    property var globalSettings: defaultGlobalSettings

    // Articulations (note-attached symbols)
    property var articulationKeyMap: ({
                                          "staccato": 0, "staccatissimo": 1, "tenuto": 2, "accent": 3, "marcato": 4, "sforzato": 5, "loure": 6, "fermata": 7, "trill": 8, "mordent": 9, "mordent inverted": 10, "turn": 11, "harmonics": 12, "mute": 13
                                      })
    // Techniques (written)
    property var techniqueKeyMap: ({
                                       "normal": 14, "arco": 15, "pizz": 16, "tremolo": 17, "con sord": 18, "senza sord": 19, "sul pont": 20, "sul tasto": 21, "harmonic": 22, "col legno": 23, "legato": 24, "spiccato": 25
                                   })

    property int ksNumerator: 1
    property int ksDenominator: 16
    property bool hideKeyswitchNotes: false
    property bool skipIfExists: true
    property bool useSourceDuration: true
    property bool dedupeAcrossVoices: true
    property int  preferVoiceForKSInsertion: 0
    property var  emittedCross: ({})
    property int defaultKsVelocity: 64

    // ------------------ INTERNAL ------------------
    property bool savedSelection: false
    property bool preflightFailed: false
    property bool promptShown: false
    property bool sawIneligible: false
    property int  firstIneligibleStaffIdx: -1

    // Within-part and multi-part handling
    property string rangeScopeMode: "staff"     // "staff" or "part"
    property string selectionPartMode: "anchor" // "anchor" or "all"
    property bool warnOnPartialSuccess: true

    // Registry & settings store
    property var defaultKeyswitchSets: ({
                                            "Default Low": {
                                                articulationKeyMap: {"staccato": 0, "staccatissimo": 1, "tenuto": 2, "accent": 3, "marcato": 4, "sforzato": 5, "loure": 6, "fermata": 7, "trill": 8, "mordent": 9, "mordent inverted": 10, "turn": 11, "harmonics": 12, "mute": 13},
                                                techniqueKeyMap:    {"normal": 14, "arco": 15, "pizz": 16, "tremolo": 17, "con sord": 18, "senza sord": 19, "sul pont": 20, "sul tasto": 21, "harmonic": 22, "col legno": 23, "legato": 24, "spiccato": 25}
                                            }
                                        })
    property var keyswitchSets: defaultKeyswitchSets
    property var setTagTimeline: ({})
    property var staffToSet: ({})

    Settings {
        id: ksPrefs
        category: "Keyswitch Creator"
        property string setsJSON: ""
        property string staffToSetJSON: ""
        property string globalJSON: ""
    }

    function loadRegistryAndAssignments() {
        var sets; try { sets = ksPrefs.setsJSON ? JSON.parse(ksPrefs.setsJSON) : defaultKeyswitchSets } catch(e) { sets = defaultKeyswitchSets }
        keyswitchSets = sets
        var a;   try { a = ksPrefs.staffToSetJSON ? JSON.parse(ksPrefs.staffToSetJSON) : {} } catch(e2) { a = {} }
        staffToSet = a
        var g;   try { g = ksPrefs.globalJSON ? JSON.parse(ksPrefs.globalJSON) : defaultGlobalSettings } catch(e3) { g = defaultGlobalSettings }
        globalSettings = g
        dbg2("plugin version", version)
        dbg2("registry keys", Object.keys(keyswitchSets).join(", "))
    }

    // ------------------ Helpers ------------------
    function staffIdxFromTrack(track) { return Math.floor(track / 4) }

    function partInfoForStaff(staffIdx) {
        if (!curScore || !curScore.parts) return null
        var t = staffIdx*4
        for (var i=0; i<curScore.parts.length; ++i) {
            var p = curScore.parts[i]
            if (t >= p.startTrack && t < p.endTrack) return { index:i, start:p.startTrack, end:p.endTrack, part:p }
        }
        return null
    }

    function partCount() { return curScore && curScore.parts ? curScore.parts.length : 0 }

    function nameForPartByRange(staffIdx, tick) {
        var pi = partInfoForStaff(staffIdx); if (!pi) return qsTr("this part")
        var p = pi.part
        var nm = (p.longName && p.longName.length) ? p.longName : (p.partName && p.partName.length) ? p.partName : (p.shortName && p.shortName.length) ? p.shortName : ""
        if (!nm && p.instrumentAtTick) { var inst = p.instrumentAtTick(tick||0); if (inst && inst.longName && inst.longName.length) nm = inst.longName }
        if (!nm) nm = qsTr("this part")
        return nm
    }

    function targetStaffForKeyswitch(srcStaffIdx) {
        if (!curScore || !curScore.staves || srcStaffIdx < 0 || srcStaffIdx >= curScore.staves.length) return -1
        var pi = partInfoForStaff(srcStaffIdx); if (!pi) { dbg("target: no part for src="+srcStaffIdx); return -1 }
        var last = srcStaffIdx
        for (var i = srcStaffIdx + 1; i < curScore.staves.length; ++i) {
            var pj = partInfoForStaff(i)
            if (!pj || pj.index !== pi.index) break
            last = i
        }
        dbg(qsTr("targetStaffForKeyswitch(range): src=%1 -> target=%2").arg(srcStaffIdx).arg(last))
        return (last > srcStaffIdx) ? last : -1
    }

    function isEligibleSourceStaff(staffIdx) { return targetStaffForKeyswitch(staffIdx) !== -1 }

    function normalizeTextBasic(s) { var t = (s || "").toString(); t = t.replace(/[“”]/g,'"').replace(/[‘’]/g,"'"); t = t.replace(/\u00A0/g," ").replace(/\s+/g," "); return t }

    function sameStaff(trackA, trackB) { return Math.floor(trackA/4) === Math.floor(trackB/4) }

    function collectSetTagsInRange() {
        setTagTimeline = {}
        var endTick = curScore.lastSegment ? (curScore.lastSegment.tick + 1) : 0
        if (curScore.selection && curScore.selection.isRange)
            endTick = curScore.selection.endSegment ? curScore.selection.endSegment.tick : endTick
        dbg("collectSetTagsInRange: begin -> endTick="+endTick)
        for (var s = 0; s < curScore.staves.length; ++s) {
            var c = curScore.newCursor(); c.track = s*4; c.rewind(Cursor.SCORE_START)
            while (c.segment && c.tick <= endTick) {
                var seg = c.segment
                if (seg) {
                    if (seg.annotations) {
                        for (var ai in seg.annotations) {
                            var ann = seg.annotations[ai]
                            var annStaff = (ann.track === -1) ? s : Math.floor(ann.track/4)
                            if ((ann.type === Element.STAFF_TEXT || ann.type === Element.SYSTEM_TEXT || ann.type === Element.EXPRESSION_TEXT) && annStaff === s) {
                                var tName = parseSetTag(ann.text || ""); if (tName.length) { if (!setTagTimeline[s]) setTagTimeline[s] = []; setTagTimeline[s].push({tick: seg.tick, setName: tName}); }
                            }
                        }
                    }
                    for (var v = 0; v < 4; ++v) {
                        var el = seg.elementAt ? seg.elementAt(s*4+v) : null
                        if (el && el.type === Element.CHORD && el.notes) {
                            for (var ni in el.notes) {
                                var note = el.notes[ni]
                                if (!note.elements) continue
                                for (var ei in note.elements) {
                                    var nel = note.elements[ei]
                                    if (nel.type === Element.TEXT) {
                                        var tn = parseSetTag(nel.text || "")
                                        if (tn.length) { if (!setTagTimeline[s]) setTagTimeline[s] = []; setTagTimeline[s].push({ tick: seg.tick, setName: tn }) }
                                    }
                                }
                            }
                        }
                    }
                }
                if (!c.next()) break
            }
            if (setTagTimeline[s]) setTagTimeline[s].sort(function(a,b){ return a.tick - b.tick })
        }
        dbg("collectSetTagsInRange: end")
    }

    function parseSetTag(rawText) {
        var s = normalizeTextBasic(rawText)
        var lower = s.toLowerCase(); var idx = lower.indexOf("ks:set"); if (idx < 0) return ""
        var i = idx+6; while (i < s.length && s[i]===" ") i++
        if (i < s.length && s[i] === "=") { i++; while (i < s.length && s[i]===" ") i++ }
        if (i >= s.length) return ""
        var ch = s[i], name=""
        if (ch==='"' || ch==="'") { var q=ch; i++; var j = s.indexOf(q,i); name = (j===-1) ? s.substring(i).trim() : s.substring(i,j).trim() }
        else { var j2=i; while (j2<s.length && s[j2]!==" ") j2++; name = s.substring(i,j2).trim() }
        return name
    }

    // --- NEW: KS:Text= tag parsing (can appear in Staff Text or System Text) ---
    function parseTextTagValues(rawText) {
        var s = normalizeTextBasic(rawText)
        var lower = s.toLowerCase()
        var out = []
        var start = 0

        while (true) {
            var idx = lower.indexOf("ks:text", start)
            if (idx < 0) break

            var i = idx + 7  // length("ks:text") == 7
            while (i < s.length && s[i] === " ") i++

            if (i < s.length && s[i] === "=") {
                i++
                while (i < s.length && s[i] === " ") i++
            }
            if (i >= s.length) { start = idx + 7; continue }

            var ch = s[i], val = ""
            if (ch === '"' || ch === "'") {
                var q = ch
                i++
                var j = s.indexOf(q, i)
                val = (j === -1) ? s.substring(i).trim() : s.substring(i, j).trim()
                start = (j === -1) ? s.length : (j + 1)
            } else {
                var j2 = i
                while (j2 < s.length && s[j2] !== " ") j2++
                val = s.substring(i, j2).trim()
                start = j2
            }

            if (val.length)
                out.push(val)
        }

        return out
    }

    // Resolve KS:Text=<value> directly against techniqueKeyMap (case-insensitive key match)
    function findTaggedTechniqueKeyswitches(texts, techMap) {
        var specs = []
        if (!techMap) return specs

        // Build a lowercase index for case-insensitive matching without changing user JSON
        var lcIndex = {}
        for (var k in techMap) {
            if (!techMap.hasOwnProperty(k)) continue
            lcIndex[String(k).toLowerCase()] = k
        }

        for (var ti = 0; ti < texts.length; ++ti) {
            var vals = parseTextTagValues(texts[ti])
            for (var vi = 0; vi < vals.length; ++vi) {
                var wanted = String(vals[vi]).toLowerCase()
                var realKey = lcIndex[wanted]
                if (realKey === undefined) continue

                var spec = parseKsMapValue(techMap[realKey])
                if (spec) specs.push(spec)
            }
        }
        return specs
    }

    // remove KS:Text=... directives so normal technique matching doesn't see tag contents
    function stripKsTextDirectives(rawText) {
        var s = normalizeTextBasic(rawText)
        var lower = s.toLowerCase()
        var out = ""
        var pos = 0

        while (true) {
            var idx = lower.indexOf("ks:text", pos)
            if (idx < 0) {
                out += s.substring(pos)
                break
            }

            // keep everything before the directive
            out += s.substring(pos, idx)

            // advance i to just after "ks:text"
            var i = idx + 7
            while (i < s.length && s[i] === " ") i++

            // optional '=' and spaces
            if (i < s.length && s[i] === "=") {
                i++
                while (i < s.length && s[i] === " ") i++
            }

            // now skip the value (quoted or single token)
            if (i >= s.length) { pos = s.length; break }

            var ch = s[i]
            if (ch === '"' || ch === "'") {
                var q = ch
                i++
                var j = s.indexOf(q, i)
                pos = (j === -1) ? s.length : (j + 1)
            } else {
                var j2 = i
                while (j2 < s.length && s[j2] !== " ") j2++
                pos = j2
            }
        }

        return out
    }

    function stripKsTextDirectivesFromList(texts) {
        var out = []
        for (var i = 0; i < texts.length; ++i)
            out.push(stripKsTextDirectives(texts[i]))
        return out
    }

    // ---- KS:Scope / KS:Parts ----
    function parseScopeTag(rawText) {
        var s = normalizeTextBasic(rawText).toLowerCase()
        var idx = s.indexOf("ks:scope"); if (idx < 0) return ""
        var i = idx + 8; while (i < s.length && s[i] === ' ') i++
        if (i < s.length && s[i] === '=') { i++; while (i < s.length && s[i] === ' ') i++ }
        var val = s.substring(i).trim(); if (!val) return ""
        if (val[0]==='"' || val[0]==="'") { var q=val[0]; var j=val.indexOf(q,1); val=(j===-1)?val.slice(1):val.slice(1,j) } else { var sp=val.indexOf(' '); if (sp>0) val=val.substring(0,sp) }
        return (val==="part"||val==="staff") ? val : ""
    }

    function parsePartsTag(rawText) {
        var s = normalizeTextBasic(rawText).toLowerCase()
        var idx = s.indexOf("ks:parts"); if (idx < 0) return ""
        var i = idx + 8; while (i < s.length && s[i] === ' ') i++
        if (i < s.length && s[i] === '=') { i++; while (i < s.length && s[i] === ' ') i++ }
        var val = s.substring(i).trim(); if (!val) return ""
        if (val[0]==='"' || val[0]==="'") { var q=val[0]; var j=val.indexOf(q,1); val=(j===-1)?val.slice(1):val.slice(1,j) } else { var sp=val.indexOf(' '); if (sp>0) val=val.substring(0,sp) }
        return (val==="all"||val==="anchor") ? val : ""
    }

    function scopeOverrideInSelection(startStaff, endStaff, startTick, endTick) {
        var scopeVal = "", partsVal = ""
        for (var s = startStaff; s <= endStaff; ++s) {
            var c = curScore.newCursor(); c.track = s*4; c.rewindToTick(startTick)
            while (c.tick < endTick) {
                var seg = c.segment
                if (seg) {
                    if (seg.annotations) {
                        for (var ai in seg.annotations) {
                            var ann = seg.annotations[ai]
                            var annStaff = (ann.track === -1) ? s : Math.floor(ann.track/4)
                            if ((ann.type === Element.STAFF_TEXT || ann.type === Element.SYSTEM_TEXT || ann.type === Element.EXPRESSION_TEXT) && annStaff === s) {
                                if (!scopeVal) scopeVal = parseScopeTag(ann.text || "")
                                if (!partsVal) partsVal = parsePartsTag(ann.text || "")
                                if (scopeVal && partsVal) return { scope: scopeVal, parts: partsVal }
                            }
                        }
                    }
                    for (var v=0; v<4; ++v) {
                        var el = seg.elementAt ? seg.elementAt(s*4+v) : null
                        if (el && el.type === Element.CHORD && el.notes) {
                            for (var ni in el.notes) {
                                var note = el.notes[ni]; if (!note.elements) continue
                                for (var ei in note.elements) {
                                    var nel = note.elements[ei]
                                    if (nel.type === Element.TEXT) {
                                        if (!scopeVal) scopeVal = parseScopeTag(nel.text || "")
                                        if (!partsVal) partsVal = parsePartsTag(nel.text || "")
                                        if (scopeVal && partsVal) return { scope: scopeVal, parts: partsVal }
                                    }
                                }
                            }
                        }
                    }
                }
                if (!c.next()) break
            }
        }
        return { scope: scopeVal, parts: partsVal }
    }

    function activeSetNameFor(staffIdx, tick) {
        var tl = setTagTimeline[staffIdx] || []
        for (var i = tl.length - 1; i >= 0; --i) {
            if (tl[i].tick <= tick) {
                var name = tl[i].setName
                if (keyswitchSets[name]) return name
                break
            }
        }
        var assigned = staffToSet[staffIdx.toString()]
        return (assigned && keyswitchSets[assigned]) ? assigned : ""   // no implicit default
    }

    function segmentTechniqueTexts(chord) {
        var out = []
        var seg = chord.parent

        // Segment-level Staff/System/Expression text
        if (seg && seg.annotations) {
            for (var i in seg.annotations) {
                var ann = seg.annotations[i]

                // DIAG: what is actually in seg.annotations at this chord?
                try {
                    dbg("ann@tick=" + (seg ? seg.tick : -1)
                        + " staff=" + chord.staffIdx
                        + " count=" + (seg && seg.annotations ? seg.annotations.length : 0));
                    if (seg && seg.annotations) {
                        for (var di = 0; di < seg.annotations.length; ++di) {
                            var a = seg.annotations[di];
                            var aType = (a && a.type !== undefined) ? a.type : -999;
                            var aName = "";
                            try { aName = a.userName ? a.userName().toString() : ""; } catch (e) {}
                            var aText = "";
                            try { aText = (a.text !== undefined) ? normalizeTextBasic(a.text) : ""; } catch (e2) {}
                            var aTrack = -999, aStaffIdx = -999;
                            try { aTrack = (a.track !== undefined) ? a.track : -999; } catch (e3) {}
                            try { aStaffIdx = (a.staffIdx !== undefined) ? a.staffIdx : -999; } catch (e4) {}

                            dbg("ann  type=" + aType
                                + " userName=" + aName
                                + " track=" + aTrack
                                + " staffIdx=" + aStaffIdx
                                + " text='" + aText + "'");
                        }
                    }
                } catch (e) { dbg("ann DIAG error: " + e); }

                // Accept Staff/System/Expression text AND palette "Playing technique annotation".
                // Observed in your log: "Playing technique annotation" has type=57 on this build.
                var isPlayTech = false
                try {
                    var un = ann.userName ? String(ann.userName()).toLowerCase() : ""
                    isPlayTech = un.indexOf("playing technique annotation") >= 0
                } catch (e) {}

                if (ann.type === Element.STAFF_TEXT
                        || ann.type === Element.SYSTEM_TEXT
                        || ann.type === Element.EXPRESSION_TEXT
                        || ann.type === 57                      // playing technique annotation (observed)
                        || isPlayTech) {                        // name-based fallback

                    // Determine staff for this annotation (best effort)
                    var annStaffIdx = -1
                    try {
                        if (ann.track !== undefined && ann.track !== -1) {
                            annStaffIdx = Math.floor(ann.track / 4)
                        } else if (ann.staffIdx !== undefined) {
                            annStaffIdx = ann.staffIdx
                        } else if (ann.type === Element.STAFF_TEXT || ann.type === Element.EXPRESSION_TEXT) {
                            // Palette-drag: no track/staffIdx in annotations; treat as current chord's staff
                            annStaffIdx = chord.staffIdx
                        }
                    } catch (e) { annStaffIdx = -1 }

                    // after computing annStaffIdx
                    dbg("ann staff decision: annType=" + ann.type
                        + " chordStaff=" + chord.staffIdx
                        + " annStaff=" + annStaffIdx);

                    // SYSTEM_TEXT is global; Staff/Expression must match the chord's staff
                    var staffOk = (ann.type === Element.SYSTEM_TEXT) || (annStaffIdx === chord.staffIdx)
                    if (staffOk) {
                        var norm = normalizeTextBasic(ann.text).toLowerCase().trim()
                        // just before pushing norm:
                        dbg("ann accepted: '" + norm + "'");
                        if (norm.length) out.push(norm)
                    }
                }
            }
        }

        // Note-attached plain text
        if (chord.notes) {
            for (var j in chord.notes) {
                var note = chord.notes[j]
                if (!note.elements) continue
                for (var k in note.elements) {
                    var nel = note.elements[k]
                    if (nel.type === Element.TEXT) {
                        var txt = normalizeTextBasic(nel.text).toLowerCase().trim()
                        if (txt.length) out.push(txt)
                    }
                }
            }
        }
        return out
    }

    function chordArticulationNames(chord) {
        var names=[]; if (!chord.articulations) return names
        for (var i in chord.articulations) {
            var a=chord.articulations[i]
            var raw=((a.articulationName?a.articulationName():"")+" "+(a.userName?a.userName():"")+" "+(a.subtypeName?a.subtypeName():"")).toLowerCase()

            var n="";
            if (raw.indexOf("staccatissimo")>=0) n="staccatissimo";
            else if (raw.indexOf("staccato")>=0) n="staccato";
            else if (raw.indexOf("tenuto")>=0) n="tenuto";
            else if (raw.indexOf("accent")>=0) n="accent";
            else if (raw.indexOf("marcato")>=0) n="marcato";
            else if (raw.indexOf("sforzato")>=0 || raw.indexOf("sfz")>=0) n="sforzato";
            else if (raw.indexOf("loure")>=0 || raw.indexOf("tenuto-staccato")>=0) n="loure";
            else if (raw.indexOf("fermata")>=0) n="fermata";
            // ornaments as "articulations"
            else if (raw.indexOf("trill")>=0) n="trill";
            else if (raw.indexOf("mordent inverted")>=0 || raw.indexOf("prallprall")>=0) n="mordent inverted";
            else if (raw.indexOf("mordent")>=0) n="mordent";
            else if (raw.indexOf("turn")>=0) n="turn";

            if (!n) n="unknown";
            names.push(n)
        }
        return names
    }

    function ensureWritableSlot(c, num, den) {
        var t=c.fraction
        c.setDuration(num,den)
        try { c.addRest() } catch(e) { dbg("ensureWritableSlot: addRest failed at "+t.numerator+"/"+t.denominator) }
        c.rewindToFraction(t)
    }

    function escapeRegex(s) { return s.replace(/[\\\-\\/\\^$*+?.()\\[\\]{}]/g,'\\$&') }

    // --- parse per-keyswitch velocity ---
    // Accepts:
    //    26          -> { pitch:26, velocity: defaultKsVelocity }
    //   "26|127"     -> { pitch:26, velocity:127 }
    //   "26"         -> { pitch:26, velocity: defaultKsVelocity }
    // (Future-proofing: if someone later uses {pitch:26, velocity:127} it will also work.)
    function clampInt(v, lo, hi) {
        var n = parseInt(v, 10)
        if (isNaN(n)) return lo
        return Math.max(lo, Math.min(hi, n))
    }

    function parseKsMapValue(v) {
        var pitch = null
        var vel = defaultKsVelocity

        if (typeof v === "number") {
            pitch = parseInt(v, 10)
        } else if (typeof v === "string") {
            var s = v.trim()
            var parts = s.split("|")
            pitch = parseInt(parts[0], 10)
            if (parts.length > 1 && parts[1].trim().length)
                vel = parseInt(parts[1], 10)
        } else if (v && typeof v === "object") {
            // Not advertised yet, but harmless to support for future schema expansion
            if (v.pitch !== undefined) pitch = parseInt(v.pitch, 10)
            else if (v.note !== undefined) pitch = parseInt(v.note, 10)
            if (v.velocity !== undefined) vel = parseInt(v.velocity, 10)
            else if (v.vel !== undefined) vel = parseInt(v.vel, 10)
        }

        if (pitch === null || isNaN(pitch)) return null
        pitch = clampInt(pitch, 0, 127)
        vel = clampInt(vel, 0, 127)
        return { pitch: pitch, velocity: vel }
    }

    // Apply absolute velocity to a Note in a version-tolerant way.
    // MS4: note.userVelocity (forum reports veloOffset doesn't work there) [3](https://musescore.org/en/node/378892)
    // MS3: note.veloType + note.veloOffset (plugin docs) [1](https://musescore.github.io/MuseScore_PluginAPI_Docs/plugins/html/class_ms_1_1_plugin_a_p_i_1_1_note.html)[2](https://github.com/musescore/MuseScore/blob/master/docs/plugins2to3.md)
    function setKeyswitchNoteVelocity(note, velocity) {
        var v = clampInt(velocity, 0, 127)

        // MuseScore Studio 4+
        try {
            if (note.userVelocity !== undefined) {
                note.userVelocity = v
                return true
            }
        } catch (e) { }

        // MuseScore 3.x
        try {
            note.veloType = NoteValueType.USER_VAL
            note.veloOffset = v
            return true
        } catch (e2) { }

        return false
    }

    // Build a "token" regex that matches alias surrounded by start/end or any non-word char.
    // Works for abbreviations with punctuation (e.g., "nor.", "ord.", "con sord.", etc.).
    function tokenRegex(alias) {
        var core = escapeRegex(String(alias||""))
        // Left boundary: start of string OR a non-word (not [A-Za-z0-9_])
        // Right boundary: non-word OR end of string
        return new RegExp('(?:^|[^A-Za-z0-9_])' + core + '(?:[^A-Za-z0-9_]|$)')
    }

    function findTechniqueKeyswitches(texts, techMap, aliasMap) {
        var specs = []
        if (!techMap) return specs
        var aliasFor = aliasMap || {}

        for (var key in techMap) {
            var spec = parseKsMapValue(techMap[key])
            if (!spec) continue

            var aliases = aliasFor[key] || [key]
            var rx = []
            for (var i=0; i<aliases.length; ++i)
                rx.push(tokenRegex(aliases[i]))

            for (var ti=0; ti<texts.length; ++ti) {
                var t = texts[ti]
                for (var ri=0; ri<rx.length; ++ri) {
                    if (rx[ri].test(t)) { specs.push(spec); break }
                }
            }
        }
        return specs
    }

    // map known aliases explicitly
    function findArticulationKeyswitches(artiNames, artiMap) {
        var specs = []
        if (!artiMap) return specs

        for (var i=0; i<artiNames.length; ++i) {
            var k = artiNames[i]

            function pushKey(name) {
                if (!artiMap || !artiMap.hasOwnProperty(name)) return
                var spec = parseKsMapValue(artiMap[name])
                if (spec) specs.push(spec)
            }

            if (artiMap.hasOwnProperty(k)) pushKey(k)
            else if (k.indexOf("tenuto")>=0) pushKey("tenuto")
            else if (k.indexOf("stacc")>=0) pushKey("staccato")
            else if (k.indexOf("accent")>=0) pushKey("accent")
            else if (k.indexOf("marcato")>=0) pushKey("marcato")
        }
        return specs
    }

    function keyswitchExistsAt(cursor, pitch) { if (!cursor.element || cursor.element.type !== Element.CHORD) return false; var chord=cursor.element; for (var i in chord.notes) if (chord.notes[i].pitch===pitch) return true; return false }

    function addKeyswitchNoteAt(sourceChord, pitch, velocity, firstOfChord, activeSet) {
        var track = sourceChord.track
        var startFrac = sourceChord.fraction
        var srcStaff = staffIdxFromTrack(track)
        var tgtStaff = targetStaffForKeyswitch(srcStaff)
        if (tgtStaff < 0) { preflightFailed = true; return false }

        var c = curScore.newCursor(); c.track = tgtStaff*4; c.rewindToFraction(startFrac)

        var policy = (activeSet && activeSet.durationPolicy) ? activeSet.durationPolicy : (globalSettings && globalSettings.durationPolicy) ? globalSettings.durationPolicy : (useSourceDuration ? "source" : "fixed")
        var dur = sourceChord.actualDuration
        var num = (policy === "source" && dur) ? dur.numerator : ksNumerator
        var den = (policy === "source" && dur) ? dur.denominator : ksDenominator
        if (!num || !den) { num = ksNumerator; den = ksDenominator }

        c.setDuration(num, den)
        if (dedupeAcrossVoices && firstOfChord && wasEmittedCross(c.staffIdx, c.tick)) return false

        // Only create a writable slot if there is nothing (or something unexpected) at this position.
        // IMPORTANT: ensureWritableSlot() adds a rest, which would overwrite an existing chord.
        var existing = c.element
        var existingIsChord = (existing && existing.type === Element.CHORD)
        var existingIsRest  = (existing && existing.type === Element.REST)
        if (!existing || (!existingIsChord && !existingIsRest))
            ensureWritableSlot(c, num, den)

        if (skipIfExists && keyswitchExistsAt(c, pitch)) return false

        // If a chord already exists here, stack into it. Otherwise create a new chord.
        var addToChord = existingIsChord
        try { c.addNote(pitch, addToChord) } catch(e) { dbg("addNote failed at tick="+c.tick+" pitch="+pitch); return false }
        c.rewindToFraction(startFrac)
        if (!keyswitchExistsAt(c, pitch)) { dbg("post-add verification failed at tick="+c.tick+" pitch="+pitch); return false }

        if (dedupeAcrossVoices && firstOfChord)
            markEmittedCross(c.staffIdx, c.tick)

        // apply velocity (and optionally hide) to the note we just inserted
        if (c.element && c.element.type === Element.CHORD) {
            var ch = c.element
            if (ch.notes) {
                for (var i in ch.notes) {
                    var nn = ch.notes[i]
                    if (nn.pitch === pitch) {
                        // Apply absolute velocity
                        setKeyswitchNoteVelocity(nn, velocity)
                        // Preserve existing behavior
                        if (hideKeyswitchNotes) { try { nn.visible = false } catch(e){} }
                    }
                }
            }
        }

        return true
    }

    function crossKey(staffIdx, tick) { return staffIdx+":"+tick }

    function wasEmittedCross(staffIdx, tick) { return emittedCross.hasOwnProperty(crossKey(staffIdx,tick)) }

    function markEmittedCross(staffIdx, tick) { emittedCross[crossKey(staffIdx,tick)] = true }

    function computeAllowedSourceStaves(startStaff, endStaff, effScope, effPartsMode) {
        var allowed = {}
        var anchorPartIdx = -1
        var piAnchor = partInfoForStaff(startStaff); if (piAnchor) anchorPartIdx = piAnchor.index
        dbg("parts: effective='"+effPartsMode+"' anchorPartIdx="+anchorPartIdx)

        if (startStaff === endStaff) { allowed[startStaff] = true; return allowed }

        var perPart = {}
        for (var s=startStaff; s<=endStaff; ++s) {
            var pi = partInfoForStaff(s); if (!pi) continue
            if (effPartsMode === "anchor" && pi.index !== anchorPartIdx) continue
            var arr = perPart[pi.index]; if (!arr) { arr=[]; perPart[pi.index]=arr }
            arr.push(s)
        }

        for (var pidx in perPart) {
            var arr = perPart[pidx]
            if (effScope === "part") { for (var i=0;i<arr.length;++i) allowed[arr[i]] = true }
            else { for (var i3=0; i3<arr.length; ++i3) allowed[arr[i3]] = true }
        }
        return allowed
    }

    function processSelection() {
        emittedCross = ({}); preflightFailed=false; sawIneligible=false; firstIneligibleStaffIdx=-1
        var ineligiblePartIdx = {}
        dbg("processSelection: begin")

        var chords=[]
        if (curScore.selection.isRange) {
            var startTick = curScore.selection.startSegment.tick
            var endTick   = curScore.selection.endSegment ? curScore.selection.endSegment.tick : curScore.lastSegment.tick + 1
            var startStaff = curScore.selection.startStaff
            // MuseScore selection.endStaff behaves as an exclusive bound; convert to inclusive for our <= loops
            var endStaffInc = Math.max(startStaff, curScore.selection.endStaff - 1)
            // Expand staff bounds with any text elements present in the selection (palette-drag or Cmd+T)
            var selMin =  99999
            var selMax = -1
            for (var ei in curScore.selection.elements) {
                var el = curScore.selection.elements[ei]
                var sIdx = -1
                try {
                    if (el.track !== undefined && el.track !== -1) sIdx = Math.floor(el.track / 4)
                    else if (el.staffIdx !== undefined) sIdx = el.staffIdx
                } catch (e) { sIdx = -1 }
                if (sIdx >= 0) {
                    if (sIdx < selMin) selMin = sIdx
                    if (sIdx > selMax) selMax = sIdx
                }
            }
            if (selMax >= 0) {
                if (selMin < startStaff) startStaff = selMin
                if (selMax > endStaffInc) endStaffInc = selMax
            }
            var overrides = scopeOverrideInSelection(startStaff, endStaffInc, startTick, endTick)
            var effScope  = overrides.scope ? overrides.scope : rangeScopeMode
            var effParts  = overrides.parts ? overrides.parts : selectionPartMode

            // any multi‑part range selection (regardless of which staff it starts on) processes all touched parts
            // unless explicitly overridden by a ks:parts tag
            var partsTouched = {}
            for (var sX = startStaff; sX <= endStaffInc; ++sX) { var pX = partInfoForStaff(sX); if (pX) partsTouched[pX.index] = true }
            var touchedCount = 0; for (var k in partsTouched) touchedCount++
            dbg("selection parts touched="+touchedCount+" / totalParts="+partCount())

            // Auto-widen whenever a range selection spans multiple parts,
            // unless explicitly overridden by a ks:parts tag in the selection.
            if (!overrides.parts && touchedCount>1) {
                effParts = "all"
                dbg("parts: auto-widen to 'all' (multi-part selection)")
            }

            var allowedMap = computeAllowedSourceStaves(startStaff, endStaffInc, effScope, effParts)
            dbg("scope: effective='"+effScope+"' parts: effective='"+effParts+"'")
            dbg("allowed source staves: "+Object.keys(allowedMap).sort().join(", "))

            for (var s = startStaff; s <= endStaffInc; ++s) {
                if (!allowedMap[s]) continue
                for (var v=0; v<4; ++v) {
                    var c=curScore.newCursor(); c.track=s*4+v; c.rewindToTick(startTick)
                    while (c.tick < endTick) {
                        var el=c.element
                        if (el && el.type===Element.CHORD && el.noteType===NoteType.NORMAL) {
                            var sIdx=el.staffIdx
                            var ok=isEligibleSourceStaff(sIdx)
                            dbg("scan: staff="+sIdx+" eligible="+ok)
                            if (ok) chords.push(el); else { sawIneligible=true; if (firstIneligibleStaffIdx<0) firstIneligibleStaffIdx=sIdx; var pi=partInfoForStaff(sIdx); if (pi) ineligiblePartIdx[pi.index]=true }
                        }
                        if (!c.next()) break
                    }
                }
            }
        } else {
            for (var i in curScore.selection.elements) {
                var el=curScore.selection.elements[i]
                var chord=null; if (el.type==Element.NOTE && el.parent && el.parent.type==Element.CHORD) chord=el.parent; else if (el.type==Element.CHORD) chord=el; else continue
                if (chord.noteType !== NoteType.NORMAL) continue
                var sIdx2=chord.staffIdx; var ok2=isEligibleSourceStaff(sIdx2)
                dbg("scan(list): staff="+sIdx2+" eligible="+ok2)
                if (ok2) chords.push(chord); else { sawIneligible=true; if (firstIneligibleStaffIdx<0) firstIneligibleStaffIdx=sIdx2; var pi2=partInfoForStaff(sIdx2); if (pi2) ineligiblePartIdx[pi2.index]=true }
            }
        }

        dbg2("chords collected", chords.length)
        collectSetTagsInRange()

        chords.sort(function(a,b){ if (a.fraction.lessThan(b.fraction)) return -1; if (a.fraction.greaterThan(b.fraction)) return 1; var pref=(typeof preferVoiceForKSInsertion!=="undefined")?preferVoiceForKSInsertion:0; var da=Math.abs(a.voice-pref), db=Math.abs(b.voice-pref); if (da!==db) return da-db; return a.track-b.track })

        var created=0
        for (var k in chords) {
            var chord=chords[k]
            var tickHere=(chord.parent && chord.parent.tick)?chord.parent.tick:0
            var setName = activeSetNameFor(chord.staffIdx, tickHere)

            if (!setName) {
                // No active set by tag or assignment => do not create keyswitches
                dbg("skip: no active set for staff="+chord.staffIdx+" tick="+tickHere);
                continue
            }
            var activeSet = keyswitchSets[setName]
            if (!activeSet) {
                // Defensive: unknown/removed set name => skip
                continue
            }

            var texts      = segmentTechniqueTexts(chord)
            dbg("texts@tick=" + tickHere + " staff=" + chord.staffIdx + " => " + texts.join(" | "))
            var artiNames  = chordArticulationNames(chord)
            var specs   = []

            // Only use maps from the active set; no global fallback
            var techMap    = activeSet.techniqueKeyMap || null
            var aliasMap   = activeSet.techniqueAliases
            if (!aliasMap && globalSettings && globalSettings.techniqueAliases)
                aliasMap = globalSettings.techniqueAliases

            specs = specs.concat(findTaggedTechniqueKeyswitches(texts, techMap))
            var textsNoKsText = stripKsTextDirectivesFromList(texts)
            specs = specs.concat(findTechniqueKeyswitches(textsNoKsText, techMap, aliasMap))
            specs = specs.concat(findArticulationKeyswitches(artiNames, activeSet.articulationKeyMap || null))

            var seen = {}
            for (var j = 0; j < specs.length; ++j) {
                var spec = specs[j]

                if (!spec) continue

                var p = spec.pitch
                if (seen[p]) continue

                var first = (j === 0)
                if (addKeyswitchNoteAt(chord, p, spec.velocity, first, activeSet))
                    created++

                if (preflightFailed) break
                seen[p] = true
            }
        }

        var partialParts = []
        if (created>0 && warnOnPartialSuccess) {
            for (var idx in ineligiblePartIdx) {
                if (ineligiblePartIdx[idx]) {
                    var idxNum = parseInt(idx, 10)
                    for (var s=0; s<curScore.staves.length; ++s) {
                        var pi=partInfoForStaff(s);
                        if (pi && pi.index === idxNum) {
                            partialParts.push(nameForPartByRange(s,0)); break
                        }
                    }
                }
            }
        }

        dbg("processSelection: createdCount="+created+" sawIneligible="+sawIneligible+" preflightFailed="+preflightFailed+" partialParts="+partialParts.join(", "))

        if (!preflightFailed && created==0 && sawIneligible && !promptShown) {
            promptShown=true
            var n=nameForPartByRange(firstIneligibleStaffIdx>=0?firstIneligibleStaffIdx:0,0)
            ksStaffPrompt.title = qsTr("Keyswitch staff not found")
            ksStaffPrompt.text  = qsTr("The staff directly below %1 does not belong to the same instrument. Create another staff below %1 then rerun Keyswitch Creator.").arg(n)
            try { ksStaffPrompt.open() } catch(e) { try { ksStaffPrompt.visible=true } catch(e2){} }
        } else if (!preflightFailed && created>0 && partialParts.length>0 && !promptShown && warnOnPartialSuccess) {
            promptShown=true
            ksStaffPrompt.title = qsTr("Some parts had no keyswitch staff")
            ksStaffPrompt.text  = qsTr("No keyswitches were added for: %1. Add a keyswitch staff below those parts, then rerun Keyswitch Creator.").arg(partialParts.join(", "))
            try { ksStaffPrompt.open() } catch(e) { try { ksStaffPrompt.visible=true } catch(e2){} }
        }
        return created
    }

    MessageDialog { id: ksStaffPrompt; title: ""; text: ""; onAccepted: { quit() } }

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
            savedSelection = (function(){
                if (!curScore.selection.elements.length) return false
                if (curScore.selection.isRange) {
                    var obj={isRange:true,startSegment:curScore.selection.startSegment.tick,endSegment:curScore.selection.endSegment?curScore.selection.endSegment.tick:curScore.lastSegment.tick+1,startStaff:curScore.selection.startStaff,endStaff:curScore.selection.endStaff}
                    dbg("readSelection: range ticks "+obj.startSegment+"…"+obj.endSegment+", staffs "+obj.startStaff+"–"+obj.endStaff)
                    return obj
                }
                var list={isRange:false,elements:[]}
                for (var i in curScore.selection.elements) list.elements.push(curScore.selection.elements[i])
                dbg("readSelection: list with "+list.elements.length+" elements")
                return list
            })()

            var count = processSelection()
            curScore.selection.clear()
            if (savedSelection && savedSelection.isRange) { dbg("writeSelection: restoring range"); curScore.selection.selectRange(savedSelection.startSegment, savedSelection.endSegment, savedSelection.startStaff, savedSelection.endStaff) }
            else if (savedSelection && !savedSelection.isRange) { for (var i in savedSelection.elements) curScore.selection.select(savedSelection.elements[i], true) }
            curScore.endCmd()
            dbg2("onRun: end, keyswitches added", count)
        } catch (e) {
            curScore.endCmd(true)
            dbg("ERROR: "+e.toString())
        }
        quit()
    }

}
