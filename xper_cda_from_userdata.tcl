######################################################################
# Name:     xper_cda_from_userdata
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc xper_cda_from_userdata { args } {
    package require base64
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_cda_from_userdata/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0
    catch {keylget uargs DEBUG debug}
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh
            set userdata [msgmetaget $mh USERDATA]

            if { $debug } {
                echo "userdata du message : $userdata"
            }

            #On change le contenu du message à l'aide du CDA contenu dans les userdata
            msgset $mh [encoding convertfrom utf-8 [::base64::decode [keylget userdata CDAB64] ]]

            catch {
                #recuperation du nom des informations du message source
                set driverCtl [msgmetaget $mh DRIVERCTL]
                set driverctl "{FILENAME [ file rootname [ keylget driverCtl FILENAME ] ].xml}"
                msgmetaset $mh DRIVERCTL $driverctl

                if { $debug } {
                    echo "filename du message : $driverctl"
                } 
            
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
