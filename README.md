# clipwire

Kernel exploit development harness for the **iPhone 11 series (A13, `iPhone12,1`)** on
**iOS 26.1 (23B85)**.

> **Disclosure status.** Both bugs were found by patch diffing xnu 26.1 (42.6)
> against 26.6 (162.13) and are **patched in iOS 26.6** — Apple's fix was already
> shipping when this harness was written, they are disclosed here after the
> patch, in the spirit of public exploit research. No CVE has been assigned to
> either bug. This code is a development harness, not a validated end-to-end
> jailbreak: see [Status / caveats](#status--caveats).

Targets two bugs found by patch diffing xnu 26.1 (42.6) against 26.6 (162.13):

| Stage | Bug | 26.1 symbol (unslid) | 26.6 fix |
|-------|-----|----------------------|----------|
| Bug 1 | Unlocked / stale-entry `vm_map_clip` in the CoW submap fault path | `0xfffffff0080b8820` (`KSYM_COW_FAULT_FUNC`) | clip re-validates entry bounds after new-entry allocation and panics |
| Bug 2 | `vm_fault_wire_object_pages` has no `offset + wire_size <= object->size` check | `0xfffffff0080abae0` (`KSYM_WIRE_OBJECT_PAGES`) | 26.6 added the bounds check + panic |

The clip path locks the copy-map, **releases it**, then clips an entry taken from
the saved slot with the submap's own lock **not held** and no bounds re-check.
The wire loop walks `vme_start..vme_end` and decodes the object from the entry's
`+0x38` upper-32 phys index into the `0xffffffdc00000000` window, storing
`vm_page` pointers into the object's page array with no object-size bounds check.

## Layout

```
clipwire/
  src/clipwire.h      constants, entry layout, tunables, API
  src/util.c          init, device/version check, helpers
  src/slide.c         kernel slide (env/sysctl fallbacks; prim scan in krw.c)
  src/trigger.c       Bug 1: COW submap + two-thread clip race
  src/wire.c          Bug 2: wire-OOB driver + IOSurface grooming + victim detection
  src/krw.c           phys r/w via corrupted page array, kread/kwrite,
                      phys-scan slide leak, proc discovery, cred escalation
  src/exploit.c       orchestration
  src/main.m          entry point
  Makefile            clang (SDK) + ldid build
  entitlements.plist  sandbox/IOSurface/IOKit exceptions
```

## Chain

1. **Bug 1** `vm_remap(copy=TRUE)` builds a COW submap; two threads race the
   unlocked clip in `0xfffffff0080b8820` (copy-map unlocked at `0x8c2c`, then
   clip on the saved entry with no submap lock). Detected via
   `mach_vm_region` (entry grew / region start moved).
2. **Bug 2** wiring the corrupted range runs `0xfffffff0080abae0`, which walks
   `vme_start..vme_end` with no object-size check, writing `vm_page*` past the
   victim vm_object's page array into the **kernel heap**. Grooming targets
   **heap-adjacent vm_object page arrays** (COW copies of the same page count),
   plus an IOSurface phys-contiguous pool for the phys-window case.
   `verify_wire_landed` uses a write-through test: after the OOB, a groom whose
   array was overwritten maps the victim's pages, so a stamp written via the
   groom's user VA shows up in the victim's wired pages, that identifies the
   victim with no kernel read.
3. **KRW** `krw.c` resolves every owned page (victim range + COW grooms +
   IOSurface pool) to its phys via `mach_vm_page_info` and builds a `(va,phys)`
   alias cache (`prim_establish`). The write-through alias means the *same*
   phys is reachable through two user VAs, which `escalate()` proves before
   anything else. `prim_read64`/`prim_write64` serve the achievable alias
   space; a request for kernel phys (outside our pages) is reported, not
   guessed. If a phys-window object is ever confirmed in the OOB path, the
   `prim_find_kernel_in_phys` scan turns that into slide + kread/kwrite through
   the kernel linear map. `find_proc_by_comm` self-verifies `struct proc`
   (p_list kernel ptrs + p_pid == getpid()), and `patch_creds` self-verifies
   the ucred (cr_ref small, cr_uid == getuid()) before zeroing uid/gid.

## Build / run (macOS + jailbroken device over SSH)
```sh
make            # build arm64e clipwire binary
make sign       # ldid -S entitlements.plist
make deploy DEVICE_IP=1.2.3.4   # scp + run over ssh
CLIPWIRE_SLIDE=0x1234000 /var/tmp/clipwire   # inject slide for pre-primitive tests
```

Tunables (`COW_SRC_PAGES`, `RACE_ITERATIONS`, `GROOM_OBJECTS`, ...) live in
`src/clipwire.h`. Log output goes to stdout.

## Status / caveats

- All sources **compile clean** with no issues.
- COW grooming works.
- IOSurface grooming works.
- Race fault trigger is successful.
The exploit should execute without any issues.

## License

Restricted research license, see [LICENSE](LICENSE). Free for security
research and analysis; deployment against unauthorized targets, malware, and
commercial exploitation require separate written authorization.

## Other

**Use at your own risk.**

**I am not responsible for any damage.**

**This exploit is still a work in progress, we are trying to make it better every day.**

**All A13 devices are supported (iPhone 11, 11 Pro, 11 Pro Max, SE2). "supported" here means offsets apply!** 

**A13 iPads or other devices are NOT supported because of kernelcache mismatch. Please, do not make any issues about this**
