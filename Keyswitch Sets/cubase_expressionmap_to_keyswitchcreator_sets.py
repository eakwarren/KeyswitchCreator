#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
cubase_expressionmap_to_keyswitchcreator_sets.py
v1.1
Build Keyswitch Creator set entries from Cubase .expressionmap files.
Requires Python 3.9+ (stdlib only).

Behavior:
- Read PSoundSlot objects from InstrumentMap/member[@name="slots"].
- Name = the embedded USlotVisuals description, preserving exact case.
- If a PSoundSlot does not contain an embedded USlotVisuals object, use its
  member[@name="name"]/string[@name="s"] display name. Some Cubase expression
  maps store visual definitions only in the top-level slotvisuals collection.
- By default, include only simple primary articulations: exactly one visual
  whose group is 0, with no modifier visuals. This excludes modifier-only and
  compound slots such as "Soft release" and "Long soft rel.".
- Keyswitch = PSlotMidiAction/int[@name="key"] in the range 0..127.
- If key is absent, use data1 from the first POutputEvent whose status is a
  MIDI Note On value (144..159).
- Ignore controller events and outgoing MIDI velocity.
- If the exact articulation name lowercased is in the MuseScore default set,
  write it to articulationKeyMap under that lowercase key.
- Otherwise, write it to techniqueKeyMap using its exact name, except known
  technique names such as Legato, Tremolo, and Pizzicato are lowercased.
- Duplicate exact articulation names within one expression map are fatal.
- Set key naming from filename: "Instrument [PREFIX].expressionmap" becomes
  "PREFIX Instrument". Without bracket tags, use the filename stem.

Options:
--wrap
- Default (no --wrap): output contains ONLY bare set entries. There is no
  enclosing outer "{" or "}". The set-entry lines retain four-space JSON
  indentation so they can be pasted into an existing outer JSON object.
- With --wrap: output is a complete JSON object with standard four-space
  indentation.

--sort-sets
- Default: preserve collection order. Expression maps found through
  --inputs-file are processed after positional inputs and overwrite a set with
  the same generated set name.
- With --sort-sets: write set entries A-to-Z, case-insensitively.

--inputs-file
- Read expression-map files, directories, or glob patterns from a text file,
  one entry per line. Blank lines and lines beginning with "#" are ignored.
  Directories are searched recursively; recursive glob patterns are supported.
  inputs.txt example:
  # Individual map
  ~/Expression Maps/Strings.expressionmap

  # Recursive directory
  ~/Expression Maps

  # Recursive glob
  ~/Downloads/**/*.expressionmap

--include-composites
- Also include modifier and compound sound slots. Their PSoundSlot display name
  is used when available. Controller data is still not encoded in the output.

Usage:
Recurse a top-level directory and sort sets by name
python3 cubase_expressionmap_to_keyswitchcreator_sets.py '/path/to/file-or-folder' --sort-sets --out 'All Keyswitch Sets.json'

Provide an inputs file and wrap in outer braces
python3 cubase_expressionmap_to_keyswitchcreator_sets.py --inputs-file '/path/to/file-or-folder' --wrap --out 'All Keyswitch Sets.json'

"""

from __future__ import annotations

import argparse
import glob
import html
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

MS_DEFAULT_SYMBOLS = {
    "staccato", "staccatissimo", "tenuto", "accent", "marcato",
    "sforzato", "loure", "fermata", "trill", "mordent",
    "mordent inverted", "turn", "harmonics", "mute",
}

TECHNIQUE_LOWERCASE = {
    "legato", "tremolo", "pizzicato", "col legno", "sul pont.",
    "sul tasto",
}

BRACKET_RX = re.compile(r"\[(.*?)\]")


def local_tag(elem: ET.Element) -> str:
    return elem.tag.rsplit("}", 1)[-1]


def named_value(parent: ET.Element, tag: str, name: str) -> Optional[str]:
    for elem in parent.iter():
        if local_tag(elem) == tag and elem.get("name") == name:
            value = elem.get("value")
            if value is not None:
                return value
    return None


def direct_named_child(parent: ET.Element, tag: str, name: str) -> Optional[ET.Element]:
    for child in parent:
        if local_tag(child) == tag and child.get("name") == name:
            return child
    return None


def parse_int(value: Optional[str], minimum: int = 0, maximum: int = 127) -> Optional[int]:
    if value is None:
        return None
    try:
        number = int(value, 10)
    except (TypeError, ValueError):
        return None
    return number if minimum <= number <= maximum else None


def split_filename_for_setname(filename: str) -> str:
    base = os.path.splitext(os.path.basename(filename))[0]
    tags = BRACKET_RX.findall(base)
    instrument = BRACKET_RX.sub("", base).strip()
    prefix = " ".join(tag.strip() for tag in tags if tag.strip())
    return f"{prefix} {instrument}".strip() if prefix else instrument


def maybe_lower_technique_key(exact_name: str) -> str:
    original = exact_name.strip()
    probe = re.sub(r"\s+", " ", original).lower()
    return probe if probe in TECHNIQUE_LOWERCASE or probe.rstrip(".") in TECHNIQUE_LOWERCASE else original


def load_xml(path: str) -> ET.Element:
    try:
        return ET.parse(path).getroot()
    except ET.ParseError:
        # Also accept files whose XML was copied as HTML entities.
        text = open(path, "r", encoding="utf-8-sig").read()
        decoded = html.unescape(text)
        return ET.fromstring(decoded)


def find_slots_member(root: ET.Element) -> Optional[ET.Element]:
    for elem in root.iter():
        if local_tag(elem) == "member" and elem.get("name") == "slots":
            return elem
    return None


def direct_sound_slots(slots_member: ET.Element) -> Iterable[ET.Element]:
    for elem in slots_member.iter():
        if local_tag(elem) == "obj" and elem.get("class") == "PSoundSlot":
            yield elem


def slot_visuals(slot: ET.Element) -> List[Tuple[str, int]]:
    sv = direct_named_child(slot, "member", "sv")
    if sv is None:
        return []

    visuals: List[Tuple[str, int]] = []
    for obj in sv.iter():
        if local_tag(obj) != "obj" or obj.get("class") != "USlotVisuals":
            continue
        description = named_value(obj, "string", "description")
        group = parse_int(named_value(obj, "int", "group"), 0, 2_147_483_647)
        if description and description.strip() and group is not None:
            visuals.append((description.strip(), group))
    return visuals


def slot_member_name(slot: ET.Element) -> Optional[str]:
    member = direct_named_child(slot, "member", "name")
    if member is None:
        return None
    value = named_value(member, "string", "s")
    return value.strip() if value and value.strip() else None


def slot_keyswitch(slot: ET.Element) -> Optional[int]:
    action = None
    for child in slot:
        if local_tag(child) == "obj" and child.get("class") == "PSlotMidiAction":
            action = child
            break
    if action is None:
        return None

    # Prefer Cubase's summarized key field.
    for child in action:
        if local_tag(child) == "int" and child.get("name") == "key":
            note = parse_int(child.get("value"))
            if note is not None:
                return note

    # Fallback: first Note On POutputEvent in midiMessages.
    midi_messages = direct_named_child(action, "member", "midiMessages")
    if midi_messages is not None:
        for event in midi_messages.iter():
            if local_tag(event) != "obj" or event.get("class") != "POutputEvent":
                continue
            status = parse_int(named_value(event, "int", "status"), 0, 255)
            data1 = parse_int(named_value(event, "int", "data1"))
            if status is not None and 144 <= status <= 159 and data1 is not None:
                return data1
    return None


def extract_slots(root: ET.Element, include_composites: bool = False) -> List[Tuple[str, int]]:
    slots_member = find_slots_member(root)
    if slots_member is None:
        raise ValueError("No InstrumentMap member named 'slots' was found")

    result: List[Tuple[str, int]] = []

    total_slots = 0
    slots_without_name = 0
    slots_without_note = 0
    filtered_visual_slots = 0

    for slot in direct_sound_slots(slots_member):
        total_slots += 1
        visuals = slot_visuals(slot)
        primary = [name for name, group in visuals if group == 0]
        modifiers = [name for name, group in visuals if group != 0]
        member_name = slot_member_name(slot)

        if len(primary) == 1 and not modifiers:
            name = primary[0]
        elif include_composites and (primary or modifiers):
            name = (member_name or " + ".join(primary + modifiers))

        elif not visuals and member_name:
            # Cubase maps may keep visual definitions solely in the
            # top-level slotvisuals collection.
            name = member_name

        else:
            filtered_visual_slots += 1
            continue

        if not name or not name.strip():
            slots_without_name += 1
            continue

        note = slot_keyswitch(slot)
        if note is None:
            slots_without_note += 1
            continue

        result.append((name.strip(), note))

    if not result:
        raise ValueError(
            "No convertible PSoundSlot articulations with keyswitches "
            f"were found. PSoundSlot count={total_slots}; "
            f"filtered by visual structure={filtered_visual_slots}; "
            f"missing name={slots_without_name}; "
            f"missing keyswitch={slots_without_note}."
        )

    return result


def process_expressionmap(path: str, include_composites: bool = False) -> Tuple[str, Dict[str, Dict[str, int]]]:
    root = load_xml(path)
    pairs = extract_slots(root, include_composites=include_composites)

    duplicates = sorted(name for name, count in Counter(name for name, _ in pairs).items() if count > 1)
    if duplicates:
        raise ValueError("Duplicate articulation names: " + ", ".join(duplicates))

    articulation_map: Dict[str, int] = {}
    technique_map: Dict[str, int] = {}
    for exact_name, note in pairs:
        symbol = exact_name.lower()
        if symbol in MS_DEFAULT_SYMBOLS and symbol not in articulation_map:
            articulation_map[symbol] = note
        else:
            technique_key = maybe_lower_technique_key(
                exact_name
            )
            technique_map[technique_key] = note

    return split_filename_for_setname(path), {
        "articulationKeyMap": articulation_map,
        "techniqueKeyMap": technique_map,
    }


def expand_input(path: str) -> Iterable[str]:
    expanded = os.path.abspath(os.path.expanduser(path))
    if os.path.isfile(expanded):
        if expanded.lower().endswith(".expressionmap"):
            yield expanded
        return
    if os.path.isdir(expanded):
        for dirpath, _, filenames in os.walk(expanded):
            for filename in filenames:
                if filename.lower().endswith(".expressionmap"):
                    yield os.path.join(dirpath, filename)
        return
    for match in glob.glob(expanded, recursive=True):
        if os.path.isfile(match) and match.lower().endswith(".expressionmap"):
            yield match


def read_inputs_file(path: str) -> Iterable[str]:
    with open(path, "r", encoding="utf-8-sig") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if line and not line.startswith("#"):
                yield line


def collect(paths: Sequence[str], inputs_file: Optional[str], include_composites: bool) -> Dict[str, Dict[str, Dict[str, int]]]:
    files: List[str] = []
    for path in paths:
        files.extend(expand_input(path))
    if inputs_file:
        for path in read_inputs_file(inputs_file):
            files.extend(expand_input(path))

    sets: Dict[str, Dict[str, Dict[str, int]]] = {}
    seen_files = set()
    for path in files:
        real_path = os.path.realpath(path)
        if real_path in seen_files:
            continue
        seen_files.add(real_path)
        try:
            set_name, entry = process_expressionmap(path, include_composites)
        except (OSError, ET.ParseError, ValueError) as exc:
            print(f"Error: {path}: {exc}", file=sys.stderr)
            raise SystemExit(1) from exc
        sets[set_name] = entry
    return sets


def render_output(sets: Dict[str, Dict[str, Dict[str, int]]], wrap: bool) -> str:
    if wrap:
        return json.dumps(sets, indent=4, ensure_ascii=False) + "\n"

    body = json.dumps(sets, indent=4, ensure_ascii=False)
    lines = body.splitlines()
    inner_lines = lines[1:-1] if len(lines) >= 2 else []
    return "\n".join(inner_lines) + ("\n" if inner_lines else "")


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert Cubase expression maps to Keyswitch Creator JSON sets")
    parser.add_argument("inputs", nargs="*", help="Expression map file(s), directories, or glob patterns")
    parser.add_argument("--inputs-file", help="Text file listing files, directories, or globs")
    parser.add_argument("--out", default="Keyswitch Sets.json", help="Output JSON path")
    parser.add_argument("--wrap", action="store_true", help="Write a complete outer JSON object")
    parser.add_argument("--sort-sets", action="store_true", help="Sort set names case-insensitively")
    parser.add_argument("--include-composites", action="store_true", help="Also include slots containing modifiers/combinations")
    args = parser.parse_args()

    if not args.inputs and not args.inputs_file:
        parser.error("provide at least one input or --inputs-file")

    sets = collect(args.inputs, args.inputs_file, args.include_composites)
    if not sets:
        parser.error("no .expressionmap files were found")
    if args.sort_sets:
        sets = dict(sorted(sets.items(), key=lambda item: item[0].casefold()))

    with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(render_output(sets, args.wrap))
    print(f"Wrote {len(sets)} set(s) to {args.out}")


if __name__ == "__main__":
    main()
