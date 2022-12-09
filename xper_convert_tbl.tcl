######################################################################
# Name:     xper_tbl_to_csv
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc xper_tbl_to_csv { args } {
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_tbl_to_csv/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0 ; catch {keylget uargs DEBUG debug}
    set sepchar ";" ; catch {keylget uargs SEPCHAR sepchar}
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh
            #set msg [msgget $mh]
            set tableIn [msgget $mh]
            set tableIn [string map {"\r\n" "\n" "\t" "    "} $tableIn]
            set csvOut ""
            set csvTemp ""
            set i 0
            set firstLine 0
            set static 0
            foreach line [split $tableIn "\n"] {
                if {$i<12 && [regexp {type:.*tbl} $line]} { 
                    echo "Il s'agit bien d'une table statique, la conversion en csv est en cours"
                    set static 1
                }
                if {$i == 12 && !$static} {
                    echo "Il ne s'agit pas d'une table statique, la conversion en csv n'a eu pas lieu"
                    set csvTemp "Il ne s'agit pas d'une table statique, la conversion en csv n'a eu pas lieu"
                    }
                
                if { $i>12 && $static && ![cequal $line "encoded=0,0"] && ![cequal [string range $line 0 3] "dflt"]} {
                    
                    if {[cequal $line "#"]} {
                        if {$firstLine} {append csvTemp "\n"}
                        set firstLine 1
                    } else {
                        if {$firstLine} { append csvTemp $line $sepchar }
                    }
                }
                incr i
            }
            set csvOut $csvTemp
            msgset $mh $csvOut
            lappend dispList "CONTINUE $mh"
        }

        time {}
        shutdown {}
        default {
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}


######################################################################
# Name:     xper_csv_to_tbl
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc xper_csv_to_tbl { args } {
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_csv_to_tbl/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0 ; catch {keylget uargs DEBUG debug}
    set sepchar ";" ; catch {keylget uargs SEPCHAR sepchar}
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh
            #set msg [msgget $mh]
            set csvIn [msgget $mh]
            set csvIn [string map {"\r\n" "\n" "\r" "\n"} $csvIn]
            set tblOut ""
            set tblOut "prologue\n    type:   tbl\n    version:    3.0\nend_prologue\n#\ndflt=\n"

            foreach line [split $csvIn "\n"] {
                append tblOut "#\n"
                foreach elem [split $line $sepchar] {
                    append tblOut $elem "\n"
                }
            }

            msgset $mh $tblOut
            lappend dispList "CONTINUE $mh"
        }

        time {}
        shutdown {}
        default {
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}
