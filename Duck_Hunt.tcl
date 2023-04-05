 ###############################################################################
#
# Duck Hunt
# v2.11 (11/04/2016)  �2015-2016 Menz Agitat
# v2.16 (20230405) Worm
#
# IRC: irc.epiknet.org  #boulets / #eggdrop
#
# Mes scripts sont t�l�chargeables sur http://www.eggdrop.fr
# Retrouvez aussi toute l'actualit� de mes releases sur
# http://www.boulets.oqp.me/tcl/scripts/index.html
#
# Remerciements � Mon qui m'a donn� l'id�e de faire ce script, � Destiny pour le
# beta-testing intensif et pas mal d'id�es, et � Fr�d�ric pour aussi pas mal
# d'id�es et la r�alisation du background inclus (duck_background.png).
#
 ###############################################################################

#
# Description
#
# Duck Hunt est un FPS pour IRC.
# De temps en temps, un canard s'envole et les joueurs doivent l'abattre le plus
# rapidement possible.
#
# Veuillez v�rifier que les param�tres de la section configuration ci-dessous
#	vous conviennent, de m�me que les param�tres que contiennent le fichier
# Duck_Hunt.cfg.
#
 ###############################################################################

#
# Licence
#
#		Cette cr�ation est mise � disposition selon le Contrat
#		Attribution-NonCommercial-ShareAlike 3.0 Unported disponible en ligne
#		http://creativecommons.org/licenses/by-nc-sa/3.0/ ou par courrier postal �
#		Creative Commons, 171 Second Street, Suite 300, San Francisco, California
#		94105, USA.
#		Vous pouvez �galement consulter la version fran�aise ici :
#		http://creativecommons.org/licenses/by-nc-sa/3.0/deed.fr
#
 ###############################################################################

if {[::tcl::info::commands ::DuckHunt::uninstall] eq "::DuckHunt::uninstall"} { ::DuckHunt::uninstall }
if { [catch { package require Tcl 8.5 }] } { putloglev o * "\00304\[Duck Hunt - erreur\]\003 Duck Hunt n�cessite que Tcl 8.5 (ou plus) soit install� pour fonctionner. Votre version actuelle de Tcl est\00304 ${::tcl_version}\003." ; return }
if { [catch { package require msgcat }] } { putloglev o * "\00304\[Duck Hunt - erreur\]\003 Duck Hunt n�cessite le package msgcat pour fonctionner. Le chargement du script a �t� annul�." ; return }
namespace eval ::DuckHunt {



 ###############################################################################
### Configuration
 ###############################################################################

	# Emplacement et nom du fichier de configuration.
	variable config_file "scripts/duck_hunt/Duck_Hunt.cfg"
	
	#####  LANGUE  ###############################################################

	# Langue des messages du script ( fr = fran�ais / en = english )
	# Remarque : Il s'agit d'un r�glage global de votre Eggdrop; ce param�tre est
	#	mis ici pour vous en faciliter l'acc�s mais vous devez veiller � ce qu'il
	# soit r�gl� de la m�me mani�re partout.
	# Concr�tement, vous ne pouvez pas d�finir la langue d'un script sur "fr" et
	# celle d'un autre sur "en".
	::msgcat::mclocale "en"

	# Emplacement des fichiers de langue.
	variable language_files_directory "scripts/duck_hunt/language"
	

	# Vous trouverez le reste des param�tres de configuration dans le fichier
	# d�sign� par le param�tre config_file (voir plus haut).




 ###############################################################################
### Fin de la configuration
 ###############################################################################



	 #############################################################################
	### Initialisation
	 #############################################################################
	variable scriptname "Duck Hunt"
	variable version "2.16.20230405"
	setudef flag DuckHunt
	setudef str DuckHunt-LastDuck
	setudef str DuckHunt-PiecesOfBread
	# Chargement des fichiers de langue.
	::msgcat::mcload [file join $::DuckHunt::language_files_directory]
	# Lecture de la configuration.
	if { [file exists $::DuckHunt::config_file] } {
		eval [list source $::DuckHunt::config_file]
	} else {
		# Message : "\00304\[%s - erreur\]\003 Le fichier de configuration n'a pas �t� trouv� � l'emplacement indiqu� ( %s ). Le chargement du script est annul�."
		putloglev o * [::msgcat::mc m180 $::DuckHunt::scriptname $::DuckHunt::config_file]
		namespace delete ::DuckHunt
		return
	}
	# Proc�dure de d�sinstallation : le script se d�sinstalle totalement avant
	# chaque rehash ou � chaque relecture au moyen de la commande "source" ou
	# autre.
	proc uninstall {args} {
		# Message : "D�sallocation des ressources de %s..."
		putlog [::msgcat::mc m0 $::DuckHunt::scriptname]
		foreach binding [lsearch -inline -all -regexp [binds *[set ns [::tcl::string::range [namespace current] 2 end]]*] " \{?(::)?$ns"] {
			unbind [lindex $binding 0] [lindex $binding 1] [lindex $binding 2] [lindex $binding 4]
		}
		foreach running_utimer [utimers] {
			if { [::tcl::string::match "*[namespace current]::*" [lindex $running_utimer 1]] } { killutimer [lindex $running_utimer 2] }
		}
		foreach running_timer [timers] {
			if { [::tcl::string::match "*[namespace current]::*" [lindex $running_timer 1]] } { killtimer [lindex $running_timer 2] }
		}
		if { [::tcl::dict::exists $::msgcat::Msgs [::msgcat::mclocale] [namespace current]] } {
			::tcl::dict::unset ::msgcat::Msgs [::msgcat::mclocale] [namespace current]
		}
		if { $::DuckHunt::method == 2 } {
			uplevel #0 [list trace remove execution *dcc:chanset leave ::DuckHunt::chanset_call]
			uplevel #0 [list trace remove execution channel leave ::DuckHunt::chanset_call]
		}
		namespace delete ::DuckHunt
	}
	set ::DuckHunt::duck_sessions {}
	if { $::DuckHunt::max_line_length <= 9 } {
		set ::DuckHunt::max_line_length 10
	}
	set ::DuckHunt::report ""
	array set ::DuckHunt::pending_transfers {}
	set ::DuckHunt::post_init_done 0
}

 ###############################################################################
### Hook des commandes DCC et Tcl qui concernent l'activation et la
### d�sactivation d'un flag sur un chan afin de r�ajuster la planification des
### envols si method = 2.
 ###############################################################################
if { $::DuckHunt::method == 2 } {
	uplevel #0 [list trace add execution *dcc:chanset leave ::DuckHunt::chanset_call]
	uplevel #0 [list trace add execution channel leave ::DuckHunt::chanset_call]
	proc ::DuckHunt::chanset_call {command errorcode result operation} {
		if { !$errorcode } {
			set lower_command [::tcl::string::tolower $command]
			if { [lindex $lower_command 0] eq "*dcc:chanset" } {
				lassign [lindex $command 3] chan flag
				::DuckHunt::apply_planification_change $chan $flag
			} elseif { [lindex $lower_command 1] eq "set" } {
				lassign $command {} {} chan flag
				::DuckHunt::apply_planification_change $chan $flag
			}
		}
	}
	proc ::DuckHunt::apply_planification_change {chan flag} {
		if { [::tcl::string::equal -nocase $flag "+DuckHunt"] } {
			::DuckHunt::plan_out_flights $chan
		} elseif { [::tcl::string::equal -nocase $flag "-DuckHunt"] } {
			if { [::tcl::dict::exists $::DuckHunt::binds_tables $chan] } {
				foreach current_bind [::tcl::dict::get $::DuckHunt::binds_tables $chan] {
					unbind {*}$current_bind
					::tcl::dict::unset ::DuckHunt::binds_tables $chan
				}
			}
		}
	}
}

 ###############################################################################
### Chaque minute, on fouille les buissons pour voir si un canard ne s'y cache
### pas. (si method = 1)
 ###############################################################################
proc ::DuckHunt::check_bushes_for_duck {args} {
	foreach chan [channels] {
		if { [set num_pieces_of_bread [llength [channel get $chan DuckHunt-PiecesOfBread]]] != 0 } {
			set extra_ducks [expr {$num_pieces_of_bread * 2}]
		} else {
			set extra_ducks 0
		}
		if {
			([channel get $chan DuckHunt])
			&& ([strftime "%H" [unixtime]] ni $::DuckHunt::duck_sleep_hours)
			&& ([expr {int(rand() * (1440 - ([llength $::DuckHunt::duck_sleep_hours] * 60))) + 1}] <= [expr {$::DuckHunt::number_of_ducks_per_day + $extra_ducks}])
		} then {
			::DuckHunt::duck_soaring $chan - 0 - - - - - -
		}
	}
}

 ###############################################################################
### R�initialisation / planification des heures d'envol (si method = 2).
 ###############################################################################
proc ::DuckHunt::plan_out_flights {args} {
	if {
		([llength $args] == 5)
		|| ($args eq {})
	} then {
		set chans_to_process [channels]
	} else {
		set chans_to_process [lindex $args 0]
	}
	foreach chan $chans_to_process {
		# On supprime les �ventuelles planifications relatives � la journ�e
		# pr�c�dente. On le fait aussi sur les chans o� le flag DuckHunt n'est pas
		# activ� car il a pu �tre d�sactiv� depuis la derni�re planification.
		if { [::tcl::dict::exists $::DuckHunt::binds_tables $chan] } {
			foreach current_bind [::tcl::dict::get $::DuckHunt::binds_tables $chan] {
				unbind {*}$current_bind
			}
			::tcl::dict::unset ::DuckHunt::binds_tables $chan
		}
		::tcl::dict::set ::DuckHunt::binds_tables $chan {}
		# On planifie l'heure d'envol des canards.
		if { [channel get $chan DuckHunt] } {
			set hours_reference_list {00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23}
			# On exclut les heures de sommeil des canards.
			foreach sleep_hour $::DuckHunt::duck_sleep_hours {
				set hours_reference_list [lsearch -all -inline -not -integer $hours_reference_list $sleep_hour]
			}
			set hours_list $hours_reference_list
			if { [set num_pieces_of_bread [llength [channel get $chan DuckHunt-PiecesOfBread]]] != 0 } {
				set ducks_per_day [expr {$::DuckHunt::number_of_ducks_per_day + $num_pieces_of_bread}]
			} else {
				set ducks_per_day $::DuckHunt::number_of_ducks_per_day
			}
			# En cas d'ajout de pain, on conserve l'heure la plus proche dans la
			# planification actuelle pour la nouvelle planification, afin d'�viter
			# que le changement fr�quent de planification ait pour effet de rar�fier
			# les canards.
			set time_to_keep ""
			if {
				([lindex $args 1] eq "bread_added")
				|| (([lindex $args 1] eq "bread_expired")
				&& ($num_pieces_of_bread > 0))
				&& ($::DuckHunt::post_init_done)
			} then {
				set current_time [strftime "%H,%M" [unixtime]]


				foreach scanned_time [lsort [::tcl::dict::get $::DuckHunt::planned_soarings $chan]] {
					if { [regsub {:} $scanned_time {,}] > $current_time } {
						set time_to_keep $scanned_time
						break
					}
				}
			}

			::tcl::dict::set ::DuckHunt::planned_soarings $chan {}
			for { set duck_number 1 } { $duck_number <= $ducks_per_day } { incr duck_number } {
				if {
					($time_to_keep ne "")
					&& ($duck_number == 1)
				} then {
					lassign [split $time_to_keep ":"] chosen_hour chosen_minutes
				} else {
					set chosen_hour [lindex $hours_list [set hour_index [rand [llength $hours_list]]]]
					set hours_list [lreplace $hours_list $hour_index $hour_index]
					if { ![llength $hours_list] } {
						set hours_list $hours_reference_list
					}
					set chosen_minutes [lindex {00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59} [rand 60]]
					# Si par malchance l'heure s�lectionn�e est 00:00, le bind ne pourra pas
					# se d�clencher donc on d�cale d'une minute le cas �ch�ant.
					if {
						($chosen_hour == 0)
						&& ($chosen_minutes == 0)
					} then {
						set chosen_minutes 01
					}
				}
				set current_bind [list time "-|-" "$chosen_minutes $chosen_hour * * *" [list ::DuckHunt::duck_soaring $chan - 0 -]]
				# Si un bind existe d�j� � cette heure, on modifie les minutes.
				while { $current_bind in [::tcl::dict::get $::DuckHunt::binds_tables $chan] } {
					set current_bind [list time "-|-" "[set chosen_minutes [lindex {00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59} [rand 60]]] $chosen_hour * * *" [list ::DuckHunt::duck_soaring $chan - 0 -]]
				}
                ::DuckHunt::display_output loglev - -  "current_bind2: $current_bind"
				bind {*}$current_bind
				::tcl::dict::lappend ::DuckHunt::binds_tables $chan $current_bind
				::tcl::dict::lappend ::DuckHunt::planned_soarings $chan "${chosen_hour}:$chosen_minutes"
			}
		}
	}
}

 ###############################################################################
### A duck flies away.
### $args receives 4 arguments for a manual launch: {chan is_golden_duck is_fake_duck fake_duck_author}
### or 9 for an auto launch: {chan is_golden_duck is_fake_duck fake_duck_author min hour day month year}
### Is_golden_duck can be 0, 1 or -
### If is_golden_duck is - then we decide randomly.
### Is_fake_duck can be 0 or 1
### Fake_duck_author contains the name of the player who purchased the fake duck.
 ###############################################################################
proc ::DuckHunt::duck_soaring {args} {
	lassign $args chan is_golden_duck is_fake_duck fake_duck_author
	# Pr�vention contre les lancements multiples en cas de timer drift de
	# l'Eggdrop.
	if {
		([set current_time [unixtime]] eq [channel get $chan DuckHunt-LastDuck])
		&& ([llength $args] == 9)
	} then {
		return
	} else {
		# On d�cide s'il s'agit ou non d'un super-canard.
		if { $is_golden_duck eq "-" } {
			if { [expr {int(rand() * $::DuckHunt::number_of_ducks_per_day) + 1}] <= $::DuckHunt::approx_number_of_golden_ducks_per_day } {
				set is_golden_duck 1
			} else {
				set is_golden_duck 0
			}
		}
		if { $is_golden_duck } {
			set HP [expr {int(rand() * ($::DuckHunt::golden_duck_max_HP - $::DuckHunt::golden_duck_min_HP + 1) + $::DuckHunt::golden_duck_min_HP)}]
		} else {
			set HP 1
		}
		# On avertit les joueurs qui poss�dent un d�tecteur de canards.
		::DuckHunt::read_database
		if { [::tcl::dict::exists $::DuckHunt::player_data $chan] } {
			set some_players_have_been_warned 0
			foreach lower_nick [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $chan]] {
				if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "22"] 0]] != -1 } {
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					# On v�rifie si le joueur n'a pas un transfert de stats en attente.
					foreach pending_transfer_hash [array names ::DuckHunt::pending_transfers] {
						lassign $::DuckHunt::pending_transfers($pending_transfer_hash) oldnick newnick
						if {
							([::tcl::string::tolower $oldnick] eq $lower_nick)
							&& ([onchan $newnick $chan])
						} then {
							::DuckHunt::ckeck_for_pending_rename $chan $newnick [set lower_nick [::tcl::string::tolower $newnick]] $pending_transfer_hash
						}
					}
					set some_players_have_been_warned 1
					# Message : "%s > CANARD sur %s"
					::DuckHunt::display_output quick NOTICE $lower_nick [::msgcat::mc m351 [::DuckHunt::get_data $lower_nick $chan "nick"] $chan]
				}
			}
			if { $some_players_have_been_warned } {
				::DuckHunt::write_database
				#  Get time and offset 1 min for new launch time
				set currentSystemTime [clock seconds]
				set currentSystemTimePlus [clock add $currentSystemTime 1 minutes]
				set hrPlus1 [clock format $currentSystemTimePlus -format %H]
				set minPlus1 [clock format $currentSystemTimePlus -format %M]
				set new_bind [list time "-|-" "$minPlus1 $hrPlus1 * * *" [list ::DuckHunt::duck_soaring $chan $is_golden_duck 0 -]]
				::DuckHunt::display_output loglev - -  "new_bind: $new_bind"
				bind {*}$new_bind
				return
			}
		}
		::DuckHunt::purge_db_from_memory
		if { $::DuckHunt::hl_prevention } {
			# Construction d'un canard unique pour d�jouer les tentatives
			# d'automatisation (HL, scripts, ...)
			# Texte : "-.,��.-��'`'��-.,��.-��'`'��"
			set trail [::msgcat::mc m136]
			set trail_length [::tcl::string::length $trail]
			set quarter_trail_length [expr {int($trail_length / 4)}]
			lappend trail_indexes [set index [rand $trail_length]]
			lappend trail_indexes [set index [expr {($index + $quarter_trail_length) % $trail_length}]]
			lappend trail_indexes [set index [expr {($index + $quarter_trail_length) % $trail_length}]]
			lappend trail_indexes [set index [expr {($index + $quarter_trail_length) % $trail_length}]]
			set trail_indexes [lsort -integer -decreasing $trail_indexes]
			for { set counter 0 } { $counter <= 3 } { incr counter } {
				set trail [::tcl::string::replace $trail [lindex $trail_indexes $counter] [lindex $trail_indexes $counter]]
			}
			# Texte : {"\\_O<" "\\_o<" "\\_�<" "\\_�<" "\\_�<" "\\_�<" "\\_�<" "\\_�<" "\\_�<" "\\_�<" "\\_�<" "\\_�<" "\\_�<" "\\_�<" "\\_0<" "\\_�<" "\\_@<" "\\_�<" "\\_�<" "\\_^<" (...)}
			set duck [lindex [::msgcat::mc m137] [rand [llength [::msgcat::mc m137]]]]
			# Texte : {"COIN" "COIN" "COIN" "COIN" "COIN" "KWAK" "KWAK" "KWAAK" "KWAAK" "KWAAAK" "KWAAAK" (...)}
			set cry [lindex [::msgcat::mc m138] [rand [llength [::msgcat::mc m138]]]]
			set output_string "\00314$trail\017 \002$duck\002   \00314$cry\017"
		} else {
			# Message : "\00314-.,��.-��'`'��-.,��.-��'`'��\017 \002\\_O<\002   \00314COIN\017"
			set output_string [::msgcat::mc m135]
		}
		::DuckHunt::display_output now PRIVMSG $chan $output_string
		if { [set num_pieces_of_bread [llength [channel get $chan DuckHunt-PiecesOfBread]]] != 0 } {
			set utimer_ID [utimer [expr {$::DuckHunt::escape_time + ($num_pieces_of_bread * 20)}] [list ::DuckHunt::terminate_duck_session $chan 0]]
		} else {
			set utimer_ID [utimer $::DuckHunt::escape_time [list ::DuckHunt::terminate_duck_session $chan 0]]
		}
		# Format de duck_sessions : {utimer_ID unixtime_en_ms_heure_envol nombre_tirs_manqu�s super_canard pts_vie_restants pts_vie_total d�j�_signal� faux_canard auteur_du_faux_canard}
		::tcl::dict::lappend ::DuckHunt::duck_sessions $chan [list $utimer_ID [::tcl::clock::milliseconds] 0 $is_golden_duck $HP $HP 0 $is_fake_duck $fake_duck_author]
		channel set $chan DuckHunt-LastDuck $current_time
		if {
			($::DuckHunt::hunting_logs)
			&& ([llength $args] == 9)
		} then {
			if { $is_golden_duck } {
				::DuckHunt::add_to_log $chan $current_time - - - - "golden_duck_soaring" 0 -
			} elseif { $is_fake_duck } {
				::DuckHunt::add_to_log $chan $current_time - - - - "fake_duck_soaring" 0 -
			} else {
				::DuckHunt::add_to_log $chan $current_time - - - - "soaring" 0 -
			}
		}
	}
}

 ###############################################################################
### Un canard a �t� abattu ou s'est �chapp�.
 ###############################################################################
proc ::DuckHunt::terminate_duck_session {chan has_been_shot} {
	if { [::tcl::dict::exists $::DuckHunt::duck_sessions $chan] } {
		if { !$has_been_shot } {
			lassign [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] 0] {} {} {} is_golden_duck {} {} {} is_fake_duck {}
			if { [llength [::tcl::dict::get $::DuckHunt::duck_sessions $chan]] > 1 } {
				if { $is_golden_duck } {
					# Message : "Un super-canard s'�chappe.     \00314��'`'�-.,��.��'`\003"
					::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m247]
				} elseif { $is_fake_duck } {
					# Message : "Un canard m�canique s'�chappe.     \00314��'`'�-.,��.��'`\003"
					::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m353]
				} else {
					# Message : "Un canard s'�chappe.     \00314��'`'�-.,��.��'`\003"
					::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m3]
				}
			} else {
				if { $is_golden_duck } {
					# Message : "Le super-canard s'�chappe.     \00314��'`'�-.,��.��'`\003"
					::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m248]
				} elseif { $is_fake_duck } {
					# Message : "Le canard m�canique s'�chappe.     \00314��'`'�-.,��.��'`\003"
					::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m354]
				} else {
					# Message : "Le canard s'�chappe.     \00314��'`'�-.,��.��'`\003"
					::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m4]
				}
				if { $::DuckHunt::gun_hand_back_mode == 2 } {
					::DuckHunt::hand_back_weapons $chan
				}
			}
			if { $::DuckHunt::hunting_logs } {
				if { $is_golden_duck } {
					::DuckHunt::add_to_log $chan [unixtime] - - - - "golden_duck_escaped" 0 -
				} elseif { $is_fake_duck } {
					::DuckHunt::add_to_log $chan [unixtime] - - - - "fake_duck_escaped" 0 -
				} else {
					::DuckHunt::add_to_log $chan [unixtime] - - - - "escaped" 0 -
				}
			}
		} else {
			killutimer [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] 0 0]
		}
		::tcl::dict::set ::DuckHunt::duck_sessions $chan [lreplace [::tcl::dict::get $::DuckHunt::duck_sessions $chan] 0 0]
		if { [::tcl::dict::get $::DuckHunt::duck_sessions $chan] eq {} } {
			::tcl::dict::unset ::DuckHunt::duck_sessions $chan
		}
	}
}


###############################################################################
### !relay computertech : A player shoots. 
 ###############################################################################
proc ::DuckHunt::shoot_relay {nick host hand chan arg} {
	set relayCMD_chk {}
	set relayCMDs "$::DuckHunt::shop_cmd $::DuckHunt::stat_cmd $::DuckHunt::lastduck_pub_cmd $::DuckHunt::reload_cmd $::DuckHunt::shooting_cmd $::DuckHunt::shooting_cmd2 $::DuckHunt::shooting_cmd3 $::DuckHunt::shooting_cmd4 $::DuckHunt::shooting_cmd5 $::DuckHunt::shooting_cmd6"
	set s [split $relayCMDs]
	foreach e $s {
		if {[string first $e $arg] != -1} {
			set relayCMD_chk "true"
		}
	}
	if { $relayCMD_chk != "true" } { return }
	
	lassign [set args [split [::tcl::string::trim $arg]]] nick cmdAct shopcmd1 shopcmd2 shopcmd3
	set nick [::tcl::string::tolower $nick]
	
	set i 0
	set l1 {}
	set num 0
	set wchop "false"
	set chops "~ + @ % &"
	set s [split $nick ""]
	foreach e $s {
		set e [split $e ""]
		incr num
	}
	puts $num

	if { [string first "/ENet" $nick ] != -1 } {
		set lastnum [ expr {$num - 7}]
	} else {
		set lastnum [ expr {$num - 2}]
	}

	foreach e $s {
		set e [split $e ""]
		if { $i == 1 } {
			if { [string first $e $chops ] != -1 } {
				set wchop "true"
			}
		}
		if { 4 < $i && $i < $lastnum && $wchop == "true" } {
			set l1 "$l1$e"
		} elseif { 3 < $i && $i < $lastnum && $wchop == "false" } {
			set l1 "$l1$e"
		}
		incr i  
	}
	set nick $l1

	set arg "$shopcmd1 $shopcmd2"
	if {$cmdAct == "" } then {
		set cmdAct $shopcmd1
		set arg "$shopcmd2 $shopcmd3"
	}
	if {[string first $e $nick] != -1} {
		set relayCMD_chk "true"
	}
	set cmdAct [::tcl::string::trim $cmdAct]

	if {($::DuckHunt::shooting_cmd == $cmdAct)
		|| ($::DuckHunt::shooting_cmd2 == $cmdAct)
		|| ($::DuckHunt::shooting_cmd3 == $cmdAct)
		|| ($::DuckHunt::shooting_cmd4 == $cmdAct)
		|| ($::DuckHunt::shooting_cmd5 == $cmdAct)
		|| ($::DuckHunt::shooting_cmd6 == $cmdAct)
		} then {			
			::DuckHunt::shoot $nick $host $hand $chan $arg		
	} elseif {$::DuckHunt::reload_cmd == $cmdAct 
		} then {::DuckHunt::reload_gun $nick $host $hand $chan $arg
	} elseif {$::DuckHunt::lastduck_pub_cmd == $cmdAct 
		} then {::DuckHunt::pub_show_last_duck $nick $host $hand $chan $arg    
	} elseif {$::DuckHunt::stat_cmd == $cmdAct 
		} then {::DuckHunt::display_stats $nick $host $hand $chan $arg 
	} elseif {$::DuckHunt::shop_cmd == $cmdAct 
		} then { 
		::DuckHunt::shop $nick $host $hand $chan $arg 
	} else {return}
}


 ###############################################################################
### !bang : Un joueur tire.
 ###############################################################################
proc ::DuckHunt::shoot {nick host hand chan arg} {

	set lower_nick [::tcl::string::tolower $nick]

	if { [matchattr $hand $::DuckHunt::launch_auth $chan] } then {
		variable canNickFlood 0
	} else {
		variable canNickFlood $::DuckHunt::antiflood
	}
	
	if {
		(![channel get $chan DuckHunt])
		|| ($hand in $::DuckHunt::blacklisted_handles)
		|| (($canNickFlood == 1)
		&& (([::DuckHunt::antiflood $nick $chan "nick" $::DuckHunt::shooting_cmd $::DuckHunt::flood_shoot])
		|| ([::DuckHunt::antiflood $nick $chan "nick" $::DuckHunt::shooting_cmd2 $::DuckHunt::flood_shoot])
		|| ([::DuckHunt::antiflood $nick $chan "nick" $::DuckHunt::shooting_cmd3 $::DuckHunt::flood_shoot])
		|| ([::DuckHunt::antiflood $nick $chan "chan" "*" $::DuckHunt::flood_global])))
	} then {
		return
	} else {
		set lower_nick [::tcl::string::tolower $nick]
		if { $::DuckHunt::preferred_display_mode == 1 } {
			set output_method "PRIVMSG"
			set output_target $chan
		} else {
			set output_method "NOTICE"
			set output_target $nick
		}
		::DuckHunt::read_database
		::DuckHunt::ckeck_for_pending_rename $chan $nick $lower_nick [md5 "$chan,$lower_nick"]
		::DuckHunt::initialize_player $nick $lower_nick $chan
		if { [::tcl::dict::exists $::DuckHunt::duck_sessions $chan] } {
			# On note le cumul du temps de r�action du joueur.
			::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "cumul_reflex_time" [expr {[::DuckHunt::get_data $lower_nick $chan "cumul_reflex_time"] + [expr {[::tcl::clock::milliseconds] - [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] 0 1]}]}]
			set num_ducks_in_flight [llength [::tcl::dict::get $::DuckHunt::duck_sessions $chan]]
		} else {
			set num_ducks_in_flight 0
		}
		set current_time [unixtime]
		::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "last_activity" $current_time
		# Le joueur n'a pas d'arme (arme confisqu�e).
		if { [::DuckHunt::get_data $lower_nick $chan "gun"] <= 0 } {
			# Message : "%s > tu n'es pas arm�."
			::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m5 $nick]
		# Le joueur a re�u un seau d'eau.
		} elseif { [lindex [::DuckHunt::get_item_info $lower_nick $chan "16"] 0] != -1 } {
			# Message : "%s > � cause de %s, tes v�tements sont tremp�s et tu ne peux pas chasser comme �a. Tu dois encore patienter pendant %s."
			::DuckHunt::display_output quick $output_method $output_target [::msgcat::mc m332 $nick [lindex [::DuckHunt::get_item_info $lower_nick $chan "16"] 2] [::DuckHunt::adapt_time_resolution [expr {([lindex [::DuckHunt::get_item_info $lower_nick $chan "16"] 1] - $current_time) * 1000}] 0]]
			::DuckHunt::purge_db_from_memory
			return
		# Le joueur a une arme.
		} else {
			set sand_effect_msg ""
			set sabotage_effect_msg ""
			set dazzle_effect_msg ""
			lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] level required_xp accuracy deflection defense jamming ammos_per_clip ammo_clips xp_miss xp_wild_fire xp_accident
			# Le joueur a du sable dans son arme.
			lassign [::DuckHunt::get_item_info $lower_nick $chan "15"] item_index {} author
			if { $item_index != -1 } {
				set jamming [expr {$jamming * 2}]
				::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
				# Texte : " \00304\[ensabl� par %s\]\003"
				set sand_effect_msg [::msgcat::mc m333 $author]
			}
			# Le joueur a graiss� son arme.
			if { [lindex [::DuckHunt::get_item_info $lower_nick $chan "6"] 0] != -1 } {
				set jamming [expr {int($jamming / 2)}]
			}
			# L'arme du joueur a �t� sabot�e.
			lassign [::DuckHunt::get_item_info $lower_nick $chan "17"] item_index {} sabotage_author
			if { $item_index != -1 } {
				set has_been_sabotaged 1
				::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
				# Texte : "   \00304\[sabotage par %s\]\003"
				set sabotage_effect_msg [::msgcat::mc m337 $sabotage_author]
			} else {
				set has_been_sabotaged 0
			}
			# Le joueur poss�de une assurance responsabilit� civile.
			if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "19"] 0]] != -1 } {
				set xp_accident [expr {int($xp_accident / 3)}]
				# Message : " \00303\[assurance resp. civile\]\003"
				set liability_insurance_msg [::msgcat::mc m343]
			} else {
				set liability_insurance_msg ""
			}
			# L'arme est enray�e.
			if { [::DuckHunt::get_data $lower_nick $chan "jammed"] } {
				# Message : "%s > \00314*CLAC*\003     \00304ARME ENRAY�E\003"
				::DuckHunt::display_output quick $output_method $output_target [::msgcat::mc m7 $nick]
				::DuckHunt::purge_db_from_memory
				return
				# L'arme s'enraye.
			} elseif {
				($has_been_sabotaged)
				|| ([expr {int(rand()*100)+1}] <= $jamming)
			} then {
				::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "jammed" 1
				::DuckHunt::incr_data $lower_nick $chan "jammed_weapons" +1
				# Message : "%s > \00314*CLAC*\003     Ton arme s'est enray�e, tu dois recharger pour la d�coincer... \00314|\003 Mun. : \002%s\002 \00314|\003 Charg. : \002%s\002"
				::DuckHunt::display_output quick $output_method $output_target "[::msgcat::mc m8 $nick [::DuckHunt::display_ammo $lower_nick $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_nick $chan $ammo_clips]]${sabotage_effect_msg}$sand_effect_msg"
				if { $::DuckHunt::hunting_logs } {
					::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "jam" 0 -
				}
				# L'arme du joueur a �t� sabot�e et explose.
				if {
					($has_been_sabotaged)
					&& ($::DuckHunt::kick_when_sabotaged)
				} then {
					if { $::DuckHunt::kick_method } {
						# Message : "\002*BOOM*\002     Ton arme vient d'exploser � cause du sabotage de %s."
						putserv "CS kick $chan $nick [::msgcat::mc m338 $sabotage_author]"
					} elseif { ![isop $::nick $chan] } {
						# Message : "\00314\[%s\]\003 \00304:::\003 Erreur : %s n'a pas pu �tre kick� sur %s car je n'y suis ni halfop�, ni op�."
						::DuckHunt::display_output loglev - - [::msgcat::mc m140 $::DuckHunt::scriptname $nick $chan]
					} else {
						# Message : "\002*BOOM*\002     Ton arme vient d'exploser � cause du sabotage de %s."
						putkick $chan $nick [::msgcat::mc m338 $sabotage_author]
					}
				}
			# L'arme ne s'enraye pas.
			} else {
				# The weapon is not loaded and the ammunition is not unlimited.
				if {
					([::DuckHunt::get_data $lower_nick $chan "current_ammo_clip"] == 0)
					&& !($::DuckHunt::unlimited_ammo_per_clip)
				} then {
					::DuckHunt::incr_data $lower_nick $chan "empty_shots" +1
					# Message : "%s > \00314*CLIC*\003     \00304CHARGEUR VIDE\003 \00314|\003 Mun. : \002%s\002 \00314|\003 Charg. : \002%s\002"
					::DuckHunt::display_output quick $output_method $output_target [::msgcat::mc m6 $nick [::DuckHunt::display_ammo $lower_nick $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_nick $chan $ammo_clips]]
					if { $::DuckHunt::hunting_logs } {
						::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "empty_shot" 0 -
					}
				# L'arme est charg�e.
				} else {
					# Le joueur poss�de un d�tecteur infrarouge et il n'y a pas de canard.
					lassign [::DuckHunt::get_item_info $lower_nick $chan "8"] item_index expiration_date item_uses
					if {
						!([set duck_present [::tcl::dict::exists $::DuckHunt::duck_sessions $chan]])
						&& ($item_index != -1)
					} then {
						# Message : "%s > \00314*CLIC*\003     G�chette verrouill�e."
						::DuckHunt::display_output quick $output_method $output_target [::msgcat::mc m290 $nick]
						::DuckHunt::decrement_item_uses $lower_nick $chan "8" $item_index $expiration_date $item_uses
						::DuckHunt::write_database
						::DuckHunt::purge_db_from_memory
						return
					}
					if { !$::DuckHunt::unlimited_ammo_per_clip } {
						::DuckHunt::incr_data $lower_nick $chan "current_ammo_clip" -1
					}
					set base_accuracy $accuracy
					# Le joueur est �bloui.
					lassign [::DuckHunt::get_item_info $lower_nick $chan "14"] item_index {} author
					if { $item_index != -1 } {
						set accuracy [expr {int($accuracy / 2)}]
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
						# Texte : " \00304\[�bloui par %s\]\003"
						set dazzle_effect_msg [::msgcat::mc m334 $author]
					}
					# Le joueur a install� une lunette de vis�e sur son arme.
					if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "7"] 0]] != -1 } {
						set accuracy [expr {$accuracy + int((100 - $base_accuracy) / 3)}]
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					set duck_fleed 0
					# Le joueur rate son tir ou il n'y a aucun canard en vol.
					if {
						!($duck_present)
						|| ([expr {int(rand()*100)+1}] > $accuracy)
					} then {
						::DuckHunt::incr_data $lower_nick $chan "missed_shots" +1
						if { ![::tcl::info::exists previous_xp] } {
							set previous_xp [::DuckHunt::get_data $lower_nick $chan "xp"]
						}
						::DuckHunt::incr_data $lower_nick $chan "xp" $xp_miss
						if { $::DuckHunt::devoice_on_miss } {
							pushmode $chan -v $nick
						}
						# Si des canards sont en vol, on incr�mente le compteur de tirs
						# manqu�s effectu�s en leur pr�sence et on voit si certains ont
						# atteint leur limite.
						if { $duck_present } {
							incr duck_fleed [::DuckHunt::ducks_scaring $chan $lower_nick]
							set xp_wild_fire_msg ""
						} else {
							# Texte : "\[tir sauvage : %s xp\] "
							set xp_wild_fire_msg [::msgcat::mc m9 $xp_wild_fire]
						}
						set chances_to_hit_someone_else [::DuckHunt::determine_chances_to_hit_someone_else $chan $duck_present]
						set someone_has_been_hit 0
						set confiscation_msg_sent 0
						set xp_penalty_msg_sent 0
						set ricochet_counter 0
						set source_nick $nick
						# La balle perdue touche un autre joueur.
						while {
							([expr {int(rand()*100)+1}] <= $chances_to_hit_someone_else)
							&& ($ricochet_counter < $::DuckHunt::max_ricochets)
							&& ([set victim [::DuckHunt::random_user $chan $source_nick]] ne "@nobody@")
						} {
							set someone_has_been_hit 1
							set source_nick $victim
							set lower_victim [::tcl::string::tolower $victim]
							::DuckHunt::ckeck_for_pending_rename $chan $victim $lower_victim [md5 "$chan,$lower_victim"]
							::DuckHunt::incr_data $lower_nick $chan "humans_shot" +1
							if { $::DuckHunt::devoice_on_accident } {
								pushmode $chan -v $nick
							}
							if { ![::tcl::info::exists previous_xp] } {
								set previous_xp [::DuckHunt::get_data $lower_nick $chan "xp"]
							}
							::DuckHunt::incr_data $lower_nick $chan "xp" $xp_accident
							::DuckHunt::initialize_player $victim $lower_victim $chan
							::DuckHunt::incr_data $lower_victim $chan "bullets_received" +1
							# Confiscation �ventuelle de l'arme.
							if {
								($::DuckHunt::gun_confiscation_when_shooting_someone)
								&& !($confiscation_msg_sent)
							} then {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "gun" 0
								::DuckHunt::incr_data $lower_nick $chan "confiscated_weapons" +1
								# Texte : " \00304\[ARME CONFISQU�E : accident de chasse\]\003"
								set gun_confiscation1 [::msgcat::mc m10]
								# Texte : " ainsi que son arme"
								set gun_confiscation2 [::msgcat::mc m11]
							} else {
								set gun_confiscation1 ""
								set gun_confiscation2 ""
							}
							# On n'affiche qu'une seule fois l'xp perdue pour tir rat�/sauvage.
							if { !$xp_penalty_msg_sent } {
								if { !$duck_present } {
									# Texte : "\[rat� : %s xp\] "
									set xp_penalty_msg "[::msgcat::mc m12 $xp_miss]$xp_wild_fire_msg"
									set lost_xp [expr {abs($xp_miss) + abs($xp_wild_fire) + abs($xp_accident)}]
								} else {
									# Texte : "\[rat� : %s xp\] "
									set xp_penalty_msg "[::msgcat::mc m12 $xp_miss]"
									set lost_xp [expr {abs($xp_miss) + abs($xp_accident)}]
								}
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "accident" 1 -
								}
							} else {
								set xp_penalty_msg ""
								set lost_xp [expr {abs($xp_accident)}]
							}
							# La victime poss�de une assurance vie.
							if { [set item_index [lindex [::DuckHunt::get_item_info $lower_victim $chan "18"] 0]] != -1 } {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_victim "items" [lreplace [::DuckHunt::get_data $lower_victim $chan "items"] $item_index $item_index]
								::DuckHunt::incr_data $lower_victim $chan "xp" [set life_insurance_xp [expr {[lindex [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_victim $chan "xp"]] 0] * 2}]]
								# Message : " \00303\[assurance vie : +%s xp pour %s\]\003"
								set life_insurance_msg [::msgcat::mc m340 $life_insurance_xp $victim]
								# Message : " \00303\[assurance vie : +%s xp\]\003"
								set life_insurance_msg2 [::msgcat::mc m341 $life_insurance_xp]
							} else {
								set life_insurance_msg ""
								set life_insurance_msg2 ""
							}
							lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_victim $chan "xp"]] {} {} {} victim_deflection victim_defense {} {} {} {} {} {}
							# La balle ricoche.
							if { [expr {int(rand()*100)+1}] <= $victim_deflection } {
								::DuckHunt::incr_data $lower_victim $chan "deflected_bullets" +1
								incr ricochet_counter
								set confiscation_msg_sent 1
								set xp_penalty_msg_sent 1
								# Message : "\00314*PIEWWW*\003     La balle de %s ricoche sur %s gr�ce � son modificateur de d�flexion de %s%%.   \00304%s\[accident : %s xp\]\003"
								::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m13 $nick $victim $victim_deflection $xp_penalty_msg $xp_accident]${gun_confiscation1}${dazzle_effect_msg}${liability_insurance_msg}$life_insurance_msg"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $lower_victim - "deflect" 1 -
								}
								#	Un canard est touch� par ricochet.
								if {
									($duck_present)
									&& ([expr {int(rand()*100)+1}] <= $::DuckHunt::chances_to_ricochet_towards_duck)
								} then {
									::DuckHunt::hit_a_duck $nick $lower_nick $chan 1 $output_method $output_target
									break
								}
							# L'autre joueur r�siste.
							} elseif { [expr {int(rand()*100)+1}] <= $victim_defense } {
								set confiscation_msg_sent 1
								set xp_penalty_msg_sent 1
								# Message : "\00314*CHTOK*\003     %s re�oit la balle de %s mais accuse le coup gr�ce � son modificateur d'armure de %s%%.   \00304%s\[accident : %s xp\]\003"
								::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m14 $victim $nick $victim_defense $xp_penalty_msg $xp_accident]${gun_confiscation1}${dazzle_effect_msg}${liability_insurance_msg}$life_insurance_msg"
								if { $::DuckHunt::hunting_logs } {
									if { $::DuckHunt::gun_confiscation_when_shooting_someone } {
										::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $lower_victim - "hit" 1 -
										::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $lower_victim - "confiscated" 0 -
									} else {
										::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $lower_victim - "hit" 0 -
									}
								}
								break
							# L'autre joueur est abattu.
							} else {
								::DuckHunt::incr_data $lower_victim $chan "deaths" +1
								set confiscation_msg_sent 1
								set xp_penalty_msg_sent 1
								if { $::DuckHunt::kick_when_shot } {
									if { $::DuckHunt::kick_method } {
										# Message : "\002*BANG*\002     Tu viens d'�tre victime d'un accident de chasse. %s s'en excuse... et perd %s pts d'xp."
										putserv "CS kick $chan $victim [::msgcat::mc m15 $nick $lost_xp]${gun_confiscation2}$life_insurance_msg2"
									} elseif { ![isop $::nick $chan] } {
										# Message : "\00314\[%s\]\003 \00304:::\003 Erreur : %s n'a pas pu �tre kick� sur %s car je n'y suis ni halfop�, ni op�."
										::DuckHunt::display_output loglev - - [::msgcat::mc m140 $::DuckHunt::scriptname $victim $chan]
									} else {
										# Message : "\002*BANG*\002     Tu viens d'�tre victime d'un accident de chasse. %s s'en excuse... et perd %s pts d'xp."
										putkick $chan $victim "[::msgcat::mc m15 $nick $lost_xp]${gun_confiscation2}$life_insurance_msg2"
									}
								}
								# Message : "\00314*BANG*\003 \002\037xO\037'\002     %s vient de se faire descendre par %s par accident.   \00304%s\[accident : %s xp\]\003"
								::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m16 $victim $nick $xp_penalty_msg $xp_accident]${gun_confiscation1}${dazzle_effect_msg}${liability_insurance_msg}$life_insurance_msg"
								if { $::DuckHunt::hunting_logs } {
									if { $::DuckHunt::gun_confiscation_when_shooting_someone } {
										::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $lower_victim - "die" 1 -
										::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $lower_victim - "confiscated" 0 -
									} else {
										::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $lower_victim - "die" 0 -
									}
								}
								break
							}
						}
						# Il n'y a actuellement aucun canard en vol sur le chan.
						if { !$duck_present } {
							::DuckHunt::incr_data $lower_nick $chan "wild_shots" +1
							if { ![::tcl::info::exists previous_xp] } {
								set previous_xp [::DuckHunt::get_data $lower_nick $chan "xp"]
							}
							::DuckHunt::incr_data $lower_nick $chan "xp" $xp_wild_fire
							if { $::DuckHunt::devoice_on_wild_fire } {
								pushmode $chan -v $nick
							}
							# Confiscation �ventuelle de l'arme.
							if {
								($::DuckHunt::gun_confiscation_on_wild_fire)
								&& ([::DuckHunt::get_data $lower_nick $chan "gun"] == 1)
							} then {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "gun" 0
								::DuckHunt::incr_data $lower_nick $chan "confiscated_weapons" +1
								# Texte : "   \00304\[ARME CONFISQU�E : tir sauvage\]\003"
								set gun_confiscation [::msgcat::mc m17]
								if { $::DuckHunt::hunting_logs } { 
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "wild_fire" 1 -
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "confiscated" 0 -
								}
							} else {
								set gun_confiscation ""
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "wild_fire" 0 -
								}
							}
							# Si personne n'a �t� touch�, c'est juste un tir sauvage.
							if { !$someone_has_been_hit } {
								# Message : "%s > Par chance tu as rat�, mais tu visais qui au juste ? Il n'y a aucun canard dans le coin...   \00304\[rat� : %s xp\] \[tir sauvage : %s xp\]\003"
								::DuckHunt::display_output quick $output_method $output_target "[::msgcat::mc m18 $nick $xp_miss $xp_wild_fire]${gun_confiscation}"
							}
						# Il y a au moins un canard en vol sur le chan.
						} else {
							# Si personne n'a �t� touch�, c'est juste un tir manqu�.
							if { !$someone_has_been_hit } {
								# Message : "%s > Rat�.   \00304\[rat� : %s xp\]\003"
								::DuckHunt::display_output quick $output_method $output_target "[::msgcat::mc m19 $nick $xp_miss]$dazzle_effect_msg"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "miss" 0 -
								}
							}
						}
						# Kick pour tir non-autoris� en l'absence de canard.
						if {
							(!$duck_present)
							&& ($::DuckHunt::kick_on_wild_fire)
						} then {
							if { $::DuckHunt::kick_method } {
								# Message : "Tu vises qui l� ? Je ne vois aucun canard dans le coin. \[%s xp\] \[%s xp\]"
								putserv "CS kick $chan $nick [::msgcat::mc m20 $xp_miss $xp_wild_fire]"
							} elseif { ![isop $::nick $chan] } {
								# Message : "\00314\[%s\]\003 \00304:::\003 Erreur : %s n'a pas pu �tre kick� sur %s car je n'y suis ni halfop�, ni op�."
								::DuckHunt::display_output loglev - - [::msgcat::mc m140 $::DuckHunt::scriptname $nick $chan]
							} else {
								# Message : "Tu vises qui l� ? Je ne vois aucun canard dans le coin. \[%s xp\] \[%s xp\]   "
								putkick $chan $nick [::msgcat::mc m20 $xp_miss $xp_wild_fire]
							}
						}
						if {
							([::tcl::info::exists previous_xp])
							&& ([lindex [::DuckHunt::get_level_and_grantings $previous_xp] 0] > [lindex [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] 0])
						} then {
							# Message "%s est r�trograd�(e) au rang de chasseur niveau %s (%s)."
							::DuckHunt::display_output quick PRIVMSG $chan [::msgcat::mc m2 $nick [set level [lindex [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] 0]] [::DuckHunt::lvl2rank $level]]
						}
					# Le joueur r�ussit son tir.
					} else {
						::DuckHunt::hit_a_duck $nick $lower_nick $chan 0 $output_method $output_target
						incr num_ducks_in_flight -1
						if { $::DuckHunt::successful_shots_also_scares_ducks } {
							incr duck_fleed [::DuckHunt::ducks_scaring $chan $lower_nick]
						}
					}
					# Le tir manqu� a effray� un ou plusieurs canards qui parviennent �
					# s'�chapper.
					if { $duck_fleed > 1 } {
						if { $duck_fleed == $num_ducks_in_flight } {
							# Message : "Effray�s par tout ce bruit, tous les canards s'�chappent.     \00314��'`'�-.,��.��'`\003"
							::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m21]
						} else {
							# Message : "Effray�s par tout ce bruit, %s canards s'�chappent.     \00314��'`'�-.,��.��'`\003"
							::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m22 $duck_fleed]
						}
						for { set counter 1 } { $counter <= $duck_fleed } { incr counter } {
							if { $::DuckHunt::hunting_logs } {
								::DuckHunt::add_to_log $chan $current_time - - - - "frightened" 0 -
							}
						}
					} elseif { $duck_fleed == 1 } {
						if { $num_ducks_in_flight == 1 } {
							# Message : "Effray� par tout ce bruit, le canard s'�chappe.     \00314��'`'�-.,��.��'`\003"
							::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m23]
						} else {
							# Message : "Effray� par tout ce bruit, un canard s'�chappe.     \00314��'`'�-.,��.��'`\003"
							::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m24]
						}
						if { $::DuckHunt::hunting_logs } {
							::DuckHunt::add_to_log $chan $current_time - - - - "frightened" 0 -
						}
					}
				}
			}
			::DuckHunt::recalculate_ammo_on_lvl_change $lower_nick $chan
			::DuckHunt::write_database
		}
		::DuckHunt::purge_db_from_memory
	}
	return
}

 ###############################################################################
### A player has shoot, we increment the degree of fear of the ducks.
 ###############################################################################
proc ::DuckHunt::ducks_scaring {chan lower_nick} {
	set duck_fleed 0
	# Si le joueur n'a pas install� de silencieux sur son arme...
	if {
		([::tcl::dict::exists $::DuckHunt::duck_sessions $chan])
		&& ([lindex [::DuckHunt::get_item_info $lower_nick $chan "9"] 0] == -1)
	} then {
		for { set counter 0 } { $counter <= [llength [::tcl::dict::get $::DuckHunt::duck_sessions $chan]] -1 } { incr counter } {
			set shots_in_presence [expr {[lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 2] + 1}]
			if {
				($shots_in_presence == $::DuckHunt::shots_before_duck_flee)
				&& !([lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 3])
				&& !([lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 7])
			} then {
				killutimer [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 0]
				::tcl::dict::set ::DuckHunt::duck_sessions $chan [lreplace [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter $counter]
				incr duck_fleed
			} else {
				::tcl::dict::set ::DuckHunt::duck_sessions $chan [lreplace [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter $counter [list [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 0] [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 1] $shots_in_presence [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 3] [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 4] [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 5] [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 6] [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 7] [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] $counter 8]]]
			}
		}
		if { [::tcl::dict::get $::DuckHunt::duck_sessions $chan] eq {} } {
			::tcl::dict::unset ::DuckHunt::duck_sessions $chan
		}
	}
	return $duck_fleed
}

 ###############################################################################
### Un canard a �t� touch�.
 ###############################################################################
proc ::DuckHunt::hit_a_duck {nick lower_nick chan lucky_shot output_method output_target} {
	lassign [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] 0] utimer_ID soaring_time shots_in_presence is_golden_duck remaining_HP total_HP already_signaled is_fake_duck fake_duck_author
	# Les d�g�ts varient selon le type de munitions utilis�es.
	if { [lindex [::DuckHunt::get_item_info $lower_nick $chan 3] 0] != -1 } {
		set damage 2
		# Texte : "*BANG*"
		set fire_sound [::msgcat::mc m427]
		# Texte : " \00303\[mun. AP\]\003"
		set ammo_effect_msg [::msgcat::mc m428]
	} elseif { [lindex [::DuckHunt::get_item_info $lower_nick $chan 4] 0] != -1 } {
		set damage 3
		# Texte : "*BOUM*"
		set fire_sound [::msgcat::mc m430]
		# Texte : " \00303\[mun. expl.\]\003"
		set ammo_effect_msg [::msgcat::mc m429]
	} else {
		set damage 1
		# Texte : "*BANG*"
		set fire_sound [::msgcat::mc m426]
		set ammo_effect_msg ""
	}
	set current_time [unixtime]
	# Il s'agit d'un super-canard.
	if { $is_golden_duck } {
		if { $remaining_HP == $total_HP } {
			set first_shot_on_golden_duck 1
		} else {
			set first_shot_on_golden_duck 0
		}
		incr remaining_HP -$damage
		# Le super-canard a �t� touch� mais n'est pas mort.
		if { $remaining_HP > 0 } {
			::tcl::dict::set ::DuckHunt::duck_sessions $chan [lreplace [::tcl::dict::get $::DuckHunt::duck_sessions $chan] 0 0 [list $utimer_ID $soaring_time $shots_in_presence $is_golden_duck $remaining_HP $total_HP $already_signaled]]
			if {
				($::DuckHunt::preferred_display_mode == 2)
				&& !($already_signaled)
			} then {
				# Message : "\00307\002* SUPER-CANARD D�TECT� *\002\003"
				::DuckHunt::display_output now PRIVMSG $chan [::msgcat::mc m259]
				::tcl::dict::set ::DuckHunt::duck_sessions $chan [lreplace [::tcl::dict::get $::DuckHunt::duck_sessions $chan] 0 0 [list $utimer_ID $soaring_time $shots_in_presence $is_golden_duck $remaining_HP $total_HP 1]]
			}
			if {
				($first_shot_on_golden_duck)
				&& ($::DuckHunt::preferred_display_mode != 2)
			} then {
				# Message : "%s > %s     Le canard a surv�cu ! Essaie encore.   \002\\_O<\002 \00304\[vie -%s\]\003  \00307\002* SUPER-CANARD D�TECT� *\002\003"
				::DuckHunt::display_output now $output_method $output_target [::msgcat::mc m249 $nick $fire_sound $damage]
			} else {
				# Message : "%s > %s     Le super-canard a surv�cu ! Essaie encore.   \002\\_O<\002 \00304\[vie -%s\]\003"
				::DuckHunt::display_output now $output_method $output_target [::msgcat::mc m271 $nick $fire_sound $damage]
			}
			if { $::DuckHunt::hunting_logs } {
				::DuckHunt::add_to_log $chan $current_time $nick - - - "hit_golden_duck" 0 -
			}
			return
		}
		set xp_won [expr {$::DuckHunt::base_xp_golden_duck * $total_HP}]
		if { $lucky_shot } {
			incr xp_won $::DuckHunt::xp_lucky_shot
		}
	} elseif { $is_fake_duck } {
		set xp_won 0
	} else {
		set xp_won $::DuckHunt::xp_duck
		if { $lucky_shot } {
			incr xp_won $::DuckHunt::xp_lucky_shot
		}
	}
	# Le joueur poss�de un tr�fle � 4 feuilles.
	lassign [::DuckHunt::get_item_info $lower_nick $chan "10"] item_index expiration_date bonus_xp
	if { $item_index != -1 } {
		incr xp_won $bonus_xp
		# Texte : " \00304\[tr�fle � 4 feuilles\]\003"
		set clover_effect_msg [::msgcat::mc m369]
	} else {
		set clover_effect_msg ""
	}
	set shooting_time [expr {[::tcl::clock::milliseconds] - $soaring_time}]
	::DuckHunt::terminate_duck_session $chan 1
	if { $is_golden_duck } {
		::DuckHunt::incr_data $lower_nick $chan "golden_ducks_shot" +1
	}
	::DuckHunt::incr_data $lower_nick $chan "ducks_shot" +1
	if { [::DuckHunt::get_data $lower_nick $chan "xp"] + $xp_won >= [lindex [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] 1] } {
		set level_gain 1
	} else {
		set level_gain 0
	}
	::DuckHunt::incr_data $lower_nick $chan "xp" $xp_won
	if {
		([expr {$shooting_time / 1000.0}] < [::DuckHunt::get_data $lower_nick $chan "best_time"])
		|| ([::DuckHunt::get_data $lower_nick $chan "best_time"] == -1)
	} then {
		::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "best_time" [format %.3f [expr {$shooting_time / 1000.0}]]
	}
	if { $level_gain } {
		# Message : " Tu deviens chasseur niveau %s (%s)."
		set lvlup [::msgcat::mc m25 [set level [lindex [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] 0]] [::DuckHunt::lvl2rank $level]]
	} else {
		set lvlup ""
	}
	set human_readable_shooting_time [::DuckHunt::adapt_time_resolution $shooting_time 1]
	# Le canard a-t-il dropp� quelque chose ?
	if { $::DuckHunt::drops_enabled } {
		set has_dropped_something 0
		set drop_msg ""
		foreach {drop} {junk_item ammo clip AP_ammo explosive_ammo grease sight infrared_detector silencer sunglasses ducks_detector four_leaf_clover 10_xp 20_xp 30_xp 40_xp 50_xp 100_xp} {
			if { [expr {int(rand()*1000) +1}] <= [set ::DuckHunt::chances_to_drop_[set drop]] } {
				set has_dropped_something 1
				# On s'arr�te car on ne veut qu'un seul drop.
				break
			}
		}
		if { $has_dropped_something } {
			lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] {} {} {} {} {} {} default_ammos_in_clip default_ammo_clips_per_day {} {} {} {}
			switch -- $drop {
				"junk_item" {
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves... "
					# Textes : 	"un canard en peluche." "un tas de plumes." "un canard en plastique pour le bain." "un chewing-gum m�chouill�." (...)
					set drop_msg "[::msgcat::mc m393 $nick][set loot [lindex [::msgcat::mc m394] [rand [llength [::msgcat::mc m394]]]]]"
				}
				"ammo" {
					# if { [::DuckHunt::get_data $lower_nick $chan "current_ammo_clip"] < $default_ammos_in_clip } {
					# 	::DuckHunt::incr_data $lower_nick $chan "current_ammo_clip" +1
					# }
					::DuckHunt::incr_data $lower_nick $chan "current_ammo_clip" +1
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves une balle suppl�mentaire !"
					set drop_msg [::msgcat::mc m395 $nick]
					# Texte : "balle suppl�mentaire"
					set loot [::msgcat::mc m407]
				}
				"clip" {
					# if { [::DuckHunt::get_data $lower_nick $chan "remaining_ammo_clips"] < $default_ammo_clips_per_day } {
					# 	::DuckHunt::incr_data $lower_nick $chan "remaining_ammo_clips" +1
					# }
					::DuckHunt::incr_data $lower_nick $chan "remaining_ammo_clips" +1					
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un chargeur suppl�mentaire !"
					set drop_msg [::msgcat::mc m396 $nick]
					# Texte : "chargeur suppl�mentaire"
					set loot [::msgcat::mc m408]
				}
				"AP_ammo" {
					if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "3"] 0]] != -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					# If the player already has explosive ammo, replace it.
					# if { [set item_index [lsearch -index 1 [::DuckHunt::get_data $lower_nick $chan "items"] "4"]] != -1 } {
					# 	::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					# }
					# ::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "3" "-"]]]
					# # Message : "%s > En fouillant les buissons autour du canard, tu trouves des munitions AP ! Les d�g�ts de ton arme sont doubl�s pendant 24h."
					# set drop_msg [::msgcat::mc m397 $nick]
					# # Texte : "munitions AP"
					# set loot [::msgcat::mc m409]
					if { [set item_index [lsearch -index 1 [::DuckHunt::get_data $lower_nick $chan "items"] "4"]] == -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "3" "-"]]]
						# Message : "%s > En fouillant les buissons autour du canard, tu trouves des munitions AP ! Les d�g�ts de ton arme sont doubl�s pendant 24h."
						set drop_msg [::msgcat::mc m397 $nick]
						# Texte : "munitions AP"
						set loot [::msgcat::mc m409]
					} else {
						set drop_msg "[::msgcat::mc m397 $nick].... You already have explosive_ammo nevermind"
					}
					
				}
				"explosive_ammo" {
					if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "4"] 0]] != -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					# Si le joueur poss�de d�j� des munitions explosives, on les remplace.
					if { [set item_index [lsearch -index 1 [::DuckHunt::get_data $lower_nick $chan "items"] "3"]] != -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "4" "-"]]]
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves des munitions explosives ! Les d�g�ts de ton arme sont tripl�s pendant 24h."
					set drop_msg [::msgcat::mc m398 $nick]
					# Texte : "munitions explosives"
					set loot [::msgcat::mc m410]
				}
				"grease" {
					if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "6"] 0]] != -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "6" "-"]]]
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves de la graisse pour ton arme ! Les risques d'enrayement de ton arme sont r�duits de moiti� pendant 24h."
					set drop_msg [::msgcat::mc m399 $nick]
					# Texte : "graisse"
					set loot [::msgcat::mc m411]
				}
				"sight" {
					if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "7"] 0]] != -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list "-" "7" "1"]]]
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves une lunette de vis�e pour ton arme ! La pr�cision de ton prochain tir augmente de (100 - pr�cision actuelle) / 3."
					set drop_msg [::msgcat::mc m400 $nick]
					# Texte : "lunette de vis�e"
					set loot [::msgcat::mc m412]
				}
				"infrared_detector" {
					if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "8"] 0]] != -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "8" "6"]]]
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un d�tecteur infrarouge ! La g�chette de ton arme sera bloqu�e s'il n'y a aucun canard dans les environs afin d'�viter le gaspillage de balles. Dure 24h pour 6 utilisations."
					set drop_msg [::msgcat::mc m401 $nick]
					# Texte : "d�tecteur infrarouge"
					set loot [::msgcat::mc m413]
				}
				"silencer" {
					if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "9"] 0]] != -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "9" "-"]]]
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un silencieux ! Tes tirs ne risquent plus d'effrayer les canards pendant 24h."
					set drop_msg [::msgcat::mc m402 $nick]
					# Texte : "silencieux"
					set loot [::msgcat::mc m414]
				}
				"sunglasses" {
					if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "11"] 0]] != -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "11" "-"]]]
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves des lunettes de soleil ! Tu es prot�g� contre l'�blouissement pendant 24h et en plus, c'est la classe."
					set drop_msg [::msgcat::mc m403 $nick]
					# Texte : "lunettes de soleil"
					set loot [::msgcat::mc m415]
				}
				"ducks_detector" {
					if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "22"] 0]] != -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list "-" "22" "1"]]]
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un d�tecteur de canards ! Tu seras averti par une notice lors de l'envol du prochain canard."
					set drop_msg [::msgcat::mc m404 $nick]
					# Texte : "d�tecteur de canards"
					set loot [::msgcat::mc m416]
				}
				"four_leaf_clover" {
					if { [set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "10"] 0]] != -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
					}
					set bonus_xp [expr {int(rand()*10) +1}]
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "10" $bonus_xp]]]
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un tr�fle � 4 feuilles +%s ! Chaque canard tu� te rapportera %s %s pendant 24h."
					# Textes "suppl�mentaire" "suppl�mentaires"
					set drop_msg [::msgcat::mc m405 $nick $bonus_xp $bonus_xp [::DuckHunt::plural $bonus_xp "[::msgcat::mc m285] [::msgcat::mc m424]" "[::msgcat::mc m286] [::msgcat::mc m425]"]]
					# Texte : "tr�fle � 4 feuilles +%s"
					set loot [::msgcat::mc m417 $bonus_xp]
				}
				"10_xp" {
					::DuckHunt::incr_data $lower_nick $chan "xp" 10
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un magazine de chasse. Sa lecture te rapporte %s %s !   \00303\[%s xp\]\003"
					set drop_msg [::msgcat::mc m406 $nick "10" [::msgcat::mc m286] "10"]
					# Texte : "magazine de chasse +%sxp"
					set loot [::msgcat::mc m418 10]
				}
				"20_xp" {
					::DuckHunt::incr_data $lower_nick $chan "xp" 20
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un magazine de chasse. Sa lecture te rapporte %s %s !   \00303\[%s xp\]\003"
					set drop_msg [::msgcat::mc m406 $nick "20" [::msgcat::mc m286] "20"]
					# Texte : "magazine de chasse +%sxp"
					set loot [::msgcat::mc m418 20]
				}
				"30_xp" {
					::DuckHunt::incr_data $lower_nick $chan "xp" 30
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un magazine de chasse. Sa lecture te rapporte %s %s !   \00303\[%s xp\]\003"
					set drop_msg [::msgcat::mc m406 $nick "30" [::msgcat::mc m286] "30"]
					# Texte : "magazine de chasse +%sxp"
					set loot [::msgcat::mc m418 30]
				}
				"40_xp" {
					::DuckHunt::incr_data $lower_nick $chan "xp" 40
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un magazine de chasse. Sa lecture te rapporte %s %s !   \00303\[%s xp\]\003"
					set drop_msg [::msgcat::mc m406 $nick "40" [::msgcat::mc m286] "40"]
					# Texte : "magazine de chasse +%sxp"
					set loot [::msgcat::mc m418 40]
				}
				"50_xp" {
					::DuckHunt::incr_data $lower_nick $chan "xp" 50
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un magazine de chasse. Sa lecture te rapporte %s %s !   \00303\[%s xp\]\003"
					set drop_msg [::msgcat::mc m406 $nick "50" [::msgcat::mc m286] "50"]
					# Texte : "magazine de chasse +%sxp"
					set loot [::msgcat::mc m418 50]
				}
				"100_xp" {
					::DuckHunt::incr_data $lower_nick $chan "xp" 100
					# Message : "%s > En fouillant les buissons autour du canard, tu trouves un magazine de chasse. Sa lecture te rapporte %s %s !   \00303\[%s xp\]\003"
					set drop_msg [::msgcat::mc m406 $nick "100" [::msgcat::mc m286] "100"]
					# Texte : "magazine de chasse +%sxp"
					set loot [::msgcat::mc m418 100]
				}
			}
		}
	}
	if { !$lucky_shot } {
		if { ![::tcl::dict::exists $::DuckHunt::duck_sessions $chan] } {
			if { $is_golden_duck } {
				# Message : "%s > %s     Tu as eu le super-canard en %s, ce qui te fait un total de %s %s (dont %s %s) sur %s.%s     \002\\_X<\002   \00314*COUAC*\003   \00303\[%s xp\]\003"
				# Textes : "canard" "canards"
				::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m250 $nick $fire_sound $human_readable_shooting_time [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::msgcat::mc m27] [::msgcat::mc m28]] [::DuckHunt::get_data $lower_nick $chan "golden_ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "golden_ducks_shot"] [::msgcat::mc m274] [::msgcat::mc m275]] $chan $lvlup $xp_won]${clover_effect_msg}$ammo_effect_msg"
			} elseif { $is_fake_duck } {
				# Message : "%s > %s     Tu as eu le canard m�canique en %s. Ce faux canard vous a �t� offert par %s.     \002\\_X<\002   \00314*BZZzZzt*\003"
				::DuckHunt::display_output quick PRIVMSG $chan [::msgcat::mc m356 $nick $fire_sound $human_readable_shooting_time $fake_duck_author]
			} else {
				# Message : "%s > %s     Tu l'as eu en %s, ce qui te fait un total de %s %s sur %s.%s     \002\\_X<\002   \00314*COUAC*\003   \00303\[%s xp\]\003"
				::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m26 $nick $fire_sound $human_readable_shooting_time [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::msgcat::mc m27] [::msgcat::mc m28]] $chan $lvlup $xp_won]$clover_effect_msg"
			}
			if { $::DuckHunt::gun_hand_back_mode == 2 } {
				::DuckHunt::hand_back_weapons $chan
			}
		} else {
			if { $is_golden_duck } {
				# Message : "%s > %s     Tu as eu un super-canard en %s, ce qui te fait un total de %s %s (dont %s %s) sur %s.%s     \002\\_X<\002   \00314*COUAC*\003   \00303\[%s xp\]\003"
				::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m251 $nick $fire_sound $human_readable_shooting_time [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::msgcat::mc m27] [::msgcat::mc m28]] [::DuckHunt::get_data $lower_nick $chan "golden_ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "golden_ducks_shot"] [::msgcat::mc m274] [::msgcat::mc m275]] $chan $lvlup $xp_won]${clover_effect_msg}$ammo_effect_msg"
			} elseif { $is_fake_duck } {
				# Message : "%s > %s     Tu as eu un canard m�canique en %s. Ce faux canard vous a �t� offert par %s.     \002\\_X<\002   \00314*BZZzZzt*\003"
				::DuckHunt::display_output quick PRIVMSG $chan [::msgcat::mc m357 $nick $fire_sound $human_readable_shooting_time $fake_duck_author]
			} else {
				# Message : "%s > %s     Tu as eu un des canards en %s, ce qui te fait un total de %s %s sur %s.%s     \002\\_X<\002   \00314*COUAC*\003   \00303\[%s xp\]\003"
				::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m155 $nick $fire_sound $human_readable_shooting_time [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::msgcat::mc m27] [::msgcat::mc m28]] $chan $lvlup $xp_won]$clover_effect_msg"
			}
		}
		if { $::DuckHunt::hunting_logs } {
			if { $is_golden_duck } {
				::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - $human_readable_shooting_time "shoot_golden_duck" 0 -
			} else {
				::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - $human_readable_shooting_time "shoot" 0 -
			}
		}
	} else {
		if { ![::tcl::dict::exists $::DuckHunt::duck_sessions $chan] } {
			if { $is_golden_duck } {
				# Message : "%s > %s     Tu as eu le super-canard par ricochet en %s, ce qui te fait un total de %s %s (dont %s %s) sur %s.%s     \002\\_X<\002   \00314*COUAC*\003   \00303\[%s xp\] \[lucky shot\]\003"
				::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m252 $nick $fire_sound $human_readable_shooting_time [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::msgcat::mc m27] [::msgcat::mc m28]] [::DuckHunt::get_data $lower_nick $chan "golden_ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "golden_ducks_shot"] [::msgcat::mc m274] [::msgcat::mc m275]] $chan $lvlup $xp_won]${clover_effect_msg}$ammo_effect_msg"
			} elseif { $is_fake_duck } {
				# Message : "%s > %s     Tu as eu le canard m�canique par ricochet en %s. Ce faux canard vous a �t� offert par %s.     \002\\_X<\002   \00314*BZZzZzt*\003"
				::DuckHunt::display_output quick PRIVMSG $chan [::msgcat::mc m358 $nick $fire_sound $human_readable_shooting_time $fake_duck_author]
			} else {
				# Message : "%s > %s     Tu l'as eu par ricochet en %s, ce qui te fait un total de %s %s sur %s.%s     \002\\_X<\002   \00314*COUAC*\003   \00303\[%s xp\] \[lucky shot\]\003"
				::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m29 $nick $fire_sound $human_readable_shooting_time [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::msgcat::mc m27] [::msgcat::mc m28]] $chan $lvlup $xp_won]$clover_effect_msg"
			}
			if { $::DuckHunt::gun_hand_back_mode == 2 } {
				::DuckHunt::hand_back_weapons $chan
			}
		} else {
			if { $is_golden_duck } {
				# Message : "%s > %s     Tu as eu un super-canard par ricochet en %s, ce qui te fait un total de %s %s (dont %s %s) sur %s.%s     \002\\_X<\002   \00314*COUAC*\003   \00303\[%s xp\] \[lucky shot\]\003"
				::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m253 $nick $fire_sound $human_readable_shooting_time [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::msgcat::mc m27] [::msgcat::mc m28]] [::DuckHunt::get_data $lower_nick $chan "golden_ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "golden_ducks_shot"] [::msgcat::mc m274] [::msgcat::mc m275]] $chan $lvlup $xp_won]${clover_effect_msg}$ammo_effect_msg"
			} elseif { $is_fake_duck } {
				# Message : "%s > %s     Tu as eu un canard m�canique par ricochet en %s. Ce faux canard vous a �t� offert par %s.     \002\\_X<\002   \00314*BZZzZzt*\003"
				::DuckHunt::display_output quick PRIVMSG $chan [::msgcat::mc m359 $nick $fire_sound $human_readable_shooting_time $fake_duck_author]
			} else {
				# Message : "%s > %s     Tu as eu un des canards par ricochet en %s, ce qui te fait un total de %s %s sur %s.%s     \002\\_X<\002   \00314*COUAC*\003   \00303\[%s xp\] \[lucky shot\]\003"
				::DuckHunt::display_output quick PRIVMSG $chan "[::msgcat::mc m156 $nick $fire_sound $human_readable_shooting_time [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_nick $chan "ducks_shot"] [::msgcat::mc m27] [::msgcat::mc m28]] $chan $lvlup $xp_won]$clover_effect_msg"
			}
		}
		if { $::DuckHunt::hunting_logs } {
			if { $is_golden_duck } {
				::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - $human_readable_shooting_time "dead_golden_duck" 0 -
			} elseif { $is_fake_duck } {
				::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - $human_readable_shooting_time "dead_fake_duck" 0 -
			} else {
				::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - $human_readable_shooting_time "dead_duck" 0 -
			}
		}
	}
	if { $has_dropped_something } {
		::DuckHunt::display_output help PRIVMSG $chan $drop_msg
		if { $::DuckHunt::hunting_logs } {
			::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "drop" 0 $loot
		}
	}
	if { $::DuckHunt::voice_when_duck_shot } {
		pushmode $chan +v $nick
	}
}

 ###############################################################################
### !reload : Recharge ou d�coince son arme.
 ###############################################################################
proc ::DuckHunt::reload_gun {nick host hand chan arg} {

	set lower_nick [::tcl::string::tolower $nick]

	if { [matchattr $hand $::DuckHunt::launch_auth $chan] } then {
		variable canNickFlood 0
	} else {
		 variable canNickFlood $::DuckHunt::antiflood
	}
	
	if {
		(![channel get $chan DuckHunt])
		|| ($hand in $::DuckHunt::blacklisted_handles)
		|| (($canNickFlood == 1)
		&& (([::DuckHunt::antiflood $nick $chan "nick" $::DuckHunt::reload_cmd $::DuckHunt::flood_reload])
		|| ([::DuckHunt::antiflood $nick $chan "chan" "*" $::DuckHunt::flood_global])))
	} then {
		return
	} else {
		set lower_nick [::tcl::string::tolower $nick]
		if { $::DuckHunt::preferred_display_mode == 1 } {
			set output_method "PRIVMSG"
			set output_target $chan
		} else {
			set output_method "NOTICE"
			set output_target $nick
		}
		::DuckHunt::read_database
		::DuckHunt::ckeck_for_pending_rename $chan $nick $lower_nick [md5 "$chan,$lower_nick"]
		# Le joueur n'a pas de stats dans la db.
		if {
			!([::tcl::dict::exists $::DuckHunt::player_data $chan])
			|| !([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_nick])
		} then {
			lassign [::DuckHunt::get_level_and_grantings 1] {} {} {} {} {} {} ammos_per_clip ammo_clips {} {} {}
			# Message : "%s > Ton arme n'a pas besoin d'�tre recharg�e. \00314|\003 Munitions dans l'arme : \002%s/%s\002 \00314|\003 Chargeurs restants : \002%s/%s\002"
			::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m204 $nick $ammos_per_clip $ammos_per_clip $ammo_clips $ammo_clips]
		# Le joueur a des stats dans la db.
		} else {
			set current_time [unixtime]
			::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "last_activity" $current_time
			# Le joueur n'a pas d'arme (arme confisqu�e).
			if { [::DuckHunt::get_data $lower_nick $chan "gun"] <= 0 } {
				# Message : "%s > Tu n'es pas arm�."
				::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m5 $nick]
			# Le joueur a une arme.
			} else {
				if { [::tcl::dict::exists $::DuckHunt::duck_sessions $chan] } {
					# On note le cumul du temps de r�action du joueur.
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "cumul_reflex_time" [expr {[::DuckHunt::get_data $lower_nick $chan "cumul_reflex_time"] + [expr {[::tcl::clock::milliseconds] - [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] 0 1]}]}]
				}
				lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] {} {} {} {} {} {} ammos_per_clip ammo_clips {} {} {}
				# L'arme est enray�e.
				if { [::DuckHunt::get_data $lower_nick $chan "jammed"] } {
					# L'arme n'est pas charg�e et les munitions par chargeur ne sont pas
					# illimit�es.
					if {
						!([::DuckHunt::get_data $lower_nick $chan "current_ammo_clip"])
						&& !($::DuckHunt::unlimited_ammo_per_clip)
					} then {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "jammed" 0
						# Le joueur n'a plus de chargeurs en r�serve et le nombre de chargeurs
						# n'est pas illimit�.
						if {
							(![::DuckHunt::get_data $lower_nick $chan "remaining_ammo_clips"])
							&& !($::DuckHunt::unlimited_ammo_clips)
						} then {
							# Message : "%s > \00314*Crr..CLIC*\003     Tu d�coinces ton arme mais tu es � court de munitions. \00314|\003 Mun. : \002%s\002 \00314|\003 Charg. : \002%s\002"
							::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m31 $nick [::DuckHunt::display_ammo $lower_nick $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_nick $chan $ammo_clips]]
							if { $::DuckHunt::hunting_logs } {
								::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "unjam" 0 -
							}
						# Lejoueur a encore des chargeurs en r�serve.
						} else {
							::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "current_ammo_clip" $ammos_per_clip
							if { !$::DuckHunt::unlimited_ammo_clips } {
								::DuckHunt::incr_data $lower_nick $chan "remaining_ammo_clips" -1
							}
							# Message : "%s > \00314*Crr..CLIC*\003     Tu d�coinces et recharges ton arme. \00314|\003 Mun. : \002%s\002 \00314|\003 Charg. : \002%s\002"
							::DuckHunt::display_output quick $output_method $output_target [::msgcat::mc m32 $nick [::DuckHunt::display_ammo $lower_nick $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_nick $chan $ammo_clips]]
							if { $::DuckHunt::hunting_logs } {
								::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "unjam_reload" 0 -
							}
						}
					# L'arme est d�j� charg�e.
					} else {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "jammed" 0
						# Message : "%s > \00314*Crr..CLIC*\003     Tu d�coinces ton arme. \00314|\003 Mun. : \002%s\002 \00314|\003 Charg. : \002%s\002"
						::DuckHunt::display_output quick $output_method $output_target [::msgcat::mc m33 $nick [::DuckHunt::display_ammo $lower_nick $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_nick $chan $ammo_clips]]
						if { $::DuckHunt::hunting_logs } {
							::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "unjam" 0 -
						}
					}
				# L'arme n'est pas charg�e et les munitions par chargeur ne sont pas
				# illimit�es.
				} elseif {
					!([::DuckHunt::get_data $lower_nick $chan "current_ammo_clip"])
					&& !($::DuckHunt::unlimited_ammo_per_clip)
				} then {
					# Le joueur n'a plus de chargeurs en r�serve et le nombre de chargeurs
					# n'est pas illimit�.
					if {
						!([::DuckHunt::get_data $lower_nick $chan "remaining_ammo_clips"])
						&& !($::DuckHunt::unlimited_ammo_clips)
					} then {
						# Message : "%s > Tu es � court de munitions. \00314|\003 Mun. : \002%s\002 \00314|\003 Charg. : \002%s\002"
						::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m34 $nick [::DuckHunt::display_ammo $lower_nick $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_nick $chan $ammo_clips]]
					# Le joueur a encore des chargeurs en r�serve.
					} else {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "current_ammo_clip" $ammos_per_clip
						if { !$::DuckHunt::unlimited_ammo_clips } {
							::DuckHunt::incr_data $lower_nick $chan "remaining_ammo_clips" -1
						}
						# Message : "%s > \00314*CLAC CLAC*\003     Tu recharges. \00314|\003 Mun. : \002%s\002 \00314|\003 Charg. : \002%s\002"
						::DuckHunt::display_output quick $output_method $output_target [::msgcat::mc m35 $nick [::DuckHunt::display_ammo $lower_nick $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_nick $chan $ammo_clips]]
						if { $::DuckHunt::hunting_logs } {
							::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "reload" 0 -
						}
					}
				# L'arme n'a pas besoin d'�tre recharg�e ou d�coinc�e.
				} else {
					# Message : "%s > Ton arme n'a pas besoin d'�tre recharg�e. \00314|\003 Munitions dans l'arme : \002%s\002 \00314|\003 Chargeurs restants : \002%s\002"
					::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m36 $nick [::DuckHunt::display_ammo $lower_nick $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_nick $chan $ammo_clips]]
				}
				::DuckHunt::write_database
			}
		}
		::DuckHunt::purge_db_from_memory
	}
	return
}

 ###############################################################################
### !lastduck : Affiche l'heure du dernier envol de canard.
 ###############################################################################
proc ::DuckHunt::pub_show_last_duck {nick host hand chan arg} {

	set lower_nick [::tcl::string::tolower $nick]

	if { [matchattr $hand $::DuckHunt::launch_auth $chan] } then {
		variable canNickFlood 0
	} else {
		 variable canNickFlood $::DuckHunt::antiflood
	}
	
	if {
		(![channel get $chan DuckHunt])
		|| ($hand in $::DuckHunt::blacklisted_handles)
		|| (($canNickFlood == 1)
		&& (([::DuckHunt::antiflood $nick $chan "nick" $::DuckHunt::lastduck_pub_cmd $::DuckHunt::flood_lastduck])
		|| ([::DuckHunt::antiflood $nick $chan "chan" "*" $::DuckHunt::flood_global])))
	} then {
		return
	} else {
		if { $::DuckHunt::preferred_display_mode == 1 } {
			set output_method "PRIVMSG"
			set output_target $chan
		} else {
			set output_method "NOTICE"
			set output_target $nick
		}
		if { [channel get $chan DuckHunt-LastDuck] eq "" } {
			# Message : "Aucun envol de canard n'a �t� enregistr� sur %s."
			::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m146 $chan]
		} else {
			# Message : "Le dernier canard a �t� aper�u il y a %s."
			::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m144 [::DuckHunt::adapt_time_resolution [expr {([unixtime] - [channel get $chan DuckHunt-LastDuck]) * 1000}] 0]]
		}
	}
}
proc ::DuckHunt::msg_show_last_duck {nick host hand arg} {
	if {
		([matchattr $hand $::DuckHunt::lastduck_msg_auth [::DuckHunt::fix_chan_case [set chan [lindex [split $arg] 0]]]])
		&& !($hand in $::DuckHunt::blacklisted_handles)
	} then {
		if {
			([set arg [::tcl::string::trim $arg]] eq "")
			|| ([llength [set arg [split $arg]]] != 1)
		} then {
			# Message : "\037Syntaxe\037 : \002%s\002 \00314<\003chan\00314>\003 \00307|\003 Affiche le temps �coul� depuis le dernier envol de canard sur le chan sp�cifi�."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m145 $::DuckHunt::lastduck_msg_cmd]
		} else {
			if { ![validchan $chan] } {
				# Message : "\00304:::\003 Erreur : %s n'est pas un chan valide."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m75 $chan]
			} elseif { ![channel get $chan DuckHunt] } {
				# Message : "\00304:::\003 Erreur : %s n'est pas activ� sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m76 $::DuckHunt::scriptname $chan]
			} elseif { [channel get $chan DuckHunt-LastDuck] eq "" } {
				# Message : "Aucun envol de canard n'a �t� enregistr� sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m146 $chan]
			} else {
				# Message : "Le dernier canard sur %s a �t� aper�u il y a %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m147 $chan [::DuckHunt::adapt_time_resolution [expr {([unixtime] - [channel get $chan DuckHunt-LastDuck]) * 1000}] 0]]
			}
		}
	}
}

 ###############################################################################
### !topduck [chan] : 
 ###############################################################################
proc ::DuckHunt::display_topDuck {nick host hand chan arg} {

	set lower_nick [::tcl::string::tolower $nick]

	if { [matchattr $hand $::DuckHunt::launch_auth $chan] } then {
		variable canNickFlood 0
	} else {
		 variable canNickFlood $::DuckHunt::antiflood
	}
	
	if {
		(![channel get $chan DuckHunt])
		|| ($hand in $::DuckHunt::blacklisted_handles)
		|| (($canNickFlood == 1)
		&& (([::DuckHunt::antiflood $nick $chan "nick" $::DuckHunt::topDuck_cmd $::DuckHunt::flood_stats])
		|| ([::DuckHunt::antiflood $nick $chan "chan" "*" $::DuckHunt::flood_global])))
	} then {
		return
	} else {
		set targetChan $chan
		if { [set arg [::tcl::string::trim $arg]] ne "" } {
			set targetChan [::tcl::string::tolower $arg]
		} 
        
        ::DuckHunt::read_database

        set hunters_And_Xp {}
        set hunters_list [lsort [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $targetChan]]]

		if { $hunters_list ne "" } {
            set num_hunters [llength $hunters_list]

            set x 0
			foreach hunter $hunters_list {
                set hunterXP [::DuckHunt::get_data $hunter $targetChan "xp"]
				lappend hunters_And_Xp "\00307$hunter\003 with $hunterXP xp"                
            }

            set TopHunters {}
            set hunters_And_Xp_Sort [lsort -decreasing -integer -index 2 $hunters_And_Xp]
            
			set x 0
             
			::DuckHunt::display_output loglev - -  "Get top 5"              
			while {$x<5} {		
				if { $x < 4 && $x < $num_hunters-1 } {
					lappend TopHunters "[lindex $hunters_And_Xp_Sort $x] \00314|\003"
				} else {
					lappend TopHunters "[lindex $hunters_And_Xp_Sort $x]"
				}
				incr x
			}
        }

		if {$TopHunters ne ""} {
			if { $::DuckHunt::preferred_display_mode == 1 } {
				set output_method "PRIVMSG"
				set output_target $chan
			} else {
				set output_method "NOTICE"
				set output_target $nick
			}
			
			putloglev o * "The top duck(s) are: [join $TopHunters]"
			#::DuckHunt::display_output help $output_method $output_target  "Hunting stats for $lower_target: [::msgcat::mc m42 [::DuckHunt::display_ammo $lower_target $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_target $chan $ammo_clips] $jammed $jammed_weapons $confiscated $confiscated_weapons [::DuckHunt::colorize_value $xp] $level $rank $xp_to_lvlup [::DuckHunt::plural [expr {$required_xp - $xp}] [::msgcat::mc m43] [::msgcat::mc m44]] $karma $accuracy $accuracy_modifier $effective_accuracy $reliability $reliability_modifier $defense $deflection $best_time $average_reflex_time $ducks_shot [::DuckHunt::plural $ducks_shot [::msgcat::mc m45] [::msgcat::mc m46]] $golden_ducks_shot [::DuckHunt::plural $golden_ducks_shot [::msgcat::mc m274] [::msgcat::mc m275]] $missed_shots [::DuckHunt::plural $missed_shots [::msgcat::mc m47] [::msgcat::mc m48]] $humans_shot [::DuckHunt::plural $humans_shot [::msgcat::mc m49] [::msgcat::mc m50]] $empty_shots [::DuckHunt::plural $empty_shots [::msgcat::mc m51] [::msgcat::mc m52]] $wild_shots [::DuckHunt::plural $wild_shots [::msgcat::mc m53] [::msgcat::mc m54]] $total_fired_ammo [::DuckHunt::plural $total_fired_ammo [::msgcat::mc m55] [::msgcat::mc m56]] $bullets_received [::DuckHunt::plural $bullets_received [::msgcat::mc m57] [::msgcat::mc m58]] $deaths [::DuckHunt::plural $deaths [::msgcat::mc m59] [::msgcat::mc m60]] $deflected_bullets [::DuckHunt::plural $deflected_bullets [::msgcat::mc m61] [::msgcat::mc m62]] $neutralized_bullets [::DuckHunt::plural $neutralized_bullets [::msgcat::mc m63] [::msgcat::mc m64]]]${items_list}$effects_list "
			::DuckHunt::display_output help $output_method $output_target  "The top duck(s) are: [join $TopHunters]"
		}
        ::DuckHunt::purge_db_from_memory

    }
}

 ###############################################################################
### !help [chan] : 
 ###############################################################################
proc ::DuckHunt::display_duckHelp {nick host hand chan arg} {

	set lower_nick [::tcl::string::tolower $nick]

	if { [matchattr $hand $::DuckHunt::launch_auth $chan] } then {
		variable canNickFlood 0
	} else {
		 variable canNickFlood $::DuckHunt::antiflood
	}
	
	if {
		(![channel get $chan DuckHunt])
		|| ($hand in $::DuckHunt::blacklisted_handles)
		|| (($canNickFlood == 1)
		&& (([::DuckHunt::antiflood $nick $chan "nick" $::DuckHunt::duckHelp_cmd $::DuckHunt::flood_stats])
		|| ([::DuckHunt::antiflood $nick $chan "chan" "*" $::DuckHunt::flood_global])))
	} then {
		return
	} else {        
		
		if { $::DuckHunt::preferred_display_mode == 1 } {
			set output_method "PRIVMSG"
			set output_target $chan
		} else {
			set output_method "NOTICE"
			set output_target $nick
		}
		
		set helpMsg "\00314\[Duck Hunt commands\]\003 !help, !bang, !reload, !shop, !topduck, !duckstats, !lastduck"
		
		#::DuckHunt::display_output help $output_method $output_target  "Hunting stats for $lower_target: [::msgcat::mc m42 [::DuckHunt::display_ammo $lower_target $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_target $chan $ammo_clips] $jammed $jammed_weapons $confiscated $confiscated_weapons [::DuckHunt::colorize_value $xp] $level $rank $xp_to_lvlup [::DuckHunt::plural [expr {$required_xp - $xp}] [::msgcat::mc m43] [::msgcat::mc m44]] $karma $accuracy $accuracy_modifier $effective_accuracy $reliability $reliability_modifier $defense $deflection $best_time $average_reflex_time $ducks_shot [::DuckHunt::plural $ducks_shot [::msgcat::mc m45] [::msgcat::mc m46]] $golden_ducks_shot [::DuckHunt::plural $golden_ducks_shot [::msgcat::mc m274] [::msgcat::mc m275]] $missed_shots [::DuckHunt::plural $missed_shots [::msgcat::mc m47] [::msgcat::mc m48]] $humans_shot [::DuckHunt::plural $humans_shot [::msgcat::mc m49] [::msgcat::mc m50]] $empty_shots [::DuckHunt::plural $empty_shots [::msgcat::mc m51] [::msgcat::mc m52]] $wild_shots [::DuckHunt::plural $wild_shots [::msgcat::mc m53] [::msgcat::mc m54]] $total_fired_ammo [::DuckHunt::plural $total_fired_ammo [::msgcat::mc m55] [::msgcat::mc m56]] $bullets_received [::DuckHunt::plural $bullets_received [::msgcat::mc m57] [::msgcat::mc m58]] $deaths [::DuckHunt::plural $deaths [::msgcat::mc m59] [::msgcat::mc m60]] $deflected_bullets [::DuckHunt::plural $deflected_bullets [::msgcat::mc m61] [::msgcat::mc m62]] $neutralized_bullets [::DuckHunt::plural $neutralized_bullets [::msgcat::mc m63] [::msgcat::mc m64]]]${items_list}$effects_list "
		::DuckHunt::display_output help $output_method $output_target  $helpMsg
	
	}

    
}

 ###############################################################################
### !duckstats [nick] : Affiche ses stats ou celles d'un autre.
 ###############################################################################
proc ::DuckHunt::display_stats {nick host hand chan arg} {

	set lower_nick [::tcl::string::tolower $nick]

	if { [matchattr $hand $::DuckHunt::launch_auth $chan] } then {
		variable canNickFlood 0
	} else {
		 variable canNickFlood $::DuckHunt::antiflood
	}
	
	if {
		(![channel get $chan DuckHunt])
		|| ($hand in $::DuckHunt::blacklisted_handles)
		|| (($canNickFlood == 1)
		&& (([::DuckHunt::antiflood $nick $chan "nick" $::DuckHunt::stat_cmd $::DuckHunt::flood_stats])
		|| ([::DuckHunt::antiflood $nick $chan "chan" "*" $::DuckHunt::flood_global])))
	} then {
		return
	} else {
		if { [set arg [::tcl::string::trim $arg]] ne "" } {
			set target $arg
			set lower_target [::tcl::string::tolower $arg]
		} else {
			set target $nick
			set lower_target [::tcl::string::tolower $nick]
		}
		::DuckHunt::read_database
		::DuckHunt::ckeck_for_pending_rename $chan $target $lower_target [md5 "$chan,$lower_target"]
		foreach varname {gun jammed current_ammo_clip remaining_ammo_clips xp ducks_shot golden_ducks_shot missed_shots empty_shots humans_shot wild_shots bullets_received deflected_bullets deaths confiscated_weapons jammed_weapons best_time cumul_reflex_time items} {
			set $varname [::DuckHunt::get_data $lower_target $chan $varname]
		}
		# Aucune entr�e n'existe � ce nom dans la base de donn�es, on prend les
		# valeurs par d�faut.
		if {
			!([::tcl::dict::exists $::DuckHunt::player_data $chan])
			|| !([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_target])
		} then {
			lassign [::DuckHunt::get_level_and_grantings 0] level required_xp accuracy deflection defense jamming ammos_per_clip ammo_clips {} {} {}
		# Il existe une entr�e pour ce joueur dans la base de donn�es.
		} else {
			lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_target $chan "xp"]] level required_xp accuracy deflection defense jamming ammos_per_clip ammo_clips {} {} {}
		}
		set rank [::DuckHunt::lvl2rank $level]
		set neutralized_bullets [expr {$bullets_received - $deaths - $deflected_bullets}]
		set reliability [expr {100 - $jamming}]
		# Le joueur a graiss� son arme.
		if { [lindex [::DuckHunt::get_item_info $lower_target $chan "6"] 0] != -1 } {
			append reliability_modifier "\00303+[expr {int((100 - $reliability) / 2)}]%\003"
		} else {
			append reliability_modifier ""
		}
		# Le joueur a du sable dans son arme.
		if { [lindex [::DuckHunt::get_item_info $lower_target $chan "15"] 0] != -1 } {
			append reliability_modifier "\00304-[expr {int($reliability / 2)}]%\003"
		} else {
			append reliability_modifier ""
		}
		if { $best_time == -1 } {
			set best_time "-"
		} else {
			set best_time [::DuckHunt::adapt_time_resolution [::tcl::string::map {"." ""} $best_time] 1]
		}
		if { $ducks_shot != 0 } {
			set average_reflex_time [::DuckHunt::adapt_time_resolution [::tcl::string::map {"." ""} [format "%.3f" [expr {($cumul_reflex_time / 1000.0) / $ducks_shot}]]] 1]
		} else {
			set average_reflex_time "-"
		}
		if { $jammed == 1 } {
			# Texte : "\00304oui\003"
			set jammed [::msgcat::mc m37]
		} else {
			# Texte : "non"
			set jammed [::msgcat::mc m38]
		}
		if { $gun <= 0 } {
			# Texte : "\00304oui\003"
			set confiscated [::msgcat::mc m37]
		} else {
			# Texte : "non"
			set confiscated [::msgcat::mc m38]
		}
		set xp_to_lvlup [expr {$required_xp - $xp}]
		set total_fired_ammo [expr {$ducks_shot + $missed_shots}]
		if { $total_fired_ammo != 0 } {
			set effective_accuracy "[expr {(100 * $ducks_shot) / $total_fired_ammo}]%"
		} else {
			set effective_accuracy "-"
		}
		# Le joueur est �bloui.
		if { [set item_index [lindex [::DuckHunt::get_item_info $lower_target $chan "14"] 0]] != -1 } {
			append accuracy_modifier "\00304-[expr {int($accuracy / 2)}]%\003"
		} else {
			append accuracy_modifier ""
		}
		# Le joueur a install� une lunette de vis�e sur son arme.
		if { [set item_index [lindex [::DuckHunt::get_item_info $lower_target $chan "7"] 0]] != -1 } {
			append accuracy_modifier "\00303+[expr {int((100 - $accuracy) / 3)}]%\003"
		} else {
			append accuracy_modifier ""
		}
		set items_list ""
		set effects_list ""
		# Texts: "Mun. AP" "Mun. expl." "Grease" "Riflescope" "Infrared Detector" "Silencer" "4 Leaf Clover" "Sunglasses" "Life Ass." "Civilian Resp. Ass." ducks" "Dazzled" "Sand" "Drenched" "Hooded"
		set item_names [list 3 [::msgcat::mc m370] 4 [::msgcat::mc m371] 6 [::msgcat::mc m372] 7 [::msgcat::mc m373] 8 [::msgcat::mc m374] 9 [::msgcat::mc m375] 10 [::msgcat::mc m376] 11 [::msgcat::mc m377] 14 [::msgcat::mc m381] 15 [::msgcat::mc m382] 16 [::msgcat::mc m383] 17 [::msgcat::mc m384] 18 [::msgcat::mc m378] 19 [::msgcat::mc m379] 22 [::msgcat::mc m380]]
		foreach item $items {
			if { [set item_id [lindex $item 1]] in {3 4 6 7 8 9 10 11 18 19 22} } {
				lappend items_list [::tcl::dict::get $item_names $item_id]
			} elseif { $item_id in {14 15 16 17} } {
				lappend effects_list [::tcl::dict::get $item_names $item_id]
			}
		}
		if { $items_list ne "" } {
			# Texte : "\00307\002  \[\037Inventaire\037\]\002\003  %s"
			set items_list [::msgcat::mc m385 [join $items_list " \00314/\003 "]]
		}
		if { $effects_list ne "" } {
			# Texte : "\00307\002  \[\037Effets\037\]\002\003  %s"
			set effects_list [::msgcat::mc m386 [join $effects_list " \00314/\003 "]]
		}
		set karma [::DuckHunt::calculate_karma $wild_shots $humans_shot $ducks_shot 0]
		# Message : "\00307\002\[\037Arme\037\]\002\003  mun. : %s \00307|\003 charg. : %s \00307|\003 enray. : %s (%s fois) \00307|\003 confisq. : %s (%s fois)\00307\002  \[\037Profil\037\]\002\003  %s XP \00307|\003 lvl %s (%s) / encore %s %s d'XP avant lvl sup. \00307|\003 karma : %s  \00307\002\[\037Stats\037\]\002\003  pr�cision th�or. : %s%%%s \00307|\003 effic. tirs : %s \00307|\003 fiabilit� arme : %s%%%s \00307|\003 armure : %s%% \00307|\003 d�flexion : %s%%\n\00307\002\[\037Tableau de chasse\037\]\002\003  meill. tps. : %s \00307|\003 tps. r�act. moyen : %s \00307|\003 %s %s (dont %s %s) \00307|\003 %s %s \00307|\003 %s %s \00307|\003 %s %s \00307|\003 %s %s \00307|\003 %s %s  \00307\002\[\037Accidents\037\]\002\003  re�u %s %s dont %s %s, %s %s et %s %s. "
		# Textes : "pt" "pts" "canard" "canards" "tir manqu�" "tirs manqu�s" "accident" "accidents" "tir � vide" "tirs � vide" "tir sauvage" "tirs sauvages" "mun. utilis." "mun. utilis." "balle perdue" "balles perdues" "l�thale" "l�thales" "a ricoch�" "ont ricoch�" "a �t� encaiss�e" "ont �t� encaiss�es"
		if { $::DuckHunt::preferred_display_mode == 1 } {
			set output_method "PRIVMSG"
			set output_target $chan
		} else {
			set output_method "NOTICE"
			set output_target $nick
		}

		# set output_method "PRIVMSG"
		# set output_target $nick		

		#::DuckHunt::display_output help $output_method $output_target  "Hunting stats for $lower_target: [::msgcat::mc m42 [::DuckHunt::display_ammo $lower_target $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_target $chan $ammo_clips] $jammed $jammed_weapons $confiscated $confiscated_weapons [::DuckHunt::colorize_value $xp] $level $rank $xp_to_lvlup [::DuckHunt::plural [expr {$required_xp - $xp}] [::msgcat::mc m43] [::msgcat::mc m44]] $karma $accuracy $accuracy_modifier $effective_accuracy $reliability $reliability_modifier $defense $deflection $best_time $average_reflex_time $ducks_shot [::DuckHunt::plural $ducks_shot [::msgcat::mc m45] [::msgcat::mc m46]] $golden_ducks_shot [::DuckHunt::plural $golden_ducks_shot [::msgcat::mc m274] [::msgcat::mc m275]] $missed_shots [::DuckHunt::plural $missed_shots [::msgcat::mc m47] [::msgcat::mc m48]] $humans_shot [::DuckHunt::plural $humans_shot [::msgcat::mc m49] [::msgcat::mc m50]] $empty_shots [::DuckHunt::plural $empty_shots [::msgcat::mc m51] [::msgcat::mc m52]] $wild_shots [::DuckHunt::plural $wild_shots [::msgcat::mc m53] [::msgcat::mc m54]] $total_fired_ammo [::DuckHunt::plural $total_fired_ammo [::msgcat::mc m55] [::msgcat::mc m56]] $bullets_received [::DuckHunt::plural $bullets_received [::msgcat::mc m57] [::msgcat::mc m58]] $deaths [::DuckHunt::plural $deaths [::msgcat::mc m59] [::msgcat::mc m60]] $deflected_bullets [::DuckHunt::plural $deflected_bullets [::msgcat::mc m61] [::msgcat::mc m62]] $neutralized_bullets [::DuckHunt::plural $neutralized_bullets [::msgcat::mc m63] [::msgcat::mc m64]]]${items_list}$effects_list "
		::DuckHunt::display_output help $output_method $output_target  "Hunting stats for $lower_target: [::msgcat::mc m42 [::DuckHunt::display_ammo $lower_target $chan $ammos_per_clip] [::DuckHunt::display_clips $lower_target $chan $ammo_clips] $jammed $jammed_weapons $confiscated $confiscated_weapons [::DuckHunt::colorize_value $xp] $level $rank $xp_to_lvlup [::DuckHunt::plural [expr {$required_xp - $xp}] [::msgcat::mc m43] [::msgcat::mc m44]] $karma $accuracy $accuracy_modifier $effective_accuracy $reliability $reliability_modifier $defense $deflection $best_time $average_reflex_time $ducks_shot [::DuckHunt::plural $ducks_shot [::msgcat::mc m45] [::msgcat::mc m46]] $golden_ducks_shot [::DuckHunt::plural $golden_ducks_shot [::msgcat::mc m274] [::msgcat::mc m275]] $missed_shots [::DuckHunt::plural $missed_shots [::msgcat::mc m47] [::msgcat::mc m48]] $humans_shot [::DuckHunt::plural $humans_shot [::msgcat::mc m49] [::msgcat::mc m50]] $empty_shots [::DuckHunt::plural $empty_shots [::msgcat::mc m51] [::msgcat::mc m52]] $wild_shots [::DuckHunt::plural $wild_shots [::msgcat::mc m53] [::msgcat::mc m54]] $total_fired_ammo [::DuckHunt::plural $total_fired_ammo [::msgcat::mc m55] [::msgcat::mc m56]] $bullets_received [::DuckHunt::plural $bullets_received [::msgcat::mc m57] [::msgcat::mc m58]] $deaths [::DuckHunt::plural $deaths [::msgcat::mc m59] [::msgcat::mc m60]] $deflected_bullets [::DuckHunt::plural $deflected_bullets [::msgcat::mc m61] [::msgcat::mc m62]] $neutralized_bullets [::DuckHunt::plural $neutralized_bullets [::msgcat::mc m63] [::msgcat::mc m64]]]${items_list}$effects_list "
		::DuckHunt::purge_db_from_memory
	}
	return
}

 ###############################################################################
### Affichage du nombre de munitions dans le chargeur.
 ###############################################################################
proc ::DuckHunt::display_ammo {lower_nick chan ammos_per_clip} {
	if { $::DuckHunt::unlimited_ammo_per_clip } {
		# Texte : "\00303Inf.\003"
		set displayed_ammo [::msgcat::mc m65]
	} else {
		set displayed_ammo "[::DuckHunt::colorize_value [::DuckHunt::get_data $lower_nick $chan "current_ammo_clip"]]/$ammos_per_clip"
	}
}

 ###############################################################################
### Affichage du nombre de chargeurs.
 ###############################################################################
proc ::DuckHunt::display_clips {lower_nick chan ammo_clips} {
	if { $::DuckHunt::unlimited_ammo_clips } {
		# Texte : "\00303Inf.\003"
		set displayed_clips [::msgcat::mc m65]
	} else {
		set displayed_clips "[::DuckHunt::colorize_value [::DuckHunt::get_data $lower_nick $chan "remaining_ammo_clips"]]/$ammo_clips"
	}
}

 ###############################################################################
### Retourne le karma d'un chasseur.
 ###############################################################################
proc ::DuckHunt::calculate_karma {wild_shots humans_shot ducks_shot short} {
	if { [expr {$wild_shots + $humans_shot + $ducks_shot}] != 0 } {
		set karma [::DuckHunt::format_floating_point_value [expr {100.0 * (-(($wild_shots * 1) + ($humans_shot * 3)) + ($ducks_shot * 2)) / (($wild_shots * 1)+($humans_shot * 3)+($ducks_shot * 2))}] 2]
		if { !$short } {
			if { $karma < 0 } {
				# Texte : "\00304mauvais chasseur � %s%%\003"
				set karma [::msgcat::mc m39 [expr {abs($karma)}]]
			} else {
				# Texte : "\00303bon chasseur � %s%%\003"
				set karma [::msgcat::mc m40 $karma]
			}
		}
	} else {
		if { $short } {
			set karma 0
		} else {
			# Texte : "neutre"
			set karma [::msgcat::mc m41]
		}
	}
	return $karma
}

 ###############################################################################
### !shop [[id] cible] : Affiche une liste des objets qu'il est possible
### d'acheter ou effectue un achat si id est sp�cifi�.
 ###############################################################################
proc ::DuckHunt::shop {nick host hand chan arg} {
	#::DuckHunt::display_output loglev - -  "shop"
	
	set lower_nick [::tcl::string::tolower $nick]
	if { [matchattr $hand $::DuckHunt::launch_auth $chan] } then {
		variable canNickFlood 0
	} else {
		 variable canNickFlood $::DuckHunt::antiflood
	}	 
		
	if {
		(![channel get $chan DuckHunt])
		|| ($hand in $::DuckHunt::blacklisted_handles)
		|| (($canNickFlood == 1)
		&& (([::DuckHunt::antiflood $nick $chan "nick" $::DuckHunt::shop_cmd $::DuckHunt::flood_shop])
		|| ([::DuckHunt::antiflood $nick $chan "chan" "*" $::DuckHunt::flood_global])))
	} then {
		return
	} else {
		
		::DuckHunt::read_database
		::DuckHunt::ckeck_for_pending_rename $chan $nick $lower_nick [md5 "$chan,$lower_nick"]
		::DuckHunt::initialize_player $nick $lower_nick $chan
		set current_time [unixtime]
		# Les joueurs ne peuvent utiliser le shop que si leur arme n'a pas �t�
		# confisqu�e de fa�on permanente.
		if { [::DuckHunt::get_data $lower_nick $chan "gun"] != -1 } {
			if { [::tcl::dict::exists $::DuckHunt::duck_sessions $chan] } {
				# On note le cumul du temps de r�action du joueur.
				::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "cumul_reflex_time" [expr {[::DuckHunt::get_data $lower_nick $chan "cumul_reflex_time"] + [expr {[::tcl::clock::milliseconds] - [lindex [::tcl::dict::get $::DuckHunt::duck_sessions $chan] 0 1]}]}]
			}
			if { $::DuckHunt::preferred_display_mode == 1 } {
				set output_method "PRIVMSG"
				set output_target $chan
			} else {
				set output_method "PRIVMSG"
				set output_target $nick
			}
			lassign [set args [split [::tcl::string::trim $arg]]] item_id target_nick
			set lower_target_nick [::tcl::string::tolower $target_nick]
			if { $item_id eq "" } {
				if { $::DuckHunt::shop_preferred_display_mode } {
					# Message : "\00314\[%s\]\003 Objets disponibles � l'achat : %s \00307|\003 \037Syntaxe\037 : \002%s\002 \00314\[\003id \00314\[\003cible\00314\]\]\003"
					set ::DuckHunt::duckURL ""
					::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m265 $::DuckHunt::scriptname $::DuckHunt::extra_ammo_cost $::DuckHunt::extra_clip_cost $::DuckHunt::AP_ammo_cost $::DuckHunt::explosive_ammo_cost $::DuckHunt::hand_back_confiscated_weapon_cost $::DuckHunt::grease_cost $::DuckHunt::sight_cost $::DuckHunt::infrared_detector_cost $::DuckHunt::silencer_cost $::DuckHunt::four_leaf_clover_cost $::DuckHunt::sunglasses_cost $::DuckHunt::spare_clothes_cost $::DuckHunt::brush_for_weapon_cost $::DuckHunt::mirror_cost $::DuckHunt::sand_cost $::DuckHunt::water_bucket_cost $::DuckHunt::sabotage_cost $::DuckHunt::life_insurance_cost $::DuckHunt::liability_insurance_cost $::DuckHunt::decoy_cost $::DuckHunt::piece_of_bread_cost $::DuckHunt::duck_detector_cost $::DuckHunt::fake_duck_cost $::DuckHunt::shop_cmd $::DuckHunt::duckURL ] 
					#::DuckHunt::display_output help $output_method $output_target "Purchasable item details: $::DuckHunt::shop_url"
				} else {
					# Message : "\00314\[%s\]\003 \037Objets disponibles � l'achat\037 : 1- Balle supp. (%s xp) \00314|\003 2- Chargeur supp. (%s xp) \00314|\003 3- Munitions AP (%s xp) \00314|\003 4- Munitions explosives (%s xp) \00314|\003 5- Rachat arme confisq. (%s xp) \00314|\003 6- Graisse (%s xp) \00314|\003 7- Lunette de vis�e (%s xp) \00314|\003 8- D�tecteur infrarouge (%s xp) \00314|\003 9- Silencieux (%s xp) \00314|\003 10- Tr�fle � 4 feuilles (%s xp) \00314|\003 11- Lunettes de soleil (%s xp) \00314|\003 12- V�tements de rechange (%s xp) \00314|\003 13- Goupillon (%s xp)\00314|\003 14- Miroir (%s xp) \00314|\003 15- Poign�e de sable (%s xp) \00314|\003 16- Seau d'eau (%s xp) \00314|\003 17- Sabotage (%s xp) \00314|\003 18- Assurance vie (%s xp) \00314|\003 19- Assurance responsabilit� civile (%s xp) \00314|\003 20- Appeau (%s xp) \00314|\003 21- Morceaux de pain (%s xp) \00314|\003 22- D�tecteur de canards (%s xp) \00314|\003 23- Canard m�canique (%s xp) \00307|\003 \037Syntaxe\037 : \002%s\002 \00314\[\003id \00314\[\003cible\00314\]\]\003"
					::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m265 $::DuckHunt::scriptname $::DuckHunt::extra_ammo_cost $::DuckHunt::extra_clip_cost $::DuckHunt::AP_ammo_cost $::DuckHunt::explosive_ammo_cost $::DuckHunt::hand_back_confiscated_weapon_cost $::DuckHunt::grease_cost $::DuckHunt::sight_cost $::DuckHunt::infrared_detector_cost $::DuckHunt::silencer_cost $::DuckHunt::four_leaf_clover_cost $::DuckHunt::sunglasses_cost $::DuckHunt::spare_clothes_cost $::DuckHunt::brush_for_weapon_cost $::DuckHunt::mirror_cost $::DuckHunt::sand_cost $::DuckHunt::water_bucket_cost $::DuckHunt::sabotage_cost $::DuckHunt::life_insurance_cost $::DuckHunt::liability_insurance_cost $::DuckHunt::decoy_cost $::DuckHunt::piece_of_bread_cost $::DuckHunt::duck_detector_cost $::DuckHunt::fake_duck_cost $::DuckHunt::shop_cmd ]					
				}
			} else {
				::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "last_activity" $current_time
				set prices {1 $::DuckHunt::extra_ammo_cost 2 $::DuckHunt::extra_clip_cost 3 $::DuckHunt::AP_ammo_cost 4 $::DuckHunt::explosive_ammo_cost 5 $::DuckHunt::hand_back_confiscated_weapon_cost 6 $::DuckHunt::grease_cost 7 $::DuckHunt::sight_cost 8 $::DuckHunt::infrared_detector_cost 9 $::DuckHunt::silencer_cost 10 $::DuckHunt::four_leaf_clover_cost 11 $::DuckHunt::sunglasses_cost 12 $::DuckHunt::spare_clothes_cost 13 $::DuckHunt::brush_for_weapon_cost 14 $::DuckHunt::mirror_cost 15 $::DuckHunt::sand_cost 16 $::DuckHunt::water_bucket_cost 17 $::DuckHunt::sabotage_cost 18 $::DuckHunt::life_insurance_cost 19 $::DuckHunt::liability_insurance_cost 20 $::DuckHunt::decoy_cost 21 $::DuckHunt::piece_of_bread_cost 22 $::DuckHunt::duck_detector_cost 23 $::DuckHunt::fake_duck_cost}
				if { [::DuckHunt::get_data $lower_nick $chan "xp"] - [subst [::tcl::dict::get $prices $item_id]] < $::DuckHunt::min_xp_for_shopping } {
					# Message : "%s > Tu n'es pas assez riche pour effectuer cet achat."
					::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m266 $nick]
					
				} else {
					if { $target_nick ne "" } {
						::DuckHunt::ckeck_for_pending_rename $chan $target_nick $lower_target_nick [md5 "$chan,$lower_target_nick"]
					}
					set must_write_db 0
					lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] previous_player_lvl {} {} {} {} {} default_ammos_in_clip default_ammo_clips_per_day {} {} {} {}
					if { $lower_target_nick ne "" } {
						lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_target_nick $chan "xp"]] previous_player_lvl {} {} {} {} {} default_ammos_in_clip default_ammo_clips_per_day {} {} {} {}
					} else {
						lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] previous_player_lvl {} {} {} {} {} default_ammos_in_clip default_ammo_clips_per_day {} {} {} {}
						}
					switch -- $item_id {
						1 {	
																		
							if { $lower_target_nick ne "" } {
									# Additional ball 
								if { ![::DuckHunt::get_data $lower_target_nick $chan "gun"] } {
									# Message : not armed.
									::DuckHunt::display_output help $output_method $output_target "$target_nick is not armed" 
								} elseif { [::DuckHunt::get_data $lower_target_nick $chan "current_ammo_clip"] >= $default_ammos_in_clip } {
								# 	# Message : "%s > The magazine of your weapon is already full."
									::DuckHunt::display_output help $output_method $output_target "$target_nick\'s magazine of their weapon is already full." 
								} else {
									::DuckHunt::incr_data $lower_target_nick $chan "current_ammo_clip" +1
									::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::extra_ammo_cost"
									if { $::DuckHunt::hunting_logs } {
										::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_1 for $target_nick" 0 -
									}
									# Message : "%s > Tu viens d'ajouter une balle dans ton arme en �change de %s %s."
									# Textes : "$nick > You just added an extra bullet in $target_nick\'s gun in exchange for"
									# set $nick > You just added an extra bullet in $target_nick\'s gun in exchange for %s %s."
									# set output ["$nick > You just added an extra bullet in $target_nick\'s gun in exchange for" $::DuckHunt::extra_ammo_cost [::DuckHunt::plural $::DuckHunt::extra_ammo_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
									set output [::msgcat::mc m268b $nick $target_nick $::DuckHunt::extra_ammo_cost [::DuckHunt::plural $::DuckHunt::extra_ammo_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
									set must_write_db 1
								}
							} else {
								# Additional ball 
								if { ![::DuckHunt::get_data $lower_nick $chan "gun"] } {
									# Message : not armed.
									::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m5 $nick] 
								} elseif { [::DuckHunt::get_data $lower_nick $chan "current_ammo_clip"] >= $default_ammos_in_clip } {
									# Message : "%s > The magazine of your weapon is already full."
									::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m267 $nick]
								} else {
									::DuckHunt::incr_data $lower_nick $chan "current_ammo_clip" +1
									::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::extra_ammo_cost"
									if { $::DuckHunt::hunting_logs } {
										::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_1" 0 -
									}
									# Message : "%s > Tu viens d'ajouter une balle dans ton arme en �change de %s %s."
									# Textes : "point d'xp" "points d'xp"
									set output [::msgcat::mc m268 $nick $::DuckHunt::extra_ammo_cost [::DuckHunt::plural $::DuckHunt::extra_ammo_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
									set must_write_db 1
								}
							} 
						}
						2 {
							::DuckHunt::display_output loglev - -  "ITEM 2"	
							if { $target_nick ne "" } {
								# Chargeur suppl�mentaire
								::DuckHunt::display_output loglev - -  "target_nick ne"	
								if { ![::DuckHunt::get_data $lower_target_nick $chan "gun"] } {
									# Message : not armed.
									::DuckHunt::display_output help $output_method $output_target "$target_nick is not armed" 
								} elseif { [::DuckHunt::get_data $lower_target_nick $chan "remaining_ammo_clips"] >= $default_ammo_clips_per_day } {
									# Message : "%s > Ta r�serve de chargeurs est d�j� pleine."
									::DuckHunt::display_output help $output_method $output_target "$target_nick\'s magazine supply is already full."
								} else {
									::DuckHunt::incr_data $lower_target_nick $chan "remaining_ammo_clips" +1
									::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::extra_clip_cost"
									if { $::DuckHunt::hunting_logs } {
										::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_2" 0 -
									}
									# Message : "%s > Tu viens d'ajouter un chargeur � ta r�serve en �change de %s %s."
									# set output ["$nick > You just added a magazine to $target_nick\'s supply in exchange for $::DuckHunt::extra_ammo_cost" [::DuckHunt::plural $::DuckHunt::extra_ammo_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
									set output [::msgcat::mc m268b $nick $target_nick $::DuckHunt::extra_ammo_cost [::DuckHunt::plural $::DuckHunt::extra_ammo_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
									set must_write_db 1
								}
								
							} else {
								# Chargeur suppl�mentaire
								if { ![::DuckHunt::get_data $lower_nick $chan "gun"] } {
									# Message : "%s > tu n'es pas arm�."
									::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m5 $nick]
								} elseif { [::DuckHunt::get_data $lower_nick $chan "remaining_ammo_clips"] >= $default_ammo_clips_per_day } {
									# Message : "%s > Ta r�serve de chargeurs est d�j� pleine."
									::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m269 $nick]
								} else {
									::DuckHunt::incr_data $lower_nick $chan "remaining_ammo_clips" +1
									::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::extra_clip_cost"
									if { $::DuckHunt::hunting_logs } {
										::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_2" 0 -
									}
									# Message : "%s > Tu viens d'ajouter un chargeur � ta r�serve en �change de %s %s."
									set output [::msgcat::mc m270 $nick $::DuckHunt::extra_clip_cost [::DuckHunt::plural $::DuckHunt::extra_clip_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
									set must_write_db 1
								}
							} 
						}
						3 {
							# Munitions AP
							lassign [::DuckHunt::get_item_info $lower_nick $chan "3"] item_index expiration_date {}
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� ce type de munitions. Le bonus expirera dans %s."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m277 $nick [::DuckHunt::adapt_time_resolution [expr {($expiration_date - $current_time) * 1000}] 0]]
							} else {
								# Si le joueur poss�de d�j� des munitions explosives, on les remplace.
								if { [set item_index [lsearch -index 1 [::DuckHunt::get_data $lower_nick $chan "items"] "4"]] != -1 } {
									::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
								}
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "3" "-"]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::AP_ammo_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_3" 0 -
								}
								# Message : "%s > Tu viens de changer le type de tes munitions en munitions AP (d�g�ts x2 pendant 24h) en �change de %s %s."
								set output [::msgcat::mc m278 $nick $::DuckHunt::AP_ammo_cost [::DuckHunt::plural $::DuckHunt::AP_ammo_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						4 {
							# Munitions explosives
							lassign [::DuckHunt::get_item_info $lower_nick $chan "4"] item_index expiration_date {}
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� ce type de munitions. Le bonus expirera dans %s."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m277 $nick [::DuckHunt::adapt_time_resolution [expr {($expiration_date - $current_time) * 1000}] 0]]
							} else {
								# Si le joueur poss�de d�j� des munitions AP, on les remplace.
								if { [set item_index [lsearch -index 1 [::DuckHunt::get_data $lower_nick $chan "items"] "3"]] != -1 } {
									::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
								}
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "4" "-"]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::explosive_ammo_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_4" 0 -
								}
								# Message : "%s > Tu viens de changer le type de tes munitions en munitions explosives (d�g�ts x3 pendant 24h) en �change de %s %s."
								set output [::msgcat::mc m279 $nick $::DuckHunt::explosive_ammo_cost [::DuckHunt::plural $::DuckHunt::explosive_ammo_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						5 {
							# Rachat d'arme confisqu�e
							if { [::DuckHunt::get_data $lower_nick $chan "gun"] } {
								# Message : "%s > Ton arme n'est pas confisqu�e."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m281 $nick]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "gun" 1
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::hand_back_confiscated_weapon_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_5" 0 -
								}
								# Message : "%s > Tu viens de racheter l'arme qui t'avait �t� confisqu�e en �change de %s %s."
								set output [::msgcat::mc m282 $nick $::DuckHunt::hand_back_confiscated_weapon_cost [::DuckHunt::plural $::DuckHunt::hand_back_confiscated_weapon_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						6 {
							# Graisse
							lassign [::DuckHunt::get_item_info $lower_nick $chan "6"] item_index expiration_date {}
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� cet item. Il expirera dans %s."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m283 $nick [::DuckHunt::adapt_time_resolution [expr {($expiration_date - $current_time) * 1000}] 0]]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "6" "-"]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::grease_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_6" 0 -
								}
								# Message : "%s > Tu viens de graisser ton arme en �change de %s %s. Le risque d'enrayement est r�duit de moiti� et la graisse prot�ge une fois contre un jet de sable pendant 24h."
								set output [::msgcat::mc m284 $nick $::DuckHunt::grease_cost [::DuckHunt::plural $::DuckHunt::grease_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						7 {
							# Lunette de vis�e
							lassign [::DuckHunt::get_item_info $lower_nick $chan "7"] item_index expiration_date item_uses
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� cet item. Il reste %s %s."
								# Texte : "utilisation" "utilisations"
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m288 $nick $item_uses [::DuckHunt::plural $item_uses [::msgcat::mc m292] [::msgcat::mc m293]]]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list "-" "7" "1"]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::sight_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_7" 0 -
								}
								# Message : "%s > Tu ajoutes une lunette de vis�e haute performance � ton arme en �change de %s %s. La pr�cision de ton prochain tir sera augment�e de (100 - pr�cision actuelle) / 3."
								set output [::msgcat::mc m287 $nick $::DuckHunt::sight_cost [::DuckHunt::plural $::DuckHunt::sight_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						8 {
							# D�tecteur infrarouge
							lassign [::DuckHunt::get_item_info $lower_nick $chan "8"] item_index expiration_date item_uses
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� cet item. Il expirera dans %s, il reste %s %s."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m295 $nick [::DuckHunt::adapt_time_resolution [expr {($expiration_date - $current_time) * 1000}] 0] $item_uses [::DuckHunt::plural $item_uses [::msgcat::mc m292] [::msgcat::mc m293]]]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "8" "6"]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::infrared_detector_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_8" 0 -
								}
								# Message : "%s > Tu viens d'�quiper ton arme d'un d�tecteur infrarouge en �change de %s %s. Ce dispositif dure 24h et verrouille la g�chette lorsqu'il n'y a pas de canard dans les environs."
								set output [::msgcat::mc m289 $nick $::DuckHunt::infrared_detector_cost [::DuckHunt::plural $::DuckHunt::infrared_detector_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						9 {
							# Silencieux
							lassign [::DuckHunt::get_item_info $lower_nick $chan "9"] item_index expiration_date {}
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� cet item. Il expirera dans %s."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m283 $nick [::DuckHunt::adapt_time_resolution [expr {($expiration_date - $current_time) * 1000}] 0]]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "9" "-"]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::silencer_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_9" 0 -
								}
								# Message : "%s > Tu viens d'�quiper ton arme d'un silencieux en �change de %s %s. Gr�ce � cet �quipement, tu n'effraies plus les canards lorsque tu tires pendant 24h."
								set output [::msgcat::mc m291 $nick $::DuckHunt::silencer_cost [::DuckHunt::plural $::DuckHunt::silencer_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						10 {
							# Tr�fle � 4 feuilles
							lassign [::DuckHunt::get_item_info $lower_nick $chan "10"] item_index expiration_date {}
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� cet item. Il expirera dans %s."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m283 $nick [::DuckHunt::adapt_time_resolution [expr {($expiration_date - $current_time) * 1000}] 0]]
							} else {
								set bonus_xp [expr {int(rand()*10) +1}]
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "10" $bonus_xp]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::four_leaf_clover_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_10" 0 $bonus_xp
								}
								# Message : "%s > Tu ach�tes un tr�fle � quatre feuilles en �change de %s %s. Ce porte-bonheur te fera gagner %s %s pour chaque canard tu� pendant 24h."
								set output [::msgcat::mc m294 $nick $::DuckHunt::four_leaf_clover_cost [::DuckHunt::plural $::DuckHunt::four_leaf_clover_cost [::msgcat::mc m285] [::msgcat::mc m286]] $bonus_xp [::DuckHunt::plural $bonus_xp "[::msgcat::mc m285] [::msgcat::mc m424]" "[::msgcat::mc m286] [::msgcat::mc m425]"]]
								set must_write_db 1
							}
						}
						11 {
							# Lunettes de soleil
							lassign [::DuckHunt::get_item_info $lower_nick $chan "11"] item_index expiration_date {}
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� cet item. Il expirera dans %s."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m283 $nick [::DuckHunt::adapt_time_resolution [expr {($expiration_date - $current_time) * 1000}] 0]]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 86400}] "11" "-"]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::sunglasses_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_11" 0 -
								}
								# Message : "%s > Tu ach�tes une paire de lunettes de soleil en �change de %s %s. Ces lunettes te prot�geront contre l'effet �blouissant du miroir pendant 24h."
								set output [::msgcat::mc m296 $nick $::DuckHunt::sunglasses_cost [::DuckHunt::plural $::DuckHunt::sunglasses_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						12 {
							# V�tements de rechange
							set item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "16"] 0]
							if { $item_index == -1 } {
								# Message : "%s > Tu n'as pas besoin de changer de v�tements."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m297 $nick]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::spare_clothes_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_12" 0 -
								}
								# Message : "%s > Tu ach�tes des v�tements secs en �change de %s %s."
								set output [::msgcat::mc m298 $nick $::DuckHunt::spare_clothes_cost [::DuckHunt::plural $::DuckHunt::spare_clothes_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						13 {
							# Goupillon
							set sand_item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "15"] 0]
							if {
								($sand_item_index == -1)
								&& ([lindex [::DuckHunt::get_item_info $lower_nick $chan "17"] 0] == -1)
							} then {
								# Message : "%s > Tu n'as pas besoin d'utiliser un goupillon."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m299 $nick]
							} else {
								if { $sand_item_index != -1 } {
									::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $sand_item_index $sand_item_index]
								}
								set sabotage_item_index [lindex [::DuckHunt::get_item_info $lower_nick $chan "17"] 0]
								if { $sabotage_item_index != -1 } {
									::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $sabotage_item_index $sabotage_item_index]
								}
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::brush_for_weapon_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_13" 0 -
								}
								# Message : "%s > Tu ach�tes un goupillon et remets ton arme en �tat en �change de %s %s."
								set output [::msgcat::mc m300 $nick $::DuckHunt::brush_for_weapon_cost [::DuckHunt::plural $::DuckHunt::brush_for_weapon_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						14 {
							# Miroir
							if { ![::tcl::dict::exists $::DuckHunt::player_data $chan $lower_target_nick] } {
								# Message : "%s > Je ne connais aucun chasseur portant ce nom."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m362 $nick]
							} elseif { ![onchan $target_nick $chan] } {
								# Message : "%s > Tu ne peux pas �blouir %s puisqu'il n'est pas l�."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m363 $nick $target_nick]
							} elseif { [lindex [::DuckHunt::get_item_info $lower_target_nick $chan "14"] 0] != -1 } {
								# Message : "%s > %s est d�j� �bloui."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m324 $nick $target_nick]
							} elseif { [lindex [::DuckHunt::get_item_info $lower_nick $chan "11"] 0] != -1 } {
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::mirror_cost"
								# Message : "%s > Ta tentative d'�blouir %s �choue car il porte des lunettes de soleil. Ton �chec te co�te quand m�me %s %s."
								set output [::msgcat::mc m325 $nick $target_nick $::DuckHunt::mirror_cost [::DuckHunt::plural $::DuckHunt::mirror_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_target_nick "items" [concat [::DuckHunt::get_data $lower_target_nick $chan "items"] [list [list "-" "14" $nick]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::mirror_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $target_nick - "item_14" 0 -
								}
								# Message : "%s > Tu ach�tes un miroir en �change de %s %s puis tu t'en sers pour �blouir %s gr�ce � un rayon de soleil, r�duisant ainsi de 50%% la pr�cision de son prochain tir."
								set output [::msgcat::mc m326 $nick $::DuckHunt::mirror_cost [::DuckHunt::plural $::DuckHunt::mirror_cost [::msgcat::mc m285] [::msgcat::mc m286]] $target_nick]
								set must_write_db 1
							}
						}
						15 {
							# Poign�e de sable
							if { ![::tcl::dict::exists $::DuckHunt::player_data $chan $lower_target_nick] } {
								# Message : "%s > Je ne connais aucun chasseur portant ce nom."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m362 $nick]
							} elseif { ![onchan $target_nick $chan] } {
								# Message : "%s > Tu ne peux pas jeter de sable dans l'arme de %s puisqu'il n'est pas l�."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m364 $nick $target_nick]
							} elseif { [::DuckHunt::get_data $lower_target_nick $chan "gun"] < 1 } {
								# Message : "%s > Tu ne peux pas jeter de sable dans l'arme de %s puisqu'il n'en a pas."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m367 $nick $target_nick]
							} elseif { [lindex [::DuckHunt::get_item_info $lower_target_nick $chan "15"] 0] != -1 } {
								# Message : "%s > %s a d�j� du sable dans son arme."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m327 $nick $target_nick]
							} elseif { [set item_index [lindex [::DuckHunt::get_item_info $lower_target_nick $chan "6"] 0]] != -1 } {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_target_nick "items" [lreplace [::DuckHunt::get_data $lower_target_nick $chan "items"] $item_index $item_index]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::sand_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $target_nick - "item_15" 0 -
								}
								# Message : "%s > Tu jettes une poign�e de sable dans l'arme de %s en �change de %s %s, mais son arme �tait graiss�e et le sable n'a eu aucun effet."
								set output [::msgcat::mc m328 $nick $target_nick $::DuckHunt::sand_cost [::DuckHunt::plural $::DuckHunt::sand_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_target_nick "items" [concat [::DuckHunt::get_data $lower_target_nick $chan "items"] [list [list "-" "15" $nick]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::sand_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $target_nick - "item_15" 0 -
								}
								# Message : "%s > Tu jettes une poign�e de sable dans l'arme de %s en �change de %s %s, r�duisant ainsi de 50%% la fiabilit� de son arme pour son prochain tir."
								set output [::msgcat::mc m329 $nick $target_nick $::DuckHunt::sand_cost [::DuckHunt::plural $::DuckHunt::sand_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						16 {
							# Seau d'eau
							if { ![::tcl::dict::exists $::DuckHunt::player_data $chan $lower_target_nick] } {
								# Message : "%s > Je ne connais aucun chasseur portant ce nom."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m362 $nick]
							} elseif { ![onchan $target_nick $chan] } {
								# Message : "%s > Tu ne peux pas jeter de seau d'eau � %s puisqu'il n'est pas l�."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m365 $nick $target_nick]
							} elseif { [lindex [::DuckHunt::get_item_info $lower_target_nick $chan "16"] 0] != -1 } {
								# Message : "%s > %s est d�j� tremp�."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m330 $nick $target_nick]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_target_nick "items" [concat [::DuckHunt::get_data $lower_target_nick $chan "items"] [list [list [expr {$current_time + 3600}] "16" $nick]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::water_bucket_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $target_nick - "item_16" 0 -
								}
								# Message : "%s > Tu jettes un seau d'eau sur %s en �change de %s %s, l'obligeant ainsi � attendre 1h que ses v�tements soient secs avant de pouvoir chasser � nouveau."
								set output [::msgcat::mc m331 $nick $target_nick $::DuckHunt::water_bucket_cost [::DuckHunt::plural $::DuckHunt::water_bucket_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						17 {
							# Sabotage
							if { ![::tcl::dict::exists $::DuckHunt::player_data $chan $lower_target_nick] } {
								# Message : "%s > Je ne connais aucun chasseur portant ce nom."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m362 $nick]
							} elseif { ![onchan $target_nick $chan] } {
								# Message : "%s > Tu ne peux pas saboter l'arme de %s puisqu'il n'est pas l�."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m366 $nick $target_nick]
							} elseif { [::DuckHunt::get_data $lower_target_nick $chan "gun"] < 1 } {
								# Message : "%s > Tu ne peux pas saboter l'arme de %s puisqu'il n'en a pas."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m368 $nick $target_nick]
							} elseif { [lindex [::DuckHunt::get_item_info $lower_target_nick $chan "17"] 0] != -1 } {
								# Message : "%s > L'arme de %s a d�j� �t� sabot�e."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m335 $nick $target_nick]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_target_nick "items" [concat [::DuckHunt::get_data $lower_target_nick $chan "items"] [list [list "-" "17" $nick]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::sabotage_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick $target_nick - "item_17" 0 -
								}
								# Message : "%s > Tu enfonces des trucs et des machins dans le canon de l'arme de %s en �change de %s %s."
								set output [::msgcat::mc m336 $nick $target_nick $::DuckHunt::sabotage_cost [::DuckHunt::plural $::DuckHunt::sabotage_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						18 {
							# Assurance vie
							lassign [::DuckHunt::get_item_info $lower_nick $chan "18"] item_index expiration_date item_uses
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� cet item. Il expirera dans %s, il reste %s %s."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m295 $nick [::DuckHunt::adapt_time_resolution [expr {($expiration_date - $current_time) * 1000}] 0] $item_uses [::DuckHunt::plural $item_uses [::msgcat::mc m292] [::msgcat::mc m293]]]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 604800}] "18" "1"]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::life_insurance_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_18" 0 -
								}
								# Message : "%s > Tu ach�tes une assurance vie en �change de %s %s. Pendant 1 semaine, si tu es victime d'un accident de chasse, tu gagnes l'�quivalent de 2x le niveau du tireur en points d'xp. Cette assurance est � usage unique."
								set output [::msgcat::mc m339 $nick $::DuckHunt::life_insurance_cost [::DuckHunt::plural $::DuckHunt::life_insurance_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						19 {
							# Assurance responsabilit� civile
							lassign [::DuckHunt::get_item_info $lower_nick $chan "19"] item_index expiration_date {}
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� cet item. Il expirera dans %s."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m283 $nick [::DuckHunt::adapt_time_resolution [expr {($expiration_date - $current_time) * 1000}] 0]]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list [expr {$current_time + 172800}] "19" "-"]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::liability_insurance_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_19" 0 -
								}
								# Message : "%s > Tu ach�tes une assurance responsabilit� civile en �change de %s %s. Pendant 2 jours, la p�nalit� d'xp sera divis�e par 3 si tu provoques un accident de chasse."
								set output [::msgcat::mc m342 $nick $::DuckHunt::liability_insurance_cost [::DuckHunt::plural $::DuckHunt::liability_insurance_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						20 {
							# Appeau
							if {
								([strftime "%H" $current_time] in $::DuckHunt::duck_sleep_hours)
								&& ($::DuckHunt::cant_attract_ducks_when_sleeping)
							} then {
								# Message : "%s > � cette heure-ci, les canards dorment."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m388 $nick]
							} else {
								if { $::DuckHunt::decoys_can_attract_golden_ducks } {
									utimer [expr {int(rand()*600) +1}] [list ::DuckHunt::duck_soaring $chan - 0 - - - - - -]
								} else {
									utimer [expr {int(rand()*600) +1}] [list ::DuckHunt::duck_soaring $chan 0 0 - - - - - -]
								}
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::decoy_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_20" 0 -
								}
								# Message : "%s > Tu ach�tes et utilises un appeau en �change de %s %s, ce qui devrait attirer un canard dans les 10 prochaines minutes."
								set output [::msgcat::mc m344 $nick $::DuckHunt::decoy_cost [::DuckHunt::plural $::DuckHunt::decoy_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						21 {
							# Morceau de pain
							if {
								([strftime "%H" $current_time] in $::DuckHunt::duck_sleep_hours)
								&& ($::DuckHunt::cant_attract_ducks_when_sleeping)
							} then {
								# Message : "%s > � cette heure-ci, les canards dorment."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m388 $nick]
							} elseif { [llength [channel get $chan DuckHunt-PiecesOfBread]] == $::DuckHunt::max_bread_on_chan } {
								# Message : "%s > Il y a d�j� %s morceaux de pain sur %s, �a devrait suffire pour l'instant."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m387 $nick $::DuckHunt::max_bread_on_chan $chan]
							} else {
								channel set $chan DuckHunt-PiecesOfBread [concat [channel get $chan DuckHunt-PiecesOfBread] [expr {$current_time + 3600}]]
								if { $::DuckHunt::method == 2 } {
									::DuckHunt::replan_flights - - - $chan $nick
								}
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::piece_of_bread_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_21" 0 -
								}
								# Message : "%s > Tu ach�tes un morceau de pain en �change de %s %s, augmentant ainsi les chances d'attirer des canards pendant 1h et retardant leur d�part. Il y a actuellement %s %s sur %s."
								# Textes : "morceau de pain" "morceaux de pain"
								set output [::msgcat::mc m347 $nick $::DuckHunt::piece_of_bread_cost [::DuckHunt::plural $::DuckHunt::piece_of_bread_cost [::msgcat::mc m285] [::msgcat::mc m286]] [set num_pieces_of_bread [llength [channel get $chan DuckHunt-PiecesOfBread]]] [::DuckHunt::plural $num_pieces_of_bread [::msgcat::mc m348] [::msgcat::mc m349]] $chan]
								set must_write_db 1
							}
						}
						22 {
							# D�tecteur de canards
							lassign [::DuckHunt::get_item_info $lower_nick $chan "22"] item_index expiration_date item_uses
							if { $item_index != -1 } {
								# Message : "%s > Tu poss�des d�j� cet item. Il reste %s %s."
								::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m288 $nick $item_uses [::DuckHunt::plural $item_uses [::msgcat::mc m292] [::msgcat::mc m293]]]
							} else {
								::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [concat [::DuckHunt::get_data $lower_nick $chan "items"] [list [list "-" "22" "1"]]]
								::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::duck_detector_cost"
								if { $::DuckHunt::hunting_logs } {
									::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_22" 0 -
								}
								# Message : "%s > Tu ach�tes un d�tecteur de canards en �change de %s %s. Tu seras averti par une notice lorsque le prochain canard s'envolera."
								set output [::msgcat::mc m350 $nick $::DuckHunt::duck_detector_cost [::DuckHunt::plural $::DuckHunt::duck_detector_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
								set must_write_db 1
							}
						}
						23 {
							# Canard m�canique
							utimer 600 [list ::DuckHunt::duck_soaring $chan 0 1 $nick - - - - -]
							::DuckHunt::incr_data $lower_nick $chan "xp" "-$::DuckHunt::fake_duck_cost"
							if { $::DuckHunt::hunting_logs } {
								::DuckHunt::add_to_log $chan $current_time $nick $lower_nick - - "item_23" 0 -
							}
							# Message : "%s > Tu ach�tes un canard m�canique en �change de %s %s, puis tu le programmes pour d�coller dans exactement 10mn."
							set output [::msgcat::mc m361 $nick $::DuckHunt::fake_duck_cost [::DuckHunt::plural $::DuckHunt::fake_duck_cost [::msgcat::mc m285] [::msgcat::mc m286]]]
							set must_write_db 1
						}
					}
					if { $must_write_db } {
						::DuckHunt::recalculate_ammo_on_lvl_change $lower_nick $chan
						::DuckHunt::write_database
					}
					if { $previous_player_lvl > [set current_player_lvl [lindex [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] 0]] } {
						# Message : "%s > Ton achat t'a fait repasser au niveau %s (%s)."
						append output [::msgcat::mc m280 $current_player_lvl [::DuckHunt::lvl2rank $current_player_lvl]]
					}
					if { [::tcl::info::exists output] } {
						::DuckHunt::display_output help $output_method $output_target $output
					}
				}
			}
		}
		::DuckHunt::purge_db_from_memory
	}
	return
}

 ###############################################################################
### !unarm [-static] <nick>: Disarms a hunter.
### A disarmed player will never be automatically re-armed.
### You will need to use the !rearm command to manually rearm it.
 ###############################################################################
proc ::DuckHunt::unarm {nick host hand chan arg} {
	if { [channel get $chan DuckHunt] } {
		if { [set arg [split [::tcl::string::trim $arg]]] == {} } {
			# Message : "\037Syntaxe\037 : \002%s\002 \00314\[\003-static\00314\] <\003nick\00314>\003 \00307|\003 D�sarme un joueur. Le param�tre -static permet de s'assurer qu'il ne sera pas r�arm� automatiquement; seule la commande \"%s\" le permettra. En l'absence de ce param�tre, l'arme sera automatiquement rendue au joueur lors de la prochaine d�-confiscation automatique."
			::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m66 $::DuckHunt::unarm_cmd]
		} else {
			if { [::tcl::string::tolower [set target [lindex $arg 0]]] eq "-static" } {
				set is_static 1
				set target [lindex $arg 1]
			} else {
				set is_static 0
			}
			set lower_target [::tcl::string::tolower $target]
			::DuckHunt::read_database
			::DuckHunt::ckeck_for_pending_rename $chan $nick $lower_target [md5 "$chan,$lower_target"]
			if {
				!([::tcl::dict::exists $::DuckHunt::player_data $chan])
				|| !([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_target])
			} then {
				# Message : "%s > %s n'a pas �t� trouv� dans la liste des chasseurs de canards sur %s."
				::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m67 $nick $target $chan]
			} else {
				# D�sarmement permanent.
				if { $is_static } {
					# Si $target est d�j� d�sarm� de fa�on permanente.
					if { [::DuckHunt::get_data $lower_target $chan "gun"] == -1 } {
						# Message : "%s fouille %s et ne trouve aucune arme sur lui. Il se rappelle maintenant que % a d�j� �t� d�sarm� de fa�on permanente."
						::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m68 $nick $target $target]
					# Si $target �tait auparavant arm�.
					} elseif { [::DuckHunt::get_data $lower_target $chan "gun"] == 1 } {
						::DuckHunt::incr_data $lower_target $chan "confiscated_weapons" +1
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_target "gun" -1
						# Message : "%s fouille %s et le d�sarme."
						::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m69 $nick $target]
						::DuckHunt::write_database
						if { $::DuckHunt::hunting_logs } {
							::DuckHunt::add_to_log $chan [unixtime] $nick - $target - "perm_unarm" 0 -
						}
					# Si $target �tait d�j� temporairement d�sarm�.
					} else { 
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_target "gun" -1
						# Message : "%s fouille %s et ne trouve aucune arme sur lui; il fait cependant le n�cessaire pour que son arme ne lui soit pas redonn�e lors de la prochaine restitution automatique."
						::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m70 $nick $target]
						::DuckHunt::write_database
						if { $::DuckHunt::hunting_logs } {
							::DuckHunt::add_to_log $chan [unixtime] $nick - $target - "perm_unarm" 0 -
						}

					}
				# D�sarmement temporaire.
				} else {
					# Si $target �tait auparavant d�sarm� de fa�on permanente.
					if { [::DuckHunt::get_data $lower_target $chan "gun"] == -1 } {
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_target "gun" 0
						# Message : "%s ne rend pas imm�diatement son arme � %s, mais fait le n�cessaire pour qu'elle lui soit rendue lors de la prochaine restitution automatique des armes."
						::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m128 $nick $target]
						::DuckHunt::write_database
						if { $::DuckHunt::hunting_logs } {
							::DuckHunt::add_to_log $chan [unixtime] $nick - $target - "temp_unarm" 0 -
						}

					# Si $target �tait auparavant arm�.
					} elseif { [::DuckHunt::get_data $lower_target $chan "gun"] == 1 } {
						::DuckHunt::incr_data $lower_target $chan "confiscated_weapons" +1
						::tcl::dict::set ::DuckHunt::player_data $chan $lower_target "gun" 0
						# Message : "%s fouille %s et lui confisque son arme. Elle lui sera rendue lors de la prochaine restitution automatique des armes."
						::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m129 $nick $target]
						::DuckHunt::write_database
						if { $::DuckHunt::hunting_logs } {
							::DuckHunt::add_to_log $chan [unixtime] $nick - $target - "temp_unarm" 0 -
						}
					# Si $target est d�j� temporairement d�sarm�.
					} else { 
						# Message : "%s fouille %s et ne trouve aucune arme sur lui."
						::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m130 $nick $target]
					}
				}
			}
			::DuckHunt::purge_db_from_memory
		}
	}
}

 ###############################################################################
### !rearm <nick> : Redonne son arme � un chasseur.
 ###############################################################################
proc ::DuckHunt::rearm {nick host hand chan target} {
	if { [channel get $chan DuckHunt] } {
		if { [set target [::tcl::string::trim $target]] == "" } {
			# Message : "\037Syntaxe\037 : \002%s\002 \00314<\003nick\00314>\003 \00307|\003 Rend son arme � un joueur qui a �t� d�sarm� automatiquement ou manuellement au moyen de la commande \"%s\"."
			::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m71 $::DuckHunt::rearm_cmd]
		} else {
			set lower_target [::tcl::string::tolower $target]
			::DuckHunt::read_database
			::DuckHunt::ckeck_for_pending_rename $chan $nick $lower_target [md5 "$chan,$lower_target"]
			if {
				!([::tcl::dict::exists $::DuckHunt::player_data $chan])
				|| !([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_target])
			} then {
				# Message : "%s > %s n'a pas �t� trouv� dans la liste des chasseurs de canards sur %s."
				::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m67 $nick $target $chan]
			} else {
				if { [::DuckHunt::get_data $lower_target $chan "gun"] == 1 } {
					# Message : "%s a d�j� une arme et regarde %s sans comprendre."
					::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m72 $target $nick]
				} else {
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_target "gun" 1
					# Message : "%s rend son arme � %s."
					::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m73 $nick $target]
					::DuckHunt::write_database
					if { $::DuckHunt::hunting_logs } {
						::DuckHunt::add_to_log $chan [unixtime] $nick - $target - "rearm" 0 -
					}
				}
			}
			::DuckHunt::purge_db_from_memory
		}
	}
}

 ###############################################################################
### ducklist <chan> [argument de recherche] : Affiche la liste des profils
### utilisateur sur le chan sp�cifi� ou effectue une recherche dans celle-ci.
 ###############################################################################
proc ::DuckHunt::findplayer {nick host hand arg} {
	if { [matchattr $hand $::DuckHunt::findplayer_auth [lindex [split $arg] 0]] } {
		if {
			([set arg [::tcl::string::trim $arg]] eq "")
			|| ([llength [set arg [split $arg]]] < 1)
		} then {
			# Message : "\037Syntaxe\037 : \002%s\002 \00314<\003chan\00314> \[\003argument de recherche\00314\]\003 \00307|\003 Affiche la liste des profils utilisateur sur le chan sp�cifi� ou effectue une recherche dans celle-ci."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m122 $::DuckHunt::findplayer_cmd]
		} else {
			lassign $arg chan search_argument
			set chan [::DuckHunt::fix_chan_case $chan]
			::DuckHunt::read_database
			if { ![validchan $chan] } {
				# Message : "\00304:::\003 Erreur : %s n'est pas un chan valide."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m75 $chan]
			} elseif { ![::tcl::dict::exists $::DuckHunt::player_data $chan] } {
				# Message : "\00304:::\003 Erreur : Aucun chasseur n'a �t� aper�u sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m123 $chan]
			} else {
				if { $search_argument eq "" } {
					set hunters_list [lsort [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $chan]]]
				} else {
					set hunters_list [lsort [lsearch -all -glob -nocase -inline [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $chan]] "*${search_argument}*"]]
				}
				if { $hunters_list ne "" } {
					set num_hunters [llength $hunters_list]
					# Message : "\0371 r�sultat\037 : %s"
					# Message : "\037%s r�sultats\037 : %s"
					::DuckHunt::display_output help NOTICE $nick [::DuckHunt::plural $num_hunters [::msgcat::mc m124 [join $hunters_list]] [::msgcat::mc m125 $num_hunters [join $hunters_list]]]
				} else {
					# Message : "La recherche de \"%s\" n'a donn� aucun r�sultat."
					::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m126 $search_argument]
				}
			}
			::DuckHunt::purge_db_from_memory
		}
	}
}

 ###############################################################################
### duckfusion <chan> <dest_nick> <src_nick1> [[src_nick2] [...]] : Fusionne les
### statistiques de plusieurs profils utilisateur.
 ###############################################################################
proc ::DuckHunt::fusion {nick host hand arg} {
	if { [matchattr $hand $::DuckHunt::fusion_auth [lindex [split $arg] 0]] } {
		if {
			([set arg [::tcl::string::trim $arg]] eq "")
			|| ([llength [set arg [split $arg]]] < 3)
		} then {
			# Message : "\037Syntaxe\037 : \002%s\002 \00314<\003chan\00314> <\003nick destination\00314> <\003nick source 1\00314> \[\003nick source 2\00314\] \[\003...\00314\]\003 \00307|\003 Fusionne les statistiques de plusieurs profils utilisateur. Les statistiques de tous les nicks source seront fusionn�es dans le nick de destination."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m74 $::DuckHunt::fusion_cmd]
		} else {
			lassign $arg chan dst_nick
			set chan [::DuckHunt::fix_chan_case $chan]
			set lower_dst_nick [::tcl::string::tolower $dst_nick]
			set src_nicks [lrange $arg 2 end]
			set must_write_db 0
			::DuckHunt::read_database
			if { ![validchan $chan] } {
				# Message : "\00304:::\003 Erreur : %s n'est pas un chan valide."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m75 $chan]
			} elseif { ![channel get $chan DuckHunt] } {
				# Message : "\00304:::\003 Erreur : %s n'est pas activ� sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m76 $::DuckHunt::scriptname $chan]
			} elseif {
				!([::tcl::dict::exists $::DuckHunt::player_data $chan])
				|| !([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_dst_nick])
			} then {
				# Message : "\00304:::\003 Erreur : %s n'a pas �t� trouv� dans la liste des chasseurs de canards sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m77 $dst_nick $chan]
			} else {
				foreach src_nick $src_nicks {
					set lower_src_nick [::tcl::string::tolower $src_nick]
					if { ![::tcl::dict::exists $::DuckHunt::player_data $chan $lower_src_nick] } {
						# Message : "\00304:::\003 Erreur : %s n'a pas �t� trouv� dans la liste des chasseurs de canards sur %s."
						::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m77 $src_nick $chan]
					} else {
						set src_stats ""
						set dst_stats ""
						foreach varname {gun jammed current_ammo_clip remaining_ammo_clips xp ducks_shot missed_shots empty_shots humans_shot wild_shots bullets_received deflected_bullets deaths confiscated_weapons jammed_weapons best_time cumul_reflex_time nick items golden_ducks_shot last_activity} {
							lappend src_stats [::DuckHunt::get_data $lower_src_nick $chan $varname]
							lappend dst_stats [::DuckHunt::get_data $lower_dst_nick $chan $varname]
						}
						::DuckHunt::merge_stats $chan $src_nick $lower_src_nick $dst_nick $lower_dst_nick $src_stats $dst_stats 1
						set must_write_db 1
						# Message : "Les statistiques de chasse de %s et de %s ont �t� fusionn�es dans %s sur le chan %s."
						::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m78 $dst_nick $src_nick $dst_nick $chan]
					}
				}
				if { $must_write_db } {
					::DuckHunt::recalculate_ammo_on_lvl_change $lower_dst_nick $chan
					::DuckHunt::write_database
				}
			}
			::DuckHunt::purge_db_from_memory
		}
	}
}

 ###############################################################################
### duckrename <chan> <source_nick> <destination_nick> : Renomme le profil de
### statistiques d'un utilisateur.
 ###############################################################################
proc ::DuckHunt::rename_player {nick host hand arg} {
	if { [matchattr $hand $::DuckHunt::fusion_auth [lindex [split $arg] 0]] } {
		if {
			([set arg [::tcl::string::trim $arg]] eq "")
			|| ([llength [set arg [split $arg]]] != 3)
		} then {
			# Message : "\037Syntaxe\037 : \002%s\002 \00314<\003chan\00314> <\003ancien nick\00314> <\003nouveau nick\00314>\003 \00307|\003 Renomme le profil de statistiques d'un utilisateur."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m131 $::DuckHunt::rename_cmd]
		} else {
			lassign $arg chan old_nick new_nick
			set chan [::DuckHunt::fix_chan_case $chan]
			set lower_old_nick [::tcl::string::tolower $old_nick]
			set lower_new_nick [::tcl::string::tolower $new_nick]
			set must_write_db 0
			::DuckHunt::read_database
			if { ![validchan $chan] } {
				# Message : "\00304:::\003 Erreur : %s n'est pas un chan valide."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m75 $chan]
			} elseif { ![channel get $chan DuckHunt] } {
				# Message : "\00304:::\003 Erreur : %s n'est pas activ� sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m76 $::DuckHunt::scriptname $chan]
			} elseif {
				!([::tcl::dict::exists $::DuckHunt::player_data $chan])
				|| !([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_old_nick])
			} then {
				# Message : "\00304:::\003 Erreur : %s n'a pas �t� trouv� dans la liste des chasseurs de canards sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m77 $old_nick $chan]
			} elseif { [::tcl::dict::exists $::DuckHunt::player_data $chan $lower_new_nick] } {
				# Message : "\00304:::\003 Erreur : Il existe d�j� un profil de statistiques au nom de %s sur %s. Si vous souhaitez fusionner les deux, utilisez plut�t la commande \"%s\"."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m132 $new_nick $chan $::DuckHunt::fusion_cmd]
			} else {
				::tcl::dict::set ::DuckHunt::player_data $chan $lower_new_nick [::tcl::dict::get $::DuckHunt::player_data $chan $lower_old_nick]
				::tcl::dict::set ::DuckHunt::player_data $chan $lower_new_nick "nick" $new_nick
				::tcl::dict::unset ::DuckHunt::player_data $chan $lower_old_nick
				set must_write_db 1
				# Message : "Le profil de statistiques de %s a �t� renomm� en %s sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m133 $old_nick $new_nick $chan]
				if { $must_write_db } {
					::DuckHunt::write_database
				}
			}
			::DuckHunt::purge_db_from_memory
		}
	}
}

 ###############################################################################
### duckdelete <chan> <nick> : Supprime le profil de statistiques d'un
### utilisateur.
 ###############################################################################
proc ::DuckHunt::delete_player {nick host hand arg} {
	if { [matchattr $hand $::DuckHunt::fusion_auth [lindex [split $arg] 0]] } {
		if {
			([set arg [::tcl::string::trim $arg]] eq "")
			|| ([llength [set arg [split $arg]]] != 2)
		} then {
			# Message : "\037Syntaxe\037 : \002%s\002 \00314<\003chan\00314> <\003nick\00314>\003 \00307|\003 Supprime le profil de statistiques d'un utilisateur."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m141 $::DuckHunt::delete_cmd]
		} else {
			lassign $arg chan target
			set chan [::DuckHunt::fix_chan_case $chan]
			set lower_target [::tcl::string::tolower $target]
			::DuckHunt::read_database
			if { ![validchan $chan] } {
				# Message : "\00304:::\003 Erreur : %s n'est pas un chan valide."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m75 $chan]
			} elseif {
				!([::tcl::dict::exists $::DuckHunt::player_data $chan])
				|| !([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_target])
			} then {
				# Message : "\00304:::\003 Erreur : il n'existe pas de profil au nom de %s sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m142 $target $chan]
			} else {
				::tcl::dict::unset ::DuckHunt::player_data $chan $lower_target
				# Message : "Le profil de statistiques de %s a �t� supprim� sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m143 $target $chan]
				::DuckHunt::write_database
			}
			::DuckHunt::purge_db_from_memory
		}
	}
}

 ###############################################################################
### duckplanning <chan> : Affiche la planification des envols de canards pour la
### journ�e en cours sur le chan sp�cifi� (si method = 2 uniquement).
 ###############################################################################
proc ::DuckHunt::show_planning {nick host hand chan} {
	if { [matchattr $hand $::DuckHunt::planning_auth [set chan [::DuckHunt::fix_chan_case [::tcl::string::trim $chan]]]] } {
		if {
			($chan eq "")
			|| ([llength [split $chan]] > 1)
		} then {
			# Message : "\037Syntaxe\037 : \002%s\002 \00314<\003chan\00314>\003 \00307|\003 Affiche la planification des envols de canards pour la journ�e en cours sur le chan sp�cifi�."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m79 $::DuckHunt::planning_cmd]
		} elseif { ![validchan $chan] } {
			# Message : "\00304:::\003 Erreur : %s n'est pas un chan valide."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m75 $chan]
		} elseif { ![channel get $chan DuckHunt] } {
			# Message : "\00304:::\003 Erreur : %s n'est pas activ� sur %s."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m76 $::DuckHunt::scriptname $chan]
		} elseif { !$::DuckHunt::post_init_done } {
			# Message : "\00304:::\003 Erreur : %s est en cours d'initialisation, la planification des envols n'a pas encore �t� calcul�e. Veuillez r�essayer d'ici quelques instants."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m243 $::DuckHunt::scriptname]
		} else {
			if { [::tcl::dict::exists $::DuckHunt::planned_soarings $chan] } {
				# Message : "Planification des envols de canards sur %s pour la journ�e en cours : %s"
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m81 $chan [join [lsort [::tcl::dict::get $::DuckHunt::planned_soarings $chan]] ", "]]
			} else {
				# Message : "Aucun envol de canard n'est planifi� pour la journ�e en cours sur %s."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m154 $chan]
			}
		}
	}
}

 ###############################################################################
### duckreplanning <chan> : Recalcule une planification diff�rente pour les
### envols de canards pour la journ�e en cours sur le chan sp�cifi�
### (si method = 2 uniquement).
 ###############################################################################
proc ::DuckHunt::replan_flights {nick host hand chan args} {
	if {
		($args ne "")
		|| ([matchattr $hand $::DuckHunt::planning_auth [set chan [::DuckHunt::fix_chan_case [::tcl::string::trim $chan]]]])
	} then {
		if {
			($chan eq "")
			|| ([llength [split $chan]] > 1)
		} then {
			# Message : "\037Syntaxe\037 : \002%s\002 \00314<\003chan\00314>\003 \00307|\003 Recalcule une planification diff�rente pour la journ�e en cours sur le chan sp�cifi�."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m148 $::DuckHunt::replanning_cmd]
		} elseif { ![validchan $chan] } {
			# Message : "\00304:::\003 Erreur : %s n'est pas un chan valide."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m75 $chan]
		} elseif { ![channel get $chan DuckHunt] } {
			# Message : "\00304:::\003 Erreur : %s n'est pas activ� sur %s."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m76 $::DuckHunt::scriptname $chan]
		} elseif { !$::DuckHunt::post_init_done } {
			if { $args eq "" } {
				# Message : "\00304:::\003 Erreur : %s est en cours d'initialisation, la planification des envols n'a pas encore �t� calcul�e. Veuillez r�essayer d'ici quelques instants."
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m243 $::DuckHunt::scriptname]
			}
		} else {
			if { $args eq "" } {
				::DuckHunt::plan_out_flights $chan
				# Message : "Une nouvelle planification des envols a �t� calcul�e pour le chan %s : %s"
				::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m149 $chan [join [lsort [::tcl::dict::get $::DuckHunt::planned_soarings $chan]] ", "]]
			} elseif { $args eq "@" } {
				::DuckHunt::plan_out_flights $chan "bread_expired"
				if { $::DuckHunt::show_bread_replanning } {
					# Message : "\00314\[%s\]\017  Morceau de pain expir�. Une nouvelle planification des envols a �t� calcul�e pour le chan %s : %s"
					::DuckHunt::display_output loglev - -  [::msgcat::mc m346 $::DuckHunt::scriptname $chan [join [lsort [::tcl::dict::get $::DuckHunt::planned_soarings $chan]] ", "]]
				}
			} else {
				::DuckHunt::plan_out_flights $chan "bread_added"
				if { $::DuckHunt::show_bread_replanning } {
					# Message : "\00314\[%s\]\017  Morceau de pain achet� par %s. Une nouvelle planification des envols a �t� calcul�e pour le chan %s : %s"
					::DuckHunt::display_output loglev - -  [::msgcat::mc m345 $::DuckHunt::scriptname [join $args] $chan [join [lsort [::tcl::dict::get $::DuckHunt::planned_soarings $chan]] ", "]]
				}
			}
		}
	}
}

 ###############################################################################
### ducklaunch <chan> [golden_duck] : Fait s'envoler un canard.
### golden_duck peut valoir 0 ou 1 et vaudra 0 s'il n'est pas sp�cifi�.
 ###############################################################################
proc ::DuckHunt::launch {nick host hand arg} {
	lassign [set args [split [::tcl::string::trim $arg]]] chan is_golden_duck
	if { [matchattr $hand $::DuckHunt::launch_auth $chan] } {
		if {
			($chan eq "")
			|| ([llength $args] > 2)
			|| ($is_golden_duck ni {{} 0 1})
		} then {
			# Message : "\037Syntaxe\037 : \002%s\002 \00314<\003chan\00314> \[\003golden_duck\00314\]\003 \00307|\003 D�clenche l'envol d'un canard sur le chan sp�cifi�. golden_duck d�termine s'il s'agit d'un super-canard ou d'un canard normal et peut valoir 0 (normal) ou 1 (super-canard). Si golden_duck est omis, il vaudra 0 par d�faut."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m82 $::DuckHunt::launch_cmd]
		} elseif { ![validchan $chan] } {
			# Message : "\00304:::\003 Erreur : %s n'est pas un chan valide."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m75 $chan]
		} elseif { ![channel get $chan DuckHunt] } {
			# Message : "\00304:::\003 Erreur : %s n'est pas activ� sur %s."
			::DuckHunt::display_output help NOTICE $nick [::msgcat::mc m76 $::DuckHunt::scriptname $chan]
		} else {
			set chan [::DuckHunt::fix_chan_case $chan]
			if { $is_golden_duck eq "" } {
				set is_golden_duck 0
			}
			if { $::DuckHunt::hunting_logs } {
				if { $is_golden_duck } {
					::DuckHunt::display_output loglev - - 	"Gold duck launched in $chan by $nick"
					::DuckHunt::add_to_log $chan [unixtime] $nick - - - "golden_duck_launch" 0 -
				} else {
					::DuckHunt::display_output loglev - -  "Duck launched in $chan by $nick"
					::DuckHunt::add_to_log $chan [unixtime] $nick - - - "launch" 0 -
				}
			}
			::DuckHunt::duck_soaring $chan $is_golden_duck 0 -
		}
	}
}

 ###############################################################################
### duckexport <chan> [crit�re de tri] : Exporte les donn�es des joueurs sous
### forme de tableau dans un fichier texte.
### Le crit�re de tri peut valoir nick xp level xp_lvl_up gun ammo max_ammo
### ammo_clips max_clips accuracy effective_accuracy deflection defense jamming
### jammed jammed_nbr confisc ducks golden_ducks missed empty accidents wild_shots total_ammo
### shot_at neutralized deflected deaths best_time average_reflex_time karma
### rank ou items.
### Si aucun crit�re de tri n'est sp�cifi�, le tableau sera tri� par nick.
 ###############################################################################
proc ::DuckHunt::export_players_table {src_nick host hand sort_by} {
	if { ![matchattr $hand $::DuckHunt::export_auth [set chan [lindex [split $sort_by] 0]]] } {
		return
	} elseif { [llength [split [::tcl::string::trim $sort_by]]] > 1 } {
		# Message : "\037Syntaxe\037 : \002%s\002 \00314\[\003crit�re de tri\00314\]\003 \00307|\003 Exporte un tableau contenant les donn�es des joueurs dans un fichier texte. Si vous ne sp�cifiez pas de crit�re de tri, le tableau sera tri� par nick. Le crit�re de tri peut valoir nick last_activity xp level xp_lvl_up gun ammo max_ammo ammo_clips max_clips accuracy effective_accuracy deflection defense jamming jammed jammed_nbr confisc ducks golden_ducks missed empty accidents wild_shots total_ammo shot_at neutralized deflected deaths best_time average_reflex_time karma rank ou items."
		::DuckHunt::display_output help NOTICE $src_nick [::msgcat::mc m205 $::DuckHunt::export_cmd]
	} elseif { $sort_by ni [set valid_arguments {{} nick last_activity xp level xp_lvl_up gun ammo max_ammo ammo_clips max_clips accuracy effective_accuracy deflection defense jamming jammed jammed_nbr confisc ducks golden_ducks missed empty accidents wild_shots total_ammo shot_at neutralized deflected deaths best_time average_reflex_time karma rank items}] } {
		# Message : "\00304:::\003 Erreur : \"%s\" n'est pas un crit�re de tri valide. Le crit�re de tri doit valoir %s"
		::DuckHunt::display_output help NOTICE $src_nick [::msgcat::mc m206 $sort_by [lreplace [linsert $valid_arguments end-1 [::msgcat::mc m80]] 0 0]]
	} else {
		::DuckHunt::read_database
		if { $sort_by eq "" } {
			set sort_by "nick"
		} else {
			set sort_by [::tcl::string::tolower $sort_by]
		}
		set indexes {"nick" 0 "last_activity" 1 "xp" 2 "level" 3 "xp_lvl_up" 4 "ammo" 5 "max_ammo" 6 "ammo_clips" 7 "max_clips" 8 "accuracy" 9 "effective_accuracy" 10 "deflection" 11 "armor" 12 "jamming" 13 "jammed" 14 "jammed_nbr" 15 "gun" 16 "confisc" 17 "ducks" 18 "golden_ducks" 19 "missed" 20 "empty" 21 "accidents" 22 "wild_shots" 23 "total_ammo" 24 "shot_at" 25 "neutralized" 26 "deflected" 27 "deaths" 28 "best_time" 29 "average_reflex_time" 30 "karma" 31 "rank" 32 "items" 33}
		set format_string {%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s%-*s}
		# Message : "%s v%s (�2015-2016 Menz Agitat) - %s - Rapport g�n�r� le %s/%s/%s � %s - tri� par %s"
		set current_time [unixtime]
		set title [::msgcat::mc m207 $::DuckHunt::scriptname $::DuckHunt::version $::network [strftime "%d" $current_time] [strftime "%m" $current_time] [strftime "%Y" $current_time] [strftime "%H:%M:%S" $current_time] $sort_by]
		set players_table_file_ID [open $::DuckHunt::players_table_file w]
		puts $players_table_file_ID " [::tcl::string::repeat "-" [expr {[::tcl::string::length $title] + 4}]] "
		puts $players_table_file_ID "|  $title  |"
		puts $players_table_file_ID " [::tcl::string::repeat "-" [expr {[::tcl::string::length $title] + 4}]] "
		puts $players_table_file_ID ""
		# Texte : "Crit�res de tri disponibles :"
		puts $players_table_file_ID "[::msgcat::mc m244] nick last_activity xp level xp_lvl_up gun ammo max_ammo ammo_clips max_clips accuracy effective_accuracy deflection defense jamming jammed jammed_nbr confisc ducks golden_ducks missed empty accidents wild_shots total_ammo shot_at neutralized deflected deaths best_time average_reflex_time karma rank items"
		puts $players_table_file_ID ""
		puts $players_table_file_ID ""
		# La base de donn�es est vide.
		if { ![llength [set chans_to_process [::tcl::dict::keys $::DuckHunt::player_data]]] } {
			# Message : "Aucune donn�e"
			puts $players_table_file_ID [::msgcat::mc m208]
		# La base de donn�es n'est pas vide.
		} else {
			# On calcule la largeur des colonnes.
			set rank_name_max_length 0
			foreach {lvl rank_name} [::msgcat::mc m134] {
				if { [set length [::tcl::string::length $rank_name]] > $rank_name_max_length } {
					set rank_name_max_length $length
				}
			}
			set nick_max_length 0
			set items_max_length 0
			foreach chan [::tcl::dict::keys $::DuckHunt::player_data] {
				foreach lower_nick [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $chan]] {
					if { [set nick_length [::tcl::string::length [::DuckHunt::get_data $lower_nick $chan "nick"]]] > $nick_max_length } {
						set nick_max_length $nick_length
					}
					if { [set items_length [::tcl::string::length [::DuckHunt::get_data $lower_nick $chan "items"]]] > $items_max_length } {
						set items_max_length $items_length
					}
				}
			}
			set counter 0
			set msgcat_index 209 ;  # index du 1er nom de colonne dans le pack de langue.
			set default_column_width [list $nick_max_length 19 5 3 4 3 3 3 3 4 7 4 4 4 1 4 2 4 5 3 5 5 4 5 6 4 4 4 4 16 16 7 $rank_name_max_length $items_max_length] ; # Largeur minimale des colonnes, calcul�e en fonction de longueur maximum estim�e de leur contenu.
			foreach column {nick last_activity xp level xp_lvl_up ammo max_ammo ammo_clips max_clips accuracy effective_accuracy deflection armor jamming jammed jammed_nbr gun confisc ducks golden_ducks missed empty accidents wild_shots total_ammo shot_at neutralized deflected deaths best_time average_reflex_time karma rank items} {
				lappend ul_width [set max [expr {max([lindex $default_column_width $counter],[::tcl::string::length [::msgcat::mc m$msgcat_index]])}]]
				lappend col_width [expr {$max + 3}]
				incr counter
				incr msgcat_index
			}
			foreach chan [::tcl::dict::keys $::DuckHunt::player_data] {
				puts $players_table_file_ID $chan
				puts $players_table_file_ID [::tcl::string::repeat "-" [::tcl::string::length $chan]]
				 # Textes : "nom" "dern. activit�" "xp" "lvl" "xp lvl sup." "mun." "mun. max." "charg." "charg. max." "pr�c. th�orique" "pr�c. effective" "d�flex." "armure" "enrayement" "enray�" "nbr enrayements" "arm�" "nbr confisc." "canards" "super-canards" "rat�s" "tirs � vide" "accidents" "tirs sauvages" "mun. utilis." "tirs re�us" "tirs encaiss�s" "tirs d�vi�s" "d�c�s" "meilleur tps." "tps. r�act. moyen" "karma" "rang" "objets sp�ciaux"
				puts $players_table_file_ID [format $format_string [lindex $col_width 0] [::msgcat::mc m209] [lindex $col_width 1] [::msgcat::mc m210] [lindex $col_width 2] [::msgcat::mc m211] [lindex $col_width 3] [::msgcat::mc m212] [lindex $col_width 4] [::msgcat::mc m213] [lindex $col_width 5] [::msgcat::mc m214] [lindex $col_width 6] [::msgcat::mc m215] [lindex $col_width 7] [::msgcat::mc m216] [lindex $col_width 8] [::msgcat::mc m217] [lindex $col_width 9] [::msgcat::mc m218] [lindex $col_width 10] [::msgcat::mc m219] [lindex $col_width 11] [::msgcat::mc m220] [lindex $col_width 12] [::msgcat::mc m221] [lindex $col_width 13] [::msgcat::mc m222] [lindex $col_width 14] [::msgcat::mc m223] [lindex $col_width 15] [::msgcat::mc m224] [lindex $col_width 16] [::msgcat::mc m225] [lindex $col_width 17] [::msgcat::mc m226] [lindex $col_width 18] [::msgcat::mc m227] [lindex $col_width 19] [::msgcat::mc m228] [lindex $col_width 20] [::msgcat::mc m229] [lindex $col_width 21] [::msgcat::mc m230] [lindex $col_width 22] [::msgcat::mc m231] [lindex $col_width 23] [::msgcat::mc m232] [lindex $col_width 24] [::msgcat::mc m233] [lindex $col_width 25] [::msgcat::mc m234] [lindex $col_width 26] [::msgcat::mc m235] [lindex $col_width 27] [::msgcat::mc m236] [lindex $col_width 28] [::msgcat::mc m237] [lindex $col_width 29] [::msgcat::mc m238] [lindex $col_width 30] [::msgcat::mc m239] [lindex $col_width 31] [::msgcat::mc m240] [lindex $col_width 32] [::msgcat::mc m241] [lindex $col_width 33] [::msgcat::mc m242]]
				puts $players_table_file_ID [format $format_string [lindex $col_width 0] [::tcl::string::repeat "-" [lindex $ul_width 0]] [lindex $col_width 1] [::tcl::string::repeat "-" [lindex $ul_width 1]] [lindex $col_width 2] [::tcl::string::repeat "-" [lindex $ul_width 2]] [lindex $col_width 3] [::tcl::string::repeat "-" [lindex $ul_width 3]] [lindex $col_width 4] [::tcl::string::repeat "-" [lindex $ul_width 4]] [lindex $col_width 5] [::tcl::string::repeat "-" [lindex $ul_width 5]] [lindex $col_width 6] [::tcl::string::repeat "-" [lindex $ul_width 6]] [lindex $col_width 7] [::tcl::string::repeat "-" [lindex $ul_width 7]] [lindex $col_width 8] [::tcl::string::repeat "-" [lindex $ul_width 8]] [lindex $col_width 9] [::tcl::string::repeat "-" [lindex $ul_width 9]] [lindex $col_width 10] [::tcl::string::repeat "-" [lindex $ul_width 10]] [lindex $col_width 11] [::tcl::string::repeat "-" [lindex $ul_width 11]] [lindex $col_width 12] [::tcl::string::repeat "-" [lindex $ul_width 12]] [lindex $col_width 13] [::tcl::string::repeat "-" [lindex $ul_width 13]] [lindex $col_width 14] [::tcl::string::repeat "-" [lindex $ul_width 14]] [lindex $col_width 15] [::tcl::string::repeat "-" [lindex $ul_width 15]] [lindex $col_width 16] [::tcl::string::repeat "-" [lindex $ul_width 16]] [lindex $col_width 17] [::tcl::string::repeat "-" [lindex $ul_width 17]] [lindex $col_width 18] [::tcl::string::repeat "-" [lindex $ul_width 18]] [lindex $col_width 19] [::tcl::string::repeat "-" [lindex $ul_width 19]] [lindex $col_width 20] [::tcl::string::repeat "-" [lindex $ul_width 20]] [lindex $col_width 21] [::tcl::string::repeat "-" [lindex $ul_width 21]] [lindex $col_width 22] [::tcl::string::repeat "-" [lindex $ul_width 22]] [lindex $col_width 23] [::tcl::string::repeat "-" [lindex $ul_width 23]] [lindex $col_width 24] [::tcl::string::repeat "-" [lindex $ul_width 24]] [lindex $col_width 25] [::tcl::string::repeat "-" [lindex $ul_width 25]] [lindex $col_width 26] [::tcl::string::repeat "-" [lindex $ul_width 26]] [lindex $col_width 27] [::tcl::string::repeat "-" [lindex $ul_width 27]] [lindex $col_width 28] [::tcl::string::repeat "-" [lindex $ul_width 28]] [lindex $col_width 29] [::tcl::string::repeat "-" [lindex $ul_width 29]] [lindex $col_width 30] [::tcl::string::repeat "-" [lindex $ul_width 30]]  [lindex $col_width 31] [::tcl::string::repeat "-" [lindex $ul_width 31]] [lindex $col_width 32] [::tcl::string::repeat "-" [lindex $ul_width 32]] [lindex $col_width 33] [::tcl::string::repeat "-" [lindex $ul_width 33]]]
				# R�cup�ration des donn�es et cr�ation du tableau.
				foreach lower_nick [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $chan]] {
					lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] level required_xp accuracy deflection defense jamming ammos_per_clip ammo_clips {} {} {}
					set rank [::DuckHunt::lvl2rank $level]
					foreach varname {gun jammed current_ammo_clip remaining_ammo_clips xp ducks_shot golden_ducks_shot missed_shots empty_shots humans_shot wild_shots bullets_received deflected_bullets deaths confiscated_weapons jammed_weapons best_time cumul_reflex_time nick items last_activity} {
						set $varname [::DuckHunt::get_data $lower_nick $chan $varname]
					}
					set karma [::DuckHunt::calculate_karma $wild_shots $humans_shot $ducks_shot 1]
					set total_ammo [expr {$ducks_shot + $missed_shots}]
					set xp_to_lvlup [expr {$required_xp - $xp}]
					if { $total_ammo != 0 } {
						set effective_accuracy [::DuckHunt::format_floating_point_value [expr {(100.0 * $ducks_shot) / $total_ammo}] 2]
					} else {
						set effective_accuracy -1
					}
					set neutralized_bullets [expr {$bullets_received - $deaths - $deflected_bullets}]
					if { $best_time == -1 } {
						set best_time 9999999999
					}
					if { $ducks_shot != 0 } {
						set average_reflex_time [format "%.3f" [expr {($cumul_reflex_time / 1000.0) / $ducks_shot}]]
					} else {
						set average_reflex_time "9999999999"
					}
					lappend data_table [list $nick $last_activity $xp $level $xp_to_lvlup $current_ammo_clip $ammos_per_clip $remaining_ammo_clips $ammo_clips $accuracy $effective_accuracy $deflection $defense $jamming $jammed $jammed_weapons $gun $confiscated_weapons $ducks_shot $golden_ducks_shot $missed_shots $empty_shots $humans_shot $wild_shots $total_ammo $bullets_received $neutralized_bullets $deflected_bullets $deaths $best_time $average_reflex_time $karma $rank $items]
				}
				# Tri du tableau.
				switch -- $sort_by {
					"nick" - "rank" {
						# Par ordre alphab�tique.
						set data_table [lsort -dictionary -index [::tcl::dict::get $indexes $sort_by] [lsort -dictionary -index 0 $data_table]]
					}
					"best_time" - "average_reflex_time" {
						# Par ordre num�rique croissant.
						set data_table [lsort -real -index [::tcl::dict::get $indexes $sort_by] [lsort -dictionary -index 0 $data_table]]
					}
					"items" {
						# Par ordre alphab�tique puis longueur de string d�croissant
						set data_table [lsort -decreasing -command {apply {{string_a string_b} {expr {[string length $string_a] - [string length $string_b]}}}} -index [::tcl::dict::get $indexes $sort_by] [lsort -dictionary -index [::tcl::dict::get $indexes $sort_by] [lsort -dictionary -index 0 $data_table]]]
					}
					default {
						# Par ordre num�rique d�croissant.
						set data_table [lsort -decreasing -real -index [::tcl::dict::get $indexes $sort_by] [lsort -dictionary -index 0 $data_table]]
					}
				}
				# Ecriture du tableau dans le fichier.
				foreach entry $data_table {
					lassign $entry nick last_activity xp level xp_to_lvlup current_ammo_clip ammos_per_clip remaining_ammo_clips ammo_clips accuracy effective_accuracy deflection defense jamming jammed jammed_weapons gun confiscated_weapons ducks_shot golden_ducks_shot missed_shots empty_shots humans_shot wild_shots total_ammo bullets_received neutralized_bullets deflected_bullets deaths best_time average_reflex_time karma rank items
					# Post-traitement des valeurs du tableau.
					if { $effective_accuracy == -1 } {
						set effective_accuracy "-"
					} else {
						set effective_accuracy "${effective_accuracy}%"
					}
					if { $best_time == 9999999999 } {
						set best_time "-"
					} else {
						set best_time [::DuckHunt::adapt_time_resolution [::tcl::string::map {"." ""} $best_time] 1]
					}
					if { $average_reflex_time == 9999999999 } {
						set average_reflex_time "-"
					} else {
						set average_reflex_time [::DuckHunt::adapt_time_resolution [::tcl::string::map {"." ""} $average_reflex_time] 1]
					}
					if { $last_activity == -1 } {
						set last_activity "-"
					} else {
						set last_activity [strftime [::msgcat::mc m422] $last_activity]
					}
					puts $players_table_file_ID [format $format_string [lindex $col_width 0] $nick [lindex $col_width 1] $last_activity [lindex $col_width 2] $xp [lindex $col_width 3] $level [lindex $col_width 4] $xp_to_lvlup [lindex $col_width 5] $current_ammo_clip [lindex $col_width 6] $ammos_per_clip [lindex $col_width 7] $remaining_ammo_clips [lindex $col_width 8] $ammo_clips [lindex $col_width 9] "${accuracy}%" [lindex $col_width 10] $effective_accuracy [lindex $col_width 11] "${deflection}%" [lindex $col_width 12] "${defense}%" [lindex $col_width 13] "${jamming}%" [lindex $col_width 14] $jammed [lindex $col_width 15] $jammed_weapons [lindex $col_width 16] $gun [lindex $col_width 17] $confiscated_weapons [lindex $col_width 18] $ducks_shot [lindex $col_width 19] $golden_ducks_shot [lindex $col_width 20] $missed_shots [lindex $col_width 21] $empty_shots [lindex $col_width 22] $humans_shot [lindex $col_width 23] $wild_shots [lindex $col_width 24] $total_ammo [lindex $col_width 25] $bullets_received [lindex $col_width 26] $neutralized_bullets [lindex $col_width 27] $deflected_bullets [lindex $col_width 28] $deaths [lindex $col_width 29] $best_time [lindex $col_width 30] $average_reflex_time [lindex $col_width 31] $karma [lindex $col_width 32] $rank [lindex $col_width 33] $items]
				}
				# On saute 2 lignes entre chaque chan.
				puts $players_table_file_ID ""
				puts $players_table_file_ID ""
				unset data_table
			}
		}
		close $players_table_file_ID
		::DuckHunt::purge_db_from_memory
		# Message : "Un rapport a �t� g�n�r� � l'emplacement %s"
		::DuckHunt::display_output help NOTICE $src_nick [::msgcat::mc m262 $::DuckHunt::players_table_file]
	}
}
 ###############################################################################
### Redonne des chargeurs � tout le monde chaque jour � minuit.
 ###############################################################################
proc ::DuckHunt::refill_ammo {args} {
	::DuckHunt::read_database
	foreach chan [::tcl::dict::keys $::DuckHunt::player_data] {
		foreach lower_nick [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $chan]] {
			::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "remaining_ammo_clips" [lindex [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] 7]
		}
		if { $::DuckHunt::hunting_logs } {
			::DuckHunt::add_to_log $chan [unixtime] - - - - "refill_ammo" 0 -
		}
	}
	::DuckHunt::write_database
	::DuckHunt::purge_db_from_memory
}

 ###############################################################################
### Rend les armes confisqu�es.
 ###############################################################################
proc ::DuckHunt::hand_back_weapons {args} {
	if { ![::tcl::info::exists ::DuckHunt::player_data] } {
		set must_unload_database 1
		::DuckHunt::read_database
	} else {
		set must_unload_database 0
	}
	# Sur un chan seulement.
	if { [llength $args] == 1 } {
		set chans_to_process [join $args]
	# Sur tous les chans.
	} else {
		set chans_to_process [::tcl::dict::keys $::DuckHunt::player_data]
	}
	foreach chan $chans_to_process {
		foreach lower_nick [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $chan]] {
			if { [::DuckHunt::get_data $lower_nick $chan "gun"] == 0 } {
				::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "gun" 1
			}
		}
		if { $::DuckHunt::hunting_logs } {
			::DuckHunt::add_to_log $chan [unixtime] - - - - "hand_back_weapons" 0 -
		}
	}
	# Remarque : on ne d�charge pas la db de la m�moire si la proc�dure a �t�
	# appel�e apr�s un envol de canard en raison de gun_hand_back_mode = 2.
	if { $must_unload_database } {
		::DuckHunt::write_database
		::DuckHunt::purge_db_from_memory
	}
}

 ###############################################################################
### We check if a player is already registered in the database and
### we initialize it if necessary.
 ###############################################################################
proc ::DuckHunt::initialize_player {nick lower_nick chan} {
	if {
		!([::tcl::dict::exists $::DuckHunt::player_data $chan])
		|| !([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_nick])
	} then {
		lassign [::DuckHunt::get_level_and_grantings 0] {} {} {} {} {} {} default_ammos_in_clip default_ammo_clips_per_day {} {} {} {}
		::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick [::tcl::dict::create "gun" 1 "jammed" 0 "current_ammo_clip" $default_ammos_in_clip "remaining_ammo_clips" $default_ammo_clips_per_day "xp" 0 "ducks_shot" 0 "missed_shots" 0 "empty_shots" 0 "humans_shot" 0 "wild_shots" 0 "bullets_received" 0 "deflected_bullets" 0 "deaths" 0 "confiscated_weapons" 0 "jammed_weapons" 0 "best_time" -1 "cumul_reflex_time" 0 "nick" $nick "items" {} "golden_ducks_shot" 0 "last_activity" [unixtime]]
	}
}

 ###############################################################################
### Retourne la valeur d'une donn�e utilisateur.
 ###############################################################################
proc ::DuckHunt::get_data {lower_nick chan field_name} {
	# On �limine les items �ventuellement expir�s de l'inventaire du joueur avant
	# de retourner l'information.
	if {
		([::tcl::dict::exists $::DuckHunt::player_data $chan])
		&& ([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_nick])
		&& ($field_name eq "items")
	} then {
		set expired_items_found 0
		set item_index 0
		foreach item [set items [::tcl::dict::get $::DuckHunt::player_data $chan $lower_nick "items"]] {
			if {
				([set expiration_date [lindex $item 0]] ne "-")
				&& ($expiration_date < [unixtime])
			} then {
				::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace $items $item_index $item_index]
				set expired_items_found 1
			} else {
				incr item_index
			}
		}
		if { $expired_items_found } {
			::DuckHunt::write_database
		}
	}
	# R�cup�ration de l'information demand�e.
	if {
		([::tcl::dict::exists $::DuckHunt::player_data $chan])
		&& ([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_nick])
	} then {
		return [::tcl::dict::get $::DuckHunt::player_data $chan $lower_nick $field_name]
	} else {
		lassign [::DuckHunt::get_level_and_grantings 0] {} {} {} {} {} {} default_ammos_in_clip default_ammo_clips_per_day {} {} {} {}
		switch -- $field_name {
			"gun" { return 1 }
			"jammed" - "xp" - "ducks_shot" - "golden_ducks_shot" - "missed_shots" - "empty_shots" - "humans_shot" - "wild_shots" - "bullets_received" - "deflected_bullets" - "deaths" - "confiscated_weapons" - "jammed_weapons" - "cumul_reflex_time" { return 0 }
			"current_ammo_clip" { return $default_ammos_in_clip }
			"remaining_ammo_clips" { return $default_ammo_clips_per_day }
			"best_time" { return -1 }
			"rank" { return [::DuckHunt::lvl2rank 1] }
			"nick" {
				# Correction de la casse du nick
				if { [onchan $lower_nick $chan] } {
					set nick [lindex [set nick_list [chanlist $chan]] [lsearch -nocase -exact $nick_list $lower_nick]]
				} else {
					set nick $lower_nick
				}
				return $nick
			}
			"items" { return "" }
			"last_activity" { return "-1" }
		}
	}
}

 ###############################################################################
### Incr�mente ou d�cr�mente la valeur d'une donn�e utilisateur.
 ###############################################################################
proc ::DuckHunt::incr_data {lower_nick chan field_name increment} {
	::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick $field_name [expr {[::DuckHunt::get_data $lower_nick $chan $field_name] + $increment}]
}

 ###############################################################################
### R�cup�re des informations sur un item poss�d� par un joueur.
### Retourne $item_index $expiration_date $data 
 ###############################################################################
proc ::DuckHunt::get_item_info {lower_nick chan item_id} {
	if { [set item_index [lsearch -index 1 [::DuckHunt::get_data $lower_nick $chan "items"] "$item_id"]] != -1 } {
		lassign [lindex [::DuckHunt::get_data $lower_nick $chan "items"] $item_index] expiration_date {} data
		return [list $item_index $expiration_date $data]
	} else {
		return {-1 0 "-"}
	}
}

 ###############################################################################
### D�cr�mente le compteur d'utilisations d'un item.
 ###############################################################################
proc ::DuckHunt::decrement_item_uses {lower_nick chan item_id item_index expiration_date item_uses} {
	incr item_uses -1
	if { $item_uses > 0 } {
		::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index [list $expiration_date $item_id $item_uses]]
	} else {
		::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" [lreplace [::DuckHunt::get_data $lower_nick $chan "items"] $item_index $item_index]
	}
}

 ###############################################################################
### Retourne une liste contenant diff�rentes informations en fonction d'un
### nombre de points d'xp :
### {level required_xp pr�cision d�flexion d�fense enrayement ammos_per_clip ammo_clips xp_miss xp_wild_fire xp_accident}
 ###############################################################################
proc ::DuckHunt::get_level_and_grantings {xp} {
	foreach level [lsort -integer [array names ::DuckHunt::level_grantings]] {
		lassign [split $::DuckHunt::level_grantings($level) ","] required_xp accuracy deflection defense jamming ammo_clip_size ammo_clips xp_miss xp_wild_fire xp_accident
		if { $xp >= $required_xp } {
			continue
		} else {
			return [list $level $required_xp [expr $accuracy] [expr $deflection] [expr $defense] [expr $jamming] [expr $ammo_clip_size] [expr $ammo_clips] $xp_miss $xp_wild_fire $xp_accident]
		}
	}
}

 ###############################################################################
### Recalcule le nombre de munitions dans l'arme et de chargeurs restants lors
### d'un changement de niveau du joueur afin que les valeurs ne d�passent pas
### les capacit�s de l'arme.
 ###############################################################################
proc ::DuckHunt::recalculate_ammo_on_lvl_change {lower_nick chan} {
	lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_nick $chan "xp"]] {} {} {} {} {} {} default_ammos_in_clip default_ammo_clips_per_day {} {} {} {}
	# if { [::DuckHunt::get_data $lower_nick $chan "current_ammo_clip"] > $default_ammos_in_clip } {
	# 	::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "current_ammo_clip" $default_ammos_in_clip
	# }
	# if { [::DuckHunt::get_data $lower_nick $chan "remaining_ammo_clips"] > $default_ammo_clips_per_day } {
	# 	::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "remaining_ammo_clips" $default_ammo_clips_per_day
	# }
}

 ###############################################################################
### Cherche et �limine les morceaux de pain expir�s
 ###############################################################################
proc ::DuckHunt::check_for_expired_pieces_of_bread {args} {
	foreach chan [channels] {
		if { [llength [set pieces_of_bread [channel get $chan DuckHunt-PiecesOfBread]]] != 0 } {
			set item_index 0
			foreach expiration_date $pieces_of_bread {
				if { $expiration_date < [unixtime] } {
					channel set $chan DuckHunt-PiecesOfBread [lreplace [channel get $chan DuckHunt-PiecesOfBread] $item_index $item_index]
					if { $::DuckHunt::method == 2 } {
						::DuckHunt::replan_flights - - - $chan "@"
					}
				} else {
					incr item_index
				}
			}
		}
	}
}

 ###############################################################################
### Convertit un niveau en rang
 ###############################################################################
proc ::DuckHunt::lvl2rank {level} {
	return [lindex [::msgcat::mc m134] $level]
}

 ###############################################################################
### Retourne le pourcentage de chances pour qu'un tir manqu� touche quelqu'un
### en fonction du nombre d'utilisateurs sur le chan.
 ###############################################################################
proc ::DuckHunt::determine_chances_to_hit_someone_else {chan duck_present} {
	# On d�termine les chances pour qu'un tir manqu� touche quelqu'un par accident
	# en fonction du nombre d'utilisateurs sur le chan.
	set num_users [llength [chanlist $chan]]
	# Si un canard est en vol.
	if { $duck_present } {
		if { $num_users <= 10 } {
			return $::DuckHunt::chances_to_hit_someone_else_1_10
		} elseif { $num_users <=20 } {
			return $::DuckHunt::chances_to_hit_someone_else_11_20
		} elseif { $num_users <=30 } {
			return $::DuckHunt::chances_to_hit_someone_else_21_30
		} else {
			return $::DuckHunt::chances_to_hit_someone_else_31_
		}
	# S'il n'y a aucun canard en vol.
	} else {
		if { $num_users <= 10 } {
			return $::DuckHunt::chances_wild_fire_hit_someone_1_10
		} elseif { $num_users <=20 } {
			return $::DuckHunt::chances_wild_fire_hit_someone_11_20
		} elseif { $num_users <=30 } {
			return $::DuckHunt::chances_wild_fire_hit_someone_21_30
		} else {
			return $::DuckHunt::chances_wild_fire_hit_someone_31_
		}
	}
}

 ###############################################################################
### Retourne le nick d'un utilisateur choisi al�atoirement sur $chan et ne
### pouvant �tre ni le nick de l'Eggdrop, ni le nick de l'utilisateur d'o�
### provient la balle.
 ###############################################################################
proc ::DuckHunt::random_user {chan source_nick} {
	if { $::DuckHunt::exempted_flags eq "" } {
		set user_list [lsearch -all -exact -not -inline [lsearch -all -exact -not -inline [chanlist $chan] $::nick] $source_nick]
	} else {
		set user_list [lsearch -all -exact -not -inline [lsearch -all -exact -not -inline [chanlist $chan "-${::DuckHunt::exempted_flags}&-${::DuckHunt::exempted_flags}"] $::nick] $source_nick]
	}
	if { $user_list eq "" } {
		return "@nobody@"
	} else {
		if { $::DuckHunt::only_hunters_can_be_shot } {
			set hunters_list [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $chan]]
			foreach hunter $hunters_list {
				if {
					([set index [lsearch -nocase -exact $user_list [set lower_hunter_nick [::tcl::string::tolower $hunter]]]] != -1)
					&& ([expr {[::DuckHunt::get_data $lower_hunter_nick $chan "ducks_shot"] + [::DuckHunt::get_data $lower_hunter_nick $chan "missed_shots"]}] > 0)
				} then {
					lappend tmp_user_list [lindex $user_list $index]
				}
			}
			if { [::tcl::info::exists tmp_user_list] } {
				set user_list $tmp_user_list
			} else {
				return "@nobody@"
			}
		}
		return [lindex $user_list [rand [llength $user_list]]]
	}
}

 ###############################################################################
### Ajoute des informations au rapport d'administration journalier.
### action peut valoir : soaring shoot reload miss jam die hit deflect wild_fire
 ###############################################################################
proc ::DuckHunt::add_to_log {chan timestamp hunter_nick lower_hunter_nick target_nick shooting_time action noLF extra_data} {
	if { $action in {hit_golden_duck shoot shoot_golden_duck miss empty_shot reload jam unjam unjam_reload accident wild_fire} } {
		lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_hunter_nick $chan "xp"]] {} {} {} {} {} {} ammos_per_clip ammo_clips
		set ammo [regsub -all "\017" [stripcodes abcgru [::DuckHunt::display_ammo $lower_hunter_nick $chan $ammos_per_clip]] ""]
		set clips [regsub -all "\017" [stripcodes abcgru [::DuckHunt::display_clips $lower_hunter_nick $chan $ammo_clips]] ""]
	}
	set logfile_ID [open "${::DuckHunt::log_directory}${chan}_[strftime "%Y%m%d" [unixtime]].log" a+]
	switch -- $action {
		"soaring" {
			# Message : "\[%s\]   \\_O<  *COIN*"
			puts -nonewline $logfile_ID [::msgcat::mc m157 [strftime "%H:%M:%S" $timestamp]]
		}
		"golden_duck_soaring" {
			# Message : "\[%s\]   \\_O<  *COIN*  \[SUPER-CANARD\]"
			puts -nonewline $logfile_ID [::msgcat::mc m254 [strftime "%H:%M:%S" $timestamp]]
		}
		"fake_duck_soaring" {
			# Message : "\[%s\]   \\_O<  *COIN*  \[canard m�canique\]"
			puts -nonewline $logfile_ID [::msgcat::mc m352 [strftime "%H:%M:%S" $timestamp]]
		}
		"launch" {
			# Message : "\[%s\]   \\_O<  *COIN*   (lancement manuel par %s)"
			puts -nonewline $logfile_ID [::msgcat::mc m158 [strftime "%H:%M:%S" $timestamp] $hunter_nick]
		}
		"golden_duck_launch" {
			# Message : "\[%s\]   \\_O<  *COIN*  \[SUPER-CANARD\]  (lancement manuel par %s)"
			puts -nonewline $logfile_ID [::msgcat::mc m255 [strftime "%H:%M:%S" $timestamp] $hunter_nick]
		}
		"frightened" {
			# Message : "\[%s\]   ��'`'�-.,��.��'` canard effray�"
			puts -nonewline $logfile_ID [::msgcat::mc m159 [strftime "%H:%M:%S" $timestamp]]
		}
		"escaped" {
			# Message : "\[%s\]   ��'`'�-.,��.��'` canard parti"
			puts -nonewline $logfile_ID [::msgcat::mc m160 [strftime "%H:%M:%S" $timestamp]]
		}
		"golden_duck_escaped" {
			# Message : "\[%s\]   ��'`'�-.,��.��'` super-canard parti"
			puts -nonewline $logfile_ID [::msgcat::mc m276 [strftime "%H:%M:%S" $timestamp]]
		}
		"fake_duck_escaped" {
			# Message : "\[%s\]   ��'`'�-.,��.��'` canard m�canique parti"
			puts -nonewline $logfile_ID [::msgcat::mc m355 [strftime "%H:%M:%S" $timestamp]]
		}
		"hit_golden_duck" {
			# Message : " |-- \[%s\] %s (%s|%s)   *BANG* \\_O<  *CHTOK*  \[SUPER-CANARD\]"
			puts -nonewline $logfile_ID [::msgcat::mc m256 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips]
		}		
		"shoot" {
			# Message : " |-- \[%s\] %s (%s|%s)   *BANG* \\_X<  *COUAC* (%s %s / %s)"
			puts -nonewline $logfile_ID [::msgcat::mc m161 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips [::DuckHunt::get_data $lower_hunter_nick $chan "ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_hunter_nick $chan "ducks_shot"] [::msgcat::mc m27] [::msgcat::mc m28]] $shooting_time]
		}
		"shoot_golden_duck" {
			# Message : " |-- \[%s\] %s (%s|%s)   *BANG* \\_X<  *COUAC*  \[SUPER-CANARD\] (%s %s / %s)"
			puts -nonewline $logfile_ID [::msgcat::mc m257 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips [::DuckHunt::get_data $lower_hunter_nick $chan "ducks_shot"] [::DuckHunt::plural [::DuckHunt::get_data $lower_hunter_nick $chan "ducks_shot"] [::msgcat::mc m27] [::msgcat::mc m28]] $shooting_time]
		}
		"miss" {
			# Message : " |-- \[%s\] %s (%s|%s)   *BANG*"
			puts -nonewline $logfile_ID [::msgcat::mc m162 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips]
		}
		"empty_shot" {
			# Message : " |-- \[%s\] %s (%s|%s)   *CLIC*"
			puts -nonewline $logfile_ID [::msgcat::mc m163 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips]
		}
		"reload" {
			# Message : " |-- \[%s\] %s (%s|%s)   *CLAC CLAC*"
			puts -nonewline $logfile_ID [::msgcat::mc m164 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips]
		}
		"jam" {
			# Message : " |-- \[%s\] %s (%s|%s)   *CLAC*"
			puts -nonewline $logfile_ID [::msgcat::mc m165 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips]
		}
		"unjam" {
			# Message : " |-- \[%s\] %s (%s|%s)   *Crr..CLIC*"
			puts -nonewline $logfile_ID [::msgcat::mc m166 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips]
		}
		"unjam_reload" {
			# Message : " |-- \[%s\] %s (%s|%s)   *Crr..CLIC* *CLAC CLAC*"
			puts -nonewline $logfile_ID [::msgcat::mc m167 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips]
		}
		"accident" {
			# Message : " |-- \[%s\] %s (%s|%s)   *BANG*  accident :"
			puts -nonewline $logfile_ID [::msgcat::mc m168 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips]
		}
		"die" {
			# Message : " %s *ARG*"
			puts -nonewline $logfile_ID [::msgcat::mc m169 $target_nick]
		}
		"hit" {
			# Message : " %s *CHTOK*"
			puts -nonewline $logfile_ID [::msgcat::mc m170 $target_nick]
		}
		"deflect" {
			# Message : " %s *PIEWWW*"
			puts -nonewline $logfile_ID [::msgcat::mc m171 $target_nick]
		}
		"wild_fire" {
			# Message : " |-- \[%s\] %s (%s|%s)   *BANG* sauvage"
			puts -nonewline $logfile_ID [::msgcat::mc m172 [strftime "%H:%M:%S" $timestamp] $hunter_nick $ammo $clips]
		}
		"confiscated" {
			# Message : "   ---> arme confisqu�e"
			puts -nonewline $logfile_ID [::msgcat::mc m173]
		}
		"dead_duck" {
			# Message : " \\_X<  *COUAC*"
			puts -nonewline $logfile_ID [::msgcat::mc m174]
		}
		"dead_golden_duck" {
			# Message : " \\_X<  *COUAC*  \[SUPER-CANARD\]"
			puts -nonewline $logfile_ID [::msgcat::mc m258]
		}
		"dead_fake_duck" {
			# Message : " \\_X<  *BZZzZzt*  \[canard m�canique\]"
			puts -nonewline $logfile_ID [::msgcat::mc m360]
		}
		"refill_ammo" {
			# Message : "\[%s\]   ravitaillement en munitions"
			puts -nonewline $logfile_ID [::msgcat::mc m175 [strftime "%H:%M:%S" $timestamp]]
		}
		"hand_back_weapons" {
			# Message : "\[%s\]   restitution des armes confisqu�es"
			puts -nonewline $logfile_ID [::msgcat::mc m176 [strftime "%H:%M:%S" $timestamp]]
		}
		"perm_unarm" {
			# Message : "\[%s\]   d�sarmement permanent de %s par %s"
			puts -nonewline $logfile_ID [::msgcat::mc m177 [strftime "%H:%M:%S" $timestamp] $target_nick $hunter_nick]
		}
		"temp_unarm" {
			# Message : "\[%s\]   d�sarmement temporaire de %s par %s"
			puts -nonewline $logfile_ID [::msgcat::mc m178 [strftime "%H:%M:%S" $timestamp] $target_nick $hunter_nick]
		}
		"rearm" {
			# Message : "\[%s\]   r�armement de %s par %s"
			puts -nonewline $logfile_ID [::msgcat::mc m179 [strftime "%H:%M:%S" $timestamp] $target_nick $hunter_nick]
		}
		"item_1" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te une balle (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m301 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::extra_ammo_cost]
		}
		"item_2" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un chargeur (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m302 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::extra_clip_cost]
		}
		"item_3" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te des munitions AP (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m303 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::AP_ammo_cost]
		}
		"item_4" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te des munitions explosives (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m304 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::explosive_ammo_cost]
		}
		"item_5" {
			# Message : "\[%s\]   \[\$\$\$\]   %s rach�te son arme confisqu�e (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m305 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::hand_back_confiscated_weapon_cost]
		}
		"item_6" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te de la graisse (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m306 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::grease_cost]
		}
		"item_7" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te une lunette de vis�e (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m307 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::sight_cost]
		}
		"item_8" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un d�tecteur infrarouge (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m308 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::infrared_detector_cost]
		}
		"item_9" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un silencieux (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m309 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::silencer_cost]
		}
		"item_10" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un tr�fle � 4 feuilles +%s (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m310 [strftime "%H:%M:%S" $timestamp] $hunter_nick $extra_data $::DuckHunt::four_leaf_clover_cost]
		}
		"item_11" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te des lunettes de soleil (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m311 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::sunglasses_cost]
		}
		"item_12" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te des v�tements de rechange (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m312 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::spare_clothes_cost]
		}
		"item_13" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un goupillon (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m313 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::brush_for_weapon_cost]
		}
		"item_14" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un miroir pour %s (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m314 [strftime "%H:%M:%S" $timestamp] $hunter_nick $target_nick $::DuckHunt::mirror_cost]
		}
		"item_15" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te une poign�e de sable pour %s (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m315 [strftime "%H:%M:%S" $timestamp] $hunter_nick $target_nick $::DuckHunt::sand_cost]
		}
		"item_16" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un seau d'eau pour %s (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m316 [strftime "%H:%M:%S" $timestamp] $hunter_nick $target_nick $::DuckHunt::water_bucket_cost]
		}
		"item_17" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un sabotage pour %s (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m317 [strftime "%H:%M:%S" $timestamp] $hunter_nick $target_nick $::DuckHunt::sabotage_cost]
		}
		"item_18" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te une assurance vie (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m318 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::life_insurance_cost]
		}
		"item_19" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te une assurance responsabilit� civile (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m319 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::liability_insurance_cost]
		}
		"item_20" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un appeau (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m320 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::decoy_cost]
		}
		"item_21" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un morceau de pain (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m321 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::piece_of_bread_cost]
		}
		"item_22" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un d�tecteur de canards (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m322 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::duck_detector_cost]
		}
		"item_23" {
			# Message : "\[%s\]   \[\$\$\$\]   %s ach�te un canard m�canique (%s xp)"
			puts -nonewline $logfile_ID [::msgcat::mc m323 [strftime "%H:%M:%S" $timestamp] $hunter_nick $::DuckHunt::fake_duck_cost]
		}
		"merge_stats_1" {
			lassign $extra_data src_stats dst_stats resulting_stats
			# Message : "\[%s\]   \[Transfert de stats\]   renommage chasseur vers chasseur d�sarm� : %s \{%s\} + %s \{%s\} = %s \{%s\}"
			puts -nonewline $logfile_ID [::msgcat::mc m389 [strftime "%H:%M:%S" $timestamp] $hunter_nick $src_stats $target_nick $dst_stats $target_nick $resulting_stats]
		}
		"merge_stats_2" {
			lassign $extra_data src_stats dst_stats resulting_stats
			# Message : "\[%s\]   \[Transfert de stats\]   renommage chasseur d�sarm� vers chasseur d�sarm� : %s \{%s\} + %s \{%s\} = %s \{%s\}"
			puts -nonewline $logfile_ID [::msgcat::mc m390 [strftime "%H:%M:%S" $timestamp] $hunter_nick $src_stats $target_nick $dst_stats $target_nick $resulting_stats]
		}
		"merge_stats_3" {
			lassign $extra_data src_stats dst_stats resulting_stats
			# Message : "\[%s\]   \[Transfert de stats\]   renommage non-chasseur vers chasseur : %s \{%s\} + %s \{%s\} = %s \{%s\}"
			puts -nonewline $logfile_ID [::msgcat::mc m391 [strftime "%H:%M:%S" $timestamp] $hunter_nick $src_stats $target_nick $dst_stats $target_nick $resulting_stats]
		}
		"merge_stats_4" {
			lassign $extra_data src_stats dst_stats resulting_stats
			# Message : "\[%s\]   \[Transfert de stats\]   renommage chasseur vers chasseur : %s \{%s\} + %s \{%s\} = %s \{%s\}"
			puts -nonewline $logfile_ID [::msgcat::mc m392 [strftime "%H:%M:%S" $timestamp] $hunter_nick $src_stats $target_nick $dst_stats $target_nick $resulting_stats]
		}
		"merge_stats_5" {
			lassign $extra_data src_stats dst_stats resulting_stats
			# Message : "\[%s\]   \[Transfert de stats\]   fusion manuelle : %s \{%s\} + %s \{%s\} = %s \{%s\}"
			puts -nonewline $logfile_ID [::msgcat::mc m420 [strftime "%H:%M:%S" $timestamp] $hunter_nick $src_stats $target_nick $dst_stats $target_nick $resulting_stats]
		}
		"drop" {
			# Message : " |-- \[%s\] %s \[drop : %s\]"
			puts -nonewline $logfile_ID [::msgcat::mc m419 [strftime "%H:%M:%S" $timestamp] $hunter_nick $extra_data]
		}
	}
	if { !$noLF } {
		puts -nonewline $logfile_ID "\n"
	}
	close $logfile_ID
}

 ###############################################################################
### Lecture de la base de donn�es.
 ###############################################################################
proc ::DuckHunt::read_database {} {
	incr ::DuckHunt::db_sessions
	if { [file exists $::DuckHunt::db_file] } {
		set dbfile_ID [open $::DuckHunt::db_file r]
		set bad_header 0
		gets $dbfile_ID 1st_line
		# Si l'en-t�te n'existe pas, on note de r��crire la base de donn�es pour y
		# rem�dier.
		if { ![::tcl::string::match "--- *" $1st_line] } {
			set bad_header 1
			seek $dbfile_ID 0
		} else {
			# Si l'en-t�te ne correspond pas � la version actuelle, on note de r��crire
			# la base de donn�es pour y rem�dier.
			if { [lindex [regexp -inline {v([^\s]+)} $1st_line] 1] != $::DuckHunt::version } {
				set bad_header 1
			}
			# On passe l'en-t�te.
			while { [gets $dbfile_ID] != "---" } {
				continue
			}
		}
		set ::DuckHunt::player_data [read -nonewline $dbfile_ID]
		# On v�rifie si la base de donn�es est d'un format ant�rieur � la v2 et
		# n�cessite d'�tre convertie.
		foreach chan [::tcl::dict::keys $::DuckHunt::player_data] {
			foreach lower_nick [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $chan]] {
				# Si le nombre de champs d'une entr�e = 21 alors la conversion n'est
				# pas n�cessaire.
				if { [llength [::tcl::dict::keys [::tcl::dict::get $::DuckHunt::player_data $chan $lower_nick]]] == 21 } {
					set converted_db_from_v1 0
					break
				} else {
					if { ![::tcl::info::exists converted_db_from_v1] } {
						# Message : "\00314\[%s\]\017  Une base de donn�es d'un ancien format a �t� d�tect�e. Conversion en cours..."
						::DuckHunt::display_output loglev - - [::msgcat::mc m260 $::DuckHunt::scriptname]
						set bad_header 1
					}
					set converted_db_from_v1 1
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "items" {}
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "golden_ducks_shot" 0
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_nick "last_activity" -1
				}
			}
			if { !$converted_db_from_v1 } {
				break
			}
		}
		if { $bad_header } {
			::DuckHunt::write_database
			# Message : "\00314\[%s\]\017  La base de donn�es a �t� mise � jour avec succ�s � la version %s."
			::DuckHunt::display_output loglev - - [::msgcat::mc m83 $::DuckHunt::scriptname $::DuckHunt::version]
		}
		close $dbfile_ID
	} else {
		set ::DuckHunt::player_data ""
	}
}

 ###############################################################################
### Ecriture de la base de donn�es.
 ###############################################################################
proc ::DuckHunt::write_database {} {
	set dbfile_ID [open $::DuckHunt::db_file w]
	# Texte : "--- %s v%s - Base de donn�es contenant les donn�es et les statistiques des participants ---"
	puts $dbfile_ID [::msgcat::mc m84 $::DuckHunt::scriptname $::DuckHunt::version]
	# Texte : "--- structure : #chan1 {player1 {gun jammed current_ammo_clip remaining_ammo_clips xp ducks_shot missed_shots empty_shots humans_shot wild_shots bullets_received deflected_bullets deaths confiscated_weapons jammed_weapons best_time cumul_reflex_time nick items golden_ducks last_activity} player2 {...}} #chan2 {...}"
	puts $dbfile_ID [::msgcat::mc m85]
	# Texte : ---			gun : 1 = arm�, 0 = d�sarmement temporaire, -1 = d�sarmement permanent.
	puts $dbfile_ID [::msgcat::mc m86]
	# Texte : "---			jammed : Peut valoir 1 ou 0 selon que l'arme est enray�e ou non."
	puts $dbfile_ID [::msgcat::mc m87]
	# Texte : "---			current_ammo_clip : Nombre de munitions restantes dans l'arme (-1 = illimit�)."
	puts $dbfile_ID [::msgcat::mc m88]
	# Texte : "---			remaining_ammo_clips : Nombre de chargeurs restants (-1 = illimit�)."
	puts $dbfile_ID [::msgcat::mc m89]
	# Texte : "---			xp : Nombre de points d'exp�rience acquis."
	puts $dbfile_ID [::msgcat::mc m90]
	# Texte : "---			ducks_shot : Nombre de canards abattus."
	puts $dbfile_ID [::msgcat::mc m91]
	# Texte : "---			missed_shots : Nombre de tirs manqu�s (inclut les accidents de chasse)."
	puts $dbfile_ID [::msgcat::mc m92]
	# Texte : "---			empty_shots : Nombre de tentatives de tir sans aucune balle dans le chargeur."
	puts $dbfile_ID [::msgcat::mc m93]
	# Texte : "---			humans_shot : Nombre d'utilisateurs touch�s par accident."
	puts $dbfile_ID [::msgcat::mc m94]
	# Texte : "---			wild_shots : Nombre de tirs effectu�s sans qu'il y ait de canard en vol."
	puts $dbfile_ID [::msgcat::mc m95]
	# Texte : "---			bullets_received : Nombre de fois la cible lors d'un accident de chasse."
	puts $dbfile_ID [::msgcat::mc m96]
	# Texte : "---			deflected_bullets : Nombre de tirs accidentels d�fl�chis vers un autre utilisateur."
	puts $dbfile_ID [::msgcat::mc m97]
	# Texte : "---			deaths : Nombre de fois mort par balle."
	puts $dbfile_ID [::msgcat::mc m98]
	# Texte : "---			confiscated_weapons : Nombre d'armes confisqu�es."
	puts $dbfile_ID [::msgcat::mc m99]
	# Texte : "---			jammed_weapons : Nombre d'armes enray�es."
	puts $dbfile_ID [::msgcat::mc m100]
	# Texte : "---			best_time : Meilleur temps pour abattre un canard. (-1 = pas encore initialis�)"
	puts $dbfile_ID [::msgcat::mc m101]
	# Texte : "---			cumul_reflex_time : Temps de r�flexe cumul�."
	puts $dbfile_ID [::msgcat::mc m202]
	# Texte : "---			nick : Nom du joueur avec la casse de caract�res d'origine."
	puts $dbfile_ID [::msgcat::mc m203]
	# Texte : "---			items : Objets sp�ciaux poss�d�s par le joueur."
	puts $dbfile_ID [::msgcat::mc m203]
	# Texte : "---			golden_ducks : Nombre de super-canards abattus."
	puts $dbfile_ID [::msgcat::mc m272]
	# Texte : "---			last_activity : Date � laquelle le joueur a �t� actif pour la derni�re fois."
	puts $dbfile_ID [::msgcat::mc m423]
	puts $dbfile_ID "---"
	puts $dbfile_ID [::tcl::dict::get $::DuckHunt::player_data]
	close $dbfile_ID
	return
}

 ###############################################################################
### D�chargement de la base de donn�es de la m�moire apr�s v�rification qu'elle
### n'est plus en cours d'utilisation.
 ###############################################################################
proc ::DuckHunt::purge_db_from_memory {} {
 	incr ::DuckHunt::db_sessions -1
	if {
		(!$::DuckHunt::db_sessions)
		&& ([::tcl::info::exists ::DuckHunt::player_data])
	} then {
		unset ::DuckHunt::player_data
	}
}

 ###############################################################################
### Suivi des changements de nick effectu�s en pr�sence de l'Eggdrop afin de
### tenir � jour le nom des joueurs dans la base de donn�es.
 ###############################################################################
proc ::DuckHunt::nickchange_tracking {oldnick host hand chan newnick} {
	if {
		([channel get $chan DuckHunt])
		&& ([set lower_oldnick [::tcl::string::tolower $oldnick]] ne [set lower_newnick [::tcl::string::tolower $newnick]])
	} then {
		set regexpable_prefix [regsub -all {\W} $::DuckHunt::anonym_prefix {\\&}]
		if {
			($::DuckHunt::anonym_prefix ne "")
			&& (![regexp -nocase "^$regexpable_prefix\[0-9\]+$" $oldnick])
			&& ([regexp -nocase "^$regexpable_prefix\[0-9\]+$" $newnick])
		} then {
			return
		} else {
			set old_hash [md5 "$chan,$lower_oldnick"]
			set new_hash [md5 "$chan,$lower_newnick"]
			::DuckHunt::read_database
			if { [::tcl::dict::exists $::DuckHunt::player_data $chan] } {
				# Si $newnick a des stats, on note le changement de nick mais on n'op�re
				# pas le transfert ou la fusion maintenant.
				if { [::tcl::dict::exists $::DuckHunt::player_data $chan $lower_newnick] } {
					# On cr�e un array de la forme pending_transfers($new_hash)={$oldnick $newnick}
					# Le renommage ou la fusion ne seront op�r�s qu'au moment o� joueur
					# participera au jeu dans le but de r�duire les risques de vols de
					# scores.
					# Si une entr�e inverse existe d�j� dans l'array, on la supprime et on
					# n'en cr�e pas de nouvelle.
					if {
						([::tcl::info::exists ::DuckHunt::pending_transfers($old_hash)])
						&& ([lindex [::tcl::string::tolower $::DuckHunt::pending_transfers($old_hash)] 0] eq $lower_newnick)
					} then {
						unset ::DuckHunt::pending_transfers($old_hash)
					# Sinon, si deux entr�es peuvent �tre factoris�es, on le fait.
					} elseif { $old_hash in [array names ::DuckHunt::pending_transfers] } {
						set ::DuckHunt::pending_transfers($new_hash) $::DuckHunt::pending_transfers($old_hash)
						unset ::DuckHunt::pending_transfers($old_hash)
						if { $::DuckHunt::warn_on_rename } {
							# Message : "\00314\[%s - surveillance\]\017 \002%s\002 (%s) s'est renomm� en \002%s\002. \037Remarque\037 : des statistiques existent d�j� � ce nom sur %s."
							::DuckHunt::display_output loglev - -  [::msgcat::mc m139 $::DuckHunt::scriptname $oldnick [getchanhost $newnick] $newnick $chan]
						}
					# Sinon on ajoute simplement une entr�e.
					} else {
						set ::DuckHunt::pending_transfers($new_hash) [list $oldnick $newnick]
						if { $::DuckHunt::warn_on_rename } {
							# Message : "\00314\[%s - surveillance\]\017 \002%s\002 (%s) s'est renomm� en \002%s\002. \037Remarque\037 : des statistiques existent d�j� � ce nom sur %s."
							::DuckHunt::display_output loglev - -  [::msgcat::mc m139 $::DuckHunt::scriptname $oldnick [getchanhost $newnick] $newnick $chan]
						}
					}
				# Si $newnick n'a pas de stats, que $oldnick en avait et qu'aucune
				# entr�e n'existe � ce nom dans pending_transfers, on ajoute une entr�e.
				} elseif {
					([::tcl::dict::exists $::DuckHunt::player_data $chan $lower_oldnick])
					&& !([::tcl::info::exists ::DuckHunt::pending_transfers($old_hash)])
				} then {
					set ::DuckHunt::pending_transfers($new_hash) [list $oldnick $newnick]
				# Suppression d'une �ventuelle entr�e inverse dans pending_transfers.
				} elseif {
					([::tcl::info::exists ::DuckHunt::pending_transfers($old_hash)])
					&& ([lindex [::tcl::string::tolower $::DuckHunt::pending_transfers($old_hash)] 0] eq $lower_newnick)
				} then {
					unset ::DuckHunt::pending_transfers($old_hash)
				}
			}
			::DuckHunt::purge_db_from_memory
		}
		::DuckHunt::update_nickchange_tracking_db
	}
}

 ###############################################################################
### Mise � jour de $::DuckHunt::pending_transfers si l'utilisateur quitte le
### chan.
 ###############################################################################
proc ::DuckHunt::update_nickchange_tracking {nick host hand chan msg} {
	set hash [md5 "$chan,[::tcl::string::tolower $nick]"]
	if { [::tcl::info::exists ::DuckHunt::pending_transfers($hash)] } {
		unset ::DuckHunt::pending_transfers($hash)
	}
	::DuckHunt::update_nickchange_tracking_db
}

 ###############################################################################
### Mise � jour de la db contenant le suivi des changements de nick.
 ###############################################################################
proc ::DuckHunt::update_nickchange_tracking_db {} {
	set pending_transfers_file_ID [open $::DuckHunt::pending_transfers_file w]
	puts $pending_transfers_file_ID [array get ::DuckHunt::pending_transfers]
	close $pending_transfers_file_ID
}

 ###############################################################################
### V�rification des renommages / fusions de profils en attente.
 ###############################################################################
proc ::DuckHunt::ckeck_for_pending_rename {chan newnick lower_newnick nick_hash} {
	# Si le participant vient de changer de nick, on transf�re ses statistiques.
	if { [::tcl::info::exists ::DuckHunt::pending_transfers($nick_hash)] } {
		set lower_oldnick [::tcl::string::tolower [set oldnick [lindex $::DuckHunt::pending_transfers($nick_hash) 0]]]
		# Si $oldnick avait des stats, on effectue une fusion avec celles de
		# $newnick.
		if { [::tcl::dict::exists $::DuckHunt::player_data $chan $lower_oldnick] } {
			foreach varname {gun jammed current_ammo_clip remaining_ammo_clips xp ducks_shot missed_shots empty_shots humans_shot wild_shots bullets_received deflected_bullets deaths confiscated_weapons jammed_weapons best_time cumul_reflex_time nick items golden_ducks_shot last_activity} {
				lappend src_stats [::DuckHunt::get_data $lower_oldnick $chan $varname]
				lappend dst_stats [::DuckHunt::get_data $lower_newnick $chan $varname]
			}
			# Si l'arme de newnick est confisqu�e mais pas celle de oldnick, alors les
			# stats de oldnick ne seront pas conserv�es.
			if {
				($::DuckHunt::confiscation_enforcement_on_fusion)
				&& ([::DuckHunt::get_data $lower_newnick $chan "gun"] < 1)
				&& ([::DuckHunt::get_data $lower_oldnick $chan "gun"] == 1)
			} then {
				if { $::DuckHunt::warn_on_takeover } {
					# Message : "\00314\[%s - surveillance\]\017 \002%s\002 (%s) s'est renomm� en \002%s\002. Des statistiques existent pour les deux noms mais puisque %s est d�sarm�, %s devrait �galement l'�tre. Pour cette raison, les statistiques de %s n'ont pas �t� conserv�es : \{%s\}"
					::DuckHunt::display_output loglev - - [::msgcat::mc m245 $::DuckHunt::scriptname $oldnick [getchanhost $newnick] $newnick $newnick $oldnick $oldnick $src_stats]
					if { $::DuckHunt::hunting_logs } {
						::DuckHunt::add_to_log $chan [unixtime] $oldnick - $newnick - "merge_stats_1" 0 [list $src_stats $dst_stats $dst_stats]
					}
				}
				::tcl::dict::unset ::DuckHunt::player_data $chan $lower_oldnick
			# Si aucun des deux joueurs n'a d'arme, on ne conserve que les stats de
			# celui qui a le plus d'xp.
			} elseif {
				($::DuckHunt::confiscation_enforcement_on_fusion)
				&& ([::DuckHunt::get_data $lower_newnick $chan "gun"] < 1)
				&& ([::DuckHunt::get_data $lower_oldnick $chan "gun"] < 1)
			} then {
				if { [::DuckHunt::get_data $lower_newnick $chan "xp"] >= [::DuckHunt::get_data $lower_oldnick $chan "xp"] } {
					if { $::DuckHunt::warn_on_takeover } {
						# Message : "\00314\[%s - surveillance\]\017 \002%s\002 (%s) s'est renomm� en \002%s\002. Des statistiques existent pour les deux noms mais puisque les deux joueurs sont d�sarm�s, seules les statistiques du joueur ayant le plus d'xp seront conserv�es. Pour cette raison, les statistiques de %s n'ont pas �t� conserv�es : \{%s\}"
						::DuckHunt::display_output loglev - - [::msgcat::mc m246 $::DuckHunt::scriptname $oldnick [getchanhost $newnick] $newnick $oldnick $src_stats]
						if { $::DuckHunt::hunting_logs } {
							::DuckHunt::add_to_log $chan [unixtime] $oldnick - $newnick - "merge_stats_2" 0 [list $src_stats $dst_stats $dst_stats]
						}
					}
					::tcl::dict::unset ::DuckHunt::player_data $chan $lower_oldnick
				} else {
					if { $::DuckHunt::warn_on_takeover } {
						# Message : "\00314\[%s - surveillance\]\017 \002%s\002 (%s) s'est renomm� en \002%s\002. Des statistiques existent pour les deux noms mais puisque les deux joueurs sont d�sarm�s, seules les statistiques du joueur ayant le plus d'xp seront conserv�es. Pour cette raison, les statistiques de %s n'ont pas �t� conserv�es : \{%s\}"
						::DuckHunt::display_output loglev - - [::msgcat::mc m246 $::DuckHunt::scriptname $oldnick [getchanhost $newnick] $newnick $newnick $dst_stats]
						if { $::DuckHunt::hunting_logs } {
							::DuckHunt::add_to_log $chan [unixtime] $oldnick - $newnick - "merge_stats_2" 0 [list $src_stats $dst_stats $src_stats]
						}
					}
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_newnick [::tcl::dict::get $::DuckHunt::player_data $chan $lower_oldnick]
					::tcl::dict::set ::DuckHunt::player_data $chan $lower_newnick "nick" $newnick
					::tcl::dict::unset ::DuckHunt::player_data $chan $lower_oldnick	
				}
			} else {
				if { $::DuckHunt::warn_on_takeover } {
					# Texte : "\00314\[%s - surveillance\]\017 \002%s\002 (%s) s'est renomm� en \002%s\002. Des statistiques existent pour les deux noms et ont �t� fusionn�es. Etat avant fusion : %s \{%s\} / %s \{%s\}. Ce message s'affiche afin de vous sensibiliser � la possibilit� de l'appropriation ill�gitime de stats appartenant � autrui."
					::DuckHunt::display_output loglev - - [::msgcat::mc m102 $::DuckHunt::scriptname $oldnick [getchanhost $newnick] $newnick $oldnick $src_stats $newnick $dst_stats]
				}
				::DuckHunt::merge_stats $chan $oldnick $lower_oldnick $newnick $lower_newnick $src_stats $dst_stats 0
			}
			::DuckHunt::recalculate_ammo_on_lvl_change $lower_newnick $chan
			::DuckHunt::write_database
		# Si $oldnick n'avait pas de stats, on signale la r�attribution en PL.
		} elseif { [::tcl::dict::exists $::DuckHunt::player_data $chan $lower_newnick] } {
			foreach varname {gun jammed current_ammo_clip remaining_ammo_clips xp ducks_shot missed_shots empty_shots humans_shot wild_shots bullets_received deflected_bullets deaths confiscated_weapons jammed_weapons best_time cumul_reflex_time nick items golden_ducks_shot last_activity} {
				lappend dst_stats [::DuckHunt::get_data $lower_newnick $chan $varname]
			}
			if { $::DuckHunt::warn_on_takeover } {
				# Texte : "\00314\[%s - surveillance\]\017 \002%s\002 (%s) s'est renomm� en \002%s\002. Des statistiques sont enregistr�es au nom de %s, mais pas au nom de %s; veuillez vous assurer qu'il s'agit bien de la m�me personne. Etat actuel des stats : %s \{%s\}. Ce message s'affiche afin de vous sensibiliser � la possibilit� de l'appropriation ill�gitime de stats appartenant � autrui."
				::DuckHunt::display_output loglev - - [::msgcat::mc m127 $::DuckHunt::scriptname $oldnick [getchanhost $newnick] $newnick $newnick $oldnick $newnick $dst_stats]
				if { $::DuckHunt::hunting_logs } {
					::DuckHunt::add_to_log $chan [unixtime] $oldnick - $newnick - "merge_stats_3" 0 [list {} $dst_stats $dst_stats]
				}
			}
		}
		unset ::DuckHunt::pending_transfers($nick_hash)
		::DuckHunt::update_nickchange_tracking_db
	}
}

 ###############################################################################
### Fusionne les statistiques d'un joueur avec celles d'un autre.
 ###############################################################################
proc ::DuckHunt::merge_stats {chan src_nick lower_src_nick dst_nick lower_dst_nick args} {
	foreach varname {xp ducks_shot golden_ducks_shot missed_shots empty_shots humans_shot wild_shots bullets_received deflected_bullets deaths confiscated_weapons jammed_weapons cumul_reflex_time} {
		set $varname [expr {[::DuckHunt::get_data $lower_src_nick $chan $varname] + [::DuckHunt::get_data $lower_dst_nick $chan $varname]}]
	}
	set gun [expr {min([::DuckHunt::get_data $lower_src_nick $chan "gun"],[::DuckHunt::get_data $lower_dst_nick $chan "gun"])}]
	set jammed [expr {max([::DuckHunt::get_data $lower_src_nick $chan "jammed"],[::DuckHunt::get_data $lower_dst_nick $chan "jammed"])}]
	# On d�termine le nombre de munitions utilis�es par chacun depuis le dernier
	# r�approvisionnement, en supposant que les armes �taient charg�es au d�part
	# (impossible � v�rifier).
	# Le nombre total de munitions utilis�es est ensuite d�duit du nombre maximum
	# de munitions du profil de destination.
	lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_src_nick $chan "xp"]] {} {} {} {} {} {} src_ammos_per_clip src_ammo_clips
	lassign [::DuckHunt::get_level_and_grantings [::DuckHunt::get_data $lower_dst_nick $chan "xp"]] {} {} {} {} {} {} dst_ammos_per_clip dst_ammo_clips
	set merged_full_ammo [expr {($src_ammos_per_clip * $src_ammo_clips) + $src_ammos_per_clip + ($dst_ammos_per_clip * $dst_ammo_clips) + $dst_ammos_per_clip}]
	set src_ammo_in_clips [expr {([::DuckHunt::get_data $lower_src_nick $chan "remaining_ammo_clips"] * $src_ammos_per_clip)}]
	set src_ammo_in_gun [::DuckHunt::get_data $lower_src_nick $chan "current_ammo_clip"]
	set dst_ammo_in_clips [expr {([::DuckHunt::get_data $lower_dst_nick $chan "remaining_ammo_clips"] * $dst_ammos_per_clip)}]
	set dst_ammo_in_gun [::DuckHunt::get_data $lower_dst_nick $chan "current_ammo_clip"]
	set used_ammo [expr {$merged_full_ammo - $src_ammo_in_clips - $src_ammo_in_gun - $dst_ammo_in_clips - $dst_ammo_in_gun}]
	lassign [::DuckHunt::get_level_and_grantings $xp] {} {} {} {} {} {} resulting_ammos_per_clip resulting_ammo_clips
	set current_ammo_clip [expr {$resulting_ammos_per_clip - ($used_ammo % $resulting_ammos_per_clip)}]
	set remaining_ammo_clips [expr {$resulting_ammo_clips - int($used_ammo / [format "%.1f" $resulting_ammos_per_clip])}]
	if { $remaining_ammo_clips < 0 } {
		set remaining_ammo_clips 0
		set current_ammo_clip 0
	}
	if { [::DuckHunt::get_data $lower_src_nick $chan "best_time"] == -1 } {
		set best_time [::DuckHunt::get_data $lower_dst_nick $chan "best_time"]
	} elseif { [::DuckHunt::get_data $lower_dst_nick $chan "best_time"] == -1 } {
		set best_time [::DuckHunt::get_data $lower_src_nick $chan "best_time"]
	} else {
		set best_time [expr {min([::DuckHunt::get_data $lower_src_nick $chan "best_time"],[::DuckHunt::get_data $lower_dst_nick $chan "best_time"])}]
	}
	set nick [::DuckHunt::get_data $lower_dst_nick $chan "nick"]
	set items [lsort -unique -index 1 [lsort -dictionary -index 0 [concat [::DuckHunt::get_data $lower_src_nick $chan "items"] [::DuckHunt::get_data $lower_dst_nick $chan "items"]]]]
	set last_activity [expr {max([::DuckHunt::get_data $lower_src_nick $chan "last_activity"],[::DuckHunt::get_data $lower_dst_nick $chan "last_activity"])}]
	::tcl::dict::set ::DuckHunt::player_data $chan $lower_dst_nick [::tcl::dict::create "gun" $gun "jammed" $jammed "current_ammo_clip" $current_ammo_clip "remaining_ammo_clips" $remaining_ammo_clips "xp" $xp "ducks_shot" $ducks_shot "missed_shots" $missed_shots "empty_shots" $empty_shots "humans_shot" $humans_shot "wild_shots" $wild_shots "bullets_received" $bullets_received "deflected_bullets" $deflected_bullets "deaths" $deaths "confiscated_weapons" $confiscated_weapons "jammed_weapons" $jammed_weapons "best_time" $best_time "cumul_reflex_time" $cumul_reflex_time "nick" $nick "items" $items "golden_ducks_shot" $golden_ducks_shot "last_activity" $last_activity]
	::tcl::dict::unset ::DuckHunt::player_data $chan $lower_src_nick
	if { $::DuckHunt::hunting_logs } {
		lassign $args src_stats dst_stats is_manual
		if { $is_manual } {
			::DuckHunt::add_to_log $chan [unixtime] $src_nick - $dst_nick - "merge_stats_5" 0 [list $src_stats $dst_stats [list $gun $jammed $current_ammo_clip $remaining_ammo_clips $xp $ducks_shot $missed_shots $empty_shots $humans_shot $wild_shots $bullets_received $deflected_bullets $deaths $confiscated_weapons $jammed_weapons $best_time $cumul_reflex_time $items $golden_ducks_shot $last_activity]]
		} else {
			::DuckHunt::add_to_log $chan [unixtime] $src_nick - $dst_nick - "merge_stats_4" 0 [list $src_stats $dst_stats [list $gun $jammed $current_ammo_clip $remaining_ammo_clips $xp $ducks_shot $missed_shots $empty_shots $humans_shot $wild_shots $bullets_received $deflected_bullets $deaths $confiscated_weapons $jammed_weapons $best_time $cumul_reflex_time $items $golden_ducks_shot $last_activity]]
		}
	}
}

 ###############################################################################
### Affichage d'un texte, filtrage des styles si n�cessaire.
### * queue peut valoir help, quick, now, serv, dcc, log ou loglev
### * method peut valoir PRIVMSG ou NOTICE et sera ignor� si queue vaut dcc ou
###      loglev
### * target peut �tre un nick, un chan ou un idx, et sera ignor� si queue vaut
###      loglev
 ###############################################################################
proc ::DuckHunt::display_output {queue method target text} {
	if {
		($::DuckHunt::monochrome)
		|| (!([::tcl::string::first "#" $target])
		&& ([::tcl::string::match *c* [lindex [split [getchanmode $target]] 0]]))
		|| (($queue eq "dcc")
		&& (![matchattr [idx2hand $target] h]))
	} then {
		# Remarque : l'aller-retour d'encodage permet de contourner un bug d'Eggdrop
		# qui corromp le charset dans certaines conditions lors de l'utilisation de
		# regsub sur une cha�ne de caract�res.
		regsub -all "\017" [stripcodes abcgru [encoding convertto utf-8 [encoding convertfrom utf-8 $text]]] "" text
	}
	switch -- $queue {
		help - quick - now - serv {
			foreach line [::DuckHunt::split_line $text $::DuckHunt::max_line_length] {
				put$queue "$method $target :$line"
			}
		}
		dcc {
			foreach line [::DuckHunt::split_line $text $::DuckHunt::max_line_length] {
				putdcc $target $line
			}
		}
		loglev {
			foreach line [::DuckHunt::split_line $text $::DuckHunt::max_line_length] {
				putloglev o * $line
			}
		}
		log {
			foreach line [::DuckHunt::split_line $text $::DuckHunt::max_line_length] {
				putlog $line
			}
		}
	}
}

 ###############################################################################
### D�coupage d'une ligne trop longue en plusieurs lignes en essayant de couper
### sur les espaces autant que possible. Si l'espace le plus proche est � plus
### de 50% de la fin de la ligne, on s'autorise � couper au milieu d'un mot.
### Les \n provoquent un retour forc� � la ligne et les styles (couleurs, gras,
### ...) sont pr�serv�s d'une ligne � l'autre.
### $limit doit �tre >= 9
### Remerciements � ealexp pour la fonction de pr�servation des styles.
 ###############################################################################
proc ::DuckHunt::split_line {data limit} {
	incr limit -1
	if { [::tcl::string::length $data] <= $limit } {
		return [expr {$data eq "" ? [list ""] : [split $data "\n"]}]
	} else {
		# Note : si l'espace le plus proche est situ� � plus de 50% de la fin du
		# fragment, on n'h�site pas � couper au milieu d'un mot.
		set middle_pos [expr round($limit / 2.0)]
		set output ""
		while {1} {
			if {
				([set cut_index [::tcl::string::first "\n" $data]] != -1)
				&& ($cut_index <= $limit)
			} then {
				# On ne fait rien de plus, on vient de d�finir $cut_index.
			} elseif {
				([set cut_index [::tcl::string::last " " $data [expr {$limit + 1}]]] == -1)
				|| ($cut_index < $middle_pos)
			} then {
				set new_cut_index -1
				# On v�rifie qu'on ne va pas couper dans la d�finition d'une couleur.
				for { set i 0 } { $i < 6 } { incr i } {
					if {
						([::tcl::string::index $data [set test_cut_index [expr {$limit - $i}]]] eq "\003")
						&& ([regexp {^\003([0-9]{1,2}(,[0-9]{1,2})?)} [::tcl::string::range $data $test_cut_index end]])
					} then {
						set new_cut_index [expr {$test_cut_index - 1}]
					}
				}
				set cut_index [expr {($new_cut_index == -1) ? ($limit) : ($new_cut_index)}]
			}
			set new_part [::tcl::string::range $data 0 $cut_index]
			set data [::tcl::string::range $data $cut_index+1 end]
			if { [::tcl::string::trim [::tcl::string::map [list \002 {} \037 {} \026 {} \017 {}] [regsub -all {\003([0-9]{0,2}(,[0-9]{0,2})?)?} $new_part {}]]] ne "" } {
				lappend output [::tcl::string::trimright $new_part]
			} 
			# Si, quand on enl�ve les espaces et les codes de formatage, il ne reste
			# plus rien, pas la peine de continuer.
			if { [::tcl::string::trim [::tcl::string::map [list \002 {} \037 {} \026 {} \017 {}] [regsub -all {\003([0-9]{0,2}(,[0-9]{0,2})?)?} $data {}]]] eq "" } {
				break
			}
			set taglist [regexp -all -inline {\002|\003(?:[0-9]{0,2}(?:,[0-9]{0,2})?)?|\037|\026|\017} $new_part]
			# Etat des tags "au repos"; les -1 signifient que la couleur est celle par
			# d�faut.
			set bold 0 ; set underline 0 ; set italic 0 ; set foreground_color "-1" ; set background_color "-1" 
			foreach tag $taglist {
				if {$tag eq ""} {
					continue
				}
				switch -- $tag {
					"\002" {
						if { !$bold } {
							set bold 1
						} else {
							set bold 0
						}
					}
					"\037" {
						if { !$underline } {
							set underline 1
						} else {
							set underline 0
						}
					}
					"\026" {
						if { !$italic } {
							set italic 1
						} else {
							set italic 0
						}
					}
					"\017" {
						set bold 0
						set underline 0
						set italic 0
						set foreground_color -1
						set background_color -1
					}
					default {
						lassign [split [regsub {\003([0-9]{0,2}(,[0-9]{0,2})?)?} $tag {\1}] ","] foreground_color background_color
						if {$foreground_color eq ""} {
							set foreground_color -1 ; set background_color -1
						} elseif {
							($foreground_color < 10)
							&& ([::tcl::string::index $foreground_color 0] ne "0")
						} then {
							set foreground_color 0$foreground_color
						}
						if {$background_color eq ""} {
							set background_color -1
						} elseif {
							($background_color < 10)
							&& ([::tcl::string::index $background_color 0] ne "0")
						} then {
							set background_color 0$background_color
						}
					}
				}
			}
			set line_start ""
			if { $bold } {
				append line_start \002
			}
			if { $underline } {
				append line_start \037
			}
			if { $italic } {
				append line_start \026
			}
			if {
				($foreground_color != -1)
				&& ($background_color == -1)
			} then {
				append line_start \003$foreground_color
			}
			if {
				($foreground_color != -1)
				&& ($background_color != -1)
			} then {
				append line_start \003$foreground_color,$background_color
			}
			set data ${line_start}$data
		}
		return $output
	}
}

 ###############################################################################
### Flood control.
### - focus can be "chan" or "nick" and will differentiate a control from flood
### collective where orders will be blocked for everyone, from one
### individual control where orders will be blocked for a single individual.
### - command can be "*" or the name of a command and will differentiate a
### control by command or all script commands combined.
### - limit is expressed as "xx:yy", where xx = maximum number of
### requests and yy = duration of an instance.
 ###############################################################################
proc ::DuckHunt::antiflood {nick chan focus command limit} {
	lassign [split $limit ":"] max_instances instance_length
	if { $focus eq "chan" } {
		set hash [md5 "$chan,$command"]
	} else {
		set hash [md5 "$nick,$chan,$command"]
	}
	# L'antiflood est dans un statut neutre, on l'initialise.
	if { ![::tcl::info::exists ::DuckHunt::instance($hash)] } {
		set ::DuckHunt::instance($hash) 0
		set ::DuckHunt::antiflood_msg($hash) 0
	}
	if { $::DuckHunt::instance($hash) >= $max_instances } {
		if { $::DuckHunt::preferred_display_mode == 1 } {
			set output_method "PRIVMSG"
			set output_target $chan
		} else {
			set output_method "NOTICE"
			set output_target $nick
		}
		if { !$::DuckHunt::antiflood_msg($hash) } {
			set ::DuckHunt::antiflood_msg($hash) 2
			if { $command eq "*" } {
				if { $focus eq "chan" } {
					# Message : "\00304:::\003 \00314Contr�le de flood activ� pour toutes les commandes du script %s : pas plus de %s %s toutes les %s %s.\003"
					# Textes : "requ�te" "requ�tes" "seconde" "secondes"
					::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m103 $::DuckHunt::scriptname $max_instances [::DuckHunt::plural $max_instances [::msgcat::mc m104] [::msgcat::mc m105]] $instance_length [::DuckHunt::plural $instance_length [::msgcat::mc m106] [::msgcat::mc m107]]]
				} else {
					# Message : "\00304:::\003 \00314Contr�le de flood activ� pour %s sur toutes les commandes du script %s : pas plus de %s %s toutes les %s %s.\003"
					# Textes : "requ�te" "requ�tes" "seconde" "secondes"
					::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m421 $nick $::DuckHunt::scriptname $max_instances [::DuckHunt::plural $max_instances [::msgcat::mc m104] [::msgcat::mc m105]] $instance_length [::DuckHunt::plural $instance_length [::msgcat::mc m106] [::msgcat::mc m107]]]
				}
			} else {
				if { $focus eq "chan" } {
					# Message : "\00304:::\003 \00314Contr�le de flood activ� pour la commande \"%s\" : pas plus de %s %s toutes les %s %s.\003"
					# Textes : "requ�te" "requ�tes" "seconde" "secondes"
					::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m108 $command $max_instances [::DuckHunt::plural $max_instances [::msgcat::mc m104] [::msgcat::mc m105]] $instance_length [::DuckHunt::plural $instance_length [::msgcat::mc m106] [::msgcat::mc m107]]]
				} else {
					# Message : "\00304:::\003 \00314Contr�le de flood activ� pour %s sur la commande \"%s\" : pas plus de %s %s toutes les %s %s.\003"
					# Textes : "requ�te" "requ�tes" "seconde" "secondes"
					::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m273 $nick $command $max_instances [::DuckHunt::plural $max_instances [::msgcat::mc m104] [::msgcat::mc m105]] $instance_length [::DuckHunt::plural $instance_length [::msgcat::mc m106] [::msgcat::mc m107]]]
				}
			}
			if { [set msgresettimer [::DuckHunt::utimerexists "::DuckHunt::antiflood_msg_reset $hash"]] ne ""} {
				killutimer $msgresettimer
			}
			utimer $::DuckHunt::antiflood_msg_interval [list ::DuckHunt::antiflood_msg_reset $hash]
		} elseif { $::DuckHunt::antiflood_msg($hash) == 1 } {
			set ::DuckHunt::antiflood_msg($hash) 2
			if { $command eq "*" } {
				# Message : "\00304:::\003 \00314Le contr�le de flood est toujours actif, merci de patienter.\003"
				::DuckHunt::display_output help PRIVMSG $chan [::msgcat::mc m109]
			} else {
				# Message : "\00304:::\003 \00314Le contr�le de flood est toujours actif, merci de patienter.\003"
				::DuckHunt::display_output help $output_method $output_target [::msgcat::mc m109]
			}
			if { [set msgresettimer [::DuckHunt::utimerexists "::DuckHunt::antiflood_msg_reset $hash"]] ne ""} {
				killutimer $msgresettimer
			}
			utimer $::DuckHunt::antiflood_msg_interval [list ::DuckHunt::antiflood_msg_reset $hash]
		}
		return "1"
	} else {
		incr ::DuckHunt::instance($hash) 1
		utimer $instance_length [list ::DuckHunt::antiflood_close_instance $hash]
		return "0"
	}
}
proc ::DuckHunt::antiflood_close_instance {hash} {
	incr ::DuckHunt::instance($hash) -1
	# si le nombre d'instances retombe � 0, on efface les variables instance et
	# antiflood_msg afin de ne pas encombrer la m�moire inutilement
	if { $::DuckHunt::instance($hash) == 0 } {
		unset ::DuckHunt::instance($hash)
		unset ::DuckHunt::antiflood_msg($hash)
	# le nombre d'instances est retomb� en dessous du seuil critique, on
	# r�initialise antiflood_msg
	} else {
		set ::DuckHunt::antiflood_msg($hash) 0
		if { [set msgresettimer [::DuckHunt::utimerexists "::DuckHunt::antiflood_msg_reset $hash"]] ne ""} {
			killutimer $msgresettimer
		}
	}
	return
}
proc ::DuckHunt::antiflood_msg_reset {hash} {
	set ::DuckHunt::antiflood_msg($hash) 1
	return
}

 ###############################################################################
### Formatting a decimal number.
### Precision determines how many decimal places to keep.
### Trailing 0s will be removed.
 ###############################################################################
proc ::DuckHunt::format_floating_point_value {value precision} {
	return [::tcl::string::trimright [::tcl::string::trimright [format "%.${precision}f" $value] 0] "."]
}

 ###############################################################################
### Test for the existence of a user, return its ID
 ###############################################################################
proc ::DuckHunt::utimerexists {command} {
	foreach utimer_ [utimers] {
		if { ![::tcl::string::compare $command [lindex $utimer_ 1]] } {
			return [lindex $utimer_ 2]
		}
	}
}

 ###############################################################################
### Test for the existence of a timer, return its ID
 ###############################################################################
proc ::DuckHunt::timerexists {command} {
	foreach timer_ [timers] {
		if { ![::tcl::string::compare $command [lindex $timer_ 1]] } {
			return [lindex $timer_ 2]
		}
	}
}

 ###############################################################################
### Transforms a time in milliseconds into a readable time with a resolution
### dynamic.
 ###############################################################################
proc ::DuckHunt::adapt_time_resolution {duration short} {
	set milliseconds [::tcl::string::range $duration end-2 end]
	set duration [::tcl::string::range $duration 0 end-3]
	if { $duration eq "" } {
		set duration 0
	}
	set days [expr {abs($duration / 86400)}]
	set hours [expr {abs(($duration % 86400) / 3600)}]
	set minutes [expr {abs(($duration % 3600) / 60)}]
	set seconds [expr {$duration % 60}]
	set valid_units 0
	set counter 1
	set output {}
	foreach unit [list $days $hours $minutes $seconds] {
		if {
			($unit > 0)
			|| ($counter == 4)
		} then {
			switch -- $counter {
				1 {
					if { !$short } {
						# Textes : "jour" "jours"
						lappend output "$unit [::DuckHunt::plural $unit [::msgcat::mc m110] [::msgcat::mc m111]]"
					} else {
						# Texte : "j"
						lappend output "${unit}[::msgcat::mc m112]"
					}
				}
				2 {
					if { !$short } {
						# Textes : "heure" "heures"
						lappend output "$unit [::DuckHunt::plural $unit [::msgcat::mc m113] [::msgcat::mc m114]]"
					} else {
						# Texte : "h"
						lappend output "${unit}[::msgcat::mc m115]"
					}
				}
				3 {
					if { !$short } {
						# Textes : "minute" "minutes"
						lappend output "$unit [::DuckHunt::plural $unit [::msgcat::mc m116] [::msgcat::mc m117]]"
					} else {
						# Texte : "mn"
						lappend output "${unit}[::msgcat::mc m118]"
					}
				}
				4 {
					if { [set milliseconds [::tcl::string::trimright $milliseconds 0]] == "" } {
						set show_ms 0
					} else {
						set show_ms 1
					}
					if { $show_ms } {
						if { !$short } {
							# Textes : "seconde" "secondes"
							lappend output "${unit}.$milliseconds [::DuckHunt::plural "${unit}$milliseconds" [::msgcat::mc m106] [::msgcat::mc m107]]"
						} else {
							# Texte : "s"
							lappend output "${unit}.${milliseconds}[::msgcat::mc m119]"
						}
					} else {
							if { !$short } {
								# Textes : "seconde" "secondes"
							lappend output "$unit [::DuckHunt::plural $unit [::msgcat::mc m106] [::msgcat::mc m107]]"
						} else {
							# Texte : "s"
							lappend output "$unit[::msgcat::mc m119]"
						}
					}
				}
			}
			incr valid_units
		}
		incr counter
	}
	if { !$short } {
		if { $valid_units > 1 } {
			# Texte "et"
			set output [linsert $output end-1 [::msgcat::mc m120]]
		}
		return [join $output]
	} else {
		return [join $output ""]
	}
}

 ###############################################################################
### Corrected the case of characters in the name of a chan.
 ###############################################################################
proc ::DuckHunt::fix_chan_case {chan} {
	if { [validchan $chan] } {
		return [lindex [set chanlist [channels]] [lsearch -nocase -exact $chanlist $chan]]
	} else {
		return $chan
	}
}

 ###############################################################################
### Returns a value in red if it is <= 0
 ###############################################################################
proc ::DuckHunt::colorize_value {value} {
	if { $value <= 0 } {
		return "\00304$value\003"
	} else {
		return $value
	}
}

 ###############################################################################
### Matches singular or plural.
 ###############################################################################
proc ::DuckHunt::plural {value singular plural} {
	if {
		($value >= 2)
		|| ($value <= -2)
	} then {
		return $plural
	} else {
		return $singular
	}
}

 ###############################################################################
### Randomly shuffles the elements of a list.
 ###############################################################################
proc ::DuckHunt::randomize_list {data} {
   set list_length [llength $data]
   for { set counter 1 } { $counter <= $list_length } { incr counter } {
      set index [rand [expr {$list_length - $counter + 1}]]
      lappend randomized_list [lindex $data $index]
      set data [lreplace $data $index $index]
   }
   return $randomized_list
}

 ###############################################################################
### Daily database backup.
 ###############################################################################
proc ::DuckHunt::backup_db {min hour day month year} {
	# Message: "\00314\[%s\]\003 Backing up database..."
	::DuckHunt::display_output loglev - - [::msgcat::mc m121 $::DuckHunt::scriptname]
	if { [file exists $::DuckHunt::db_file] } {
		file copy -force -- $::DuckHunt::db_file "${::DuckHunt::db_file}.bak"
	}
}

 ###############################################################################
### Post-initialisation.
 ###############################################################################
# Rereading the nick change tracking database.
if {
	([file exists $::DuckHunt::pending_transfers_file])
	&& ([file mtime $::DuckHunt::pending_transfers_file] + $::DuckHunt::pending_transfers_file_max_age > [unixtime])
} then {
	set ::DuckHunt::pending_transfers_file_ID [open $::DuckHunt::pending_transfers_file r]
	array set ::DuckHunt::pending_transfers [gets $::DuckHunt::pending_transfers_file_ID]
	close $::DuckHunt::pending_transfers_file_ID
	unset ::DuckHunt::pending_transfers_file_ID
}
if { $::DuckHunt::method == 2 } {
	set ::DuckHunt::binds_tables {}
	utimer $::DuckHunt::post_init_delay ::DuckHunt::post_init
} elseif { $::DuckHunt::shop_enabled } {
	bind time - "* * * * *" ::DuckHunt::check_for_expired_pieces_of_bread
}
proc ::DuckHunt::post_init {} {
	::DuckHunt::plan_out_flights
	if { $::DuckHunt::shop_enabled } {
		bind time - "* * * * *" ::DuckHunt::check_for_expired_pieces_of_bread
	}
	set ::DuckHunt::post_init_done 1	
}


 ###############################################################################
### help Msg
 ###############################################################################
proc ::DuckHunt::help_cmd {nick host hand arg} {
    set output_method "PRIVMSG"
	lassign [set args [split [::tcl::string::trim $arg]]] fullHelp 
	if { $fullHelp != "full" } then {
        ::DuckHunt::display_output help $output_method $nick "To get a more detailed list use 'help full'"
        ::DuckHunt::display_output help $output_method $nick "\00307Channel commands\003: $::DuckHunt::shooting_cmd, $::DuckHunt::reload_cmd, $::DuckHunt::lastduck_pub_cmd, $::DuckHunt::stat_cmd, $::DuckHunt::topDuck_cmd, $::DuckHunt::shop_cmd"              
    } else {
        # ::DuckHunt::display_output help NOTICE $nick "\00307Channel commands\003"
        ::DuckHunt::display_output help $output_method $nick "\00307Channel commands\003"
        ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::shooting_cmd:\002\003 Command used to shoot a duck. Don\’t forget that sometimes, mistakes happen and you can miss the ducks… Or worse. Alts: !meow, !bef, !weed" 
        ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::reload_cmd:\002\003 Reloads or unjams your weapon. You must have chargers left if you want to reload. They are given back for free everyday, but you can also buy them in the shop."
        ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::lastduck_pub_cmd:\002\003 	Displays the last seen duck"
        ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::stat_cmd:\002\003 Gets your or another player hunting statistics."
        ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::topDuck_cmd:\002\003 Shows the top 5 players."
        ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::shop_cmd:\002\003 You can buy objects with the command !shop {item number} {possible arguments, such as the @target nickname} You need to have enough exp to buy an item."
    }
	
	if { $hand != "*" } then {
        set nickCanUnarm [matchattr $hand $::DuckHunt::unarm_auth ] 
        set nickCanRearm [matchattr $hand $::DuckHunt::rearm_auth ]
        set nickCanfindplayer [matchattr $hand $::DuckHunt::findplayer_auth ]
        set nickCanFuss [matchattr $hand $::DuckHunt::fusion_auth ]
        set nickCanRename [matchattr $hand $::DuckHunt::rename_auth ]
        set nickCanDel [matchattr $hand $::DuckHunt::delete_auth ]
        set nickCanLaunch [matchattr $hand $::DuckHunt::launch_auth ]
        set nickCanExport [matchattr $hand $::DuckHunt::export_auth ]
        set nickCanPlan [matchattr $hand $::DuckHunt::planning_auth ]
        set nickCanReplan [matchattr $hand $::DuckHunt::replanning_auth ]  

        if { $fullHelp != "full" } then { 
            set helpMsg {}

            if { $nickCanUnarm || $nickCanRearm } then { 
                lappend helpMsg "\00307Admin commands\003"
                if { $nickCanUnarm } then { 
                    lappend helpMsg "$::DuckHunt::unarm_cmd $::DuckHunt::unarm_cmd2"  
                    }
                if { $nickCanRearm } then { 
                    lappend helpMsg "$::DuckHunt::rearm_cmd" 
                    }
                }
            
            ::DuckHunt::display_output help $output_method $nick "[join $helpMsg]"

            set helpMsg {}
            if { $nickCanfindplayer || $nickCanFuss || $nickCanRename || $nickCanDel
                || $nickCanLaunch || $nickCanExport || $nickCanPlan || $nickCanReplan } then {
                    lappend helpMsg "\00307Admin commands to be sent to bot in a PRIVMSG\003"    
                }        
            if { $nickCanfindplayer } then { 
                lappend helpMsg "$::DuckHunt::findplayer_cmd"  
                }
            if { $nickCanFuss } then { 
                lappend helpMsg "$::DuckHunt::fusion_cmd"  
                }
            if { $nickCanRename } then { 
                lappend helpMsg "$::DuckHunt::rename_cmd"  
                }
            if { $nickCanDel } then { 
                lappend helpMsg "$::DuckHunt::delete_cmd"  
                }
            if { $nickCanLaunch } then { 
                lappend helpMsg "$::DuckHunt::launch_cmd"  
                }
            if { $nickCanExport } then { 
                lappend helpMsg "$::DuckHunt::export_cmd"  
                }
            if { $nickCanPlan } then { 
                lappend helpMsg "$::DuckHunt::planning_cmd"  
                }
            if { $nickCanReplan } then { 
                lappend helpMsg "$::DuckHunt::replanning_cmd"  
                }  
        ::DuckHunt::display_output help $output_method $nick "[join $helpMsg]" 

        } else {

            if { $nickCanUnarm || $nickCanRearm } then { 
                ::DuckHunt::display_output help $output_method $nick "\00307Admin commands\003"
                if { $nickCanUnarm } then { 
                    ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::unarm_cmd or $::DuckHunt::unarm_cmd2:\002\003 "  
                    }
                if { $nickCanRearm } then { 
                    ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::rearm_cmd:\002\003 " 
                    }
                }

            if { $nickCanfindplayer || $nickCanFuss || $nickCanRename || $nickCanDel
                || $nickCanLaunch || $nickCanExport || $nickCanPlan || $nickCanReplan } then {
                    ::DuckHunt::display_output help $output_method $nick "\00307Admin commands to be sent to bot in a PRIVMSG\003"    
                }        
            if { $nickCanfindplayer } then { 
                ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::findplayer_cmd:\002\003 "  
                }
            if { $nickCanFuss } then { 
                ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::fusion_cmd:\002\003 "  
                }
            if { $nickCanRename } then { 
                ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::rename_cmd:\002\003 "  
                }
            if { $nickCanDel } then { 
                ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::delete_cmd:\002\003 "  
                }
            if { $nickCanLaunch } then { 
                ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::launch_cmd:\002\003 "  
                }
            if { $nickCanExport } then { 
                ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::export_cmd:\002\003 "  
                }
            if { $nickCanPlan } then { 
                ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::planning_cmd:\002\003 "  
                }
            if { $nickCanReplan } then { 
                ::DuckHunt::display_output help $output_method $nick "\002\00310$::DuckHunt::replanning_cmd:\002\003 "  
                }     
        }

    }
}

 ###############################################################################
### Binds
 ###############################################################################
bind evnt - prerehash ::DuckHunt::uninstall
if { $::DuckHunt::method == 1 } {
	bind time - "* * * * *" ::DuckHunt::check_bushes_for_duck
} else {
	bind time - "00 00 * * *" ::DuckHunt::plan_out_flights
	bind msg $::DuckHunt::planning_auth $::DuckHunt::planning_cmd ::DuckHunt::show_planning
	bind msg $::DuckHunt::replanning_auth $::DuckHunt::replanning_cmd ::DuckHunt::replan_flights
}
if {
	($::DuckHunt::gun_hand_back_mode == 1)
	&& (($::DuckHunt::gun_confiscation_when_shooting_someone)
	|| ($::DuckHunt::gun_confiscation_on_wild_fire))
} then {
	bind time - "[lindex [split $::DuckHunt::auto_gun_hand_back_time ":"] 1] [lindex [split $::DuckHunt::auto_gun_hand_back_time ":"] 0] * * *" ::DuckHunt::hand_back_weapons
}
bind time - "[lindex [split $::DuckHunt::auto_refill_ammo_time ":"] 1] [lindex [split $::DuckHunt::auto_refill_ammo_time ":"] 0] * * *" ::DuckHunt::refill_ammo
bind time - "[lindex [split $::DuckHunt::backup_time ":"] 1] [lindex [split $::DuckHunt::backup_time ":"] 0] * * *" ::DuckHunt::backup_db
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_cmd ::DuckHunt::shoot
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_cmd2 ::DuckHunt::shoot
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_cmd3 ::DuckHunt::shoot
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_cmd4 ::DuckHunt::shoot
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_cmd5 ::DuckHunt::shoot
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_cmd6 ::DuckHunt::shoot
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_relay ::DuckHunt::shoot_relay
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_relay2 ::DuckHunt::shoot_relay
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_relay3 ::DuckHunt::shoot_relay
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_relay4 ::DuckHunt::shoot_relay
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_relay5 ::DuckHunt::shoot_relay
bind pub $::DuckHunt::shooting_auth $::DuckHunt::shooting_relay6 ::DuckHunt::shoot_relay
bind pub $::DuckHunt::reload_auth $::DuckHunt::reload_cmd ::DuckHunt::reload_gun
bind pub $::DuckHunt::lastduck_pub_auth $::DuckHunt::lastduck_pub_cmd ::DuckHunt::pub_show_last_duck
bind msg $::DuckHunt::lastduck_msg_auth $::DuckHunt::lastduck_msg_cmd ::DuckHunt::msg_show_last_duck
bind pub $::DuckHunt::stat_auth $::DuckHunt::stat_cmd ::DuckHunt::display_stats
bind pub $::DuckHunt::topDuck_auth $::DuckHunt::topDuck_cmd ::DuckHunt::display_topDuck

bind msg -|- help ::DuckHunt::help_cmd
bind pub $::DuckHunt::duckHelp_auth $::DuckHunt::duckHelp_cmd ::DuckHunt::display_duckHelp
if { $::DuckHunt::shop_enabled } {
	bind pub $::DuckHunt::shop_auth $::DuckHunt::shop_cmd ::DuckHunt::shop
}
bind pub $::DuckHunt::unarm_auth $::DuckHunt::unarm_cmd ::DuckHunt::unarm
bind pub $::DuckHunt::unarm_auth $::DuckHunt::unarm_cmd2 ::DuckHunt::unarm
bind pub $::DuckHunt::rearm_auth $::DuckHunt::rearm_cmd ::DuckHunt::rearm
bind msg $::DuckHunt::findplayer_auth $::DuckHunt::findplayer_cmd ::DuckHunt::findplayer
bind msg $::DuckHunt::fusion_auth $::DuckHunt::fusion_cmd ::DuckHunt::fusion
bind msg $::DuckHunt::rename_auth $::DuckHunt::rename_cmd ::DuckHunt::rename_player
bind msg $::DuckHunt::delete_auth $::DuckHunt::delete_cmd ::DuckHunt::delete_player
bind msg $::DuckHunt::launch_auth $::DuckHunt::launch_cmd ::DuckHunt::launch
bind msg $::DuckHunt::export_auth $::DuckHunt::export_cmd ::DuckHunt::export_players_table
bind nick -|- * ::DuckHunt::nickchange_tracking
bind part -|- * ::DuckHunt::update_nickchange_tracking
bind sign -|- * ::DuckHunt::update_nickchange_tracking





#	Message : "%s v%s (�2015-2016 Menz Agitat) a �t� charg�."
namespace eval ::DuckHunt {
	putlog [::msgcat::mc m1 $::DuckHunt::scriptname $::DuckHunt::version]
}
