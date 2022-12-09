#####################################################################
# Name:           xper_replaceChars
# Purpose:        replace all ocurrences of the string 'from' with 'to'
#                 in 'data'
# UPoC type:      other
#
# Known problem:  replacing a character by a string that includes the same
#                 character will result in an infinit loop.\
#
proc xper_replaceChars { from to data } {
    set from_len [string length $from]
    set from_pos 1
    while {$from_pos != -1} {
        set from_pos [string first $from $data]
        if { $from_pos != -1 } {
            set msg_start [csubstr $data 0 $from_pos]
            set msg_end   [csubstr $data [expr $from_pos + $from_len] end]
            set data $msg_start$to$msg_end
        }
    }
    return $data
}

#####################################################################
# Name:           xper_decrypt_mdp
# Purpose:        Procédure permettant de décrypter des mots de passe
# UPoC type:      other
#
#
proc xper_decrypt_mdp { password } {
    package require base64
    catch {exec hcicrypt decrypt $password} password
    set password  [::base64::decode $password]

    return $password
}


#####################################################################
# Name:           xper_resolve_gv
# Purpose:        Procédure permettant de résoudre les variables globales
# UPoC type:      other
#
#
proc xper_resolve_gv { gv_to_resolve } {
	global HciConnName
	package require Sitecontrol
	set cisversion $::env(HCIVERSION)
	if {$cisversion >= 6.2 } {
		set gv_pattern {(\$\$[a-zA-Z0-9_]*)}
		set gv_list ""; set gv_state 0; set gv_map ""; set gv_resolved "";
		set gv_list [regexp -inline $gv_pattern $gv_to_resolve]
		set gv_state [ llength $gv_list]
		if { $gv_state >= 0 } {
			foreach gv_element $gv_list {
				set gv_map [gvgetvar [string range $gv_element 2 end]]
				set gv_resolved [ string map [list $gv_element $gv_map] $gv_to_resolve ]
			}
		} else { 
			set gv_resolved $gv_to_resolve
		}
	} else {
		if { $gv_state >= 0 } {echo "Attention, votre version de cloverleaf, ne prend pas en charge la résolution des Variables Globales en tcl"}
		set gv_resolved $gv_to_resolve
		}
	return $gv_resolved
}