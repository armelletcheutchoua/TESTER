######################################################################
# Name:         enf_xmlAddDefaultNamespace
# Purpose:      Applications sends H'Prim XML files without the required default namespace
#               The required namespace is xmlns="http://www.hprim.org/hprimXML".
#               This script will add that namespace to the root node of the instance.
#               If it happens to be already present, this script will not readd it.
# UPoC type:    tps
# Args:       {DEBUG 0|1}(optional, default = 0)
# Returns: tps disposition list
# History: 1.0 2006-01-25 AH, E.Novation, cloverleaf@lifeline.nl
#              initial version

proc enf_xmlAddDefaultNamespace { args } {
    global HciConnName                             ;# Contains name of thread we're in
                                                   ;#  unless called in xlt context

    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch context we're in
    set uargs {} ; keylget args ARGS uargs         ;# Fetch userdefined args

    set debug 0       ; keylget uargs DEBUG debug

    # Use '$module' before every echo/puts, so you know where the text came from
    set module "[lindex [info level 0] 0]/$HciConnName/$ctx"

    set dispList {}
    switch -exact -- $mode {
        start {
            # Perform special init functions
	    # N.B.: there may or may not be a MSGID key in args
        }

        run {
	    # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh

            # Look for optional/repeating patterns of <[..]>, <?..?>, and <!--..-->
            # (possibly with leading/trailing whitespace)
            #
            # Then find the first element (aka root element) from and including < to and including >
            # From that root element extract the rootNodeName, meaning the name of the rootElement 
            # possibly including its namespace
            # xmlns="http://www.hprim.org/hprimXML"
            # <evenementsServeurActes 

            if { [msglength $mh] == 0 } {
                if { $debug } { echo "$module: Not processing ok file from Application here." }
                lappend dispList "CONTINUE $mh"
                return $dispList
            }

            set nsToInsert "xmlns=\"http://www.hprim.org/hprimXML\""
            if { [regexp -- {^(\s*<[?!\[][^?!\]]+[?!\]-]-?>\s*)*\s*(<([^?!/][^\s/>]+)[^>]*>)} [msgget $mh] full leadTags rootElement rootNodeName] } {

                set nsDfltFound [regexp -- "xmlns=\[\"\'\](\[^\"\']+)\[\"\'\]" $rootElement full nsDfltDecl]
                # Now find declaration
                if { $nsDfltFound == 1 } {
                    # We already have a default namespace declaration
                    if { $debug } {
                        echo "$module: Default namespace already set '$nsDfltDecl', nothing to do."
                    }
                } else {
                    if { $debug } {
                        echo "$module: Adding default namespace '$nsToInsert'."
                    }
                    regsub -- "($rootNodeName )" [msgget $mh] "\\1$nsToInsert " msg
                    msgset $mh $msg
                    unset msg
                }
            } else {
                if { $debug } {
                    echo "$module: Does not start with '<?xml', not adding a namespace."
                }
            }

            lappend dispList "CONTINUE $mh"
        }

        time {
            # Timer-based processing
	    # N.B.: there may or may not be a MSGID key in args
        }
        
        shutdown {
	    # Doing some clean-up work 
	}
    }

    return $dispList
}
