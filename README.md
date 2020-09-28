# PFRPG: Live Hitpoints from Constitution
Inspired by [xBzGrumpyCat's Base HP Box extension](https://www.fantasygrounds.com/forums/showthread.php?48752-Base-HP-Box), I decided to code an extension which automates the process by changing the HP total whenever CON was changed.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Classic](https://www.fantasygrounds.com/home/FantasyGroundsClassic.php) 3.3.11 and [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.0.0 (2020-08-05).

1. Before installing this extension, write down each player's HP total.
2. Enable the extension in FG launcher.
3. Subtract the number in Live HP on each character sheet corresponding to each number you wrote down.
4. Write that number into the HD HP box on the same character's sheet.

# Features
* Track Ability Effects in the combat tracker to affect HP
* Track base Ability mod, Ability dmg, and scrollable Ability mod bonus to affect HP
* Seperate HP into two boxes with a third total. Abil. HP for static/'rolled' HP and favored class bonuses, and Live HP for all others (which change on the fly).
* Populates the appropriate boxes on level-up
* New effect tag: "MHP: N" to raise max hitpoints (rather than temporary)
* Negative levels now lower hitpoints accordingly
* Automate the Toughness and Improved Toughness feats in Pathfinder and the Toughness feat in 3.5E.

# Video Demonstration (click for video)
[<img src="https://i.ytimg.com/vi_webp/Pda9zZhl7WE/hqdefault.webp">](https://youtu.be/Pda9zZhl7WE)
