#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
logic_plist_to_keyswitchcreator_sets.py

Build Keyswitch Creator set entries from Logic Pro articulation set .plist files.
Requires Python 3.9+ (stdlib only).

Behavior:
- Read only Articulations. Name = ArticulationID (string) EXACT (fallback: Name).
- Keyswitch = Output.MB1 (integer, or decimal string). Ignore Switches entirely.
- Velocity: If the Output block has ValueLow, use it as velocity.
    * Map value written as "note|velocity" (string), e.g., "0|1".
    * If ValueLow is absent, map value is just note integer.
- Symbol handling (MuseScore):
    * If 'Symbol' exists and its lowercase is in the MuseScore default set,
      write to articulationKeyMap under that LOWERCASE key.
    * If a second articulation reuses the same recognized symbol in the
      same file, write that second one to techniqueKeyMap using the original
      EXACT name (no alt2).
    * If 'Symbol' is absent or not recognized, write to techniqueKeyMap
      using the original EXACT name.
- Special case: when writing to techniqueKeyMap, if the EXACT name == "Legato",
  key is "legato".
- Duplicate detection: if ANY two articulations in the same plist resolve to the
  same EXACT name, exit with error and list duplicates.
- Set key naming from filename: "Instrument [PREFIX].plist" → "PREFIX Instrument".

Options:
--wrap
- Default (no --wrap): the output file contains ONLY bare set entries, e.g.:
    "BFO Horn": { ... },
    "SSOD Trumpet": { ... }
  There is NO enclosing '{' or '}'. Each line is indented with exactly 4 spaces
  so it can be pasted inside an outer JSON object cleanly. (When adding more sets
  to existing ones in registry.)
- With --wrap: the output is a COMPLETE JSON object wrapped in braces, with
  standard pretty-printing (opening and closing braces NOT indented) and a
  4-space indent for JSON nesting. (When replacing with a single set in registry.)

--sort-sets
Sorts the generated set entries by set name (case-insensitive) before writing.
- Default behavior (no flag): preserves insertion order (filesystem walk
  order + any entries added from --inputs-file; entries from --inputs-file
  overwrite duplicates from the root scan).
- With --sort-sets: output order is deterministic A→Z by set name, whether
  you write bare entries (default, no --wrap) or a complete object (--wrap).

--inputs-file
Use a listing .plist files, directories (recursed), or globs (recursive globs supported).
One per line; '#' comments allowed. Entries from --inputs-file overwrite same-named sets found via root.
# inputs.txt example
~/Music/Audio Music Apps/Articulation Settings/Horn.plist
~/Music/Audio Music Apps/Articulation Settings
~/Downloads/**/*.plist

Usage:
Recurse a top-level directory and sort sets by name
python3 logic_plist_to_keyswitchcreator_sets.py /path/to/file-or-folder  --sort-sets --out 'All Keyswitch Sets.json'

Provide an inputs file and wrap in outer braces
python3 logic_plist_to_keyswitchcreator_sets.py --inputs-file /path/to/inputs.txt --wrap --out "All Keyswitch Sets.json"

"""

import argparse
import glob
import json
import os
import plistlib
import re
import sys
from typing import Any, Dict, List, Optional, Tuple

# ---------- filename → set name ----------
BRACKET_RX = re.compile(r"\[(.*?)\]")

def split_filename_for_setname(filename: str) -> str:
    """
    'Horn [SFBOC].plist' -> 'SFBOC Horn'
    '[A][B] Violin.plist' -> 'A B Violin'
    If no bracket tags: returns base name without extension.
    """
    base = os.path.splitext(os.path.basename(filename))[0]
    tags = BRACKET_RX.findall(base)
    instrument = BRACKET_RX.sub("", base).strip()
    prefix = " ".join(t.strip() for t in tags if t.strip())
    return f"{prefix} {instrument}".strip() if prefix else instrument

# ---------- Logic default symbols (lowercase) ----------
MS_DEFAULT_SYMBOLS = {
    "staccato",
    "staccatissimo",
    "tenuto",
    "accent",
    "marcato",
    "sforzato",
    "loure",
    "fermata",
    "trill",
    "mordent",
    "mordent inverted",
    "turn",
    "harmonics",
    "mute",
}

# Technique names that should be lowered when used as technique keys
TECHNIQUE_LOWERCASE = {
    "legato",
    "tremolo",
    "pizzicato",
    "col legno",
    "sul pont.",
    "sul tasto",
}

# ---------- plist helpers ----------
def try_load_plist(path: str) -> Optional[Dict[str, Any]]:
    try:
        with open(path, "rb") as f:
            return plistlib.load(f)  # XML or binary
    except Exception:
        return None

def extract_articulations(pl: Dict[str, Any]) -> List[Dict[str, Any]]:
    arts = pl.get("Articulations") or pl.get("articulations")
    return arts if isinstance(arts, list) else []

def get_exact_name(a: Dict[str, Any]) -> Optional[str]:
    """
    Name precedence:
      1) ArticulationID (string) EXACT (strip surrounding whitespace)
      2) Name (string) EXACT (strip surrounding whitespace)
    """
    art_id = a.get("ArticulationID")
    if isinstance(art_id, str):
        nm = art_id.strip()
        if nm:
            return nm
    nm = a.get("Name")
    if isinstance(nm, str):
        nm2 = nm.strip()
        if nm2:
            return nm2
    return None

def get_symbol_lower(a: Dict[str, Any]) -> Optional[str]:
    sym = a.get("Symbol")
    if isinstance(sym, str) and sym.strip():
        return sym.strip().lower()
    return None

def maybe_lower_technique_key(exact_name: str) -> str:
    # Preserve the original for non-matching cases
    original = exact_name.strip()
    # Normalize for matching: collapse spaces, case-insensitive
    normalized = re.sub(r"\s+", " ", original).strip()
    probe = normalized.lower()
    # Try exact, and a variant without trailing dot for robustness
    if probe in TECHNIQUE_LOWERCASE or probe.rstrip(".") in TECHNIQUE_LOWERCASE:
        # Return a lowercased key; keep the trailing dot if present in the source
        return probe
    return original

def _parse_int_0_127(value: Any) -> Optional[int]:
    """
    Parse value as int in [0,127]. Accept int or decimal string (leading zeros ok).
    """
    v = None
    if isinstance(value, int):
        v = value
    elif isinstance(value, str) and value.isdigit():
        v = int(value, 10)
    if v is None:
        return None
    if 0 <= v <= 127:
        return v
    return None

def extract_output_note_vel(a: Dict[str, Any]) -> Tuple[Optional[int], Optional[int]]:
    """
    Returns (note, velocity). Both are optional ints in [0..127].
    Output can be dict or list; we take the FIRST dict that provides MB1 (note).
    If that same dict has ValueLow, we also return it as velocity.
    """
    out_block = a.get("Output")

    candidates: List[Dict[str, Any]] = []
    if isinstance(out_block, dict):
        candidates = [out_block]
    elif isinstance(out_block, list):
        candidates = [x for x in out_block if isinstance(x, dict)]

    for c in candidates:
        note = _parse_int_0_127(c.get("MB1"))
        if note is None:
            continue
        # If ValueLow exists in the SAME dict, parse velocity
        vel = _parse_int_0_127(c.get("ValueLow"))
        return note, vel

    return None, None

# ---------- main per-plist processing ----------
def process_plist(path: str) -> Optional[Tuple[str, Dict[str, Dict[str, Any]]]]:
    pl = try_load_plist(path)
    if not pl:
        return None

    set_name = split_filename_for_setname(path)

    technique_map: Dict[str, Any] = {}
    articulation_map: Dict[str, Any] = {}

    # Exact-name duplicate detection across both maps
    seen_exact_names: Dict[str, int] = {}
    dup_exact_names: List[str] = []

    # Track which MuseScore default symbols already used in articulationKeyMap
    used_ms_symbols: set = set()

    arts = extract_articulations(pl)
    for a in arts:
        exact_name = get_exact_name(a)
        if not exact_name:
            continue
        note, vel = extract_output_note_vel(a)
        if note is None:
            continue

        # Compute the stored value: "note|velocity" if vel present, else note int
        value: Any = f"{note}|{vel}" if vel is not None else note

        # Duplicate exact-name detection (across BOTH maps)
        if exact_name in seen_exact_names:
            dup_exact_names.append(exact_name)
            continue
        seen_exact_names[exact_name] = 1

        sym_lower = get_symbol_lower(a)

        if sym_lower and sym_lower in MS_DEFAULT_SYMBOLS:
            if sym_lower in used_ms_symbols:
                # Fall back to technique map with the original exact name
                key = maybe_lower_technique_key(exact_name)
                technique_map[key] = value
            else:
                articulation_map[sym_lower] = value
                used_ms_symbols.add(sym_lower)
        else:
            # No recognized symbol: technique map with exact name (except Legato → legato)
            key = maybe_lower_technique_key(exact_name)
            technique_map[key] = value

    if dup_exact_names:
        print("ERROR: Duplicate articulation names in file:", path, file=sys.stderr)
        for d in dup_exact_names:
            print(f"  - {d}", file=sys.stderr)
        sys.exit(3)

    if not articulation_map and not technique_map:
        return None

    entry = {
        "articulationKeyMap": articulation_map,
        "techniqueKeyMap": technique_map
    }
    return (set_name, entry)

# ---------- collection helpers ----------
def collect_from_root(root: Optional[str]) -> Dict[str, Dict[str, Dict[str, Any]]]:
    out: Dict[str, Dict[str, Dict[str, Any]]] = {}
    if not root:
        return out
    if not os.path.isdir(root):
        print(f"Warning: {root} is not a directory, skipping.", file=sys.stderr)
        return out
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            if not fn.lower().endswith(".plist"):
                continue
            full = os.path.join(dirpath, fn)
            result = process_plist(full)
            if result is None:
                continue
            set_name, entry = result
            out[set_name] = entry
    return out

def _process_one_plist(plist_path: str, out: Dict[str, Dict[str, Dict[str, Any]]]) -> None:
    result = process_plist(plist_path)
    if result is None:
        return
    set_name, entry = result
    out[set_name] = entry  # inputs-file wins if duplicated

def collect_from_inputs_file(inputs_file: Optional[str]) -> Dict[str, Dict[str, Dict[str, Any]]]:
    out: Dict[str, Dict[str, Dict[str, Any]]] = {}
    if not inputs_file:
        return out

    path = os.path.expanduser(os.path.expandvars(inputs_file))
    if not os.path.isfile(path):
        print(f"Error: inputs file not found: {inputs_file}", file=sys.stderr)
        sys.exit(4)

    with open(path, "r", encoding="utf-8") as f:
        lines = [ln.strip() for ln in f.readlines()]

    for ln in lines:
        if not ln or ln.startswith("#"):
            continue

        ln_expanded = os.path.expanduser(os.path.expandvars(ln))

        # 1) Directory: recurse and process all *.plist
        if os.path.isdir(ln_expanded):
            for dirpath, _, filenames in os.walk(ln_expanded):
                for fn in filenames:
                    if fn.lower().endswith(".plist"):
                        _process_one_plist(os.path.join(dirpath, fn), out)
            continue

        # 2) Glob: expand and process each match (files and/or directories)
        if glob.has_magic(ln_expanded):
            matches = glob.glob(ln_expanded, recursive=True)
            if not matches:
                print(f"Warning: glob matched no files: {ln}", file=sys.stderr)
            for m in matches:
                m_exp = os.path.expanduser(os.path.expandvars(m))
                if os.path.isfile(m_exp) and m_exp.lower().endswith(".plist"):
                    _process_one_plist(m_exp, out)
                elif os.path.isdir(m_exp):
                    for dirpath, _, filenames in os.walk(m_exp):
                        for fn in filenames:
                            if fn.lower().endswith(".plist"):
                                _process_one_plist(os.path.join(dirpath, fn), out)
                else:
                    print(f"Warning: not a file or directory (skipped): {m}", file=sys.stderr)
            continue

        # 3) Regular file path
        if not os.path.isfile(ln_expanded):
            print(f"Warning: file not found (skipped): {ln}", file=sys.stderr)
            continue
        if not ln_expanded.lower().endswith(".plist"):
            print(f"Warning: not a .plist (skipped): {ln}", file=sys.stderr)
            continue

        _process_one_plist(ln_expanded, out)

    return out

# ---------- main ----------
def main():
    ap = argparse.ArgumentParser(
        description="Build Keyswitch Creator set entries from Logic .plist articulation sets "
                    "(Output.MB1 only; optional ValueLow for velocity), with MuseScore symbol "
                    "matching. Without --wrap, output contains ONLY bare entries like: "
                    '"Set Name": { ... } (no enclosing braces), each line indented 4 spaces. '
                    "Use --wrap to output a complete JSON object.")
    ap.add_argument(
        "root", nargs="?",
        help="Top-level directory to recurse for .plist files (optional if --inputs-file is used)")
    ap.add_argument(
        "--inputs-file",
        help="Path to a text file listing .plist files, directories, and/or globs (one per line; "
             "lines starting with '#' are ignored).")
    ap.add_argument("--out", default="Keyswitch Sets.json", help="Output file path (.json)")
    ap.add_argument(
        "--sort-sets", action="store_true",
        help="Write sets in sorted order (default: insertion order).")
    ap.add_argument(
        "--wrap", action="store_true",
        help="Wrap output in braces and produce a complete JSON object (4-space indentation).")
    args = ap.parse_args()

    if not args.root and not args.inputs_file:
        print("Error: Provide a root directory OR --inputs-file (or both).", file=sys.stderr)
        sys.exit(1)

    result: Dict[str, Dict[str, Dict[str, Any]]] = {}
    # Collect from root (if provided)
    result.update(collect_from_root(args.root))
    # Collect from explicit file list (if provided) — overwrites duplicates
    result.update(collect_from_inputs_file(args.inputs_file))

    if not result:
        print("No sets built (no valid articulations with Output.MB1 found).", file=sys.stderr)
        sys.exit(2)

    # Prepare ordered items (optionally sort)
    items = list(result.items())
    if args.sort_sets:
        items = sorted(items, key=lambda kv: kv[0].lower())

    with open(args.out, "w", encoding="utf-8") as f:
        if args.wrap:
            # Build an ordered mapping and pretty-print with 4-space indent.
            ordered_obj = {k: v for k, v in items}
            json.dump(ordered_obj, f, ensure_ascii=False, indent=4)
            f.write("\n")
        else:
            # Write ONLY bare entries, comma-separated, each line starting with 4 spaces.
            for idx, (set_name, entry) in enumerate(items):
                # Dump the entry JSON with 4-space indent.
                entry_str = json.dumps(entry, ensure_ascii=False, indent=4)
                entry_lines = entry_str.splitlines()

                # First line:     "Set Name": {
                set_key_json = json.dumps(set_name, ensure_ascii=False)
                f.write("    " + f"{set_key_json}: " + entry_lines[0] + "\n")

                # Middle/closing lines, indented by 4 spaces
                if len(entry_lines) > 1:
                    for j, line in enumerate(entry_lines[1:], start=1):
                        is_last_line = (j == len(entry_lines) - 1)
                        if is_last_line and idx != len(items) - 1:
                            # Add a trailing comma to the closing brace of this entry
                            f.write("    " + line + ",\n")
                        else:
                            f.write("    " + line + "\n")
                else:
                    # Single-line object (unlikely with indent=4); add comma if not last
                    if idx != len(items) - 1:
                        f.write("    ,\n")

    print(f"Wrote {len(items)} set entry/entries to {args.out}")

if __name__ == "__main__":
    main()
