# Game Analyzer v0.8

The Game Analyzer is a read-only semantic layer over Project UAI's existing discovery infrastructure. It is designed for client-visible data and authorized test/debug environments.

## Pipeline

Discovery -> Normalization -> Evidence -> Entities -> Graph -> Classification -> Adaptive Plan -> Timeline -> Knowledge observations

## Tool surface

- `game_analyze` — initial bounded analysis
- `game_refresh` — repeat and merge analysis
- `game_focus` — bounded follow-up scan of an analyzer-selected path
- `game_systems` — detected systems
- `game_evidence` — supporting evidence
- `game_entities` — semantic entities
- `game_world` — graph and world model
- `game_graph` — graph edges
- `game_timeline` — newly observed entities across analysis passes
- `game_plan` — bounded follow-up targets
- `game_classification` — comparative game-type classification
- `game_knowledge` — static semantic patterns and in-session learned confidence summaries
- `game_stats` — analyzer statistics

## Confidence model

Scores are evidence-weighted hints, not guarantees. The analyzer should prefer `FOUND`/`OBSERVED` evidence over inference and leave uncertain systems unresolved rather than inventing facts.

## Runtime behavior

All analyzer tools are marked read-only. The analyzer does not create, destroy, reparent, or invoke game objects. Runtime observation is represented as data supplied by the existing discovery layer.

## Coverage

The current knowledge catalog includes Enemy, Boss, Character, Quest, Stage, Wave, Inventory, Shop, Gacha, Upgrade, Currency, Crafting, Trading, and Rebirth patterns. More patterns can be added without changing the graph or agent architecture.

## Build

The canonical build remains `luajit tools/bundle.lua --native`. The supplied `dist/uai.lua` in this development package was assembled from `src/` and `init.lua`, but native Luau compilation was not available in the execution environment used to prepare this archive; run the project's normal build/test commands before deployment.
