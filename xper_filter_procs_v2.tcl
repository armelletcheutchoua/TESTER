######################################################################
# Name:    xper_killOkFile
# Purpose: Supprime les fichiers témoins en précisant en argument
#          l'extension du fichier à supprimer (ok par défaut)
# UPoC type: tps
# Args: EXT extension du fichier à supprimer.
# Returns: tps disposition list
# History :
#

proc xper_killOkFile { args } {
    keylget args MODE mode                  ;# Fetch mode
    set ext "ok"; catch {keylget args ARGS.EXT ext}

    set dispList {}             ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set file ""
            if { [catch {set file [msgmetaget $mh DRIVERCTL]} err] } {
               puts stderr "Error: $err"
               usage ; return ""
            }
            keylget file FILENAME name
            set extension [file extension $name]

            if { [cequal [string toupper $extension] .[string toupper $ext]]} {
                lappend dispList "KILL $mh"
            } else {
                lappend dispList "CONTINUE $mh"
            }
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

######################################################################
# Name:      xper_tps_removeEmptyFile
# Purpose:   Supprime les fichiers vides
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    <describe user-supplied args here>
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   <date> <name> <comments>
#                 

proc xper_tps_removeEmptyFile { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "xper_removeEmptyFile/$HciConnName/$ctx" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            
            if { $debug } {
                puts stdout "$module: Starting in debug mode..."
            }
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            
            keylget args MSGID mh
            set data [msgget $mh]

            if { [cequal $data ""] } {
                lappend dispList "KILL $mh"    
            } else {   
                lappend dispList "CONTINUE $mh"
            }
        }

        time {
            # Timer-based processing
            # N.B.: there may or may not be a MSGID key in args
            
        }
        
        shutdown {
            # Doing some clean-up work 
            
        }
        
        default {
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}
