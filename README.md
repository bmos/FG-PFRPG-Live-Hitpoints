# PFRPG: Live Hitpoints from Constitution
This extension automates changes to hitpoints based on an ability score.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.0.10 (2021-02-04).

# Features
* Tracks ability effects in the combat tracker to affect maximum hitpoints
* Tracks ability mod to affect hitpoints
* Separates hitpoints into compendent parts: Rolled HP for static/'rolled' HP and favored class bonuses, Ability HP for hitpoints calculated from ability scores, Feat HP for hitpoints provided by supported feats, and Misc HP for tracking of anything else.
* Adds effect tag: "MHP: N" to raise max hitpoints (rather than temporary)
* Negative levels now lower hitpoints by 5 per negative level.
* Automates the Toughness and Improved Toughness feats in Pathfinder and the Toughness feat in 3.5E.
