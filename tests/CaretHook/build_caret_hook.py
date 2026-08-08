#!/usr/bin/env python3
"""Flatten the MSVC COFF object used by the standalone caret hook test."""

from __future__ import annotations

import base64
import hashlib
import json
import struct
import sys
from dataclasses import dataclass
from pathlib import Path


COFF_HEADER_SIZE = 20
SECTION_HEADER_SIZE = 40
SYMBOL_SIZE = 18
MACHINE_I386 = 0x014C
MACHINE_AMD64 = 0x8664
IMAGE_REL_I386_DIR32 = 0x0006
IMAGE_REL_I386_REL32 = 0x0014
IMAGE_REL_AMD64_REL32 = 0x0004
IMAGE_REL_AMD64_REL32_6 = 0x000A


@dataclass
class Section:
    index: int
    name: str
    raw_size: int
    raw_offset: int
    reloc_offset: int
    reloc_count: int
    output_offset: int = -1


@dataclass
class Symbol:
    name: str
    value: int
    section_index: int


def u16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def i16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<h", data, offset)[0]


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def i32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<i", data, offset)[0]


def symbol_name(raw: bytes, string_table: bytes) -> str:
    if raw[:4] == b"\0\0\0\0":
        offset = u32(raw, 4)
        if offset >= len(string_table):
            raise ValueError(f"Invalid COFF string-table offset: {offset}")
        end = string_table.find(b"\0", offset)
        if end < 0:
            end = len(string_table)
        return string_table[offset:end].decode("ascii")
    return raw.rstrip(b"\0").decode("ascii")


def parse_object(path: Path) -> tuple[bytes, int, list[Section], list[Symbol | None], bytes]:
    data = path.read_bytes()
    if len(data) < COFF_HEADER_SIZE:
        raise ValueError("Object file is too small to be COFF")

    machine = u16(data, 0)
    section_count = u16(data, 2)
    symbol_offset = u32(data, 8)
    symbol_count = u32(data, 12)
    optional_header_size = u16(data, 16)
    section_table = COFF_HEADER_SIZE + optional_header_size

    sections: list[Section] = []
    for i in range(section_count):
        offset = section_table + i * SECTION_HEADER_SIZE
        raw_name = data[offset : offset + 8]
        name = raw_name.rstrip(b"\0").decode("ascii")
        sections.append(
            Section(
                index=i + 1,
                name=name,
                raw_size=u32(data, offset + 16),
                raw_offset=u32(data, offset + 20),
                reloc_offset=u32(data, offset + 24),
                reloc_count=u16(data, offset + 32),
            )
        )

    string_table_offset = symbol_offset + symbol_count * SYMBOL_SIZE
    if string_table_offset + 4 > len(data):
        raise ValueError("COFF string table is missing")
    string_table_size = u32(data, string_table_offset)
    string_table = data[string_table_offset : string_table_offset + string_table_size]

    symbols: list[Symbol | None] = []
    offset = symbol_offset
    i = 0
    while i < symbol_count:
        raw = data[offset : offset + SYMBOL_SIZE]
        symbols.append(Symbol(symbol_name(raw[:8], string_table), u32(raw, 8), i16(raw, 12)))
        aux_count = raw[17]
        symbols.extend([None] * aux_count)
        offset += SYMBOL_SIZE * (1 + aux_count)
        i += 1 + aux_count

    return data, machine, sections, symbols, string_table


def included_section(section: Section) -> bool:
    return (
        section.name == ".data"
        or section.name == ".rdata"
        or section.name == ".text"
        or section.name.startswith(".text$")
    )


def find_symbol(symbols: list[Symbol | None], prefix: str) -> Symbol:
    candidates = [symbol for symbol in symbols if symbol is not None and symbol.name.startswith(prefix)]
    if len(candidates) != 1:
        raise ValueError(f"Expected one symbol starting with {prefix!r}, found {candidates}")
    return candidates[0]


def flatten(input_path: Path) -> tuple[bytearray, dict[str, int]]:
    data, machine, sections, symbols, _ = parse_object(input_path)
    if machine not in (MACHINE_I386, MACHINE_AMD64):
        raise ValueError(f"Unsupported COFF machine: 0x{machine:04X}")

    selected = [section for section in sections if included_section(section)]
    data_sections = [section for section in selected if section.name == ".data"]
    if len(data_sections) != 1:
        raise ValueError(f"Expected one .data section, found {len(data_sections)}")

    output = bytearray()
    for section in selected:
        section.output_offset = len(output)
        output.extend(data[section.raw_offset : section.raw_offset + section.raw_size])

    section_map = {section.index: section for section in selected}
    symbol_map = {index: symbol for index, symbol in enumerate(symbols)}

    for section in selected:
        for i in range(section.reloc_count):
            reloc_offset = section.reloc_offset + i * 10
            virtual_address = u32(data, reloc_offset)
            symbol_index = u32(data, reloc_offset + 4)
            reloc_type = u16(data, reloc_offset + 8)
            symbol = symbol_map[symbol_index]
            target_section = section_map.get(symbol.section_index)
            if target_section is None:
                raise ValueError(
                    f"Relocation targets excluded section: {section.name} -> {symbol.name}"
                )

            patch_offset = section.output_offset + virtual_address
            target_offset = target_section.output_offset + symbol.value
            if machine == MACHINE_AMD64 and IMAGE_REL_AMD64_REL32 <= reloc_type <= IMAGE_REL_AMD64_REL32_6:
                addend = i32(output, patch_offset)
                value = target_offset + addend - (patch_offset + 4 + reloc_type - IMAGE_REL_AMD64_REL32)
                struct.pack_into("<i", output, patch_offset, value)
            elif machine == MACHINE_I386 and reloc_type == IMAGE_REL_I386_REL32:
                addend = i32(output, patch_offset)
                value = target_offset + addend - (patch_offset + 4)
                struct.pack_into("<i", output, patch_offset, value)
            elif machine == MACHINE_I386 and reloc_type == IMAGE_REL_I386_DIR32:
                addend = u32(output, patch_offset)
                struct.pack_into("<I", output, patch_offset, target_offset + addend)
            else:
                raise ValueError(
                    f"Unsupported relocation type 0x{reloc_type:04X} in {section.name}"
                )

    thread_proc = find_symbol(symbols, "?ThreadProc@@")
    thread_section = section_map.get(thread_proc.section_index)
    if thread_section is None:
        raise ValueError("ThreadProc is not in a selected section")

    metadata = {
        "machine": machine,
        "pointer_size": 8 if machine == MACHINE_AMD64 else 4,
        "data_size": data_sections[0].raw_size,
        "entry_offset": thread_section.output_offset + thread_proc.value,
        "rect_offset": 56 if machine == MACHINE_AMD64 else 32,
        "size": len(output),
    }
    return output, metadata


def write_outputs(input_path: Path, binary_path: Path, payload_path: Path, metadata_path: Path) -> None:
    output, metadata = flatten(input_path)
    binary_path.parent.mkdir(parents=True, exist_ok=True)
    binary_path.write_bytes(output)
    metadata["sha256"] = hashlib.sha256(output).hexdigest()
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")

    class_name = "CaretHookPayloadX64" if metadata["pointer_size"] == 8 else "CaretHookPayloadX86"
    encoded = base64.b64encode(output).decode("ascii")
    payload_path.write_text(
        "#Requires AutoHotkey v2.0\n"
        f"class {class_name} {{\n"
        f"    static shellcode_base64 := \"{encoded}\"\n"
        f"    static pointer_size := {metadata['pointer_size']}\n"
        f"    static data_size := {metadata['data_size']}\n"
        f"    static entry_offset := {metadata['entry_offset']}\n"
        f"    static rect_offset := {metadata['rect_offset']}\n"
        "}\n",
        encoding="utf-8",
    )


def main() -> int:
    if len(sys.argv) != 5:
        print(f"usage: {sys.argv[0]} INPUT.obj OUTPUT.bin PAYLOAD.ahk METADATA.json", file=sys.stderr)
        return 2
    write_outputs(*(Path(argument) for argument in sys.argv[1:]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
