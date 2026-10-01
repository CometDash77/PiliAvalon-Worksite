#!/usr/bin/env python3
"""Select a clickable recommendation video card from Android UIAutomator XML."""

import argparse
import re
import sys
import xml.etree.ElementTree as ET


BOUNDS_RE = re.compile(r"^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$")
VIDEO_DURATION_RE = re.compile(r"(?<!\d)\d{1,2}:\d{2}(?!\d)")
VIDEO_OWNER_RE = re.compile(r"\bUP\s*[：:]", re.IGNORECASE)
MENU_LABELS = ("显示菜单", "更多选项", "更多设置", "More options", "Show menu")
DETAIL_MARKERS = ("返回主页", "Back to home")


def _bounds(node):
    match = BOUNDS_RE.fullmatch(node.attrib.get("bounds", ""))
    return tuple(map(int, match.groups())) if match else None


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


def find_video_detail_more_button(xml_text):
    """Return the upper-right player menu, excluding menus in related cards."""
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return None

    screen_bounds = next(
        (
            _bounds(node)
            for node in root.iter("node")
            if node.attrib.get("class") == "android.widget.FrameLayout"
            and _bounds(node)
        ),
        None,
    )
    if screen_bounds is None:
        return None
    screen_width, screen_height = screen_bounds[2:]

    has_detail_marker = any(
        marker.casefold() in " ".join(
            (node.attrib.get("text", ""), node.attrib.get("content-desc", ""))
        ).casefold()
        for node in root.iter("node")
        for marker in DETAIL_MARKERS
    )
    if not has_detail_marker:
        return None

    candidates = []
    for node in root.iter("node"):
        if node.attrib.get("clickable") != "true":
            continue
        label = " ".join((node.attrib.get("text", ""), node.attrib.get("content-desc", "")))
        if not any(menu_label.casefold() in label.casefold() for menu_label in MENU_LABELS):
            continue

        bounds = _bounds(node)
        if bounds is None:
            continue
        left, top, right, bottom = bounds
        if right <= left or bottom <= top:
            continue

        cx = (left + right) // 2
        cy = (top + bottom) // 2
        if cx < screen_width * 0.75 or cy > screen_height * 0.25:
            continue

        candidates.append(
            {
                "bounds": node.attrib.get("bounds", ""),
                "cx": cx,
                "cy": cy,
                "description": label.replace("\r", " ").replace("\n", " "),
                "top": top,
                "right": right,
            }
        )

    if not candidates:
        return None
    return min(candidates, key=lambda candidate: (candidate["top"], -candidate["right"]))


def main():
    parser = argparse.ArgumentParser()
    selector = parser.add_mutually_exclusive_group(required=True)
    selector.add_argument("--video-card", help="Select a clickable recommendation video card")
    selector.add_argument("--detail-more-menu", help="Select the video player toolbar menu")
    args = parser.parse_args()

    try:
        dump_path = args.video_card or args.detail_more_menu
        with open(dump_path, encoding="utf-8") as handle:
            xml_text = handle.read()
        target = (
            find_first_video_card(xml_text)
            if args.video_card
            else find_video_detail_more_button(xml_text)
        )
    except OSError as exc:
        print(f"# read_error={exc}")
        return 1

    if target is None:
        selector_name = "clickable_video_card" if args.video_card else "video_detail_more_button"
        print(f"# no_{selector_name}")
        return 1

    print(
        f"content_desc={target['description']} matched={'video_card' if args.video_card else 'video_detail_more_menu'} bounds={target['bounds']} "
        f"clickable=true cx={target['cx']} cy={target['cy']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
