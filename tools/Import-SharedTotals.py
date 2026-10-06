"""Import successful totals from an exported scan report; exclude all account progress."""
import argparse
import csv
import json
from datetime import datetime, timezone
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("report", type=Path)
parser.add_argument("--checked-at", required=True, help="UTC scan time, e.g. 2026-10-05T23:13:52Z")
parser.add_argument("--catalogue", type=Path, default=Path(__file__).resolve().parents[1] / "catalog/achievement-totals.json")
args = parser.parse_args()
timestamp = datetime.fromisoformat(args.checked_at.replace("Z", "+00:00"))
if timestamp.tzinfo is None or timestamp > datetime.now(timezone.utc):
    parser.error("checked-at must be a past timestamp with a timezone")
document = json.loads(args.catalogue.read_text(encoding="utf-8")) if args.catalogue.exists() else {"schemaVersion": 1, "entries": []}
if document["schemaVersion"] != 1:
    parser.error("Unsupported catalogue schema")
entries = {entry["titleId"]: entry for entry in document["entries"]}
accepted = 0
with args.report.open(encoding="utf-8-sig", newline="") as source:
    for row in csv.DictReader(source):
        if row["Result"] != "Updated":
            continue
        title_id, total = row["Title ID"], int(row["Total"])
        platforms = sorted(set(p.strip() for p in row["Platform"].split("/") if p.strip()))
        if not title_id.isdecimal() or not 0 < int(title_id) <= 4294967295 or not 0 < total <= 10000 or not platforms:
            raise ValueError("Invalid successful report entry")
        old = entries.get(title_id)
        if old and datetime.fromisoformat(old["checkedAt"].replace("Z", "+00:00")) >= timestamp:
            continue
        entries[title_id] = {"titleId": title_id, "name": row["Title"], "platforms": platforms, "total": total,
                             "checkedAt": timestamp.isoformat().replace("+00:00", "Z"), "endpoint": row["Endpoint"]}
        accepted += 1
document = {"schemaVersion": 1, "entries": sorted(entries.values(), key=lambda e: int(e["titleId"]))}
temporary = args.catalogue.with_suffix(".tmp")
temporary.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
temporary.replace(args.catalogue)
print(f"Imported {accepted} successful totals; catalogue contains {len(entries)} titles. No account progress included.")
