######################################################################
# Name:      xper_transformAckToMsg
# Purpose:   <description>
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

proc xper_transformAckToMsg { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "xper_filterIUC/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
            keylget args OBMSGID ob_mh
            set newMh [msgcreate -type data [msgget $mh]]
            msgmetaset $newMh USERDATA [msgmetaget $ob_mh USERDATA]
            lappend dispList "KILLREPLY $mh"
            lappend dispList "KILL $ob_mh"
            lappend dispList "CONTINUE $newMh"
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

######################################################################
# Name:           setEmailToUserData_xltp
# Purpose:        Récupère la valeur du champ passé en paramètre dans USER
#                 Et le met dans le xlateOutVals.
# UPoC type:      xltp
# Args:           none
# Notes:          All data is presented through special variables.  The initial
#                 upvar in this proc provides access to the required variables.
#
#                 This proc style only works when called from a code fragment
#                 within an XLT.

 
proc setEmailToUserData_xltp {} {
    upvar xlateId       xlateId        \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals

    set metadata [xpmmetaget $xlateId USERDATA]

    set key [lindex $xlateInVals 0]
    set value [lindex $xlateInVals 1]
    
    if {[keylget metadata $key val]} {        
        append val ";" $value
        keylset metadata $key $val       
    } else {
        keylset metadata $key $value
    }
    
   

    xpmmetaset $xlateId USERDATA $metadata
}

######################################################################
# Name:      medimail_ref_update_to_send
# Purpose:   Procédure de mise à jour de la base pour la plateforme SaaS SIB 
#            Flux Web Services
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

proc medimail_ref_update_to_send { args } {
    package require pgintcl
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
       
    set dblogin "" ; catch {keylget uargs DBLOGIN dblogin}
    set dbpassword "" ; catch {keylget uargs DBPASSWORD dbpassword}
    set dbhost localhost ; catch {keylget uargs DBHOST dbhost}
    set dbport 5432 ; catch {keylget uargs DBPORT dbport}
    set dbschema "" ; catch {keylget uargs DBSCHEMA dbschema}
    set dbid "IDBDD" ; catch {keylget uargs DBID dbid}
    set mssref "REF_MEDIMAIL" ; catch {keylget uargs MSSREF mssref}

    set module "medimail_ref_update_to_send/$HciConnName/$ctx" ;# Use this before every echo/puts,
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

            # get id from userdata
            set userdata [msgmetaget $mh USERDATA]
            set id [keylget userdata $dbid]
            set ref [keylget userdata $mssref]
          
            #dbrequest
            set dbrequest "UPDATE to_send SET filename='$ref', state=2 WHERE id=$id"
            
            if {$debug } {
                echo DBREQUEST : "${dbrequest};"
            }
            xper_saas_updateDB $uargs $dbrequest
            
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
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}

######################################################################
# Name:      medimail_ACK_account_update
# Purpose:   Procédure de mise à jour de la base pour la plateforme SaaS SIB 
#            Flux Web Services
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

proc medimail_ACK_account_update { args } {
    package require pgintcl
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
       
    set dblogin "" ; catch {keylget uargs DBLOGIN dblogin}
    set dbpassword "" ; catch {keylget uargs DBPASSWORD dbpassword}
    set dbhost localhost ; catch {keylget uargs DBHOST dbhost}
    set dbport 5432 ; catch {keylget uargs DBPORT dbport}
    set dbschema "" ; catch {keylget uargs DBSCHEMA dbschema}
    set dbid "ID" ; catch {keylget uargs DBID dbid}
    set checkdate "CHECK_DATE" ; catch {keylget uargs CHECKBOXDATE checkdate}

    set module "medimail_ACK_account_update/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
            set ack_userdata [msgmetaget $mh USERDATA]
            set responseCode [keylget ack_userdata httpResponseCode]
            set httpResponseHeaders [keylget ack_userdata httpResponseHeaders]
            if { $debug } {
                echo "response code : $responseCode"
            }

            if { $responseCode == "200" } {
                keylget args OBMSGID ob_mh
    
                # get userdata from OB_MSG
                set ob_userdata [msgmetaget $ob_mh USERDATA]
                set id [keylget ob_userdata $dbid]
                set bddcheckdate [keylget ob_userdata $checkdate]

                if { $debug } {
                    echo "date checking to update : $bddcheckdate"
                }
    
                #dbrequest
                set dbrequest "UPDATE mss_account_config SET check_date='$bddcheckdate' WHERE id=$id"
                
                if {$debug } {
                    echo DBREQUEST : "${dbrequest};"
                }
                xper_saas_updateDB $uargs $dbrequest
    
                set newMh [msgcreate -type data [msgget $mh]]
                msgmetaset $newMh USERDATA [msgmetaget $ob_mh USERDATA]
                
                lappend dispList "KILLREPLY $mh"
                lappend dispList "KILL $ob_mh"
                lappend dispList "CONTINUE $newMh"
            } else {
                echo "Impossible de se connecter au serveur médimail."
                echo "Entête complète de la réponse : $httpResponseHeaders"
                lappend dispList "CONTINUE $newMh"
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
