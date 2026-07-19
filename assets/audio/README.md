# Audio

## Folders

- `sfx/` — short one-shots (place, harvest, UI, animals). Prefer **OGG** or **WAV**.
- `music/` — loops (`day.mp3` is the default BGM).

## Naming (matches `AudioManager`)

| File | Wired? |
|------|--------|
| `ui_click.ogg` | Menu buttons |
| `place.ogg` | Place object |
| `harvest.ogg` | Crop harvest (swipe / tap) |
| `hoe.ogg` | Hoe grass |
| `copy_confirm.ogg` (also accepts `copy_comfirm.ogg`) | Copy-extend confirm |
| `delete.ogg` | Delete selection |
| `feed.ogg` | Feed animal |
| `fish_catch.ogg` | Catch fish |
| `fishing_drop.ogg` | Cast line into water |
| `chick.ogg` | Chicken |
| `moo.ogg` | Cow |
| `pig.ogg` | Pig |
| `quack.ogg` | Duck |
| `sheep.ogg` | Sheep |
| `rabbit.ogg` | Rabbit |
| `music/day.mp3` | Looping BGM (−14 dB under SFX) |

Animal voices are spatial: quiet when zoomed out; louder when zoomed in and closer to that animal. Ambient calls are rare and throttled; feed always plays a clearer cue.

Mute (music + SFX) is toggled from the bottom bar speaker button; preference saved to `user://audio_settings.cfg`.

```gdscript
AudioManager.play("harvest")
AudioManager.play_animal_for_item(ItemData.ItemType.COW)
AudioManager.play_music("day")
AudioManager.toggle_mute()
```
