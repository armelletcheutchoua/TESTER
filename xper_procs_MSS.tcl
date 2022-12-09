######################################################################
# Name: xper_send_message_MSS
# Purpose: génére un, mail a destination de la messagerie cytoyenne
# UPoC type: tps
# Args: tps keyedlist containing the following keys:
# MODE run mode ("start", "run", "time" or "shutdown")
# MSGID message handle
# CONTEXT tps caller context
# ARGS user-supplied arguments:
#         #Definition des parametres
#       set mailserver "10.250.1.60"
#       set mailfrom "chc_rdv_mss@ch-calais.fr"
#       set mailport 25
#        set usetls 0
#       set maillogin "bal_rdv_mss"
#       set mailpassword "4aCR59!*qMr#"
#
# Returns: tps disposition list:
# <describe dispositions used here>
#
# Notes: <put your notes here>
#
# History: <date> <name> <comments>
#

proc xper_send_message_MSS { args } {
    global HciConnName ;# Name of thread
    package require base64
    package require smtp
    package require mime
    keylget args MODE mode ;# Fetch mode
    set ctx "" ; keylget args CONTEXT ctx ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs ;# Fetch user-supplied args
    
    set debug 0 ; ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug} ;# assume uargs is a keyed list
    #recuperation des paramètres
    set mailserver ""
    catch {keylget uargs MAILSERVER mailserver} ;
    
    set mailfrom ""
    catch {keylget uargs MAILFROM mailfrom} ;

    set maillogin ""
    catch {keylget uargs MAILLOGIN maillogin} ;

    set mailpassword ""
    catch {keylget uargs MAILPASSWORD mailpassword} ;

    #PAR DEFAUT
    set mailport 25
    catch {keylget uargs MAILPORT mailport} ;

    set usetls 0
    catch {keylget uargs USETLS usetls} ;

    #set module ;# Use this before every echo/puts,
    ;# it describes where the text came from
     echo " *****  xper_sendMessage_MSS  *****"
    set dispList {} ;# Nothing to return
    
    switch -exact -- $mode {
    start {
        # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
        
        if { $debug } {
            puts stdout "Starting in debug mode..."
        }
    }
    
    run {
        # 'run' mode always has a MSGID; fetch and process it
        keylget args MSGID mh
        set data [msgget $mh]
        set userdata [msgmetaget $mh USERDATA]
        keylget userdata SUBJECT subject
        keylget userdata MAILTO mailto
        keylget userdata MAILFROM mailfrom
        keylget userdata BODY body
        if { $debug } {
            echo "body : $body"
        }
        
        if (![cequal $body ""]) {
            set token [mime::initialize -canonical text/plain -string $body]
            set command [list ::smtp::sendmessage $token -servers $mailserver -ports $mailport -username $maillogin -password $mailpassword -usetls $usetls -header [list From "$mailfrom"] -header [list To "$mailto"] -header [list Subject "$subject"] -header [list Date "[clock format [clock seconds]]"] -debug $debug]
            if {$debug} { echo "command: $command" }
            
            echo Emission du mail à $mailto en cours 
            eval $command
            echo Emission du mail terminée
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
    
    default {
        error "Unknown mode '$mode'"
        }
    }
    
    return $dispList
}

######################################################################
# Name: xper_sendMessage_MSS_Fin
# Purpose:  Envoi d'un second mail pour indiquer "la fin" de l'envoi du mail.
# UPoC type: tps
# Args: tps keyedlist containing the following keys:
# MODE run mode ("start", "run", "time" or "shutdown")
# MSGID message handle
# CONTEXT tps caller context
# ARGS user-supplied arguments:
#         #Definition des parametres
#       set mailserver "10.250.1.60"
#       set mailfrom "chc_rdv_mss@ch-calais.fr"
#       set mailport 25
#        set usetls 0
#       set maillogin "bal_rdv_mss"
#       set mailpassword "4aCR59!*qMr#"
#
# Returns: tps disposition list:
# <describe dispositions used here>
#
# Notes: <put your notes here>
#
# History: <date> <name> <comments>
#

proc xper_sendMessage_MSS_Fin { args } {
    global HciConnName ;# Name of thread
    package require base64
    package require smtp
    package require mime
    keylget args MODE mode ;# Fetch mode
    set ctx "" ; keylget args CONTEXT ctx ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs ;# Fetch user-supplied args

        
    set debug 0 ; ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug} ;# assume uargs is a keyed list
    #recuperation des paramètres
    set mailserver ""
    catch {keylget uargs MAILSERVER mailserver} ;
    
    set mailfrom ""
    catch {keylget uargs MAILFROM mailfrom} ;

    set maillogin ""
    catch {keylget uargs MAILLOGIN maillogin} ;

    set mailpassword ""
    catch {keylget uargs MAILPASSWORD mailpassword} ;

    #PAR DEFAUT
    set mailport 25
    catch {keylget uargs MAILPORT mailport} ;

    set usetls 1
    catch {keylget uargs USETLS usetls} ;
    
    
    #set module ;# Use this before every echo/puts,
    ;# it describes where the text came from
    
    set dispList {} ;# Nothing to return
    echo " *****  xper_sendMessage_MSS_Fin  *****"
    switch -exact -- $mode {
    start {
        # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
        
        if { $debug } {
            puts stdout "Starting in debug mode..."
        }
    }
    
    run {
        # 'run' mode always has a MSGID; fetch and process it
        keylget args MSGID mh
        #On récupère le mail de destination à partir de l'InS du patient quicompose le nom de fichier d'entrée
        set driver [msgmetaget $mh DRIVERCTL]
        set ins [file tail [file rootname [keylget driver FILENAME]]]
        echo "INS : $ins"
        set mailto "$ins@patient.mssante.fr"
        

        #Envoi d'un second mail pour indiquer "la fin" de l'envoi du mail.
        set subject "\[FIN\]"
        set token [mime::initialize -canonical text/plain -string ""]
        set command [list ::smtp::sendmessage $token -servers $mailserver -ports $mailport -username $maillogin -password $mailpassword -usetls $usetls -header [list From "$mailfrom"] -header [list To "$mailto"] -header [list Subject "$subject"] -header [list Date "[clock format [clock seconds]]"] -debug $debug]
        if {$debug} { echo "command: $command" }

        echo Emission du mail $subject à $mailto en cours 
        eval $command
        echo Emission du mail terminée
        
        lappend dispList "CONTINUE $mh"
    
    }
    
    time {
    # Timer-based processing
    # N.B.: there may or may not be a MSGID key in args
    
    }
    
    shutdown {
    # Doing some clean-up work
    
    }
    
    default {
        error "Unknown mode '$mode'"
        }
    }
    
    return $dispList
}

######################################################################
# Name:     xper_xltp_getTimestamp
# Purpose:  retourne le timestamp de la date passÃ©e en parametre
#            - parametres 
#             dateRef : date Ã  convertir
#             formatIn : format de la date d'entrÃ©e ( exemple %d/%m/%Y)
#
#           - retour
#             une date au format timestamp
# Author:        Michel LAMBERT - Xperis (03/03/2021)
# UPoC type: xltp
######################################################################

proc xper_xltp_getTimestamp {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName

    set dateRef [lindex $xlateInVals 0]
    set formatIn [lindex $xlateInVals 1]
     #conversion de la date d'entrÃ©e en timestamp
    set outVal [clock scan $dateRef -format "$formatIn"]
    set xlateOutVals [list $outVal]
}

######################################################################
# Name:     xper_xltp_dateFromTimestamp 
# Purpose:  retourne une date au format demandÃ©e Ã  partir d'un timestamp
#            - parametres :
#              dateRefTimestamp : date au format timlestamp
#              formatOut : format de la datede sortie ( exemple %d/%m/%Y)
#
#           - retour
#             une date au format demandÃ©
# Author:        Michel LAMBERT - Xperis (03/03/2021)
# UPoC type: xltp
######################################################################

proc xper_xltp_dateFromTimestamp {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName

    set dateRefTimestamp [lindex $xlateInVals 0]
    set formatOut [lindex $xlateInVals 1]
    set outVal [clock format $dateRefTimestamp -format "$formatOut"]    
    set xlateOutVals [list $outVal]
}