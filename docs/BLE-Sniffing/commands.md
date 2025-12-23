Where To Store Logs

- hvac_support_app/docs/BLE-Sniffing/
- phone-data/: raw pulled files from device (e.g., btsnoop_hci.log, bugreport zips).
- extracted_YYYYMMDD_device/: unzipped bugreport contents and decoded artifacts.
- reports/: human-readable summaries, .csv, .tjf vendor exports.
# Notes:
  - Large zips and extracted folders are already gitignored by patterns in .gitignore for docs/BLE-Sniffing/*.
  - Sync important metadata (summary JSON or notes) to Firestore ble_sniff_logs when relevant.
# Android HCI Snoop Log (Manual Enable)

# On phone: enable Developer Options → turn on “Bluetooth HCI snoop log”.
Reproduce BLE session, then use these commands.


# Pull Raw HCI Log To Project
## Set project path variable for convenience
- PROJ="/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app"

# Create target folders
- mkdir -p "$PROJ/docs/BLE-Sniffing/phone-data"

# Common paths (varies by device/Android version)
# Try direct pull from modern path:
- adb pull /sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log \
  "$PROJ/docs/BLE-Sniffing/phone-data/btsnoop_hci.log" || \
# Fallback older path:
- adb pull /sdcard/btsnoop_hci.log \
  "$PROJ/docs/BLE-Sniffing/phone-data/btsnoop_hci.log"

# Generate Full Bugreport Zip (Alternative)
## Bugreport creates a comprehensive ZIP with Bluetooth logs inside
- mkdir -p "$PROJ/docs/BLE-Sniffing/phone-data"
- adb bugreport "/tmp/bugreport.zip"
- mv "/tmp/bugreport.zip" "$PROJ/docs/BLE-Sniffing/phone-data/bugreport_$(date +%F).zip"

# Unzip Bugreport To Extracted Folder
- PROJ="/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app"
- ZIP="$PROJ/docs/BLE-Sniffing/phone-data/bugreport_$(date +%F).zip"
OUT="$PROJ/docs/BLE-Sniffing/extracted_$(date +%F)_pixel"  # adjust device label

mkdir -p "$OUT"
unzip -q "$ZIP" -d "$OUT"

# Locate the HCI snoop log inside the bugreport
# Common filenames: btsnoop_hci.log, bluetooth_snoop.log
find "$OUT" -iname "*snoop*.log" -o -iname "btsnoop_hci.log"


# Optional: Export To CSV Using tshark
## Install tshark (macOS): brew install wireshark
PROJ="/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app"
IN="$PROJ/docs/BLE-Sniffing/phone-data/btsnoop_hci.log"
OUTCSV="$PROJ/docs/BLE-Sniffing/reports/hci_packets_$(date +%F).csv"

mkdir -p "$(dirname "$OUTCSV")"

tshark -r "$IN" -T fields \
  -E header=y -E separator=, \
  -e frame.time \
  -e bluetooth.hci_command_opcode \
  -e bluetooth.hci_event_code \
  -e bluetooth.src \
  -e bluetooth.dst \
  -e bluetooth.uuid \
  -e bluetooth.data \
  > "$OUTCSV"


# You can tailor fields for specific devices/services (e.g., ABM-200 service UUID, Manufacturer data for Fieldpiece).
Placing .csv And .tjf Reports

Put human-readable exports in hvac_support_app/docs/BLE-Sniffing/reports/.
Keep raw logs in phone-data/, and any unzipped content in a dated extracted_... folder.
If .tjf is a vendor format, store it alongside CSVs in reports/ and add a short README in that folder describing the capture context.
Tip

After pulls, consider adding a small summary JSON (date/device/probe/notes) in reports/ and upload summary metadata to Firestore ble_sniff_logs so it’s discoverable across the shared backend.
The .gitignore already ignores big zip/extracted folders under BLE-Sniffing, so you won’t accidentally commit large blobs.  