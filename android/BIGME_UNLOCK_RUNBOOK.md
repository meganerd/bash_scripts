# Bigme InkNote Color+ (MT6765) Unlock Runbook

**Target:** Bigme AINote InkNote Color+, MediaTek MT6765 (Helio P35),
Android 11, `alps/full_k65v1_64_bsp`. Security patch 2021-01-05 → MTK
BootROM is KAMAKIRI-vulnerable.

**Outcome:** unlocked bootloader, full partition backup, Magisk root
option, and Treble-GSI path to Android 13/14.

---

## Risk summary — read before starting

| Phase | Destructive? | Reversible from BROM? |
|---|---|---|
| 1. DPI / debloat via ADB | No | Yes |
| 2. Partition backup via mtkclient | No (read-only) | n/a |
| 3. Enable OEM unlock toggle | No | Yes (toggle off) |
| 4. `fastboot flashing unlock` | **Wipes userdata** | Yes (re-lock) |
| 5. Disable vbmeta verification | Yes (boot chain change) | Yes if you kept backup |
| 6. Flash GSI over `system` | Yes | Yes if you kept backup |

If Phase 2 completes, everything after it is recoverable: the mtkclient
BootROM path is always available on MT6765 regardless of software state.
**Do not skip Phase 2.**

---

## Phase 0 — prerequisites (host side)

```
# udev rules so the user can talk to MTK preloader without sudo
sudo cp ~/src/mtkclient/mtkclient/Setup/Linux/*.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger

# python deps (currently blocked pending authorization — see session notes)
cd ~/src/mtkclient && pip install --user -r requirements.txt

# smoke-test mtkclient against a sleeping device
python3 ~/src/mtkclient/mtk.py --help
```

---

## Phase 1 — flip the OEM-unlock toggle (on device)

1. Settings → Developer options → enable **"OEM unlocking"**.
   - If Bigme's custom Settings hides it, launch it via ADB:
     `adb shell am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS`
   - After toggle: `adb shell getprop sys.oem_unlock_allowed` should return `1`
     (requires reboot on some builds).

---

## Phase 2 — full partition backup via mtkclient (**mandatory**)

1. Power the tablet OFF completely.
2. Hold **Volume-Up + Volume-Down** simultaneously, then plug USB into the
   host. Keep holding until `dmesg` shows `idVendor=0e8d idProduct=0003`
   (BROM mode) on the host.
3. Run:

   ```
   bigme-mtk-backup ~/backups/bigme-inknote-colorplus-$(date +%F)
   ```

4. Verify the manifest has entries for `boot_a`, `boot_b`, `super`,
   `vbmeta_a`, `vbmeta_b`, `dtbo_a`, `dtbo_b`, `preloader_*`,
   `lk_a`, `lk_b`, `tee_a`, `tee_b`, `md1img_*`, etc.
5. Copy the backup dir to a second location (Nextcloud, external drive).

---

## Phase 3 — unlock the bootloader

```
adb reboot bootloader     # drops to fastboot
fastboot oem device-info  # confirm "Device unlocked: false", "Unlock allowed: true"
fastboot flashing unlock  # device screen prompts — press Volume-Up to confirm
# → userdata wipes, device reboots, setup wizard returns
```

After unlock the boot splash will show a yellow/orange warning — that's
normal. `fastboot getvar unlocked` should return `yes`.

Re-enable ADB, re-pair wireless if you were using it.

---

## Phase 4 — Magisk root (optional, less invasive than GSI)

```
adb pull /dev/block/by-name/boot_a stock_boot_a.img
# patch stock_boot_a.img with Magisk Manager on-device, pull the patched img
fastboot flash boot_a magisk_patched_boot.img
fastboot flash boot_b magisk_patched_boot.img   # keep both slots consistent
fastboot reboot
```

EBC driver + Bigme userspace all stay intact. Good stopping point if you
just want debloat + ad-blocking + a newer Chrome.

---

## Phase 5 — GSI flash (Android 13/14 path)

GSI candidates:
- **PHH-Treble GSI** — most compatible, A/B-AB, vndklite variants
- **LineageOS GSI** (arm64-ab, `-vndklite` for VNDK 30)

Steps:

```
# patch vbmeta to disable verification BEFORE flashing GSI
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
fastboot --disable-verity --disable-verification flash vbmeta_system vbmeta_system.img
fastboot --disable-verity --disable-verification flash vbmeta_vendor vbmeta_vendor.img

# wipe super-map entries for system on the inactive slot
fastboot delete-logical-partition system_b
fastboot delete-logical-partition product_b
fastboot create-logical-partition system_b <size-of-gsi>

fastboot flash system_b system-squashfs-arm64-ab-vndklite.img
fastboot --set-active=b
fastboot -w   # wipe userdata (required for GSI's format)
fastboot reboot
```

**Known risks on this device:**
- Bigme's EBC driver binds to specific kernel ABI — GSI uses *their* kernel
  (Android keeps the OEM kernel, only `system` swaps), so display usually
  survives. Touch/stylus drivers also live in vendor → should survive.
- Bigme's custom launcher / reading apps are in `system` → they vanish. Stock
  AOSP launcher will come up instead. This is a feature, not a bug.
- Kaleido 3 color mapping lives partly in userspace — colors may render flat
  under AOSP until a color profile is applied.
- Google Play requires re-certifying the device (Play Integrity); low chance
  it stays CTS-approved after GSI.

**Always test in slot B first** — if it bricks, `fastboot --set-active=a`
drops back to stock.

---

## Phase 6 — DPI sanity pass (any phase)

```
bigme-dpi 280        # tighter
bigme-dpi 360        # larger
bigme-dpi reset      # back to 300
```

No root or unlock required — works on stock.

---

## Recovery: if you brick it

1. Power off (hold power 10s).
2. Hold Vol-Up + Vol-Down, plug USB.
3. On host: `python3 ~/src/mtkclient/mtk.py wl ~/backups/bigme-inknote-colorplus-YYYY-MM-DD/`
4. Disconnect, hold power to boot. Stock should return.

If BROM mode no longer triggers (very rare on pre-2022 MT6765), you need a
JTAG rig or a new mainboard. One-in-hundreds.

---

## References

- mtkclient: https://github.com/bkerler/mtkclient
- Bigme HiBreak root thread (same SoC): https://xdaforums.com/t/bigme-hibreak-root-mediatek-6765.4697830/
- PHH-Treble GSIs: https://github.com/phhusson/treble_experimentations
- LineageOS GSIs: https://wiki.lineageos.org/gsi/
