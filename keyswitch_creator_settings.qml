//===============================================================================
//  Keyswitch Creator Settings for MuseScore Studio articulation & technique text
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

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Muse.Ui 1.0
import Muse.UiComponents 1.0
import MuseScore 3.0

MuseScore {
    version: "0.9.2"
    title: qsTr("Keyswitch Creator Settings")
    description: qsTr("Assign keyswitch sets to staves and manage set registry + global settings")
    pluginType: "dialog"
    categoryCode: "Keyswitch Creator"

    width: 900
    height: 540

    Settings { id: ksPrefs; category: "Keyswitch Creator"; property string setsJSON: ""; property string staffToSetJSON: ""; property string globalJSON: "" }

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

    // Neutral editor border color
    property color editorBorderColor: ui && ui.theme ? ui.theme.separatorColor : "#cccccc"

    // Shared left text margin to align editor with 'Assign set to...' title
    property int leftTextMargin: 12

    ListModel { id: staffListModel }   // { idx, name }
    ListModel { id: setsListModel }    // { name }

    // ---------- Defaults ----------
    function defaultGlobalSettingsObj() {
        return {
            "priority": ["accent","staccato","tenuto","marcato"],
            "durationPolicy": "source",
            "techniqueAliases": {
                "pizz": ["pizz","pizz.","pizzicato"],
                "con sord": ["con sord","con sord.","con sordino"],
                "sul pont": ["sul pont","sul pont.","sul ponticello"]
            }
        }
    }

    function defaultRegistryObj() {
        return {
            "Generic": {
                "articulationKeyMap": { "staccato": 31, "staccatissimo": 32, "tenuto": 37, "accent": 38, "marcato": 39 },
                "techniqueKeyMap":    { "pizz": 24, "arco": 25, "harmonic": 31, "con sord": 27, "senza sord": 28, "sul pont": 29 }
            }
        }
    }

    // ---------- Compact JSON formatters ----------
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
            if (innerLines.length) lines.push(innerLines.join(',
'))
            lines.push('    }' + (i < setNames.length - 1 ? ',' : ''))
        }
        lines.push('}')
        return lines.join('
')
    }

    function formatGlobalsCompact(glob) {
        var lines = ['{']
        lines.push('    "priority":' + JSON.stringify(glob.priority || [] ) + ',')
        lines.push('    "durationPolicy":' + JSON.stringify(glob.durationPolicy || "source") + ',')
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

    // ---------- Helpers: selection management ----------
    function bumpSelection() { selectedCountProp = Object.keys(selectedStaff).length }
    function clearSelection() { selectedStaff = ({}); bumpSelection() }
    function setRowSelected(rowIndex, on) {
        if (rowIndex < 0 || rowIndex >= staffListModel.count) return
        var sIdx = staffListModel.get(rowIndex).idx
        var ns = Object.assign({}, selectedStaff)
        if (on) ns[sIdx] = true
        else    delete ns[sIdx]
        selectedStaff = ns
        bumpSelection()
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
    }
    function toggleRow(rowIndex) {
        var wasSelected = isRowSelected(rowIndex)
        setRowSelected(rowIndex, !wasSelected)
        lastAnchorIndex = rowIndex
        currentStaffIdx = staffListModel.get(rowIndex).idx
        if (selectedCountProp === 0) setRowSelected(rowIndex, true)
    }
    function selectRange(rowIndex) {
        if (lastAnchorIndex < 0) { selectSingle(rowIndex); return }
        var a = Math.min(lastAnchorIndex, rowIndex)
        var b = Math.max(lastAnchorIndex, rowIndex)
        clearSelection()
        for (var r = a; r <= b; ++r) setRowSelected(r, true)
        currentStaffIdx = staffListModel.get(rowIndex).idx
    }
    function selectAll() {
        clearSelection()
        for (var r = 0; r < staffListModel.count; ++r) setRowSelected(r, true)
        if (staffList.currentIndex >= 0) lastAnchorIndex = staffList.currentIndex
    }

    // ---------- Name helpers (strip CR/LF) ----------
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
               : (p.partName  && p.partName.length)  ? p.partName
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

    function loadData() {
        try { keyswitchSets = (ksPrefs.setsJSON && ksPrefs.setsJSON.length) ? JSON.parse(ksPrefs.setsJSON) : {} } catch (e) { keyswitchSets = {} }
        try { staffToSet   = (ksPrefs.staffToSetJSON && ksPrefs.staffToSetJSON.length) ? JSON.parse(ksPrefs.staffToSetJSON) : {} } catch (e2) { staffToSet = {} }
        try { globalSettings = (ksPrefs.globalJSON && ksPrefs.globalJSON.length) ? JSON.parse(ksPrefs.globalJSON) : defaultGlobalSettingsObj() } catch (e3) { globalSettings = defaultGlobalSettingsObj() }

        if (Object.keys(keyswitchSets).length === 0) keyswitchSets = defaultRegistryObj()

        staffListModel.clear()
        if (curScore && curScore.parts) {
            for (var pIdx = 0; pIdx < curScore.parts.length; ++pIdx) {
                var p = curScore.parts[pIdx]
                var baseStaff = Math.floor(p.startTrack / 4)
                var numStaves = Math.floor((p.endTrack - p.startTrack) / 4)
                var partName  = nameForPart(p, 0)
                var cleanPart = cleanName(partName)
                for (var sOff = 0; sOff < numStaves; ++sOff) {
                    var staffIdx = baseStaff + sOff
                    var display  = cleanPart + ': ' + qsTr('Staff %1 (%2)').arg(sOff + 1).arg(sOff === 1 ? 'Bass' : 'Treble')
                    staffListModel.append({ idx: staffIdx, name: display })
                }
            }
        }
        var initIndex = indexForStaff(0)
        selectSingle(initIndex)

        setsListModel.clear()
        for (var k in keyswitchSets) setsListModel.append({ name: k })

        jsonArea.text    = formatRegistryCompact(keyswitchSets)
        globalsArea.text = formatGlobalsCompact(globalSettings)
    }

    function saveData() {
        ksPrefs.setsJSON       = jsonArea.text
        ksPrefs.globalJSON     = globalsArea.text
        ksPrefs.staffToSetJSON = JSON.stringify(staffToSet)
    }

    onRun: {
        loadData()
        // Ensure initial focus goes to staves list for keyboard shortcuts
        staffList.forceActiveFocus()
    }

    // ---------- UI ----------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // staves list
            GroupBox {
                title: qsTr('Staves')
                Layout.preferredWidth: 216
                Layout.fillHeight: true

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

                        Keys.onPressed: function(event) {
                            var ctrlOrCmd = (event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.MetaModifier)
                            var isShift   = (event.modifiers & Qt.ShiftModifier)
                            if (ctrlOrCmd && event.key === Qt.Key_A) { selectAll(); event.accepted = true; return }
                            if (event.key === Qt.Key_Up)   { var idx = Math.max(0, staffList.currentIndex - 1); if (isShift) selectRange(idx); else selectSingle(idx); staffList.currentIndex = idx; event.accepted = true; return }
                            if (event.key === Qt.Key_Down) { var idx2 = Math.min(staffListModel.count - 1, staffList.currentIndex + 1); if (isShift) selectRange(idx2); else selectSingle(idx2); staffList.currentIndex = idx2; event.accepted = true; return }
                        }

                        delegate: ItemDelegate {
                            id: rowDelegate
                            width: ListView.view.width
                            text: cleanName(model.name)

                            background: Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: isRowSelected(index) ? ui.theme.accentColor : "transparent"
                                opacity: isRowSelected(index) ? 0.30 : 1.0
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                onClicked: function(mouse) {
                                    var idx = index
                                    var ctrlOrCmd = (mouse.modifiers & Qt.ControlModifier) || (mouse.modifiers & Qt.MetaModifier)
                                    var isShift   = (mouse.modifiers & Qt.ShiftModifier)
                                    if (isShift)       selectRange(idx)
                                    else if (ctrlOrCmd) toggleRow(idx)
                                    else               selectSingle(idx)
                                    staffList.currentIndex = idx
                                }
                            }
                        }
                    }
                }
            }

            // Assign set to + editors
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                GroupBox {
                    title: (selectedCountProp === 1 && currentStaffIdx >= 0)
                           ? qsTr('Assign set to ') + cleanName(staffNameByIdx(currentStaffIdx))
                           : qsTr('Assign set to %1 staves').arg(selectedCountProp)
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160

                    ButtonGroup { id: setGroup; exclusive: true }

                    ScrollView {
                        anchors.fill: parent
                        ListView {
                            id: setsList
                            clip: true
                            model: setsListModel
                            spacing: 8
                            delegate: Row {
                                width: ListView.view.width
                                spacing: 10
                                padding: 3

                                RoundedRadioButton {
                                    id: rb
                                    ButtonGroup.group: setGroup
                                    checked: (selectedCountProp === 1 && currentStaffIdx >= 0)
                                             ? ((staffToSet[currentStaffIdx.toString()] || 'Generic') === model.name)
                                             : false
                                    onClicked: {
                                        var keys = Object.keys(selectedStaff)
                                        if (keys.length === 0 && currentStaffIdx >= 0)
                                            staffToSet[currentStaffIdx.toString()] = model.name
                                        else
                                            for (var i = 0; i < keys.length; ++i)
                                                staffToSet[keys[i]] = model.name
                                    }
                                }

                                StyledTextLabel {
                                    text: model.name
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 4
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            rb.checked = true
                                            var keys = Object.keys(selectedStaff)
                                            if (keys.length === 0 && currentStaffIdx >= 0)
                                                staffToSet[currentStaffIdx.toString()] = model.name
                                            else
                                                for (var i = 0; i < keys.length; ++i)
                                                    staffToSet[keys[i]] = model.name
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    StyledTabBar {
                        id: editorTabs
                        Layout.fillWidth: true
                        spacing: 36
                        background: Item { implicitHeight: 32 }

                        StyledTabButton { text: qsTr("Edit set registry"); onClicked: editorModeIndex = 0 }
                        StyledTabButton { text: qsTr("Global settings");   onClicked: editorModeIndex = 1 }
                    }

                    StackLayout {
                        id: navTabPanel
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: -1   // hug tabs above
                        currentIndex: editorModeIndex

                        // Registry editor tab
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: leftTextMargin

                            Rectangle {
                                id: registryFrame
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: editorBorderColor
                                radius: 4

                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 0
                                    TextArea {
                                        id: jsonArea
                                        wrapMode: TextArea.NoWrap
                                        font.family: 'monospace'
                                    }
                                }
                            }
                        }

                        // Globals editor tab
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: leftTextMargin

                            Rectangle {
                                id: globalsFrame
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: editorBorderColor
                                radius: 4

                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 0
                                    TextArea {
                                        id: globalsArea
                                        wrapMode: TextArea.NoWrap
                                        font.family: 'monospace'
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    FlatButton {
                        text: qsTr('Reset to Default')
                        onClicked: {
                            if (editorModeIndex === 0)
                                jsonArea.text = formatRegistryCompact(defaultRegistryObj())
                            else
                                globalsArea.text = formatGlobalsCompact(defaultGlobalSettingsObj())
                        }
                    }

                    Item { Layout.fillWidth: true }

                    FlatButton { text: qsTr('Save'); accentButton: true; onClicked: { saveData(); quit() } }
                    FlatButton { text: qsTr('Cancel'); onClicked: quit() }
                }
            }
        }
    }
}
