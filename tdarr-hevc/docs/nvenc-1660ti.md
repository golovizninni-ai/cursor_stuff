# NVENC reference for GTX 1660 Ti (Turing)

Use these values in Tdarr Flow / Custom FFmpeg Arguments.
Do not mix with the RTX 3070 Ti profile from section 10 of the main README.

## Base encode arguments

```bash
-hwaccel cuda -hwaccel_output_format cuda
-c:v hevc_nvenc -preset p5 -tune hq -profile:v main10 -pix_fmt p010le
-rc vbr -cq CQ -b:v 0 -spatial-aq 1 -temporal-aq 1 -rc-lookahead 20
-c:a copy -c:s copy -map 0 -map_metadata 0
```

CRF like x265 does not exist on NVENC. Use VBR + CQ with `-b:v 0`.
Preset `p5` is the sweet spot on Turing; `p6` is slower with almost no gain.

## CQ by content type

| Content | CQ |
| --- | --- |
| 1080 SDR | 22 |
| Anime 1080 | 20 |
| 4K SDR (height ≥ 2160) | 23 |
| 4K HDR10 | 20 |

For 4K HDR10 also set:

```bash
-color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc
```

Add mastering display / MaxCLL metadata when the source carries it.

## Flow rules (1660 Ti)

| Condition | Action |
| --- | --- |
| Nearby `*.rus.*` / `*.eng.*` not yet in container | Mux neighbours; default language `rus` |
| Already HEVC/AV1 | Skip encode |
| Dolby Vision / HDR10+ | Skip encode |
| height ≥ 2160, SDR | CQ 23, preset p5 |
| height ≥ 2160, HDR10 | CQ 20, PQ tags |
| Anime 1080 | CQ 20, 10-bit |
| Other 1080 SDR | CQ 22 |

After mux: `-map 0 -c:a copy -c:s copy`.
Replace must overwrite the same inode (in-place), never `mv`.

## Other settings

- Container filters: `mkv`, `mp4`, `m4v`, `avi`, `ts`
- Do not downmix audio
- Reject output larger than source
- Run Health Check before accepting in-place replace
- Folder Watch: off
- Scheduler: off
- GPU workers: 1
- Auto-accept: off until the test batch is validated

## RTX 3070 Ti (future, section 10)

| Parameter | 1660 Ti now | 3070 Ti later |
| --- | --- | --- |
| NVENC | Turing, 6 GB | Ampere, 8 GB |
| Preset | p5 | p6 |
| Lookahead | 20 | 32 |
| CQ 1080 / anime / 4K SDR / HDR10 | 22 / 20 / 23 / 20 | 23 / 21 / 24 / 21 |
| GPU workers | 1 | 2 on 1080, 1 on 4K or 1 GbE |
| AV1 encode | no | no |
| Cache `/temp` | 150–200 GB | 200–300 GB |

Do not change Flow structure when swapping GPUs — only these numbers.
