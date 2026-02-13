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

    categoryCode: "Keyswitch Creator"
    description: qsTr("Creates keyswitch notes on a staff below in the same instrument.")
    thumbnailName: "keyswitch_creator.png"
    title: qsTr("Keyswitch Creator")
    version: "0.9.7"

    // Articulations (note-attached symbols)
    property var articulationKeyMap: ({
                                          "slur": 0,
                                          "accent": 1,
                                          "staccato": 2,
                                          "staccatissimo": 3,
                                          "tenuto": 4,
                                          "loure": 5,
                                          "marcato": 6,
                                          "accent-staccato": 7,
                                          "marcato-staccato": 8,
                                          "marcato-tenuto": 9,
                                          "staccatissimo stroke": 10,
                                          "staccatissimo wedge": 11,
                                          "stress": 12,
                                          "tenuto-accent": 13,
                                          "unstress": 14,
                                          "open": 15,
                                          "muted": 16,
                                          "harmonic": 17,
                                          "up bow": 18,
                                          "down bow": 19,
                                          "soft accent": 20,
                                          "soft accent-staccato": 21,
                                          "soft accent-tenuto": 22,
                                          "soft accent-tenuto-staccato": 23,
                                          "fade in": 24,
                                          "fade out": 25,
                                          "volume swell": 26,
                                          "sawtooth line segment": 27,
                                          "wide sawtooth line segment": 28,
                                          "snap pizzicato": 29,
                                          "half-open 2": 30,
                                          "trill": 31,
                                          "trill line": 32,
                                          "fall": 36,
                                          "doit": 37,
                                          "plop": 38,
                                          "scoop": 39,
                                          "slide out down": 40,
                                          "slide out up": 41,
                                          "slide in above": 42,
                                          "slide in below": 43
                                      })

    // Techniques (written)
    property var techniqueKeyMap: ({
                                       "arco": 44,
                                       "normal": 45,
                                       "legato": 46,
                                       "pizz.": 47,
                                       "tremolo": 48,
                                       "vibrato": 49,
                                       "col legno": 50,
                                       "harmonics": 51,
                                       "sul pont.": 52,
                                       "sul tasto": 53,
                                       "mute": 54,
                                       "open": 55,
                                       "détaché": 56,
                                       "martelé": 57,
                                       "jazz tone": 58,
                                       "distort": 59,
                                       "overdrive": 60,
                                       "vibrato large faster": 33,
                                       "vibrato large slowest": 34,
                                       "tremolo bar": 35
                                   })

    // Debug
    property bool debugEnabled: true
    property bool dedupeAcrossVoices: true

    // Global Settings
    property var defaultGlobalSettings: ({
                                             durationPolicy: "source",
                                             formatKeyswitchStaff: "true",
                                             techniqueAliases: {
                                                 // phrasing
                                                 "legato": ["legato", "leg.", "slur", "slurred"],
                                                 "normal": ["normal", "normale", "norm.", "nor.", "ordinary", "ord.", "standard", "std."],
                                                 // mutes
                                                 "con sord": ["con sord", "con sord.", "con sordino", "sord", "sord.", "with mute", "mute",
                                                     "muted", "stopped"],
                                                 "senza sord": ["senza sord", "senza sord.", "senza sordino", "open"],
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
                                         })

    // Registry
    // Slur is a spanner element entered via the Lines system / shortcut S
    // It’s not an articulation
    property var defaultKeyswitchSets: ({
                                            "Default": {
                                                articulationKeyMap: {
                                                    "slur": 0,
                                                    "accent": 1,
                                                    "staccato": 2,
                                                    "staccatissimo": 3,
                                                    "tenuto": 4,
                                                    "loure": 5,
                                                    "marcato": 6,
                                                    "accent-staccato": 7,
                                                    "marcato-staccato": 8,
                                                    "marcato-tenuto": 9,
                                                    "staccatissimo stroke": 10,
                                                    "staccatissimo wedge": 11,
                                                    "stress": 12,
                                                    "tenuto-accent": 13,
                                                    "unstress": 14,
                                                    "open": 15,
                                                    "muted": 16,
                                                    "harmonic": 17,
                                                    "up bow": 18,
                                                    "down bow": 19,
                                                    "soft accent": 20,
                                                    "soft accent-staccato": 21,
                                                    "soft accent-tenuto": 22,
                                                    "soft accent-tenuto-staccato": 23,
                                                    "fade in": 24,
                                                    "fade out": 25,
                                                    "volume swell": 26,
                                                    "sawtooth line segment": 27,
                                                    "wide sawtooth line segment": 28,
                                                    "snap pizzicato": 29,
                                                    "half-open 2": 30,
                                                    "trill": 31,
                                                    "trill line": 32,
                                                    "fall": 36,
                                                    "doit": 37,
                                                    "plop": 38,
                                                    "scoop": 39,
                                                    "slide out down": 40,
                                                    "slide out up": 41,
                                                    "slide in above": 42,
                                                    "slide in below": 43
                                                },
                                                techniqueKeyMap: {
                                                    "arco": 44,
                                                    "normal": 45,
                                                    "legato": 46,
                                                    "pizz.": 47,
                                                    "tremolo": 48,
                                                    "vibrato": 49,
                                                    "col legno": 50,
                                                    "harmonics": 51,
                                                    "sul pont.": 52,
                                                    "sul tasto": 53,
                                                    "mute": 54,
                                                    "open": 55,
                                                    "détaché": 56,
                                                    "martelé": 57,
                                                    "jazz tone": 58,
                                                    "distort": 59,
                                                    "overdrive": 60,
                                                    "vibrato large faster": 33,
                                                    "vibrato large slowest": 34,
                                                    "tremolo bar": 35
                                                }
                                            },
                                            "English Horn": {
                                                "articulationKeyMap": {
                                                    "staccatissimo": 115,
                                                    "tenuto": 116,
                                                    "loure": 117,
                                                    "marcato": 118,
                                                    "accent-staccato": 119,
                                                    "marcato-staccato": 120,
                                                    "marcato-tenuto": 121,
                                                    "staccatissimo stroke": 122
                                                },
                                                "techniqueKeyMap": {
                                                    "arco": 123,
                                                    "normal": 124,
                                                    "legato": 125,
                                                    "pizz.": 126,
                                                    "tremolo": 127
                                                }
                                            }
                                        })

    property int defaultKsVelocity: 64
    property var emittedCross: ({})
    property int firstIneligibleStaffIdx: -1
    property var globalSettings: defaultGlobalSettings
    property bool hideKeyswitchNotes: false
    property var keyswitchSets: defaultKeyswitchSets
    property int ksDenominator: 16
    property int ksNumerator: 1
    property int preferVoiceForKSInsertion: 0
    property bool preflightFailed: false
    property bool promptShown: false

    // Within-part and multi-part handling
    property string rangeScopeMode: "staff" // "staff" or "part"

    // Internal
    property bool savedSelection: false
    property bool sawIneligible: false
    property string selectionPartMode: "anchor" // "anchor" or "all"
    property var setTagTimeline: ({})
    property bool skipIfExists: true
    property var slurStartByStaff: ({})
    property var effectStartByStaff: ({})   // staffIdx(string) -> { tick -> ["fade in", "tremolo bar", ...] }
    property var effectRangeByStaff: ({})    // staffIdx(string) -> [{start: tStart, end: tEnd, tokens: ["..."]}, ...]
    property var staffToSet: ({})
    property string staffToSetMetaTagKey: "keyswitch_creator.staffToSet"
    property var formattedKsStaff: ({}) // staffIdx (string) -> true once formatted this run

    property bool useSourceDuration: true
    property bool warnOnPartialSuccess: true

    // Optional: interpret graphical slurs as a 'legato' trigger (best-effort).
    // If MuseScore doesn't expose slur spanners to plugins, this has no effect.
    property bool interpretSlurAsLegato: true

    function activeSetNameFor(staffIdx, tick) {
        var tl = setTagTimeline[staffIdx] || []
        for (var i = tl.length - 1; i >= 0; --i) {
            if (tl[i].tick <= tick) {
                var name = tl[i].setName
                if (keyswitchSets[name])
                    return name
                break
            }
        }
        var assigned = staffToSet[staffIdx.toString()]
        return (assigned && keyswitchSets[assigned]) ? assigned : ""
    }

    function addKeyswitchNoteAt(sourceChord, pitch, velocity, firstOfChord, activeSet) {
        var track = sourceChord.track
        var startFrac = sourceChord.fraction
        var srcStaff = staffIdxFromTrack(track)
        var tgtStaff = targetStaffForKeyswitch(srcStaff)
        if (tgtStaff < 0) {
            preflightFailed = true
            return false
        }

        var c = curScore.newCursor()
        c.track = tgtStaff * 4
        c.rewindToFraction(startFrac);

        // one switch for KS note/chord visual formatting in this function
        var fmtEnabled = (globalSettings && globalSettings.formatKeyswitchStaff !== undefined) ? globalSettings.formatKeyswitchStaff :
                                                                                                 "true"
        var fmtOn = flagIsTrue(fmtEnabled)

        var policy = (activeSet && activeSet.durationPolicy) ? activeSet.durationPolicy : (globalSettings && globalSettings.durationPolicy)
                                                               ? globalSettings.durationPolicy : (useSourceDuration ? "source" : "fixed")
        var dur = sourceChord.actualDuration
        var num = (policy === "source" && dur) ? dur.numerator : ksNumerator
        var den = (policy === "source" && dur) ? dur.denominator : ksDenominator
        if (!num || !den) {
            num = ksNumerator
            den = ksDenominator
        }

        c.setDuration(num, den)
        if (dedupeAcrossVoices && firstOfChord && wasEmittedCross(c.staffIdx, c.tick))
            return false

        // only create a writable slot if there is nothing (or something unexpected) at this position.
        // ensureWritableSlot() adds a rest, which would overwrite an existing chord.
        var existing = c.element
        var existingIsChord = (existing && existing.type === Element.CHORD)
        var existingIsRest = (existing && existing.type === Element.REST)
        if (!existing || (!existingIsChord && !existingIsRest))
            ensureWritableSlot(c, num, den)

        if (skipIfExists && keyswitchExistsAt(c, pitch))
            return false

        // if a chord already exists here, stack into it; otherwise create a new chord.
        var addToChord = existingIsChord
        try {
            c.addNote(pitch, addToChord)
        } catch (e) {
            dbg("addNote failed at tick=" + c.tick + " pitch=" + pitch)
            return false
        }
        c.rewindToFraction(startFrac)
        if (!keyswitchExistsAt(c, pitch)) {
            dbg("post-add verification failed at tick=" + c.tick + " pitch=" + pitch)
            return false
        }

        if (dedupeAcrossVoices && firstOfChord)
            markEmittedCross(c.staffIdx, c.tick);

        // apply velocity, optionally hide, and optionally attach the note we just inserted to staff line
        if (c.element && c.element.type === Element.CHORD) {
            var ch = c.element

            if (fmtOn) {
                try {
                    ch.noStem = true
                } catch (eCH) {}
            }

            try {
                forceNoBeamForChord(ch)
            } catch (eNB1) {}

            if (ch.notes) {
                for (var i in ch.notes) {
                    var nn = ch.notes[i]
                    if (nn.pitch === pitch) {
                        // apply absolute velocity
                        setKeyswitchNoteVelocity(nn, velocity)
                        // preserve existing behavior
                        if (hideKeyswitchNotes) {
                            try {
                                nn.visible = false
                            } catch (e) {}
                        }
                        // stemless fallback on the note, in case staff-level Stemless is unavailable
                        if (fmtOn) {
                            try {
                                nn.noStem = true
                            } catch (eNS) {}
                        }
                        // attach note to staff line
                        if (fmtOn) {
                            try {
                                nn.fixed = true
                                // index 0 (single staff line)
                                // nn.fixedLine = 0
                            } catch (eFix) {}
                        }
                    }
                }
            }
        }

        return true
    }

    function chordArticulationNames(chord) {
        var names = []
        function pushUnique(n) {
            if (n && names.indexOf(n) === -1)
                names.push(n)
        }

        function _hasSeq3(lbl, a, b, c) {

            // tolerate punctuation/extra spaces by normalizing to tokens
            var norm = lbl.replace(/[^a-z0-9]+/g, " ").trim()
            var i = norm.indexOf(a)
            if (i < 0)
                return false
            var j = norm.indexOf(b, i + a.length)
            if (j < 0)
                return false
            var k = norm.indexOf(c, j + b.length)
            return k >= 0
        }

        function _pushJazzFromLabel(lbl) {
            if (!lbl)
                return
            if (lbl.indexOf("fall") >= 0)
                pushUnique("fall")
            if (lbl.indexOf("doit") >= 0)
                pushUnique("doit")
            if (lbl.indexOf("plop") >= 0)
                pushUnique("plop")
            if (lbl.indexOf("scoop") >= 0)
                pushUnique("scoop")
            if (_hasSeq3(lbl, "slide", "out", "down"))
                pushUnique("slide out down")
            if (_hasSeq3(lbl, "slide", "out", "up"))
                pushUnique("slide out up")
            if (_hasSeq3(lbl, "slide", "in", "above"))
                pushUnique("slide in above")
            if (_hasSeq3(lbl, "slide", "in", "below"))
                pushUnique("slide in below")
        }

        function _labelOf(el) {
            var parts = []
            try {
                if (el.userName)
                    parts.push(String(el.userName()).toLowerCase())
            } catch (_) {}
            try {
                if (el.subtypeName)
                    parts.push(String(el.subtypeName()).toLowerCase())
            } catch (_) {}
            try {
                if (el.text)
                    parts.push(String(el.text).toLowerCase())
            } catch (_) {}
            try {
                if (el.plainText)
                    parts.push(String(el.plainText).toLowerCase())
            } catch (_) {}
            return (" " + parts.join(" ")).replace(/\s+/g, " ").trim()
        }

        function considerArticulation(a) {
            var raw = ((a.articulationName ? a.articulationName() : "") + " " + (a.userName ? a.userName() : "") + " " + (a.subtypeName ? a.subtypeName(
                                                                                                                                              ) : "")).toLowerCase(
                        )

            function has(s) {
                return raw.indexOf(s) >= 0
            }
            function hasAny(arr) {
                for (var i = 0; i < arr.length; ++i)
                    if (has(arr[i]))
                        return true
                return false
            }

            // --- base flags used by combos ---
            var softAccent = has("soft accent")
            var accent = (has("accent")) && !softAccent
            var marcato = has("marcato")
            var tenuto = has("tenuto")
            var staccatissimo = has("staccatissimo")
            var staccato = has("staccato")
            var loureGlyph = has("loure") || has("tenuto-staccato") || has("tenuto staccato");

            // --- COMBINATIONS (most specific first) ---
            if (softAccent && tenuto && staccato) {
                pushUnique("soft accent-tenuto-staccato")
                return
            }
            if (marcato && staccato) {
                pushUnique("marcato-staccato")
                return
            }
            if ((softAccent || accent) && staccato) {
                pushUnique(softAccent ? "soft accent-staccato" : "accent-staccato")
                return
            }
            if (marcato && tenuto) {
                pushUnique("marcato-tenuto")
                return
            }
            if ((softAccent || accent) && tenuto) {
                // registry uses "tenuto-accent"
                pushUnique(softAccent ? "soft accent-tenuto" : "tenuto-accent")
                return
            }
            if (loureGlyph || (tenuto && staccato)) {
                pushUnique("loure")
                return
            }

            // --- SPECIFIC named articulations (ordered to avoid substring shadowing) ---

            // 1) Sawtooth variants: check WIDE before the generic one
            if (has("wide sawtooth line segment")) {
                pushUnique("wide sawtooth line segment")
                return
            }
            if (has("sawtooth line segment")) {
                pushUnique("sawtooth line segment")
                return
            }

            // 2) Half-open must precede "open" to avoid substring collisions
            if (has("half-open 2")) {
                pushUnique("half-open 2")
                return
            }
            if (has("open") && !has("half-open")) {
                pushUnique("open")
                return
            }

            // Fade & swell (explicit literals)
            if (has("fade in")) {
                pushUnique("fade in")
                return
            }
            if (has("fade out")) {
                pushUnique("fade out")
                return
            }
            if (has("volume swell")) {
                pushUnique("volume swell")
                return
            }

            // 3) Vibrato large variants (explicit literals)
            if (has("vibrato large faster")) {
                pushUnique("vibrato large faster")
                return
            }
            if (has("vibrato large slowest")) {
                pushUnique("vibrato large slowest")
                return
            }

            // 4) Harmonic and tremolo bar (treat as articulations if presented as such)
            if (has("harmonic")) {
                pushUnique("harmonic")
                return
            }
            if (has("tremolo bar")) {
                pushUnique("tremolo bar")
                return
            }

            // 5) Staccatissimo split glyphs
            if (staccatissimo && hasAny(["wedge"])) {
                pushUnique("staccatissimo wedge")
                return
            }
            if (staccatissimo && hasAny(["stroke"])) {
                pushUnique("staccatissimo stroke")
                return
            }

            // 6) Other specific marks
            if (has("stress") && !accent && !(has("unstress"))) {
                pushUnique("stress")
                return
            }
            if (has("unstress")) {
                pushUnique("unstress")
                return
            }
            if (has("muted") || has("mute") || has("stopped")) {
                pushUnique("muted")
                return
            }
            if (has("up bow") || has("up-bow") || has("upbow")) {
                pushUnique("up bow")
                return
            }
            if (has("down bow") || has("down-bow") || has("downbow")) {
                pushUnique("down bow")
                return
            }
            if (has("snap pizzicato") || has("bartok pizzicato")) {
                pushUnique("snap pizzicato")
                return
            }

            // --- SINGLE MARKS (fallbacks) ---
            if (staccatissimo) {
                pushUnique("staccatissimo")
                return
            }
            if (staccato) {
                pushUnique("staccato")
                return
            }
            if (tenuto) {
                pushUnique("tenuto")
                return
            }
            if (marcato) {
                pushUnique("marcato")
                return
            }
            if (softAccent) {
                pushUnique("soft accent")
                return
            }
            if (accent) {
                pushUnique("accent")
                return
            }

            if (has("sforzato") || has("sfz")) {
                pushUnique("sforzato")
                return
            }
            if (has("fermata")) {
                pushUnique("fermata")
                return
            }
            if (has("trill")) {
                pushUnique("trill")
                return
            }
            if (has("mordent inverted") || has("prallprall")) {
                pushUnique("mordent inverted")
                return
            }
            if (has("mordent")) {
                pushUnique("mordent")
                return
            }
            if (has("turn")) {
                pushUnique("turn")
                return
            }

            // --- Jazz bends & slides (explicit literals) ---
            if (has("fall")) {
                pushUnique("fall")
                return
            }
            if (has("doit")) {
                pushUnique("doit")
                return
            }
            if (has("plop")) {
                pushUnique("plop")
                return
            }
            if (has("scoop")) {
                pushUnique("scoop")
                return
            }
            if (has("slide out down")) {
                pushUnique("slide out down")
                return
            }
            if (has("slide out up")) {
                pushUnique("slide out up")
                return
            }
            if (has("slide in above")) {
                pushUnique("slide in above")
                return
            }
            if (has("slide in below")) {
                pushUnique("slide in below")
                return
            }

            pushUnique("unknown")
        }

        // 0) Segment-level: mine any annotation-like elements for jazz bend/slide labels
        (function scanSegmentAnnotations() {
            try {
                var seg = chord.parent
                if (!seg || !seg.annotations)
                    return
                for (var ai = 0; ai < seg.annotations.length; ++ai) {
                    var ann = seg.annotations[ai]
                    try {
                        _pushJazzFromLabel(_labelOf(ann))
                    } catch (_) {}
                }
            } catch (_) {}
        })();

        // 1) Chord-level articulations
        if (chord && chord.articulations) {
            for (var i in chord.articulations)
                considerArticulation(chord.articulations[i])
        }

        // 2) Note-level articulations (Element.ARTICULATION on note.elements)
        if (chord && chord.notes) {
            for (var j in chord.notes) {
                var note = chord.notes[j]
                if (!note || !note.elements)
                    continue
                for (var k in note.elements) {
                    var el = note.elements[k]
                    try {
                        if (el && el.type === Element.ARTICULATION)
                            considerArticulation(el)
                    } catch (e) {}
                }
            }
        }

        // 3) Note-level non-ARTICULATION palette items we still want to treat as articulations
        if (chord && chord.notes) {
            for (var j2 in chord.notes) {
                var n2 = chord.notes[j2]
                if (!n2 || !n2.elements)
                    continue
                for (var e2 in n2.elements) {
                    var el2 = n2.elements[e2]
                    try {
                        // Harmonic mark (separate DOM type in MS4)
                        if (el2 && (el2.type === Element.HARMONIC_MARK || (el2.userName && String(el2.userName()).toLowerCase().indexOf(
                                                                               "harmonic") >= 0))) {
                            pushUnique("harmonic")
                        }
                        // name-based fallback for special symbols that show up as custom elements
                        if (el2 && el2.userName) {
                            var uname = String(el2.userName()).toLowerCase()
                            if (uname.indexOf("tremolo bar") >= 0)
                                pushUnique("tremolo bar")
                            if (uname.indexOf("vibrato large faster") >= 0)
                                pushUnique("vibrato large faster")
                            if (uname.indexOf("vibrato large slowest") >= 0)
                                pushUnique("vibrato large slowest")
                            if (uname.indexOf("wide sawtooth line segment") >= 0)
                                pushUnique("wide sawtooth line segment")
                            else if (uname.indexOf("sawtooth line segment") >= 0)
                                pushUnique("sawtooth line segment")
                            if (uname.indexOf("half-open 2") >= 0)
                                pushUnique("half-open 2")
                        }

                        _pushJazzFromLabel(_labelOf(el2))
                    } catch (eHM) {}
                }
            }
        }

        // 4) Chord-level ORNAMENTS (e.g., "tr" above note from Ornaments palette)
        if (chord && chord.elements) {
            for (var oi = 0; oi < chord.elements.length; ++oi) {
                var o = chord.elements[oi]
                try {
                    if (o && o.type === Element.ORNAMENT) {
                        // Mine every label we can find
                        var parts = []
                        try {
                            if (o.userName)
                                parts.push(String(o.userName()).toLowerCase())
                        } catch (_) {}
                        try {
                            if (o.subtypeName)
                                parts.push(String(o.subtypeName()).toLowerCase())
                        } catch (_) {}
                        try {
                            if (o.text)
                                parts.push(String(o.text).toLowerCase())
                        } catch (_) {}
                        var label = (" " + parts.join(" ")).replace(/\s+/g, " ").trim()
                        if (label.indexOf("tr") >= 0 || label.indexOf("trill") >= 0) {
                            pushUnique("trill")
                            // canonical token → map in articulationKeyMap
                        }
                    }
                } catch (_) {}
            }
        }

        // 4b) Chord-level name-based fallback for Jazz bends & slides
        if (chord && chord.elements) {
            for (var ce = 0; ce < chord.elements.length; ++ce) {
                var elC = chord.elements[ce]
                try {
                    _pushJazzFromLabel(_labelOf(elC))
                } catch (_) {}
            }
        }

        return names
    }

    // Slur detection for Mu 4.7+: consult slurStartByStaff, with a fallback to "_any".
    function hasSlurStartAtChord(chord) {
        try {
            var sIdx = chord.staffIdx
            var t = (chord.parent && chord.parent.tick) ? chord.parent.tick : 0
            if (slurStartByStaff && slurStartByStaff[String(sIdx)] && slurStartByStaff[String(sIdx)][t])
                return true
            if (slurStartByStaff && slurStartByStaff["_any"] && slurStartByStaff["_any"][t])
                return true
        } catch (e) {}
        return false
    }

    // Parse per-keyswitch velocity
    // Accepts:
    // 26       -> { pitch:26, velocity: defaultKsVelocity }
    // "26|127" -> { pitch:26, velocity:127 } {pitch:26, velocity:127} also works
    // "26"     -> { pitch:26, velocity: defaultKsVelocity }
    function clampInt(v, lo, hi) {
        var n = parseInt(v, 10)
        if (isNaN(n))
            return lo
        return Math.max(lo, Math.min(hi, n))
    }

    function collectSetTagsInRange() {
        setTagTimeline = {}
        var endTick = curScore.lastSegment ? (curScore.lastSegment.tick + 1) : 0
        if (curScore.selection && curScore.selection.isRange)
            endTick = curScore.selection.endSegment ? curScore.selection.endSegment.tick : endTick
        dbg("collectSetTagsInRange: begin -> endTick=" + endTick);

        // walk each staff with a cursor, guard against sparse/undefined annotations and missing staffIdx
        // which is not guaranteed for palette-dragged text or System text
        for (var s = 0; s < curScore.staves.length; ++s) {
            var c = curScore.newCursor()
            c.track = s * 4
            c.rewind(Cursor.SCORE_START)
            while (c.segment && c.tick <= endTick) {
                var seg = c.segment
                if (seg) {
                    // Staff/System/Expression text at the segment
                    if (seg.annotations) {
                        for (var ai in seg.annotations) {
                            var ann = seg.annotations[ai]
                            if (!ann)
                                continue
                            // guard against sparse arrays, get staff for this annotation
                            var annStaff = (ann.track === -1) ? s : Math.floor(ann.track / 4)

                            if ((ann.type === Element.STAFF_TEXT || ann.type === Element.SYSTEM_TEXT || ann.type
                                 === Element.EXPRESSION_TEXT) && annStaff === s) {
                                var tName = parseSetTag(ann.text || "")
                                if (tName.length) {
                                    if (!setTagTimeline[s])
                                        setTagTimeline[s] = []
                                    setTagTimeline[s].push({
                                                               tick: seg.tick,
                                                               setName: tName
                                                           })
                                }
                            }
                        }
                    }
                    // note-attached plain Text on this staff at this segment
                    for (var v = 0; v < 4; ++v) {
                        var el = seg.elementAt ? seg.elementAt(s * 4 + v) : null
                        if (el && el.type === Element.CHORD && el.notes) {
                            for (var ni in el.notes) {
                                var note = el.notes[ni]
                                if (!note.elements)
                                    continue
                                for (var ei in note.elements) {
                                    var nel = note.elements[ei]
                                    if (nel.type === Element.TEXT) {
                                        var tn = parseSetTag(nel.text || "")
                                        if (tn.length) {
                                            if (!setTagTimeline[s])
                                                setTagTimeline[s] = []
                                            setTagTimeline[s].push({
                                                                       tick: seg.tick,
                                                                       setName: tn
                                                                   })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if (!c.next())
                    break
            }
            if (setTagTimeline[s])
                setTagTimeline[s].sort(function (a, b) {
                    return a.tick - b.tick
                })
        }
        dbg("collectSetTagsInRange: end")
    }

    // Convert a Fraction-like object to absolute ticks (Mu 4.7).
    function fractionToTicks(fr) {
        try {
            if (typeof fr === 'number')
                return fr
            if (fr && fr.ticks !== undefined) // many wrappers expose .ticks
                return parseInt(fr.ticks, 10)
            if (fr && fr.numerator !== undefined && fr.denominator !== undefined) {
                var num = parseInt(fr.numerator, 10)
                var den = parseInt(fr.denominator, 10)
                if (!isNaN(num) && !isNaN(den) && den !== 0)
                    return Math.floor(num * division / den)
                // division = ticks per quarter
            }
        } catch (e) {}
        return 0
    }

    // ---- Spanner property helpers (Mu 4.7+) -----------------------------------
    function spStartTick(s) {
        // prefer 'spannerTick', then 'tick'; else 'startSegment.tick'
        try {
            if (s.spannerTick !== undefined)
                return fractionToTicks(s.spannerTick)
        } catch (e0) {}
        try {
            if (s.tick !== undefined)
                return fractionToTicks(s.tick)
        } catch (e1) {}
        try {
            if (s.startSegment && s.startSegment.tick !== undefined)
                return fractionToTicks(s.startSegment.tick)
        } catch (e2) {}
        return 0
    }

    function spEndTick(s) {
        // prefer explicit end tick-ish properties; else fall back to endSegment.tick
        try {
            if (s.spannerTick2 !== undefined)
                return fractionToTicks(s.spannerTick2)
        } catch (e0) {}
        try {
            if (s.endTick !== undefined)
                return fractionToTicks(s.endTick)
        } catch (e1) {}
        try {
            if (s.tick2 !== undefined)
                return fractionToTicks(s.tick2)
        } catch (e2) {}
        try {
            if (s.endSegment && s.endSegment.tick !== undefined)
                return fractionToTicks(s.endSegment.tick)
        } catch (e3) {}
        // As a last resort, return start tick
        try {
            return spStartTick(s)
        } catch (_) {}
        return 0
    }

    function spStartStaffIdx(s) {
        // Prefer staff.index; else derive from 'track' (start track) or 'spannerTrack2' if present.
        try {
            if (s.staff && s.staff.index !== undefined)
                return s.staff.index
        } catch (e0) {}
        try {
            if (s.track !== undefined)
                return Math.floor(s.track / 4)
        } catch (e1) {}
        try {
            if (s.spannerTrack2 !== undefined)
                return Math.floor(s.spannerTrack2 / 4)
        } catch (e2) {}
        // As an absolute last resort, try startSegment's element parent staff if exposed
        try {
            if (s.startSegment && s.startSegment.parent && s.startSegment.parent.staffIdx !== undefined)
                return s.startSegment.parent.staffIdx
        } catch (e3) {}
        return -1
    }

    // Sets chord.beamMode = 1, verifies it, and refreshes layout.
    // Returns true only if the write sticks (read-back equals 1).
    function forceNoBeamForChord(chord) {
        if (!chord)
            return false
        var OK = false
        try {
            chord.beamMode = 1
            OK = (chord.beamMode === 1)
        } catch (_) {
            OK = false
        }
        try {
            if (curScore && curScore.doLayout)
                curScore.doLayout()
        } catch (_) {}
        try {
            dbg("beam: chord.beamMode -> " + (OK ? "1 (OK)" : "failed"))
        } catch (_) {}
        return OK
    }

    // Build a map of slur starts from curScore.spanners (Mu 4.7+).
    //   slurStartByStaff[staffIdx][tick] = true
    function buildSlurStartMapFromSpanners(startTick, endTick, allowedMap) {
        slurStartByStaff = ({})
        if (!curScore || !curScore.spanners)
            return
        var sp = curScore.spanners
        var collected = 0

        for (var i = 0; i < sp.length; ++i) {
            var s = sp[i]
            if (!s)
                continue

            // Accept SLUR (some builds also surface SLUR_SEGMENT in lists; ignore those here)
            if (s.type !== Element.SLUR)
                continue
            var tStart = spStartTick(s)
            if (typeof startTick === 'number' && typeof endTick === 'number') {
                if (!(tStart >= startTick && tStart < endTick))
                    continue
            }

            var staffIdx = spStartStaffIdx(s)
            if (allowedMap && staffIdx >= 0 && allowedMap.hasOwnProperty(staffIdx) && !allowedMap[staffIdx])
                continue
            var key = (staffIdx >= 0) ? String(staffIdx) : "_any"
            if (!slurStartByStaff[key])
                slurStartByStaff[key] = ({})
            if (!slurStartByStaff[key][tStart]) {
                slurStartByStaff[key][tStart] = true
                collected++
            }
        }

        dbg("slur-starts via spanners=" + collected)
    }

    // Build a map of effect starts from curScore.spanners for just the requested items.
    // - HAIRPIN -> "fade in" (crescendo) / "fade out" (decrescendo)
    // - Named lines by userName: "tremolo bar", "vibrato large faster", "vibrato large slowest", "volume swell" (or "swell").
    function buildEffectStartMapFromSpanners(startTick, endTick, allowedMap) {
        effectStartByStaff = ({})
        if (!curScore || !curScore.spanners)
            return
        effectRangeByStaff = ({})
        // clear ranges for this run
        var sp = curScore.spanners
        var collected = 0

        function pushTok(staffIdx, tick, tok) {
            var key = (staffIdx >= 0) ? String(staffIdx) : "_any"
            if (!effectStartByStaff[key])
                effectStartByStaff[key] = ({})
            if (!effectStartByStaff[key][tick])
                effectStartByStaff[key][tick] = []
            if (effectStartByStaff[key][tick].indexOf(tok) === -1) {
                effectStartByStaff[key][tick].push(tok)
                collected++
            }
        }

        function pushTokRange(staffIdx, tStart, tEnd, tok) {
            var key = (staffIdx >= 0) ? String(staffIdx) : "_any"
            if (!effectRangeByStaff[key])
                effectRangeByStaff[key] = [];
            // coerce sane order
            var a = Math.min(tStart, tEnd), b = Math.max(tStart, tEnd)
            effectRangeByStaff[key].push({
                                             start: a,
                                             end: b,
                                             tokens: [tok]
                                         })

            dbg("effect-range: '" + tok + "' staff=" + key + " [" + a + ".." + b + ")")
        }

        for (var i = 0; i < sp.length; ++i) {
            var s = sp[i]
            if (!s)
                continue
            var tStart = spStartTick(s)
            var tEnd = spEndTick(s)

            if (typeof startTick === 'number' && typeof endTick === 'number') {
                // keep spanners whose RANGE overlaps the window
                var overlaps = (tEnd > startTick) && (tStart < endTick)
                if (!overlaps)
                    continue
            }
            var staffIdx = spStartStaffIdx(s)
            if (allowedMap && staffIdx >= 0 && allowedMap.hasOwnProperty(staffIdx) && !allowedMap[staffIdx])
                continue

            // 1) Hairpins -> "fade in" / "fade out"
            try {
                if (s.type === Element.HAIRPIN) {
                    var desc = ""
                    try {
                        if (s.hairpinType !== undefined)
                            desc = String(s.hairpinType).toLowerCase()
                    } catch (e0) {}
                    try {
                        if (!desc && s.subtypeName)
                            desc = String(s.subtypeName()).toLowerCase()
                    } catch (e1) {}
                    try {
                        if (!desc && s.userName)
                            desc = String(s.userName()).toLowerCase()
                    } catch (e2) {}

                    if (desc.indexOf("crescendo") >= 0)
                        pushTok(staffIdx, tStart, "fade in")
                    else if (desc.indexOf("decrescendo") >= 0 || desc.indexOf("diminuendo") >= 0)
                        pushTok(staffIdx, tStart, "fade out")
                }
            } catch (eH) {}

            // 2) Named line spanners: look at multiple label fields, then push your exact registry keys
            try {
                // Collect every string-y label we can find for this spanner
                var parts = []

                try {
                    if (s.userName)
                        parts.push(String(s.userName()).toLowerCase())
                } catch (eUN) {}
                try {
                    if (s.subtypeName)
                        parts.push(String(s.subtypeName()).toLowerCase())
                } catch (eST) {}
                try {
                    if (s.text)
                        parts.push(String(s.text).toLowerCase())
                } catch (eTX) {}
                try {
                    if (s.beginText) {
                        var bt = (s.beginText && s.beginText.text) ? s.beginText.text : s.beginText
                        parts.push(String(bt).toLowerCase())
                    }
                } catch (eBT) {}
                try {
                    if (s.endText) {
                        var et = (s.endText && s.endText.text) ? s.endText.text : s.endText
                        parts.push(String(et).toLowerCase())
                    }
                } catch (eET) {}
                try {
                    if (s.plainText)
                        parts.push(String(s.plainText).toLowerCase())
                } catch (ePT) {}

                var label = (" " + parts.join(" ")).replace(/\s+/g, " ").trim();
                // tolerant

                function has(str) {
                    return label.indexOf(str) >= 0
                }
                // Very small tolerance for punctuation: match by words-in-order
                function hasSeq(a, b, c) {
                    var norm = label.replace(/[^a-z0-9]+/g, " ").trim()
                    var i = norm.indexOf(a)
                    if (i < 0)
                        return false
                    var j = norm.indexOf(b, i + a.length)
                    if (j < 0)
                        return false
                    var k = norm.indexOf(c, j + b.length)
                    return k >= 0
                }

                if (has("tremolo bar")) {
                    pushTok(staffIdx, tStart, "tremolo bar")
                    pushTokRange(staffIdx, tStart, tEnd, "tremolo bar")
                }

                if (hasSeq("vibrato", "large", "faster")) {
                    pushTok(staffIdx, tStart, "vibrato large faster")
                    pushTokRange(staffIdx, tStart, tEnd, "vibrato large faster")
                }

                if (hasSeq("vibrato", "large", "slowest")) {
                    pushTok(staffIdx, tStart, "vibrato large slowest")
                    pushTokRange(staffIdx, tStart, tEnd, "vibrato large slowest")
                }

                // We already handle hairpins above; keep optional "swell" alias here too
                if (has("volume swell") || has("swell"))
                    pushTok(staffIdx, tStart, "volume swell")
            } catch (eN) {}

            // 3) TRILL line spanners: treat as a range token "trill line"
            try {
                if (s.type === Element.TRILL || s.type === Element.TRILL_SEGMENT) {
                    pushTok(staffIdx, tStart, "trill line")
                    pushTokRange(staffIdx, tStart, tEnd, "trill line")
                }
            } catch (_) {}
        }

        dbg("effects via spanners=" + collected);

        // if spanners are scarce (or simply missing our targets), also mine annotations in the same window
        buildEffectRangesFromAnnotationsFallback(startTick, endTick, allowedMap);

        // mine selection elements too (covers cases where those lines are not exposed as spanners or annotations)
        buildEffectRangesFromSelectionElements(startTick, endTick, allowedMap)
    }

    // --- Fallback: synthesize effect ranges from segment annotations when spanners are missing ---
    function normalizeEffectLabel_(s) {
        try {
            var t = (s || "").toString().toLowerCase();
            // normalize punctuation/whitespace -> single spaces
            t = t.replace(/[“”]/g, '"').replace(/[‘’]/g, "'")
            t = t.replace(/\u00A0/g, " ").replace(/[^a-z0-9]+/g, " ").replace(/\s+/g, " ").trim()
            return t
        } catch (_) {
            return ""
        }
    }

    // Return the first matching effect token for a normalized label, or "" if none.
    function pickEffectTokenFromLabel_(norm) {
        // tolerate comma: "vibrato large, faster" -> "vibrato large faster" after normalization
        function hasSeq(a, b, c) {
            var i = norm.indexOf(a)
            if (i < 0)
                return false
            var j = norm.indexOf(b, i + a.length)
            if (j < 0)
                return false
            var k = norm.indexOf(c, j + b.length)
            return k >= 0
        }
        if (norm.indexOf("tremolo bar") >= 0)
            return "tremolo bar"
        if (hasSeq("vibrato", "large", "faster"))
            return "vibrato large faster"
        if (hasSeq("vibrato", "large", "slowest"))
            return "vibrato large slowest"
        if (norm.indexOf("volume swell") >= 0 || norm === "swell")
            return "volume swell"
        return ""
    }

    function buildEffectRangesFromAnnotationsFallback(startTick, endTick, allowedMap) {
        try {
            if (!curScore || !curScore.staves)
                return
            // If endTick wasn't provided, cap at score end
            var endLim = (typeof endTick === 'number') ? endTick : (curScore.lastSegment ? (curScore.lastSegment.tick + 1) : 0)

            for (var s = 0; s < curScore.staves.length; ++s) {
                if (allowedMap && !allowedMap[s])
                    continue
                var c = curScore.newCursor()
                c.track = s * 4
                c.rewindToTick(startTick)

                while (c.segment && c.tick < endLim) {
                    var seg = c.segment

                    // look at segment-level annotations (Staff/System/Expression + "playing technique annotation" fallback)
                    if (seg && seg.annotations) {
                        for (var ai = 0; ai < seg.annotations.length; ++ai) {
                            var ann = seg.annotations[ai]
                            if (!ann)
                                continue

                            // best-effort staff match like in segmentTechniqueTexts(...)
                            var annStaffIdx = -1
                            try {
                                if (ann.track !== undefined && ann.track !== -1)
                                    annStaffIdx = Math.floor(ann.track / 4)
                                else if (ann.staffIdx !== undefined)
                                    annStaffIdx = ann.staffIdx
                                else if (ann.type === Element.STAFF_TEXT || ann.type === Element.EXPRESSION_TEXT)
                                    annStaffIdx = s
                            } catch (eAS) {
                                annStaffIdx = -1
                            }

                            // SYSTEM_TEXT is global; Staff/Expression must match this staff
                            var staffOk = (ann.type === Element.SYSTEM_TEXT) || (annStaffIdx === s)
                            if (!staffOk)
                                continue
                            var raw = ""
                            try {
                                raw = ann.text || ""
                            } catch (_) {
                                raw = ""
                            }
                            var norm = normalizeEffectLabel_(raw)
                            if (!norm)
                                continue
                            var tok = pickEffectTokenFromLabel_(norm)
                            if (!tok)
                                continue

                            // Found an effect start at this segment; synthesize a range to selection end (or score end)
                            // Reuse your existing helpers
                            // pushTokRange(staffIdx, tStart, tEnd, tok)
                            pushTokRange(s, c.tick, endLim, tok);
                            // Also record a start token for completeness (not strictly required)
                            pushTok(s, c.tick, tok)

                            dbg("fallback-range: '" + tok + "' staff=" + s + " [" + c.tick + ".." + endLim + ")")
                        }
                    }

                    if (!c.next())
                        break
                }
            }
        } catch (eFB) {
            try {
                dbg("fallback error: " + String(eFB))
            } catch (_) {}
        }
    }
    // --- Selection fallback: synthesize effect ranges from selection elements ---
    // Uses the same normalizer + token picker you already added for the annotations fallback.
    function buildEffectRangesFromSelectionElements(startTick, endTick, allowedMap) {
        try {
            if (!curScore || !curScore.selection || !curScore.selection.elements || !curScore.selection.elements.length)
                return
            var endLim = (typeof endTick === 'number') ? endTick : (curScore.lastSegment ? (curScore.lastSegment.tick + 1) : 0)

            for (var ii = 0; ii < curScore.selection.elements.length; ++ii) {
                var el = curScore.selection.elements[ii]
                if (!el)
                    continue

                // Gather every name-ish field the element might expose
                var parts = []
                try {
                    if (el.userName)
                        parts.push(String(el.userName()).toLowerCase())
                } catch (_) {}
                try {
                    if (el.subtypeName)
                        parts.push(String(el.subtypeName()).toLowerCase())
                } catch (_) {}
                try {
                    if (el.text)
                        parts.push(String(el.text).toLowerCase())
                } catch (_) {}
                try {
                    if (el.plainText)
                        parts.push(String(el.plainText).toLowerCase())
                } catch (_) {}

                var label = normalizeEffectLabel_((" " + parts.join(" ")).replace(/\s+/g, " ").trim())
                if (!label)
                    continue
                var tok = pickEffectTokenFromLabel_(label)
                if (!tok)
                    continue

                // Determine staff
                var sIdx = -1
                try {
                    if (el.staffIdx !== undefined)
                        sIdx = el.staffIdx
                } catch (_) {}
                if (sIdx < 0) {
                    try {
                        if (el.track !== undefined && el.track !== -1)
                            sIdx = Math.floor(el.track / 4)
                    } catch (_) {}
                }
                if (sIdx < 0)
                    continue
                if (allowedMap && !allowedMap[sIdx])
                    continue

                // Determine a time span for the token.
                // Prefer spanner-like timing if present; else use element's parent segment; else use selection start.
                var t0 = 0, t1 = endLim
                try {
                    t0 = spStartTick(el)
                } catch (_) {}
                try {
                    t1 = spEndTick(el)
                } catch (_) {}
                if (!(t1 > t0)) {
                    try {
                        if (el.parent && el.parent.tick !== undefined)
                            t0 = el.parent.tick
                    } catch (_) {}
                    t1 = endLim
                }

                pushTokRange(sIdx, t0, t1, tok)
                pushTok(sIdx, t0, tok)
                dbg("sel-fallback-range: '" + tok + "' staff=" + sIdx + " [" + t0 + ".." + t1 + ")")
            }
        } catch (eSF) {
            try {
                dbg("sel-fallback error: " + String(eSF))
            } catch (_) {}
        }
    }

    // Retrieve any effect tokens that start on this staff/tick.
    function effectTokensAt(staffIdx, tick) {
        try {
            var key = String(staffIdx);

            // Helper: collect keys for other staves in the same part
            function samePartKeys(curStaff) {
                var out = []
                var pi0 = partInfoForStaff(curStaff)
                if (!pi0)
                    return out

                // 1) keys present in start map
                if (effectStartByStaff) {
                    for (var k in effectStartByStaff) {
                        if (k === "_any")
                            continue
                        var s2 = parseInt(k, 10)
                        if (isNaN(s2))
                            continue
                        var pi2 = partInfoForStaff(s2)
                        if (pi2 && pi2.index === pi0.index && s2 !== curStaff)
                            out.push(k)
                    }
                }
                // 2) keys present in range map that might not exist in start map
                if (effectRangeByStaff) {
                    for (var k2 in effectRangeByStaff) {
                        if (k2 === "_any")
                            continue
                        // avoid duplicates from previous loop
                        if (out.indexOf(k2) !== -1)
                            continue
                        var s3 = parseInt(k2, 10)
                        if (isNaN(s3))
                            continue
                        var pi3 = partInfoForStaff(s3)
                        if (pi3 && pi3.index === pi0.index && s3 !== curStaff)
                            out.push(k2)
                    }
                }
                return out
            }

            // 1) Exact-start tokens
            var arr = (effectStartByStaff && effectStartByStaff[key] && effectStartByStaff[key][tick]) ? effectStartByStaff[key][tick] :
                                                                                                         null

            // 1b) fall back to _any
            if (!arr && effectStartByStaff && effectStartByStaff["_any"] && effectStartByStaff["_any"][tick])
                arr = effectStartByStaff["_any"][tick];

            // 1c) NEW: fall back to other staves in the same part
            if ((!arr || !arr.length) && effectStartByStaff) {
                var sib = samePartKeys(staffIdx)
                var hitsStart = []
                for (var iS = 0; iS < sib.length; ++iS) {
                    var kS = sib[iS]
                    if (effectStartByStaff[kS] && effectStartByStaff[kS][tick]) {
                        var aS = effectStartByStaff[kS][tick]
                        for (var jS = 0; jS < aS.length; ++jS)
                            if (hitsStart.indexOf(aS[jS]) === -1)
                                hitsStart.push(aS[jS])
                    }
                }
                if (hitsStart.length)
                    arr = hitsStart
            }

            // 2) Ranges at this tick
            if ((!arr || !arr.length) && effectRangeByStaff && effectRangeByStaff[key]) {
                var hits = []
                var ranges = effectRangeByStaff[key]
                for (var i = 0; i < ranges.length; ++i) {
                    var R = ranges[i]
                    if (tick >= R.start && tick < R.end) {
                        for (var j = 0; j < R.tokens.length; ++j)
                            if (hits.indexOf(R.tokens[j]) === -1)
                                hits.push(R.tokens[j])
                    }
                }
                if (hits.length)
                    arr = hits
            }

            // 2b) _any ranges
            if ((!arr || !arr.length) && effectRangeByStaff && effectRangeByStaff["_any"]) {
                var hits2 = []
                var ranges2 = effectRangeByStaff["_any"]
                for (var k = 0; k < ranges2.length; ++k) {
                    var R2 = ranges2[k]
                    if (tick >= R2.start && tick < R2.end) {
                        for (var m = 0; m < R2.tokens.length; ++m)
                            if (hits2.indexOf(R2.tokens[m]) === -1)
                                hits2.push(R2.tokens[m])
                    }
                }
                if (hits2.length)
                    arr = hits2
            }

            // 2c) ranges from other staves in the same part
            if ((!arr || !arr.length) && effectRangeByStaff) {
                var sib2 = samePartKeys(staffIdx)
                var hits3 = []
                for (var i2 = 0; i2 < sib2.length; ++i2) {
                    var k2 = sib2[i2]
                    var ranges3 = effectRangeByStaff[k2]
                    if (!ranges3)
                        continue
                    for (var r = 0; r < ranges3.length; ++r) {
                        var R3 = ranges3[r]
                        if (tick >= R3.start && tick < R3.end) {
                            for (var n = 0; n < R3.tokens.length; ++n)
                                if (hits3.indexOf(R3.tokens[n]) === -1)
                                    hits3.push(R3.tokens[n])
                        }
                    }
                }
                if (hits3.length)
                    arr = hits3
            }

            return arr ? arr.slice(0) : []
        } catch (e) {
            return []
        }
    }

    function computeAllowedSourceStaves(startStaff, endStaff, effScope, effPartsMode) {
        var allowed = {}
        var anchorPartIdx = -1
        var piAnchor = partInfoForStaff(startStaff)
        if (piAnchor)
            anchorPartIdx = piAnchor.index
        dbg("parts: effective='" + effPartsMode + "' anchorPartIdx=" + anchorPartIdx)

        if (startStaff === endStaff) {
            allowed[startStaff] = true
            return allowed
        }

        var perPart = {}
        for (var s = startStaff; s <= endStaff; ++s) {
            var pi = partInfoForStaff(s)
            if (!pi)
                continue
            if (effPartsMode === "anchor" && pi.index !== anchorPartIdx)
                continue
            var arr = perPart[pi.index]
            if (!arr) {
                arr = []
                perPart[pi.index] = arr
            }
            arr.push(s)
        }

        for (var pidx in perPart) {
            var arr = perPart[pidx]
            if (effScope === "part") {
                for (var i = 0; i < arr.length; ++i)
                    allowed[arr[i]] = true
            } else {
                for (var i3 = 0; i3 < arr.length; ++i3)
                    allowed[arr[i3]] = true
            }
        }
        return allowed
    }

    function crossKey(staffIdx, tick) {
        return staffIdx + ":" + tick
    }

    function dbg(msg) {
        if (debugEnabled)
            console.log("[KS] " + msg)
    }

    function dbg2(k, v) {
        if (debugEnabled)
            console.log("[KS] " + k + ": " + v)
    }

    function ensureWritableSlot(c, num, den) {
        var t = c.fraction
        c.setDuration(num, den)
        try {
            c.addRest()
        } catch (e) {
            dbg("ensureWritableSlot: addRest failed at " + t.numerator + "/" + t.denominator)
        }
        c.rewindToFraction(t)
    }

    function escapeRegex(s) {
        return s.replace(/[\\\-\\/\\^$*+?.()\\[\\]{}]/g, '\\$&')
    }

    // Return true if the value is "true" (string) or boolean true.
    function flagIsTrue(val) {
        if (val === true)
            return true
        if (val === "true")
            return true
        if (typeof val === "string") {
            var s = val.trim().toLowerCase()
            return (s === "true" || s === "1" || s === "yes")
        }
        return false
    }

    // Insert a Staff type change (STC) on the given staff once per run.
    // Anchor at 'insertTick' (selection start); if that yields no segment,
    // fall back to SCORE_START. ADD the element first, then set properties.
    function applyKsStaffFormattingIfNeeded(tgtStaffIdx, insertTick) {
        try {
            if (tgtStaffIdx < 0)
                return
            var key = String(tgtStaffIdx)
            if (formattedKsStaff[key])
                return
            var enabled = (globalSettings && globalSettings.formatKeyswitchStaff !== undefined) ? globalSettings.formatKeyswitchStaff :
                                                                                                  "true"

            if (!flagIsTrue(enabled)) {
                formattedKsStaff[key] = true
                return
            }

            var c = curScore.newCursor()
            c.track = tgtStaffIdx * 4;

            // Prefer selection-start tick; else fall back to SCORE_START
            var hasSeg = false
            if (typeof insertTick === 'number') {
                c.rewindToTick(insertTick)
                if (c.segment)
                    hasSeg = true
            }
            if (!hasSeg) {
                c.rewind(Cursor.SCORE_START)
                if (c.segment)
                    hasSeg = true
            }
            if (!hasSeg) {
                formattedKsStaff[key] = true
                return
            }

            dbg("KS format: staff=" + tgtStaffIdx + " at tick=" + c.tick);

            // --- 1) Create and ADD the Staff type change element ---
            var stc = newElement(Element.STAFFTYPE_CHANGE)
            try {
                c.add(stc)
            } catch (eAdd) {
                dbg("add(STC) failed: " + String(eAdd))
                formattedKsStaff[key] = true
                return
            }

            // --- 2) Now set properties (prefer underlying StaffType) ---
            function safeSet(fn) {
                try {
                    fn()
                } catch (__) {}
            }
            var st = null
            try {
                st = stc.staffType
            } catch (eST) {
                st = null
            }

            if (st) {
                // StaffType-level settings
                // safeSet(function () {
                //     st.lines = 1
                // })
                // safeSet(function () {
                //     st.lineDistance = 1.0
                // });

                // // Visibility toggles
                // safeSet(function () {
                //     st.genClef = false
                // })
                // safeSet(function () {
                //     st.genTimesig = false
                // })
                // safeSet(function () {
                //     st.genKeysig = false
                // })
                // safeSet(function () {
                //     st.showLedgerLines = false
                // })
                // safeSet(function () {
                //     st.showBarlines = true
                // });

                // Stemless
                safeSet(function () {
                    st.stemless = true
                });

                // Notehead scheme → Pitch names
                safeSet(function () {
                    if (typeof PluginAPI !== "undefined" && PluginAPI.NoteHeadScheme && PluginAPI.NoteHeadScheme.PITCH_NAME !== undefined) {
                        st.noteHeadScheme = PluginAPI.NoteHeadScheme.PITCH_NAME
                    } else {
                        // common fallback used by many builds for "Pitch names"
                        st.noteHeadScheme = 1
                    }
                })
            } else {
                // Fallback: some builds expose wrapper properties right on the STC
                // safeSet(function () {
                //     stc.lines = 1
                // })
                // safeSet(function () {
                //     stc.lineDistance = 1.0
                // })
                // safeSet(function () {
                //     stc.genClef = false
                // })
                // safeSet(function () {
                //     stc.genTimesig = false
                // })
                // safeSet(function () {
                //     stc.genKeysig = false
                // })
                // safeSet(function () {
                //     stc.showLedgerLines = false
                // })
                // safeSet(function () {
                //     stc.showBarlines = true
                // })
                safeSet(function () {
                    stc.stemless = true
                })
                safeSet(function () {
                    if (typeof PluginAPI !== "undefined" && PluginAPI.NoteHeadScheme && PluginAPI.NoteHeadScheme.PITCH_NAME !== undefined) {
                        stc.headScheme = PluginAPI.NoteHeadScheme.PITCH_NAME
                    } else {
                        stc.headScheme = 1
                    }
                })
                safeSet(function () {
                    if (stc.headScheme === undefined)
                        stc.noteHeadScheme = 1
                })
            }

            // Hide the magenta STC icon
            safeSet(function () {
                stc.visible = false
            })
            safeSet(function () {
                stc.offsetY = -1000
            });

            // (Optional) force layout if your build requires it for Lines/Stemless to appear immediately
            try {
                if (curScore && curScore.doLayout)
                    curScore.doLayout()
            } catch (_e) {}
        } catch (e) {
            dbg("applyKsStaffFormattingIfNeeded failed: " + String(e))
        } finally {
            formattedKsStaff[String(tgtStaffIdx)] = true
        }
    }

    // Format all target KS staves for a given staff window before scanning chords.
    // 'allowedMap' is the map of source staves we actually process in this run.
    // 'insertTick' is where to anchor the Staff type change (selection start is safest).
    function applyKsFormattingForSourceWindow(startStaff, endStaff, allowedMap, insertTick) {
        try {
            var enabled = (globalSettings && globalSettings.formatKeyswitchStaff !== undefined) ? globalSettings.formatKeyswitchStaff :
                                                                                                  "true"

            if (!flagIsTrue(enabled))
                return
            for (var s = startStaff; s <= endStaff; ++s) {
                if (!allowedMap[s])
                    continue
                var tgt = targetStaffForKeyswitch(s)
                if (tgt >= 0)
                    applyKsStaffFormattingIfNeeded(tgt, insertTick)
                // << pass the tick
            }
        } catch (e) {
            dbg("applyKsFormattingForSourceWindow failed: " + String(e))
        }
    }

    // Map known aliases explicitly
    function findArticulationKeyswitches(artiNames, artiMap) {
        var specs = []
        if (!artiMap)
            return specs

        for (var i = 0; i < artiNames.length; ++i) {
            var k = artiNames[i]

            function pushKey(name) {
                if (!artiMap || !artiMap.hasOwnProperty(name))
                    return
                var spec = parseKsMapValue(artiMap[name])
                if (spec)
                    specs.push(spec)
            }

            if (artiMap.hasOwnProperty(k))
                pushKey(k)
            else if (k.indexOf("tenuto") >= 0)
                pushKey("tenuto")
            else if (k.indexOf("stacc") >= 0)
                pushKey("staccato")
            else if (k.indexOf("accent") >= 0)
                pushKey("accent")
            else if (k.indexOf("marcato") >= 0)
                pushKey("marcato")
            else if (k.indexOf("harmonic") >= 0) {
                // allow either "harmonic" or "harmonics" in user maps
                pushKey("harmonic")
                pushKey("harmonics")
            }
        }
        return specs
    }

    // Resolve KS:Text=<value> directly against techniqueKeyMap (case-insensitive key match)
    function findTaggedTechniqueKeyswitches(texts, techMap) {
        var specs = []
        if (!techMap)
            return specs

        // build a lowercase index for case-insensitive matching without changing user JSON
        var lcIndex = {}
        for (var k in techMap) {
            if (!techMap.hasOwnProperty(k))
                continue
            lcIndex[String(k).toLowerCase()] = k
        }

        for (var ti = 0; ti < texts.length; ++ti) {
            var vals = parseTextTagValues(texts[ti])
            for (var vi = 0; vi < vals.length; ++vi) {
                var wanted = String(vals[vi]).toLowerCase()
                var realKey = lcIndex[wanted]
                if (realKey === undefined)
                    continue
                var spec = parseKsMapValue(techMap[realKey])
                if (spec)
                    specs.push(spec)
            }
        }
        return specs
    }

    function findTechniqueKeyswitches(texts, techMap, aliasMap) {
        var specs = []
        if (!techMap)
            return specs
        var aliasFor = aliasMap || {}

        for (var key in techMap) {
            var spec = parseKsMapValue(techMap[key])
            if (!spec)
                continue
            var aliases = aliasFor[key] || [key]
            var rx = []
            for (var i = 0; i < aliases.length; ++i)
                rx.push(tokenRegex(aliases[i]))

            for (var ti = 0; ti < texts.length; ++ti) {
                var t = texts[ti]
                for (var ri = 0; ri < rx.length; ++ri) {
                    if (rx[ri].test(t)) {
                        specs.push(spec)
                        break
                    }
                }
            }
        }
        return specs
    }

    function isEligibleSourceStaff(staffIdx) {
        return targetStaffForKeyswitch(staffIdx) !== -1
    }

    function keyswitchExistsAt(cursor, pitch) {
        if (!cursor.element || cursor.element.type !== Element.CHORD)
            return false
        var chord = cursor.element
        for (var i in chord.notes)
            if (chord.notes[i].pitch === pitch)
                return true
        return false
    }

    // Build a MIDI-set (pitch -> true) for all keyswitch pitches used by the active set.
    function midiSetForActiveSet(activeSet) {
        var setMap = {}
        if (!activeSet)
            return setMap
        function consider(val) {
            var spec = parseKsMapValue(val)
            if (!spec)
                return
            setMap[spec.pitch] = true
        }
        if (activeSet.articulationKeyMap) {
            for (var k in activeSet.articulationKeyMap)
                consider(activeSet.articulationKeyMap[k])
        }
        if (activeSet.techniqueKeyMap) {
            for (var t in activeSet.techniqueKeyMap)
                consider(activeSet.techniqueKeyMap[t])
        }
        return setMap
    }

    // Reconcile the keyswitch chord at the KS staff for this source chord:
    // - add missing desired pitches
    // - update velocity for matching pitches
    // - remove stale pitches that are part of the active set and look plugin-made
    // Returns the count of newly added notes.
    function applyKeyswitchSetAt(sourceChord, specs, activeSet, hasAnyDirective) {
        try {
            if (typeof hasAnyDirective !== 'boolean')
                hasAnyDirective = false
            var track = sourceChord.track
            var startFrac = sourceChord.fraction
            var srcStaff = staffIdxFromTrack(track)
            var tgtStaff = targetStaffForKeyswitch(srcStaff)
            if (tgtStaff < 0) {
                preflightFailed = true
                return 0
            }

            var c = curScore.newCursor()
            c.track = tgtStaff * 4
            c.rewindToFraction(startFrac);

            // Respect de-duplication across voices before touching anything
            if (dedupeAcrossVoices && wasEmittedCross(c.staffIdx, c.tick))
                return 0

            var fmtEnabled = (globalSettings && globalSettings.formatKeyswitchStaff !== undefined) ? globalSettings.formatKeyswitchStaff :
                                                                                                     "true"

            var fmtOn = flagIsTrue(fmtEnabled);

            // Duration policy identical to addKeyswitchNoteAt
            var policy = (activeSet && activeSet.durationPolicy) ? activeSet.durationPolicy : (globalSettings
                                                                                               && globalSettings.durationPolicy)
                                                                   ? globalSettings.durationPolicy : (useSourceDuration ? "source" :
                                                                                                                          "fixed")
            var dur = sourceChord.actualDuration
            var num = (policy === "source" && dur) ? dur.numerator : ksNumerator
            var den = (policy === "source" && dur) ? dur.denominator : ksDenominator
            if (!num || !den) {
                num = ksNumerator
                den = ksDenominator
            }
            c.setDuration(num, den);

            // Don't create a slot unless necessary (mirror your existing guard)
            var existing = c.element
            var existingIsChord = (existing && existing.type === Element.CHORD)
            var existingIsRest = (existing && existing.type === Element.REST)
            if (!existing || (!existingIsChord && !existingIsRest))
                ensureWritableSlot(c, num, den);

            // Build desired map pitch->velocity (first occurrence wins, keeps your deterministic behavior)
            var desired = {}
            for (var i = 0; i < specs.length; ++i) {
                var s = specs[i]
                if (!s)
                    continue
                if (desired[s.pitch] === undefined)
                    desired[s.pitch] = clampInt(s.velocity, 0, 127)
            }

            // If there is a chord already, compute present KS notes and reconcile
            c.rewindToFraction(startFrac)
            var added = 0
            var ch = (c.element && c.element.type === Element.CHORD) ? c.element : null

            // Helper to ensure chord-level formatting once
            function formatChordOnce(chordObj) {
                if (!fmtOn || !chordObj)
                    return
                try {
                    chordObj.noStem = true
                } catch (e) {}
            }
            // Helper to apply per-note formatting + velocity
            function applyPerNoteProps(noteObj, wantPitch) {
                try {
                    setKeyswitchNoteVelocity(noteObj, desired[wantPitch] !== undefined ? desired[wantPitch] : defaultKsVelocity)
                } catch (e) {}
                if (hideKeyswitchNotes) {
                    try {
                        noteObj.visible = false
                    } catch (e1) {}
                }
                if (fmtOn) {
                    try {
                        noteObj.noStem = true
                    } catch (e2) {}
                    try {
                        noteObj.fixed = true
                    } catch (e3) {}
                }
            }

            // One scan to gather state
            c.rewindToFraction(startFrac)
            var added = 0
            var ch = (c.element && c.element.type === Element.CHORD) ? c.element : null

            var existingKsPitch = {}
            var toRemove = []
            var activeMidi = midiSetForActiveSet(activeSet)
            var missing = []

            if (ch && ch.notes) {
                formatChordOnce(ch)
                try {
                    forceNoBeamForChord(ch)
                } catch (eNB1) {}
                for (var j in ch.notes) {
                    var nn = ch.notes[j]
                    if (!nn)
                        continue
                    var p = nn.pitch
                    if (desired[p] !== undefined) {
                        // desired now: keep & refresh velocity
                        applyPerNoteProps(nn, p)
                        existingKsPitch[p] = true
                    } else if (activeMidi[p]) {
                        // KS pitch of current set but not desired at this tick
                        toRemove.push(nn)
                    }
                }
            }

            // If nothing is desired now, remove any active-set KS here.
            // If the chord contains ONLY active-set KS notes, remove the WHOLE chord to avoid
            // "Removal of final note is not allowed." Then add back a rest in this slot.

            var desiredIsEmpty = true
            for (var _k in desired) {
                desiredIsEmpty = false
                break
            }

            // Only perform removal when nothing is desired AND the source chord has no directive.
            if (desiredIsEmpty && !hasAnyDirective) {
                if (ch && ch.notes && ch.notes.length > 0) {
                    var allActiveSet = true
                    for (var _n = 0; _n < ch.notes.length; ++_n) {
                        var _p = ch.notes[_n].pitch
                        if (!activeMidi[_p]) {
                            allActiveSet = false
                            break
                        }
                    }
                    if (allActiveSet) {
                        // remove entire KS chord, then ensure a rest at this slot
                        try {
                            dbg("removed KS chord at tick=" + c.tick + " (no directive at source)")
                            removeElement(ch)
                        } catch (eWhole) {}
                        ensureWritableSlot(c, num, den)
                    } else if (toRemove.length > 0) {
                        // remove only active-set KS notes; at least one non-active note remains
                        c.rewindToFraction(startFrac)
                        ch = (c.element && c.element.type === Element.CHORD) ? c.element : null
                        for (var r0 = 0; r0 < toRemove.length; ++r0) {
                            var stale0 = toRemove[r0]
                            try {
                                dbg("removed KS pitch=" + stale0.pitch + " at tick=" + c.tick)
                                ch.remove(stale0)
                            } catch (eRem0) {
                                try {
                                    removeElement(stale0)
                                } catch (eRem02) {}
                            }
                        }
                    }
                }
                return 0
            }

            // If desired is empty *but* the source still has some directive (unknown/unsupported),
            // do nothing here. Leave any existing KS intact.
            if (desiredIsEmpty && hasAnyDirective) {
                return 0
            }

            // Compute missing desired pitches using a live check at this tick
            // (so we only skip adding if a KS note is truly present on the KS staff)
            missing = []
            c.rewindToFraction(startFrac)
            for (var wantPitch in desired) {
                var p = Number(wantPitch)
                if (isNaN(p))
                    continue
                if (!keyswitchExistsAt(c, p))
                    missing.push(p)
            }

            // Debug: show what we plan to add at this tick
            try {
                dbg("missing@tick=" + c.tick + " => " + missing.join(","))
            } catch (eDbgM) {}

            // Pass 2: add missing desired FIRST (avoid "final note" removal error)
            for (var m = 0; m < missing.length; ++m) {
                var want = missing[m];

                // Re-ensure a writable slot at this exact fraction (defensive)
                c.rewindToFraction(startFrac)
                c.setDuration(num, den)
                var elNow = c.element
                var isChordNow = (elNow && elNow.type === Element.CHORD)
                var isRestNow = (elNow && elNow.type === Element.REST)
                if (!elNow || (!isChordNow && !isRestNow)) {
                    ensureWritableSlot(c, num, den)
                    c.rewindToFraction(startFrac)
                }

                // Decide stacking based on what's currently there
                var addToChord = !!(c.element && c.element.type === Element.CHORD)

                try {
                    c.addNote(want, addToChord)
                    // Refresh element and apply formatting/velocity to the just-added note
                    c.rewindToFraction(startFrac)
                    var chNow = (c.element && c.element.type === Element.CHORD) ? c.element : null
                    if (chNow && chNow.notes) {
                        formatChordOnce(chNow)
                        try {
                            forceNoBeamForChord(chNow)
                        } catch (eNB1) {}
                        for (var k in chNow.notes) {
                            var n2 = chNow.notes[k]
                            if (n2 && n2.pitch === want)
                                applyPerNoteProps(n2, want)
                        }
                    }
                    try {
                        dbg("added KS pitch=" + want + " at tick=" + c.tick)
                    } catch (eDbgA) {}
                    added++
                } catch (eAdd) {
                    dbg("applyKeyswitchSetAt: addNote failed at tick=" + c.tick + " pitch=" + want + " err=" + eAdd)
                }
            }

            if (dedupeAcrossVoices && added > 0)
                markEmittedCross(c.staffIdx, c.tick);

            // Pass 3: remove stale active-set KS that remain (safe now that desired exists)
            if (toRemove.length > 0) {
                c.rewindToFraction(startFrac)
                ch = (c.element && c.element.type === Element.CHORD) ? c.element : null
                for (var r = 0; r < toRemove.length; ++r) {
                    var stale = toRemove[r]
                    try {
                        dbg("removed KS pitch=" + stale.pitch + " at tick=" + c.tick)
                        ch.remove(stale)
                    } catch (eRem) {
                        try {
                            removeElement(stale)
                        } catch (eRem2) {}
                    }
                }
            }

            if (dedupeAcrossVoices && added > 0)
                markEmittedCross(c.staffIdx, c.tick)

            return added
        } catch (eTop) {
            dbg("applyKeyswitchSetAt error: " + String(eTop))
            return 0
        }
    }

    function loadRegistryAndAssignments() {
        var sets
        try {
            sets = ksPrefs.setsJSON ? JSON.parse(ksPrefs.setsJSON) : defaultKeyswitchSets
        } catch (e) {
            sets = defaultKeyswitchSets
        }
        keyswitchSets = sets

        var perScore = readStaffAssignmentsFromScore()
        staffToSet = perScore ? perScore : {}

        var g
        try {
            g = ksPrefs.globalJSON ? JSON.parse(ksPrefs.globalJSON) : defaultGlobalSettings
        } catch (e3) {
            g = defaultGlobalSettings
        }
        globalSettings = g

        dbg2("plugin version", version)
        dbg2("registry keys", Object.keys(keyswitchSets).join(", "))
    }

    function readStaffAssignmentsFromScore() {
        if (!curScore || !curScore.metaTag)
            return null
        try {
            var raw = curScore.metaTag(staffToSetMetaTagKey)
            if (raw && raw.length) {
                var parsed = JSON.parse(raw)
                if (parsed && typeof parsed === "object")
                    return parsed
            }
        } catch (e) {}
        return null
    }

    function markEmittedCross(staffIdx, tick) {
        emittedCross[crossKey(staffIdx, tick)] = true
    }

    function nameForPartByRange(staffIdx, tick) {
        var pi = partInfoForStaff(staffIdx)
        if (!pi)
            return qsTr("this part")
        var p = pi.part
        var nm = (p.longName && p.longName.length) ? p.longName : (p.partName && p.partName.length) ? p.partName : (p.shortName
                                                                                                                    && p.shortName.length)
                                                                                                      ? p.shortName : ""
        if (!nm && p.instrumentAtTick) {
            var inst = p.instrumentAtTick(tick || 0)
            if (inst && inst.longName && inst.longName.length)
                nm = inst.longName
        }
        if (!nm)
            nm = qsTr("this part")
        return nm
    }

    function normalizeTextBasic(s) {
        var t = (s || "").toString()
        t = t.replace(/[“”]/g, '"').replace(/[‘’]/g, "'")
        t = t.replace(/\u00A0/g, " ").replace(/\s+/g, " ")
        return t
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
            if (v.pitch !== undefined)
                pitch = parseInt(v.pitch, 10)
            else if (v.note !== undefined)
                pitch = parseInt(v.note, 10)
            if (v.velocity !== undefined)
                vel = parseInt(v.velocity, 10)
            else if (v.vel !== undefined)
                vel = parseInt(v.vel, 10)
        }

        if (pitch === null || isNaN(pitch))
            return null
        pitch = clampInt(pitch, 0, 127)
        vel = clampInt(vel, 0, 127)
        return {
            pitch: pitch,
            velocity: vel
        }
    }

    function parsePartsTag(rawText) {
        var s = normalizeTextBasic(rawText).toLowerCase()
        var idx = s.indexOf("ks:parts")
        if (idx < 0)
            return ""
        var i = idx + 8
        while (i < s.length && s[i] === ' ')
            i++
        if (i < s.length && s[i] === '=') {
            i++
            while (i < s.length && s[i] === ' ')
                i++
        }
        var val = s.substring(i).trim()
        if (!val)
            return ""
        if (val[0] === '"' || val[0] === "'") {
            var q = val[0]
            var j = val.indexOf(q, 1)
            val = (j === -1) ? val.slice(1) : val.slice(1, j)
        } else {
            var sp = val.indexOf(' ')
            if (sp > 0)
                val = val.substring(0, sp)
        }
        return (val === "all" || val === "anchor") ? val : ""
    }

    // KS:Scope / KS:Parts
    function parseScopeTag(rawText) {
        var s = normalizeTextBasic(rawText).toLowerCase()
        var idx = s.indexOf("ks:scope")
        if (idx < 0)
            return ""
        var i = idx + 8
        while (i < s.length && s[i] === ' ')
            i++
        if (i < s.length && s[i] === '=') {
            i++
            while (i < s.length && s[i] === ' ')
                i++
        }
        var val = s.substring(i).trim()
        if (!val)
            return ""
        if (val[0] === '"' || val[0] === "'") {
            var q = val[0]
            var j = val.indexOf(q, 1)
            val = (j === -1) ? val.slice(1) : val.slice(1, j)
        } else {
            var sp = val.indexOf(' ')
            if (sp > 0)
                val = val.substring(0, sp)
        }
        return (val === "part" || val === "staff") ? val : ""
    }

    function parseSetTag(rawText) {
        var s = normalizeTextBasic(rawText)
        var lower = s.toLowerCase()
        var idx = lower.indexOf("ks:set")
        if (idx < 0)
            return ""
        var i = idx + 6
        while (i < s.length && s[i] === " ")
            i++
        if (i < s.length && s[i] === "=") {
            i++
            while (i < s.length && s[i] === " ")
                i++
        }
        if (i >= s.length)
            return ""
        var ch = s[i], name = ""
        if (ch === '"' || ch === "'") {
            var q = ch
            i++
            var j = s.indexOf(q, i)
            name = (j === -1) ? s.substring(i).trim() : s.substring(i, j).trim()
        } else {
            var j2 = i
            while (j2 < s.length && s[j2] !== " ")
                j2++
            name = s.substring(i, j2).trim()
        }
        return name
    }

    // KS:Text= tag parsing (can appear in Staff Text or System Text)
    function parseTextTagValues(rawText) {
        var s = normalizeTextBasic(rawText)
        var lower = s.toLowerCase()
        var out = []
        var start = 0

        while (true) {
            var idx = lower.indexOf("ks:text", start)
            if (idx < 0)
                break
            var i = idx + 7
            while (i < s.length && s[i] === " ")
                i++

            if (i < s.length && s[i] === "=") {
                i++
                while (i < s.length && s[i] === " ")
                    i++
            }
            if (i >= s.length) {
                start = idx + 7
                continue
            }

            var ch = s[i], val = ""
            if (ch === '"' || ch === "'") {
                var q = ch
                i++
                var j = s.indexOf(q, i)
                val = (j === -1) ? s.substring(i).trim() : s.substring(i, j).trim()
                start = (j === -1) ? s.length : (j + 1)
            } else {
                var j2 = i
                while (j2 < s.length && s[j2] !== " ")
                    j2++
                val = s.substring(i, j2).trim()
                start = j2
            }

            if (val.length)
                out.push(val)
        }

        return out
    }

    function partCount() {
        return curScore ? curScore.parts.length : 0
    }

    // Returns the part index (not startTrack) and keeps multi‑part selection logic correct.
    function partInfoForStaff(staffIdx) {
        var staffTrack = staffIdx * 4
        if (!curScore || !curScore.parts)
            return null
        for (var i = 0; i < curScore.parts.length; ++i) {
            var p = curScore.parts[i]
            if (staffTrack >= p.startTrack && staffTrack < p.endTrack)
                return {
                    index: i,
                    start: p.startTrack,
                    end: p.endTrack,
                    part: p
                }
        }
        return null
    }

    function processSelection() {
        emittedCross = ({})
        preflightFailed = false
        sawIneligible = false
        firstIneligibleStaffIdx = -1
        var ineligiblePartIdx = {}
        formattedKsStaff = ({})
        dbg("processSelection: begin")

        var chords = []
        if (curScore.selection.isRange) {
            var startTick = curScore.selection.startSegment.tick
            var endTick = curScore.selection.endSegment ? curScore.selection.endSegment.tick : curScore.lastSegment.tick + 1
            var startStaff = curScore.selection.startStaff
            // MuseScore selection.endStaff behaves as an exclusive bound; convert to inclusive <= loops
            var endStaffInc = Math.max(startStaff, curScore.selection.endStaff - 1);
            // expand staff bounds with any text elements present in the selection (palette-drag or Cmd+T)
            var selMin = curScore.nstaves + 1
            var selMax = -1
            for (var el of curScore.selection.elements) {
                var sIdx = el.staffIdx
                if (sIdx >= 0) {
                    if (sIdx < selMin)
                        selMin = sIdx
                    if (sIdx > selMax)
                        selMax = sIdx
                }
            }
            if (selMax >= 0) {
                if (selMin < startStaff)
                    startStaff = selMin
                if (selMax > endStaffInc)
                    endStaffInc = selMax
            }
            var overrides = scopeOverrideInSelection(startStaff, endStaffInc, startTick, endTick)
            var effScope = overrides.scope ? overrides.scope : rangeScopeMode
            var effParts = overrides.parts ? overrides.parts : selectionPartMode

            // any multi‑part range selection (regardless of which staff it starts on) processes all touched parts
            // unless explicitly overridden by a ks:parts tag
            var partsTouched = {}
            for (var sX = startStaff; sX <= endStaffInc; ++sX) {
                var pX = partInfoForStaff(sX)
                if (pX)
                    partsTouched[pX.index] = true
            }
            var touchedCount = 0
            for (var k in partsTouched)
                touchedCount++
            dbg("selection parts touched=" + touchedCount + " / totalParts=" + partCount());

            // auto-widen whenever a range selection spans multiple parts,
            // unless explicitly overridden by a ks:parts tag in the selection.
            if (!overrides.parts && touchedCount > 1) {
                effParts = "all"
                dbg("parts: auto-widen to 'all' (multi-part selection)")
            }

            var allowedMap = computeAllowedSourceStaves(startStaff, endStaffInc, effScope, effParts)
            dbg("scope: effective='" + effScope + "' parts: effective='" + effParts + "'")
            dbg("allowed source staves: " + Object.keys(allowedMap).sort().join(", "));

            // format KS staves once up front at selection start (avoid mutating the score mid-scan)
            applyKsFormattingForSourceWindow(startStaff, endStaffInc, allowedMap, startTick)

            for (var t = startStaff * 4; t < 4 * (endStaffInc + 1); ++t) {
                var trackStaff = staffIdxFromTrack(t)
                if (!allowedMap[trackStaff])
                    continue
                var eligible = isEligibleSourceStaff(trackStaff)
                var hadNormalChord = false

                var c = curScore.newCursor()
                c.track = t
                c.rewindToTick(startTick)

                while (c.tick < endTick) {
                    var el = c.element
                    if (el && el.type === Element.CHORD && el.noteType === NoteType.NORMAL) {
                        hadNormalChord = true
                        if (eligible) {
                            var sIdx = el.staffIdx
                            dbg("scan: staff=" + sIdx)
                            chords.push(el)
                        }
                    }
                    if (!c.next())
                        break
                }

                if (!eligible && hadNormalChord) {
                    sawIneligible = true
                    if (firstIneligibleStaffIdx < 0)
                        firstIneligibleStaffIdx = trackStaff
                    var piN = partInfoForStaff(trackStaff)
                    if (piN)
                        ineligiblePartIdx[piN.index] = true
                }
            }
        } else {
            for (var el of curScore.selection.elements) {
                var chord = null
                if (el.type === Element.NOTE && el.parent && el.parent.type === Element.CHORD)
                    chord = el.parent
                else if (el.type === Element.CHORD)
                    chord = el
                else
                    continue
                if (chord.noteType !== NoteType.NORMAL)
                    continue
                var sIdx2 = chord.staffIdx
                var ok2 = isEligibleSourceStaff(sIdx2)
                dbg("scan(list): staff=" + sIdx2 + " eligible=" + ok2)
                if (ok2)
                    chords.push(chord)
                else {
                    sawIneligible = true
                    if (firstIneligibleStaffIdx < 0)
                        firstIneligibleStaffIdx = sIdx2
                    var pi2 = partInfoForStaff(sIdx2)
                    if (pi2)
                        ineligiblePartIdx[pi2.index] = true
                }
            }
        }

        dbg2("chords collected", chords.length)
        collectSetTagsInRange();

        // Probe A: how many spanners does the plugin actually see?
        try {
            var N = (curScore && curScore.spanners) ? curScore.spanners.length : 0
            dbg("spanners.length = " + N)
            for (var i = 0; i < N; ++i) {
                var s = curScore.spanners[i]
                var t0 = spStartTick(s), t1 = spEndTick(s), st = spStartStaffIdx(s)
                var u = ""
                try {
                    u = s.userName ? String(s.userName()).toLowerCase() : ""
                } catch (_) {}
                var stn = ""
                try {
                    stn = s.subtypeName ? String(s.subtypeName()).toLowerCase() : ""
                } catch (_) {}
                var bt = ""
                try {
                    bt = (s.beginText && s.beginText.text) ? String(s.beginText.text).toLowerCase() : ""
                } catch (_) {}
                var et = ""
                try {
                    et = (s.endText && s.endText.text) ? String(s.endText.text).toLowerCase() : ""
                } catch (_) {}
                dbg("SP[" + i + "]: type=" + s.type + " [" + t0 + ".." + t1 + ") staff=" + st + " label='" + (u + " " + stn + " " + bt
                                                                                                              + " " + et).trim() + "'")
            }
        } catch (e) {}

        if (debugEnabled && curScore && curScore.spanners && curScore.spanners.length) {
            for (var __i = 0; __i < Math.min(8, curScore.spanners.length); ++__i) {
                var __s = curScore.spanners[__i]
                try {
                    dbg("SP[" + __i + "]: type=" + __s.type + " t=" + spStartTick(__s) + " staff=" + spStartStaffIdx(__s))
                } catch (_e) {}
            }
        }

        // Build slur-start map from 'curScore.spanners' for the time and staff window we’re about to process.
        var _minT = 0, _maxT = 0, _haveT = false
        var _allow = {}
        for (var _i = 0; _i < chords.length; ++_i) {
            var _ch = chords[_i]
            var _t = (_ch.parent && _ch.parent.tick) ? _ch.parent.tick : 0
            if (!_haveT) {
                _minT = _t
                _maxT = _t
                _haveT = true
            } else {
                if (_t < _minT)
                    _minT = _t
                if (_t > _maxT)
                    _maxT = _t
            }
            _allow[_ch.staffIdx] = true
        }
        buildSlurStartMapFromSpanners(_haveT ? _minT : 0, _haveT ? (_maxT + 1) : 0, _allow)
        buildEffectStartMapFromSpanners(_haveT ? _minT : 0, _haveT ? (_maxT + 1) : 0, _allow);

        // Probe B: what did we actually record?
        try {
            var keys = Object.keys(effectRangeByStaff || {})
            for (var i = 0; i < keys.length; ++i) {
                var k = keys[i]
                var L = effectRangeByStaff[k] ? effectRangeByStaff[k].length : 0
                dbg("effectRangeByStaff[" + k + "] = " + L + " entries")
            }
        } catch (_) {}

        chords.sort(function (a, b) {
            if (a.fraction.lessThan(b.fraction))
                return -1
            if (a.fraction.greaterThan(b.fraction))
                return 1
            var pref = (typeof preferVoiceForKSInsertion !== "undefined") ? preferVoiceForKSInsertion : 0
            var da = Math.abs(a.voice - pref), db = Math.abs(b.voice - pref)
            if (da !== db)
                return da - db
            return a.track - b.track
        })

        var created = 0
        for (var chord of chords) {
            var tickHere = (chord.parent && chord.parent.tick) ? chord.parent.tick : 0
            var setName = activeSetNameFor(chord.staffIdx, tickHere)

            if (!setName) {
                // No active set by tag or assignment => do not create keyswitches
                dbg("skip: no active set for staff=" + chord.staffIdx + " tick=" + tickHere)
                continue
            }
            var activeSet = keyswitchSets[setName]
            if (!activeSet) {
                // defensive: unknown/removed set name => skip
                continue
            }

            var texts = segmentTechniqueTexts(chord)
            dbg("texts@tick=" + tickHere + " staff=" + chord.staffIdx + " => " + texts.join(" | "));

            // 1) Get base articulation tokens for this chord
            var artiNames = chordArticulationNames(chord);

            // 2) Add spanner-derived tokens (hairpins / named lines you requested) at this tick
            if (debugEnabled) {
                var __tok = effectTokensAt(chord.staffIdx, tickHere)
                if (__tok && __tok.length)
                    dbg("spanner/range tokens @" + tickHere + " -> " + __tok.join(", "))
            }

            (function () {
                var tok = effectTokensAt(chord.staffIdx, tickHere)
                if (tok && tok.length) {
                    for (var i = 0; i < tok.length; ++i) {
                        if (artiNames.indexOf(tok[i]) === -1)
                            artiNames.push(tok[i])
                    }
                }
            })()

            var specs = [];

            // only use maps from the active set; no global fallback
            var techMap = activeSet.techniqueKeyMap
            var aliasMap = activeSet.techniqueAliases
            if (!aliasMap && globalSettings && globalSettings.techniqueAliases)
                aliasMap = globalSettings.techniqueAliases

            specs = specs.concat(findTaggedTechniqueKeyswitches(texts, techMap))
            var textsNoKsText = stripKsTextDirectivesFromList(texts)
            specs = specs.concat(findTechniqueKeyswitches(textsNoKsText, techMap, aliasMap))
            specs = specs.concat(findArticulationKeyswitches(artiNames, activeSet.articulationKeyMap || null));

            // Debug: what articulations and how many KS specs we will emit at this tick
            try {
                var _tickHere = (chord.parent && chord.parent.tick) ? chord.parent.tick : 0
                dbg("arti@tick=" + _tickHere + " => " + artiNames.join(", ") + " | specs=" + specs.length)
            } catch (eDbgA) {}

            // Slur handling: prefer articulationKeyMap['slur'] at slur start; else fall back to technique 'legato'
            if (interpretSlurAsLegato && hasSlurStartAtChord(chord)) {
                var slurSpec = null
                if (activeSet && activeSet.articulationKeyMap && activeSet.articulationKeyMap.hasOwnProperty('slur')) {
                    slurSpec = parseKsMapValue(activeSet.articulationKeyMap['slur'])
                }
                if (slurSpec) {
                    specs.push(slurSpec)
                } else if (techMap) {
                    var legKey = null
                    // direct lookup preferred
                    if (techMap.hasOwnProperty('legato'))
                        legKey = 'legato'
                    // fallback: find a key whose aliases include 'legato' or 'slur'
                    if (!legKey && aliasMap) {
                        for (var k in aliasMap) {
                            var arr = aliasMap[k]
                            if (!arr)
                                continue
                            var low = arr.join('\u0001').toLowerCase()
                            if (low.indexOf('legato') >= 0 || low.indexOf('slur') >= 0) {
                                legKey = k
                                break
                            }
                        }
                    }
                    if (legKey && techMap.hasOwnProperty(legKey)) {
                        var specL = parseKsMapValue(techMap[legKey])
                        if (specL)
                            specs.push(specL)
                    }
                }
            }

            var seen = {};
            // Determine if the source chord *has any* directive at all (articulation/text/slur→legato).
            var hasAnyDirective = false

            // 1) Any articulation other than "unknown"?
            for (var __i = 0; __i < artiNames.length; ++__i)
                if (artiNames[__i] && artiNames[__i] !== "unknown") {
                    hasAnyDirective = true
                    break
                }

            // 2) Any Staff/System/Expression text at this segment?
            if (!hasAnyDirective && texts && texts.length > 0)
                hasAnyDirective = true;

            // 3) Treat "slur start" as a directive if enabled
            if (!hasAnyDirective && (interpretSlurAsLegato && hasSlurStartAtChord(chord)))
                hasAnyDirective = true;

            // Reconcile the entire desired set (add/update/remove),
            // and only remove on empty 'specs' when hasAnyDirective === false.
            var addedHere = applyKeyswitchSetAt(chord, specs, activeSet, hasAnyDirective)
            created += addedHere
            if (preflightFailed)
                break
        }

        var partialParts = []
        if (created > 0 && warnOnPartialSuccess) {
            for (var idx in ineligiblePartIdx) {
                if (ineligiblePartIdx[idx]) {
                    var idxNum = parseInt(idx, 10)
                    for (var s = 0; s < curScore.staves.length; ++s) {
                        var pi = partInfoForStaff(s)
                        if (pi && pi.index === idxNum) {
                            partialParts.push(nameForPartByRange(s, 0))
                            break
                        }
                    }
                }
            }
        }

        dbg("processSelection: createdCount=" + created + " sawIneligible=" + sawIneligible + " preflightFailed=" + preflightFailed
            + " partialParts=" + partialParts.join(", "))

        if (!preflightFailed && created == 0 && sawIneligible && !promptShown) {
            promptShown = true
            var n = nameForPartByRange(firstIneligibleStaffIdx >= 0 ? firstIneligibleStaffIdx : 0, 0)
            infobox.title = qsTr("Keyswitch staff not found")
            infobox.text = qsTr(
                        "The staff directly below %1 does not belong to the same instrument. Create another staff below %1 then rerun Keyswitch Creator.").arg(
                        n)
            try {
                infobox.open()
            } catch (e) {
                try {
                    infobox.visible = true
                } catch (e2) {}
            }
        } else if (!preflightFailed && created > 0 && partialParts.length > 0 && !promptShown && warnOnPartialSuccess) {
            promptShown = true
            infobox.title = qsTr("Some parts had no keyswitch staff")
            infobox.text = qsTr(
                        "No keyswitches were added for: %1. Add a keyswitch staff below those parts, then rerun Keyswitch Creator.").arg(
                        partialParts.join(", "))
            try {
                infobox.open()
            } catch (e) {
                try {
                    infobox.visible = true
                } catch (e2) {}
            }
        }
        return created
    }

    function sameStaff(trackA, trackB) {
        return staffIdxFromTrack(trackA) === staffIdxFromTrack(trackB)
    }

    function scopeOverrideInSelection(startStaff, endStaff, startTick, endTick) {
        var scopeVal = "", partsVal = ""
        for (var s = startStaff; s <= endStaff; ++s) {
            var c = curScore.newCursor()
            c.track = s * 4
            c.rewindToTick(startTick)
            while (c.tick < endTick) {
                var seg = c.segment
                if (seg) {
                    if (seg.annotations) {
                        for (var ai in seg.annotations) {
                            var ann = seg.annotations[ai]
                            var annStaff = (ann.track === -1) ? s : Math.floor(ann.track / 4)
                            if ((ann.type === Element.STAFF_TEXT || ann.type === Element.SYSTEM_TEXT || ann.type
                                 === Element.EXPRESSION_TEXT) && annStaff === s) {
                                if (!scopeVal)
                                    scopeVal = parseScopeTag(ann.text || "")
                                if (!partsVal)
                                    partsVal = parsePartsTag(ann.text || "")
                                if (scopeVal && partsVal)
                                    return {
                                        scope: scopeVal,
                                        parts: partsVal
                                    }
                            }
                        }
                    }
                    for (var v = 0; v < 4; ++v) {
                        var el = seg.elementAt ? seg.elementAt(s * 4 + v) : null
                        if (el && el.type === Element.CHORD && el.notes) {
                            for (var ni in el.notes) {
                                var note = el.notes[ni]
                                if (!note.elements)
                                    continue
                                for (var ei in note.elements) {
                                    var nel = note.elements[ei]
                                    if (nel.type === Element.TEXT) {
                                        if (!scopeVal)
                                            scopeVal = parseScopeTag(nel.text || "")
                                        if (!partsVal)
                                            partsVal = parsePartsTag(nel.text || "")
                                        if (scopeVal && partsVal)
                                            return {
                                                scope: scopeVal,
                                                parts: partsVal
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
                if (!c.next())
                    break
            }
        }
        return {
            scope: scopeVal,
            parts: partsVal
        }
    }

    function segmentTechniqueTexts(chord) {
        var out = []
        var seg = chord.parent

        // segment-level Staff/System/Expression text (incl. 'Playing technique annotation')
        if (seg && seg.annotations) {
            for (var idx = 0; idx < seg.annotations.length; ++idx) {
                var ann = seg.annotations[idx]
                if (!ann)
                    continue
                var isPlayTech = false
                try { // name-based fallback (seen on some builds)
                    var un = ann.userName ? String(ann.userName()).toLowerCase() : ""
                    isPlayTech = un.indexOf("playing technique annotation") >= 0
                } catch (e) {}

                if (ann.type === Element.STAFF_TEXT || ann.type === Element.SYSTEM_TEXT || ann.type === Element.EXPRESSION_TEXT || ann.type
                        === 57 || isPlayTech) {

                    // best-effort staff determination
                    var annStaffIdx = -1
                    try {
                        if (ann.track !== undefined && ann.track !== -1)
                            annStaffIdx = Math.floor(ann.track / 4)
                        else if (ann.staffIdx !== undefined)
                            annStaffIdx = ann.staffIdx
                        else if (ann.type === Element.STAFF_TEXT || ann.type === Element.EXPRESSION_TEXT)
                            annStaffIdx = chord.staffIdx
                        // palette-drag fallback
                    } catch (e) {
                        annStaffIdx = -1
                    }

                    // SYSTEM_TEXT is global; Staff/Expression must match chord's staff
                    var staffOk = (ann.type === Element.SYSTEM_TEXT) || (annStaffIdx === chord.staffIdx)
                    if (staffOk) {
                        var norm = normalizeTextBasic(ann.text || "").toLowerCase().trim()
                        if (norm.length)
                            out.push(norm)
                    }
                }
            }
        }

        // note-attached plain text
        if (chord.notes) {
            for (var j in chord.notes) {
                var note = chord.notes[j]
                if (!note.elements)
                    continue
                for (var k in note.elements) {
                    var nel = note.elements[k]
                    if (nel.type === Element.TEXT) {
                        var txt = normalizeTextBasic(nel.text || "").toLowerCase().trim()
                        if (txt.length)
                            out.push(txt)
                    }
                }
            }
        }
        return out
    }

    // Apply absolute velocity to a Note in a version-tolerant way.
    // MS4: note.userVelocity (forum reports veloOffset doesn't work there) [3](https://musescore.org/en/node/378892)
    // MS3: note.veloType + note.veloOffset (plugin docs)
    // [1](https://musescore.github.io/MuseScore_PluginAPI_Docs/plugins/html/class_ms_1_1_plugin_a_p_i_1_1_note.html)
    // [2](https://github.com/musescore/MuseScore/blob/master/docs/plugins2to3.md)
    function setKeyswitchNoteVelocity(note, velocity) {
        var v = clampInt(velocity, 0, 127)

        try {
            if (note.userVelocity !== undefined) {
                note.userVelocity = v
                return true
            }
        } catch (e) {}

        return false
    }

    // Helpers
    function staffIdxFromTrack(track) {
        return Math.floor(track / 4)
    }

    // Remove KS:Text=... directives so normal technique matching doesn't see tag contents
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
            out += s.substring(pos, idx);

            // advance i to just after "ks:text"
            var i = idx + 7
            while (i < s.length && s[i] === " ")
                i++;

            // optional '=' and spaces
            if (i < s.length && s[i] === "=") {
                i++
                while (i < s.length && s[i] === " ")
                    i++
            }

            // now skip the value (quoted or single token)
            if (i >= s.length) {
                pos = s.length
                break
            }

            var ch = s[i]
            if (ch === '"' || ch === "'") {
                var q = ch
                i++
                var j = s.indexOf(q, i)
                pos = (j === -1) ? s.length : (j + 1)
            } else {
                var j2 = i
                while (j2 < s.length && s[j2] !== " ")
                    j2++
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

    function targetStaffForKeyswitch(srcStaffIdx) {
        if (!curScore || srcStaffIdx < 0 || srcStaffIdx >= curScore.staves.length)
            return -1
        var last = staffIdxFromTrack(curScore.staves[srcStaffIdx].part.endTrack) - 1
        var ret = (last > srcStaffIdx) ? last : -1
        dbg(qsTr("targetStaffForKeyswitch(range): src=%1 -> target=%2").arg(srcStaffIdx).arg(ret))
        return ret
    }

    // Build a "token" regex that matches alias surrounded by start/end or any non-word char.
    // Works for abbreviations with punctuation (e.g., "nor.", "ord.", "con sord.", etc.).
    function tokenRegex(alias) {
        var core = escapeRegex(String(alias || ""));
        // left boundary: start of string OR a non-word (not [A-Za-z0-9_])
        // right boundary: non-word OR end of string
        return new RegExp('(?:^|[^A-Za-z0-9_])' + core + '(?:[^A-Za-z0-9_]|$)')
    }

    function wasEmittedCross(staffIdx, tick) {
        return emittedCross.hasOwnProperty(crossKey(staffIdx, tick))
    }

    onRun: {
        dbg("onRun: begin")
        // reset per-run prompt suppression
        promptShown = false
        loadRegistryAndAssignments()
        if (!curScore) {
            dbg("No score open; quitting")
            quit()
            return
        }

        if (!curScore.selection.elements.length) {
            dbg("No selection; selecting whole score")
            curScore.startCmd("Keyswitch Creator (whole score)")
            cmd("select-all")
        } else {
            dbg("Selection present (" + curScore.selection.elements.length + " elements)")
            curScore.startCmd("Keyswitch Creator (selection)")
        }

        try {
            savedSelection = (function () {
                if (!curScore.selection.elements.length)
                    return false
                if (curScore.selection.isRange) {
                    var obj = {
                        isRange: true,
                        startSegment: curScore.selection.startSegment.tick,
                        endSegment: curScore.selection.endSegment ? curScore.selection.endSegment.tick : curScore.lastSegment.tick + 1,
                        startStaff: curScore.selection.startStaff,
                        endStaff: curScore.selection.endStaff
                    }
                    dbg("readSelection: range ticks " + obj.startSegment + "…" + obj.endSegment + ", staffs " + obj.startStaff + "–"
                        + obj.endStaff)

                    return obj
                }
                var list = {
                    isRange: false,
                    elements: []
                }
                for (var i in curScore.selection.elements)
                    list.elements.push(curScore.selection.elements[i])
                dbg("readSelection: list with " + list.elements.length + " elements")
                return list
            })()

            var count = processSelection()
            curScore.selection.clear()
            if (savedSelection && savedSelection.isRange) {
                dbg("writeSelection: restoring range")
                curScore.selection.selectRange(savedSelection.startSegment, savedSelection.endSegment, savedSelection.startStaff,
                                               savedSelection.endStaff)
            } else if (savedSelection && !savedSelection.isRange) {
                for (var i in savedSelection.elements)
                    curScore.selection.select(savedSelection.elements[i], true)
            }
            curScore.endCmd()
            dbg2("onRun: end, keyswitches added", count)
        } catch (e) {
            curScore.endCmd(true)
            dbg("ERROR: " + e.toString())
        }
        // if a dialog was opened inside processSelection(), keep the plugin alive
        // so the user can read it. The dialog's onAccepted calls quit().
        if (!promptShown)
            quit()
    }

    Settings {
        id: ksPrefs

        property string globalJSON: ""
        property string setsJSON: ""
        property string staffToSetJSON: ""

        category: "Keyswitch Creator"
    }

    MessageDialog {
        id: infobox

        text: ""
        title: ""

        onAccepted: {
            quit()
        }
    }
}
