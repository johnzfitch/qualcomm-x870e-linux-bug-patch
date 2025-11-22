#!/usr/bin/env python3
"""
Fix e0fb entry in board-2.json

Problem: e0fb is in multiple groups including generic (e0ee) and non-variant (e0dc).
         Driver finds generic entry first and uses wrong calibration.

Solution: Remove e0fb from ALL non-variant groups, add standalone entry pointing to QC_5mm data.
"""

import json

# Read original JSON
with open('board-2.json', 'r') as f:
    data = json.load(f)

e0fb_removed_from = []
e0fb_pattern = 'subsystem-device=e0fb'
qc5mm_data = 'bus=pci,vendor=17cb,device=1107,subsystem-vendor=105b,subsystem-device=e0dc,qmi-chip-id=2,qmi-board-id=255,variant=QC_5mm.bin'

# Process board entries
for entry in data[0]['board']:
    names = entry.get('names', [])
    # Find and remove e0fb entries that DON'T have variant=QC_5mm
    new_names = []
    for name in names:
        if e0fb_pattern in name and 'variant=QC_5mm' not in name:
            e0fb_removed_from.append(entry.get('data', 'unknown'))
        else:
            new_names.append(name)
    entry['names'] = new_names

# Remove entries with empty names
data[0]['board'] = [e for e in data[0]['board'] if e.get('names')]

# Add standalone e0fb entry pointing to QC_5mm data at the BEGINNING
# (so it's found first during search)
new_entry = {
    "names": [
        "bus=pci,vendor=17cb,device=1107,subsystem-vendor=105b,subsystem-device=e0fb,qmi-chip-id=2,qmi-board-id=255"
    ],
    "data": qc5mm_data
}

# Insert at beginning of board array
data[0]['board'].insert(0, new_entry)

# Write fixed JSON
with open('board-2-fixed.json', 'w') as f:
    json.dump(data, f, indent=4)

print(f"Removed e0fb from {len(e0fb_removed_from)} groups:")
for d in e0fb_removed_from:
    print(f"  - {d}")
print(f"\nAdded standalone e0fb entry pointing to: {qc5mm_data}")
print("\nOutput: board-2-fixed.json")
