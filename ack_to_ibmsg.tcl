######################################################################
# Name:     ack_to_ibmsg
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc ack_to_ibmsg { args } {
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "ack_to_ibmsg/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0
    catch {keylget uargs DEBUG debug}
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh
            keylget args OBMSGID obmh
            set msg [msgget $mh]
            set test [msgdump $mh]
            echo OBMSG
            msgdump $obmh
            echo MESSAGE : $msg
            echo METADATA : $test
            set idsmgtest [msgmetaget $obmh USERDATA]
            echo USERDATA : $idsmgtest
            keylget idsmgtest ID_MSG toto
            echo ID_MSG $toto
            
            #echo ID_MSG $idsmgtest_test
            set ibmh [msgcreate -type data -recover $msg]
            msgmetaset $ibmh USERDATA $idsmgtest
            lappend dispList "KILLREPLY $mh"
            lappend dispList "KILL $obmh"
            lappend dispList "CONTINUE $ibmh"
        }

        time {}
        shutdown {}
        default {
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}
