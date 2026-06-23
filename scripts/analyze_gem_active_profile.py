#!/usr/bin/env python3
import argparse
import csv
import json
import sys


def load_profile(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def fmt_ratio(value):
    return f"{value:.4f}"


def print_entries(title, entries, limit):
    print(title)
    if not entries:
        print("  (none)")
        return
    for entry in entries[:limit]:
        print(
            "  idx={idx} block={block} stage={stage} cycles={cycles} "
            "activity={activity} toggles={toggles} skipped={skipped}".format(
                idx=entry.get("profile_index"),
                block=entry.get("block_id"),
                stage=entry.get("stage_id"),
                cycles=entry.get("cycles", 0),
                activity=fmt_ratio(entry.get("activity_ratio", 0.0)),
                toggles=entry.get("toggle_popcount", 0),
                skipped=entry.get("skipped", 0),
            )
        )


def write_csv(path, counters):
    fieldnames = [
        "profile_index",
        "block_id",
        "stage_id",
        "cycles",
        "input_changed",
        "output_changed",
        "toggle_popcount",
        "skipped",
        "activity_ratio",
        "skip_ratio",
    ]
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for entry in counters:
            writer.writerow({name: entry.get(name) for name in fieldnames})


def main():
    parser = argparse.ArgumentParser(
        description="Analyze GEM-Active profile JSON and print summary metrics."
    )
    parser.add_argument("profile_json", help="Path to profile.json")
    parser.add_argument("--top", type=int, default=5, help="Top entries to show")
    parser.add_argument("--csv", help="Optional CSV output path")
    args = parser.parse_args()

    data = load_profile(args.profile_json)
    counters = data.get("counters", [])
    summary = data.get("summary", {})

    inactive = sorted(counters, key=lambda c: c.get("activity_ratio", 0.0))
    hot = sorted(counters, key=lambda c: c.get("toggle_popcount", 0), reverse=True)

    print_entries("Top inactive partitions", inactive, args.top)
    print_entries("Top high-toggle partitions", hot, args.top)
    print("Mean activity ratio:", fmt_ratio(summary.get("mean_activity_ratio", 0.0)))
    print("Total skipped cycles:", summary.get("total_skipped", 0))
    print("Skip ratio:", fmt_ratio(summary.get("mean_skip_ratio", 0.0)))

    if args.csv:
        write_csv(args.csv, counters)
        print("CSV written to", args.csv)


if __name__ == "__main__":
    sys.exit(main())
