# IRC_DuckHunt


This was originally written by MenzAgitat, you can find his versions here https://scripts.eggdrop.fr/details-Duck+Hunt-s228.html

Installing
-----
* Place both the tcl script and the dir from the git in your /eggdrop/scripts/ dir.
* Add `source scripts/Duck_Hunt.tcl` to you eggdrop.conf file
* Start your duck hunt. Or if it's already running use the Partyline and rehash your eggdrop.
* To activate Duckhunt
  - In the Partyline: `.chanset #ChanName +DuckHunt`
  - Then give the bot at least voice in your channel
* To deactivate Duckhunt
  - In the Partyline: `.chanset #ChanName -DuckHunt`




Ver 2.16.20250102
-----
* added option to turn off nick tracing
* new topduck options
  - 'top#' where the # is the # of players to return 
  - '#channel' to return a different channels topduck 
  - 'ducks' to get the list of players with the most ducks shot
  
Ver 2.16.20230823
-----
* Small fix to block anyone from acting like the relay bot.
  
Ver 0.2.16a
-----
* Incresed player lvl to 100

Ver 0.2.16
-----
* Added new help msg
* Fixed the preducklaunch msg the duck detector did not notify the user with ample time.

Ver 0.2.15
-----
* throttling override for owners
* topduck to get the top 5 players
* changed all pronouns to be none gender 
* adding in a function for irc relay players 
* shop list can now output both a url and a irc message rather then 1 or the other
* shop 1 & shop 2 now have the abillity to be purchesed for a player other then yourself

