# HermesCommander Progress Update

Date: 2026-06-18
Branch: `hermes-commander`

## Summary

The IPTV/Free TV work is now in a strong steady state. We selectively borrowed the useful parts of `clubTivi` without absorbing its entire player stack.

## Completed

- Free TV parser/model now preserves richer M3U metadata, including `tvg-id`, `tvg-name`, channel number, and stream type.
- TV database now stores EPG sources, EPG channels, programme listings, mappings, and stream health data.
- XMLTV EPG import and refresh are implemented.
- EPG auto-mapping is implemented using `tvg-id`, normalized IDs, channel numbers, logos, and name matching.
- Free TV now has a mobile guide route and per-channel current/next programme snippets.
- Stream health scoring and ranked alternative-stream failover are implemented.
- Android PiP is enabled through a native method channel and exposed in the TV player UI.
- The bundled IPTV import list now includes the requested Religion and Sport sources, with duplicate suppression.

## Decision

- The `media_kit` migration was evaluated and intentionally deferred.
- HermesCommander stays on the current `video_player`/Chewie stack for now, because the higher-value IPTV work landed cleanly without a backend swap.

## Verification

- Targeted analysis passed for the changed Free TV, EPG, settings, router, and player surfaces.
- Full repo analysis still reports pre-existing info-level lints outside this work.

## Next Required Work

- Physical Android QA for live TV playback, geoblocked streams, EPG mapping, PiP, and sleep/battery behavior.

