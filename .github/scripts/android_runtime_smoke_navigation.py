#!/usr/bin/env python3
"""Select a clickable recommendation video card from Android UIAutomator XML."""

import argparse
import re
import sys
import xml.etree.ElementTree as ET


BOUNDS_RE = re.compile(r"^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$")
VIDEO_DURATION_RE = re.compile(r"(?<!\d)\d{1,2}:\d{2}(?!\d)")
VIDEO_OWNER_RE = re.compile(r"\bUP\s*[：:]", re.IGNORECASE)


def find_first_video_card(xml_text):
    """Return the first visible clickable video card and tap coordinates."""
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return None

    candidates = []
    for node in root.iter("node"):
        if node.attrib.get("clickable") != "true":
            continue

        description = " ".join(
            value
            for value in (node.attrib.get("text", ""), node.attrib.get("content-desc", ""))
            if value
        )
        if not VIDEO_DURATION_RE.search(description) or not VIDEO_OWNER_RE.search(description):
            continue

        bounds = node.attrib.get("bounds", "")
        match = BOUNDS_RE.fullmatch(bounds)
        if not match:
            continue

        left, top, right, bottom = map(int, match.groups())
        if right <= left or bottom <= top:
            continue

        candidates.append(
            {
                "bounds": bounds,
                "cx": (left + right) // 2,
                "cy": (top + bottom) // 2,
                "description": description.replace("\r", " ").replace("\n", " "),
                "top": top,
                "left": left,
            }
        )

    if not candidates:
        return None
    return min(candidates, key=lambda candidate: (candidate["top"], candidate["left"]))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--video-card", required=True, help="UIAutomator XML dump path")
    args = parser.parse_args()

    try:
        with open(args.video_card, encoding="utf-8") as handle:
            target = find_first_video_card(handle.read())
    except OSError as exc:
        print(f"# read_error={exc}")
        return 1

    if target is None:
        print("# no_clickable_video_card")
        return 1

    print(
        f"content_desc={target['description']} matched=video_card bounds={target['bounds']} "
        f"clickable=true cx={target['cx']} cy={target['cy']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
