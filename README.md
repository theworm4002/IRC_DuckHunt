# IRC_DuckHunt


This was originally written by MenzAgitat, you can find his versions here https://scripts.eggdrop.fr/details-Duck+Hunt-s228.html

Installing
-----
* Place both th etcl script and the dir from the git in you /eggdrop/scripts/ dir.
* Add `source scripts/Duck_Hunt.tcl` to you eggdrop.conf file
* Start your duck hunt. or if its already running use the Partyline and rehash your eggdrop
* In the Partyline:
* to activate Duckhunt
* `.chanset #ChanName +DuckHunt`
* to deactivate Duckhunt
* `.chanset #ChanName -DuckHunt`

Ver 2.16
-----
* throttling override for owners New help msg
* Fixed the preducklaunch msg, the duck detector did not notify the user with ample time.

Ver 2.15
-----
* throttling override for owners
* topduck to get the top 5 players
* changed all pronouns to be none gender 
* adding in a function for irc relay players 
* shop list can now output both a url and a irc message rather then 1 or the other
* shop 1 & shop 2 now have the abillity to be purchesed for a player other then yourself

