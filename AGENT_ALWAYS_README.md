Modify the existing repository in place. Do not rewrite from scratch.

Project identity:
The game is titled:
Vault of Bent Geometry That Loads Correctly (VBGTLC)

Use that title in the project, README, title screen, and relevant UI where appropriate.
The title should feel like a suspicious system assertion, a lie, or a coping statement.
The game’s tone can be eerie, funny, glitchy, or ominous, but it should not become generic dark fantasy bullshit.
The repo should preserve the anti-name energy: overconfident system language, procedural denial, and subtle “everything is fine” vibes even when the world is clearly unstable.

Project constraints:
- Godot 4 project
- GDScript only unless a tiny helper script is genuinely necessary
- No external art packs or paid assets
- Use generated low-poly geometry, primitive meshes, procedural materials, or simple in-repo placeholder assets
- Keep the project runnable after changes
- Do not intentionally add bugs or sabotage
- Do not mention hidden bugs or create an answer key
- Prefer real systems over fake stubs
- Avoid TODO placeholders; implement the feature for real, even if simplified
- Keep the code reasonably organized, but do not over-refactor away existing architecture unless needed
- Preserve backward compatibility when practical with existing saves/config/data
- Update README and controls/setup notes, but it is fine if a tiny detail becomes slightly stale
- Keep sample content/seeds/data in repo so the project can be exercised immediately

Design goal:
Build an ambitious low-poly procedural dungeon crawler / light RPG with generated geometry, verticality, combat, loot, quests, hub flow, save/load, UI, minimap, multiple enemy types, and several overlapping systems. The dungeon must not be limited to axis-aligned rectangles or 90-degree-only layouts. Use angled rooms, wedge rooms, slanted corridors, irregular outlines, ramps, bridges, and vertical connections where feasible.

Title/tone requirements:
- The title and UI flavor should suggest “the system insists it is working”
- It is good if menu text, load text, codex text, debug strings, or shrine/system messages occasionally use suspicious reassurance like:
  - geometry integrity nominal
  - vault loaded correctly
  - state continuity preserved
  - no meaningful deviation detected
- Do not overdo the joke everywhere; keep it woven into the project identity rather than turning the whole game into a meme terminal
- The world should still function as a real playable RPG prototype, not just a gag

Important:
- Use deterministic seeds where practical
- Keep generation/gameplay/debug tools inside the repo
- Integrate new systems into the existing ones rather than leaving them isolated
- Prefer believable solo-dev prototype architecture over polished enterprise architecture
- When adding UI or lore flavor, align it with the title’s “confident denial” tone

When done:
- Print a brief summary of what changed