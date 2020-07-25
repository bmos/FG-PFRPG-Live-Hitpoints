# PFRPG: Live Hitpoints from Constitution
Inspired by [xBzGrumpyCat's Base HP Box extension](https://www.fantasygrounds.com/forums/showthread.php?48752-Base-HP-Box), I decided to code an extension which automates the process by changing the HP total whenever CON was changed.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Classic](https://www.fantasygrounds.com/home/FantasyGroundsClassic.php) 3.3.11 and [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.0.0 (2020-07-16).

1. Before installing this extension, write down each player's HP total.
2. Enable the extension in FG launcher.
3. Subtract the number in Live HP on each character sheet corresponding to each number you wrote down.
4. Write that number into the HD HP box on the same character's sheet.

# Features
* Track CON Effects in the combat tracker to affect HP
* Track base CON mod, CON dmg, and scrollable CON mod bonus to affect HP
* Seperate HP into two boxes with a third total. HD HP for static/'rolled' HP and favored class bonuses, and Live HP for all others (which change on the fly).
* Populates the appropriate boxes on level-up
* New effect tag: "MHP: N" to raise max hitpoints (rather than temporary)
* Heavy focus on code documentation so you can see how it works and modify/build off it for your own needs or to contribute back to the project.

# Video Demonstration
[![v1.0.5 demo](https://i.imgur.com/N21cWom.jpg)](https://www.youtube.com/watch?v=clH4L8CrAwc "Live Hitpoints from Constitution - v1.0.5 - Click to Watch!")
