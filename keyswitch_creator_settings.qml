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
import QtQuick.Window 2.15
import Muse.Ui 1.0
//import Muse.UiComponents 1.0
import MuseScore.NotationScene 1.0
import MuseScore 3.0

MuseScore {
  version: "0.9.3.12 combo"
  title: qsTr("Keyswitch Creator Settings")
  description: qsTr("Assign keyswitch sets to staves and manage set registry + global settings")
  pluginType: "dialog"
  categoryCode: "Keyswitch Creator"
  width: 1385
  height: 810

  //-----------------------------------------------------------------------------
  // Settings storage
  //-----------------------------------------------------------------------------
  Settings {
    id: ksPrefs
    category: "Keyswitch Creator"
    property string setsJSON: ""
    property string staffToSetJSON: ""
    property string globalJSON: ""
  }

  //-----------------------------------------------------------------------------
  // Data state
  //-----------------------------------------------------------------------------
  property var keyswitchSets: ({})
  property var staffToSet: ({})
  property var globalSettings: ({})
  property int currentStaffIdx: -1
  property int lastAnchorIndex: -1
  property var selectedStaff: ({})
  property int selectedCountProp: 0
  property int editorModeIndex: 0 // Mode selector: 0 = registry, 1 = globals

  // Theme colors (safe fallbacks)
  readonly property color themeAccent: (ui && ui.theme && ui.theme.accentColor) ? ui.theme.accentColor : "#2E7DFF"
  readonly property color themeSeparator: (ui && ui.theme && ui.theme.separatorColor) ? ui.theme.separatorColor : "#D0D0D0"
  property color editorBorderColor: themeSeparator // Neutral editor border color (safe)
  property int leftTextMargin: 12 // Shared left text margin to align editor with 'Assign set to...' title

  ListModel { id: staffListModel } // { idx, name }
  ListModel { id: setsListModel }  // { name }

  //--------------------------------------------------------------------------------
  // Defaults
  //--------------------------------------------------------------------------------
  function defaultGlobalSettingsObj() {
    return {
      "priority": ["accent", "staccato", "tenuto", "marcato"],
      "durationPolicy": "source",
      "techniqueAliases": {
        "pizz": ["pizz", "pizz.", "pizzicato"],
        "con sord": ["con sord", "con sord.", "con sordino"],
        "sul pont": ["sul pont", "sul pont.", "sul ponticello"]
      }
    }
  }

  function defaultRegistryObj() {
    return {
      "Default Low": {
        "articulationKeyMap": { "staccato": 0, "tenuto": 1, "accent": 2, "marcato": 3 },
        "techniqueKeyMap": { "pizz": 4, "arco": 5, "harmonic": 6, "con sord": 7, "senza sord": 5, "sul pont": 8 }
      },
      "Default High": {
        "articulationKeyMap": { "staccato": 127, "tenuto": 126, "accent": 125, "marcato": 124 },
        "techniqueKeyMap": { "pizz": 123, "arco": 122, "harmonic": 121, "con sord": 120, "senza sord": 122, "sul pont": 119 }
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
      var innerLines = [] // MOD IN 38
      var innerKeys = Object.keys(setObj) //MOD IN 38 innerKeys -> ks
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

  function bumpSelection() { selectedCountProp = Object.keys(selectedStaff).length } // OK
  function clearSelection() { selectedStaff = ({}); bumpSelection(); refreshUISelectedSet() }  //OK

  function setRowSelected(rowIndex, on) { //OK
    if (rowIndex < 0 || rowIndex >= staffListModel.count) return
    var sIdx = staffListModel.get(rowIndex).idx
    var ns = Object.assign({}, selectedStaff)
    if (on) ns[sIdx] = true
    else delete ns[sIdx]
    selectedStaff = ns
    bumpSelection()
    refreshUISelectedSet()
  }

  function isRowSelected(rowIndex) { //OK
    if (rowIndex < 0 || rowIndex >= staffListModel.count) return false
    var sIdx = staffListModel.get(rowIndex).idx
    return !!selectedStaff[sIdx]
  }

  function selectSingle(rowIndex) { //OK
    clearSelection()
    setRowSelected(rowIndex, true)
    lastAnchorIndex = rowIndex
    if(rowIndex>=0&&rowIndex<staffListModel.count) currentStaffIdx = staffListModel.get(rowIndex).idx
    refreshUISelectedSet()
  }

  // in 38 (but may not work right)
  // function toggleRow(rowIndex){
  //   var was=isRowSelected(rowIndex)
  //   setRowSelected(rowIndex,!was)
  //   lastAnchorIndex=rowIndex
  //   if(rowIndex>=0&&rowIndex<staffListModel.count) currentStaffIdx=staffListModel.get(rowIndex).idx
  //   if(selectedCountProp===0&&staffListModel.count>0) setRowSelected(0,true)
  // }
  function toggleRow(rowIndex) {
    clearSelection()
    setRowSelected(rowIndex,true)
    setRowSelected(rowIndex, !wasSelected)
    lastAnchorIndex = rowIndex //same
    currentStaffIdx = staffListModel.get(rowIndex).idx
    if (selectedCountProp === 0) setRowSelected(rowIndex, true)
    refreshUISelectedSet()
  }

  function selectRange(rowIndex) {
    if (lastAnchorIndex < 0) { selectSingle(rowIndex); return }
    var a = Math.min(lastAnchorIndex, rowIndex)
    var b = Math.max(lastAnchorIndex, rowIndex)
    clearSelection()
    // for(var r=a;r<=b&&r<staffListModel.count;++r) setRowSelected(r,true)
    for (var r = a; r <= b; ++r) setRowSelected(r, true)
    // if(rowIndex>=0&&rowIndex<staffListModel.count)
    currentStaffIdx = staffListModel.get(rowIndex).idx
    refreshUISelectedSet()
  }

  function selectAll() { //OK
    clearSelection()
    for (var r = 0; r < staffListModel.count; ++r) setRowSelected(r, true)
    if (staffList.currentIndex >= 0) lastAnchorIndex = staffList.currentIndex
    refreshUISelectedSet()
  }

  //--------------------------------------------------------------------------------
  // Name helpers (strip CR/LF)
  //--------------------------------------------------------------------------------
  function cleanName(s) { //OK
    var t = String(s || '')
    t = t.split('
').join(' ')
    t = t.split('
').join(' ')
    return t
  }

  function staffBaseTrack(staffIdx) { return staffIdx * 4 }

  function partForStaff(staffIdx) { //OK
    if (!curScore || !curScore.parts) return null
    var t = staffBaseTrack(staffIdx)
    for (var i = 0; i < curScore.parts.length; ++i) {
      var p = curScore.parts[i]
      if (t >= p.startTrack && t < p.endTrack) return p
    }
    return null
  }

  function nameForPart(p, tick) { //OK
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

  function indexForStaff(staffIdx) { //OK
    for (var i = 0; i < staffListModel.count; ++i) {
      var item = staffListModel.get(i)
      if (item && item.idx === staffIdx) return i
    }
    return 0
  }

  function staffNameByIdx(staffIdx) { //OK
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
  function loadData() { //MOD IN 38
    try { keyswitchSets = (ksPrefs.setsJSON && ksPrefs.setsJSON.length) ? JSON.parse(ksPrefs.setsJSON) : {} } catch (e) { keyswitchSets = {} }
    try { staffToSet = (ksPrefs.staffToSetJSON && ksPrefs.staffToSetJSON.length) ? JSON.parse(ksPrefs.staffToSetJSON) : {} } catch (e2) { staffToSet = {} }
    try { globalSettings = (ksPrefs.globalJSON && ksPrefs.globalJSON.length) ? JSON.parse(ksPrefs.globalJSON) : defaultGlobalSettingsObj() } catch (e3) { globalSettings = defaultGlobalSettingsObj() }

    if (Object.keys(keyswitchSets).length === 0) keyswitchSets = defaultRegistryObj()

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

    var initIndex = indexForStaff(0) //here only
    selectSingle(initIndex) //here only

    setsListModel.clear()
    for (var k in keyswitchSets) /*if (keyswitchSets.hasOwnProperty(k))*/ setsListModel.append({ name: k })

    /*if (jsonArea)*/jsonArea.text = formatRegistryCompact(keyswitchSets)
    /*if (globalsArea)*/globalsArea.text = formatGlobalsCompact(globalSettings)

    refreshUISelectedSet()
  }

  function saveData() { //OK
    ksPrefs.setsJSON = jsonArea.text
    ksPrefs.globalJSON = globalsArea.text
    ksPrefs.staffToSetJSON = JSON.stringify(staffToSet)
  }

  onRun: {
    loadData()
    // Ensure initial focus goes to staves list for keyboard shortcuts
    /*if (staffList) */staffList.forceActiveFocus()
    refreshUISelectedSet()
  }
  // Component.onCompleted: { if (staffListModel.count===0 && setsListModel.count===0) loadData() } //in 38

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
        title: qsTr('Staves')
        Layout.preferredWidth: 216
        Layout.fillHeight: true

        ScrollView {
          id: stavesScroll //missing from 38
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
              id: rowDelegate //not in 38
              width: ListView.view.width
              text: cleanName(model.name)
              background: Rectangle {
                anchors.fill: parent
                radius: 6
                color: isRowSelected(index) ? themeAccent : "transparent"
                opacity: isRowSelected(index) ? 0.30 : 1.0
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
                }
              }
            }
          }
        }
      }

      // Right side: Assign set to ...
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        // Hidden icon-size probe using a standard icon button to get canonical metrics
        FlatButton { id: _iconProbe; visible: false; icon: IconCode.SAVE }

        // Title row with dynamic text and the piano icon button
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
          // Piano button styled as FlatButton; glyph from MuseScoreIcon font (U+F3BB), rotated -90°
          FlatButton {
            id: pianoButton
            Layout.preferredWidth: _iconProbe.implicitHeight
            Layout.preferredHeight: _iconProbe.implicitHeight
            width: _iconProbe.implicitHeight
            height: _iconProbe.implicitHeight
            transparent: false
            clip: true
            onClicked: { //handles piano window creation?
              var w=null; try { w=(Qt.application && Qt.application.activeWindow)? Qt.application.activeWindow : null } catch(e){ w=null }
              verticalKbWindow.transientParent = w; verticalKbWindow.forceOnTop = (w===null)
              if (!verticalKbWindow.visible) {
                verticalKbWindow.x=120; verticalKbWindow.y=120
                try { if (ksPrefs.kbWindowGeomJSON && ksPrefs.kbWindowGeomJSON.length) { var g=JSON.parse(ksPrefs.kbWindowGeomJSON); if (g && typeof g.x==='number' && typeof g.y==='number' && typeof g.w==='number' && typeof g.h==='number') { verticalKbWindow.x=g.x; verticalKbWindow.y=g.y; verticalKbWindow.width=g.w; verticalKbWindow.height=g.h } } } catch(e) {}
                verticalKbWindow.show()
              }
              verticalKbWindow.raise(); verticalKbWindow.requestActivate();
              verticalKbWindow.rebuildKsTextModel()
            }
            Text {
              anchors.centerIn: parent
              text: ""
              font.family: "MuseScoreIcon"
              font.pixelSize: Math.round(parent.height * 0.6)
              rotation: -90
              color: ui && ui.theme ? ui.theme.fontPrimaryColor : "#333"
              renderType: Text.NativeRendering //not in 38. Delete?
            }
          }
        }

        // Set buttons box (title removed so the piano button sits outside the frame)
        GroupBox {
          id: assignBox
          title: ""
          Layout.fillWidth: true
          Layout.preferredHeight: 160

          // Size probe to match FlatButton metrics (use the exact component type)
          FlatButton { id: _sizeProbe; visible: false; text: qsTr('Save'); accentButton: true }

          ScrollView {
            anchors.fill: parent

            Flow {
              id: setButtonsFlow
              width: parent.width
              spacing: 8
              flow: Flow.LeftToRight

              // Local UI-selected set; updated by refreshUISelectedSet() and on clicks
              property string uiSelectedSet: "__none__"

              Repeater {
                model: setsListModel
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
                    // verticalKbWindow.rebuildKsTextModel() //only in 38
                  }
                }
              }
            }
          }
        }

        // Editors (unchanged)
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 0

          StyledTabBar {
            id: editorTabs
            Layout.fillWidth: true
            spacing: 36
            background: Item { implicitHeight: 32 }
            StyledTabButton { text: qsTr('Edit set registry'); onClicked: editorModeIndex = 0 } //no error in 38
            StyledTabButton { text: qsTr('Global settings'); onClicked: editorModeIndex = 1 } //no error in 38
          }

          StackLayout {
            id: navTabPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: -1
            currentIndex: editorModeIndex

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
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

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
      FlatButton { id: saveButtonRef; text: qsTr('Save'); accentButton: true; onClicked: { saveData(); quit() } } //no error in 38
      FlatButton { id: cancelButtonRef; text: qsTr('Cancel'); onClicked: quit() }
    }
  }

  //-----------------------------------------------------------------------------
  // Vertical keyboard Window – keyboard + synchronized text column
  //-----------------------------------------------------------------------------
  Window {
    id: verticalKbWindow
    visible: false
    modality: Qt.NonModal


    // 1) When the vertical keyboard window is shown, rebuild from the current set
    Component.onCompleted: { rebuildKsTextModel() }
    onVisibleChanged:      if (visible) Qt.callLater(rebuildKsTextModel)

    // 2) Rebuild whenever the selected set changes
    Connections {
      target: setButtonsFlow
      function onUiSelectedSetChanged() { rebuildKsTextModel() }
    }

    // 3) Rebuild whenever the registry JSON changes (e.g., after Save)
    Connections {
      target: ksPrefs
      function onSetsJSONChanged() {
        try { keyswitchSets = (ksPrefs.setsJSON && ksPrefs.setsJSON.length) ? JSON.parse(ksPrefs.setsJSON) : {};
        } catch (e) {
          keyswitchSets = {};
        }
        rebuildKsTextModel();
      }
    }

    // Thickness of the vertical keyboard stripe
    property int keyThickness:  (width > 0 ? Math.max(160, Math.min(360, Math.round(width * 0.22))) : 220)
    // Width of your label column (adjust to taste)
    property int labelWidth:    250

    // Key geometry used to compute the full 128-key vertical length
    property real whiteKeyUnitPx: 22
    property real blackKeyUnitRatio: 0.60
    function isWhite(m)        { var pc=(m%12+12)%12; return !(pc===1||pc===3||pc===6||pc===8||pc===10) }
    function keyUnit(m)        { return isWhite(m) ? whiteKeyUnitPx : (whiteKeyUnitPx * blackKeyUnitRatio) }


    // --- Visual calibration for PianoKeyboardPanel ---
    // Small padding that the panel paints around the stack (tune if needed)
    property int panelTopPadPx:    1    // pixels from the top (G9 side)
    property int panelBottomPadPx: 1    // pixels from the bottom (C-1 side)

    // If the panel draws a 1px separator between white rows, account for it here.
    // Start with 0; increase to 1 if you still see a consistent "one-pixel high" drift.
    property int whiteRowSeparatorPx: 0

    // Some builds render black key rectangles a touch above/below their midpoint.
    // Bias the center for whites/blacks independently (can be negative).
    // These are the key ones to tune. NEGATIVE values move labels/lines DOWN.
    property real whiteCenterBiasPx: 0.0   // try -1.0 .. -1.5 for whites
    property real blackCenterBiasPx: 0.0   // try -2.0 .. -2.5 for blacks

    // Per-pitch-class fine offsets (px), repeats every octave ---
    // Order: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
    // NEGATIVE moves label downward, POSITIVE upward (because we measure from bottom).
    property var pcCenterBiasPx: [
      0.0,  // C
      0.0,  // C#
      0.0,  // D
      0.0,  // D#
      0.0,  // E
      0.0,  // F
      0.0,  // F#
      0.0,  // G
      0.0,  // G#
      0.0,  // A
      0.0,  // A#
      0.0   // B
    ]

    // Pitch-class helpers
    function pcOf(m) { return ((m|0) % 12 + 12) % 12 }
    function isWhitePC(pc) { return !(pc === 1 || pc === 3 || pc === 6 || pc === 8 || pc === 10) }
    function pcBias(m) { return pcCenterBiasPx[pcOf(m)] || 0.0 }


    // Utility: distance from TOP (G9) to TOP of MIDI m, including row separators for whites
    function cumulativeBeforeFromTopWithPads(m) {
        var s = 0;
        var mm = Math.max(0, Math.min(127, m));
        for (var i = 127; i > mm; --i) {
            s += keyUnit(i);
            if (isWhite(i)) s += whiteRowSeparatorPx;
        }
        return panelTopPadPx + s;
    }

    // Centerline from TOP including pads/bias
    function labelCenterYFromTopCalibrated(m) {
      var mm = Math.max(0, Math.min(127, m));
      var base = cumulativeBeforeFromTopWithPads(mm) + keyUnit(mm) * 0.5;
      var pc   = pcOf(mm);
      var wbBias = isWhitePC(pc) ? whiteCenterBiasPx : blackCenterBiasPx;
      return base + wbBias + pcBias(mm);
    }

    // Centerline from BOTTOM (C-1) including pads/bias
    function labelCenterYFromBottomCalibrated(m) {
      // total painted height we target = pads + all units + pads
      var sepSum = (function(){
        var w=0; for (var i=1;i<=127;++i) if (isWhite(i)) ++w; return w*whiteRowSeparatorPx;
      })();
      var paintedTotal = panelTopPadPx + totalUnits + panelBottomPadPx + sepSum;
      return paintedTotal - labelCenterYFromTopCalibrated(m);
    }

    // Distance from TOP (G9) to TOP of MIDI m
    function cumulativeBeforeFromTop(m) {
        var s = 0, mm = Math.max(0, Math.min(127, m));
        for (var i = 127; i > mm; --i) s += keyUnit(i);
        return s;
    }

    // Centerline from TOP
    function labelCenterYFromTop(m) {
        var mm = Math.max(0, Math.min(127, m));
        return cumulativeBeforeFromTop(mm) + keyUnit(mm) * 0.5;
    }

    // Centerline from BOTTOM (C‑1)
    function labelCenterYFromBottom(m) {
        return totalUnits - labelCenterYFromTop(m);
    }

    property real totalUnits:  (function(){ var s=0; for (var i=0;i<128;++i) s += keyUnit(i); return s })()

    property bool forceOnTop: false

    property int midiOffset: 0

    function toGeom(m){ return m - midiOffset }
    function keyCenterY(m){ var g = toGeom(m); return isBlackGeom(g)
                             ? blackTopYAdjustedGeom(g) + Math.round(blackHeight/2)
                             : rowTopYGeom(g) + Math.round(keyHeight/2) }

    flags: forceOnTop
           ? (Qt.Tool | Qt.WindowTitleHint | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint | Qt.WindowStaysOnTopHint)
           : (Qt.Tool | Qt.WindowTitleHint | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint)
    title: qsTr('Keyboard Map')

    width: 350
    height: 850
    color: ui && ui.theme ? ui.theme.backgroundPrimaryColor : "#f2f2f2"

    // Text model from the active set (labels placed by MIDI mapping)
    ListModel { id: ksTextModel } // { midi:int, label:string }

    function activeSetName(){ return setButtonsFlow ? setButtonsFlow.uiSelectedSet : "__none__" }

    function rebuildKsTextModel(){
      var name = activeSetName(); var setObj = keyswitchSets[name] || {}; var A=setObj.articulationKeyMap || {}; var T=setObj.techniqueKeyMap || {}
      var rows = []
      for (var k in A) if (A.hasOwnProperty(k)) rows.push({ midi: A[k], label: 'Articulation | '+k })
      for (var t in T) if (T.hasOwnProperty(t)) rows.push({ midi: T[t], label: 'Technique | '+t })
      // was: rows.sort(function(a,b){ return b.midi - a.midi })
      rows.sort(function(a,b){ return a.midi - b.midi }); // lowest MIDI first (C‑1 first)

      ksTextModel.clear(); for (var i=0;i<rows.length;++i) ksTextModel.append(rows[i])
    }


    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 0
      anchors.bottomMargin: 10
      spacing: 0



      ScrollView {
        id: kbScroll
        Layout.fillWidth:  true
        Layout.fillHeight: true
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        // 1) Helper to scroll to the very bottom (C-1 visible)
        function scrollBottom() {
          // NOTE: in QQC2 ScrollView, the *inner Flickable* is contentItem
          var f = kbScroll.contentItem;
          f.contentY = Math.max(0, f.contentHeight - f.height);
        }

        // 2) Run after the first layout pass (and once more a tick later)
        Component.onCompleted: {
          Qt.callLater(kbScroll.scrollBottom);   // next event-loop turn
          deferredBottom.restart();              // one more after ~30ms
        }

        // 3) Re-apply whenever the inner Flickable’s geometry changes
        Connections {
          target: kbScroll.contentItem          // the Flickable inside ScrollView
          function onContentHeightChanged() { kbScroll.scrollBottom() }
          function onHeightChanged()        { kbScroll.scrollBottom() }
          // OPTIONAL: if you ever change width dynamically and want to keep it,
          // you can watch onWidthChanged() here too.
        }

        // 4) One-shot timer to handle late-bound sizing (fonts, transforms, etc.)
        Timer {
          id: deferredBottom
          interval: 30
          running: false
          repeat: false
          onTriggered: kbScroll.scrollBottom()
        }


        // The logical content area of the ScrollView:
        // width = keyboard thickness + label column
        // height = full 128-key vertical length
        Item {
          id: contentArea
          width:  verticalKbWindow.keyThickness + verticalKbWindow.labelWidth
          height: verticalKbWindow.totalUnits

          // CRITICAL: expose implicit sizes so ScrollView's Flickable computes full content
          implicitWidth:  width
          implicitHeight: height

          Row {
            id: contentRow
            anchors.fill: parent
            spacing: 0      // change to >0 if you want a tiny gap between keys and labels

            // ===== THIN keyboard column used for Row layout =====
            // Row will treat this as 'keyThickness' wide (correct), not the unrotated long side
            Item {
              id: kbColumn
              width:  verticalKbWindow.keyThickness   // <-- thin stripe as you see it
              height: contentArea.height

              // The rotated content lives inside this thin column
              Item {
                id: rot
                // UNROTATED dimensions (swap axes BEFORE rotation)
                width:  kbColumn.height                 // long side = 128-key length
                height: kbColumn.width                  // short side = thickness

                // Rotate, then translate DOWN by the UNROTATED width
                transform: [
                  Rotation { angle: -90; origin.x: 0; origin.y: 0 },
                  Translate { y: rot.width }            // NOTE: translate by 'width', NOT height
                ]

                PianoKeyboardPanel {
                  id: msPianoPanel
                  anchors.fill: parent
                  Component.onCompleted: {
                    try {
                      if (typeof msPianoPanel.showFullRange !== "undefined")
                        msPianoPanel.showFullRange = true;
                      if (typeof msPianoPanel.keySizeMode   !== "undefined")
                        msPianoPanel.keySizeMode   = "Normal";
                    } catch (e) { /* defaults */ }
                  }
                }
              }
            }

            // ===== LABELS column immediately to the right of the keyboard =====
            Item {
              id: labelsCanvas
              width:  verticalKbWindow.labelWidth
              height: contentArea.height
              clip:   true


              // Add inside labelsCanvas for debugging; remove later
              Repeater {
                model: 128
                delegate: Rectangle {
                  x: 0
                  width: parent.width
                  height: 1
                  color: "#66FF8800"            // amber
                  y: Math.round(verticalKbWindow.labelCenterYFromBottomCalibrated(index))
                  opacity: 0.5
                }
              }


              Repeater {
                model: ksTextModel

                delegate: Item {
                  // Capture the roles from ListModel directly (NOT model.midi/model.label)
                  // Use a local so we can guard once and keep expressions clean.
                  property int  midiNote: (typeof midi === "number" ? Math.max(0, Math.min(127, midi)) : 0)
                  property string labelText: (typeof label === "string" ? label : "")

                  width:  parent.width
                  height: Math.max(14, verticalKbWindow.whiteKeyUnitPx * 0.70)

                  // Center the row on the MIDI key, measuring from the BOTTOM (so C-1 is near window bottom)
                  y: Math.round(verticalKbWindow.labelCenterYFromBottomCalibrated(midiNote) - height / 2)

                  Text {
                    text: labelText
                    anchors.fill: parent
                    anchors.leftMargin:  6
                    anchors.rightMargin: 6
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    font.pixelSize: 14
                    color: (ui && ui.theme && ui.theme.fontPrimaryColor !== undefined)
                           ? ui.theme.fontPrimaryColor : "#ddd"
                  }
                }
              }

            }
          }
        }

      }
    }

  }
}
