
######################################################################
# Name:     bdd_to_medimail_date_xltp
# Purpose:  <description>
# UPoC type: xltp
######################################################################

proc bdd_to_medimail_date_xltp {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName

    set inVal [lindex $xlateInVals 0]
    set outVal "";
    set lmin 0; catch {set lmin [lindex $xlateInVals 1]}
    if { $lmin != 0 && $lmin !="" } {
        set outVal [clock format [clock add [clock seconds] $lmin day] -format "%Y-%m-%dT%T"]
    } else {
        set outVal [clock format [clock scan $inVal -format "%Y-%m-%d %H:%M:%S"] -format "%Y-%m-%dT%T"]
    }
   
    set xlateOutVals [list $outVal]
}

######################################################################
# Name:     seconds_to_medimail_date_xltp
# Purpose:  <description>
# UPoC type: xltp
######################################################################

proc seconds_to_medimail_date_xltp {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName

    set metadata [xpmmetaget $xlateId USERDATA]

    set outVal "";
    set dateCheck [clock seconds]
    set outVal [clock format $dateCheck -format "%Y-%m-%dT%T"]
    set xlateOutVals [list $outVal]
    keylset metadata CHECK_DATE [clock format $dateCheck -format "%Y-%m-%d %T"]
    xpmmetaset $xlateId USERDATA $metadata
}

######################################################################
# Name:     xper_keep_content_medimail_ack
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc xper_keep_content_medimail_ack { args } {
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_keep_content_medimail_ack/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0 ; catch {keylget uargs DEBUG debug}
    set type "SEND" ; catch {keylget uargs TYPE type}
    set dispList {}

    echo xperis $mode
    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh
            set msg [msgget $mh]
            set msg [string map {\&lt\; <} $msg]

            switch $type {
                "OPEN" {
                    set result [regexp {(<webiopen.*</webiopen>)} $msg returnStr]
                }
                "CHECKBOX" {
                    set result [regexp {(<webicheckbox.*</webicheckbox>)} $msg returnStr]
                }
                default {
                    set result [regexp {(<webisend.*</webisend>)} $msg returnStr]
                }
            }

            if {$debug} {
                echo "msg after extraction : $returnStr"
            }
            
            if {$result} {
                msgset $mh $returnStr
            } else {
                msgset $mh $msg
            }

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

