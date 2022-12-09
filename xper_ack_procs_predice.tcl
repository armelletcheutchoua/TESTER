# Name:            pre_validate_reply_predice
# Purpose:      Validate an inbound reply, resend message if necessary.
# UPoC type:    tps
# Args:         tps keyedlist containing the following keys:
#               MODE    run mode ("start" or "run")
#               MSGID   message handle
#               OBMSGID saved ob message handle
#               ARGS    user-supplied arguments:
#                   DEBUG             : increase log traces
#                   ROUTE_REPLY     : continue msg on route reply 
#                   SEND_STATS         : continue msg on STATS route (needs xper_trxId_userdata)
#                   HL7             : 0 = no HL7, 1 = HL7 format
#                   FILTRE             : Specifies the Table.tbl that will determine the action
#                        ACTION LIST
#                                DELETE     : Kills the message without error
#                                STATS     : Send the msg only on the route STATS
#                                ERROR     : Send the msg to error db
#
# Returns: tps disposition list:
#           CONTINUE    = reply OK, continue it
#           KILLREPLY   = reply not OK, kill it
#           PROTO       = reply not OK, resend original message
#
# Notes:
#                  Cette procédure à été créée spécialement pour la gestion des ACK du projet Prédice
#                Elle a pour but de trier de façon intelligible les retours de la plateforme
#                Et de déterminer le traitement de chacun des types d'ACK
#
proc pre_validate_reply_predice { args } {

    global HciConnName errorTcl
    global HciSiteDir
    global HciRootDir
    
    package require Sitecontrol
    set module "(VALIDATE_REPLY/$HciConnName)"
    set dispList {}

    keylget args MODE mode                  ;# Fetch mode
    keylget args ARGS uargs

    set debug 0                                            ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}                      ;# assume uargs is a keyed list    
    
    set route_reply 0                                    ;# Fetch user argument ROUTE_REPLY and
    catch {keylget uargs ROUTE_REPLY route_reply}        ;# assume uargs is a keyed list
    
    set hl7 0                                            ;# Fetch user argument ROUTE_REPLY and
    catch {keylget uargs HL7 hl7}                        ;# assume uargs is a keyed list    

    #liste des erreurs répertoriées
    set liste_erreur "InvalidValueInRequest;ProfessionalNotFound;EXCEPTION_IDR_NOT_FOUND"    ;# Fetch user argument DEBUG and
    catch {keylget uargs LISTE_ERR_FONC liste_erreur}                                        ;# assume uargs is a keyed list
    
    switch -exact -- $mode {
        start {
            # Perform special init functions
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            keylget args OBMSGID obmh
            if { ![keylget args OBMSGID obmh] } {
                return "{KILLREPLY $mh}"
            }
            if { [cequal $route_reply 1] } {
                return "{CONTINUE $mh} {KILL $obmh}" 
            }
            #Récupération de la configuration du filtres ACK
            set filtre [tableToKeylist $debug $uargs]
            set msg [msgget $mh]
            if {$debug} {
                echo "MSG : $msg"
            }
            # Décapsulation de la data si HL7
            if { $hl7 } {
                if {$debug} {
                    echo "TYPE : HL7"
                }
                set state [parse_hl7_msg $debug $msg]                
            } else {
                if {$debug} {
                    echo "TYPE : NO HL7"
                }              
                
                set state $msg               
            }
            if {$debug} {
                    echo "state : $state"
            }  
            # Traitement des retours OK - Suppression
            if { [cequal $state OK] } {
                if {$debug} {
                    echo "ACK OK, kill msg et reply"
                }
                return "{KILLREPLY $mh} {KILL $obmh}"
            #En cas de retour vide - Rejoue
            } else {
                if { ![cequal $filtre 0] } {
                    set action [errMatch $debug $filtre $state]
                    switch $action {
                        "DELETE" {
                            echo "SWITCH : DELETE"
                            return "{KILLREPLY $mh} {KILL $obmh}" 
                        }
                        "STATS" {
                            echo "SWITCH : STATS"
                            set statmh [send_to_stats $debug $obmh $msg]
                            return "{KILLREPLY $mh} {KILL $obmh} {CONTINUE $statmh}"
                        }
                        "ERROR" {
                            echo "SWITCH : KO"
                            return "{KILLREPLY $mh} {ERROR $obmh}"
                        }
                        default {
                            return "{KILLREPLY $mh} {ERROR $obmh}"
                        }
                    }
                } else {
                    return "{KILLREPLY $mh} {ERROR $obmh}"
                }
            }
        }
    }
    proc send_to_stats { debug obmh msg } {
        if {$debug} {
            echo "SEND_STATS : msg routed... "
        }
        #Concaténation du OBMSG avec son ACK
        set obmsg [msgget $obmh]
        set newmsg "$obmsg\n\n$msg"
        
        #Construction d'un nouveau message de type data
        set statmh [msgcreate -recover ""]
        msgset $statmh $newmsg
        keylset uData TRXID STATS
        #ajout de l'erreur dans les userdata pour recup dans trackcis si c'est du xml - MLA
        #keylset uData MSG $obmsg
        keylset uData ERR $msg
        msgmetaset $statmh USERDATA $uData
        return $statmh
    }
    
    proc errMatch { debug filtre msg } {
        if {$debug} {
            echo "Looking for err match ..."
        }
        foreach {key val} $filtre {
            #Searching for Err match
            if {[string match "*$key*" $msg]} {
                if {$debug} {
                    echo "Err Match : $key - Interruption de la recherche"
                    echo "Action : $val"
                    return $val
                }
                #return {$key $val}
            } else {
                if {$debug} {
                    echo "No Err Match!"
                }
            }
        }
        return 0
    }
    proc tableToKeylist { debug uargs } {
        set filtre 0                                            ;# Fetch user argument DEBUG and
        catch {keylget uargs FILTRE filtre}                  ;# assume uargs is a keyed list
        
        if { ![cequal $filtre 0] } {
            #Récupération du fichier & extraction de la data
            set tableDir $::HciSiteDir/Tables/$filtre
            set file_data [fileToData $debug $tableDir]
            #Transformationl de la data en keylist
            set count 0
            set errorMap {}
            foreach type_err [split $file_data "#"] {
                incr count
                
                if {$count>"4"} {
                    if {$debug} {
                    }
                    set count2 0
                    foreach err [split $type_err "\r\n"] {
                        
                        if {($count2=="1")} {
                            set temp $err
                        }
                        if {($count2=="2")} {
                            lappend errorMap "$temp" "$err"
                        }
                        incr count2
                    }
                }
            }
            if {$debug} {
                echo "Résultat du l'extration de la table : $errorMap"
            }
            return $errorMap
        } else {
            echo "INFO : Aucun filtre paramétré dans les arguments (FILTRE)"
            return 0
        }
    }
    
    proc fileToData { debug file } {
        #Récupération de la donnée contenue de la table
        if { [catch {set fp [open $file r]} errmsg ]} {
            error "FICHIER INTROUVABLE" "\nVérifier l'arg FILTRE de la proc. \nOu l'existance du fichier : $file"
        }
        if { [catch {set file_data [read $fp]} errmsg ]} {
            error "FICHIER INTROUVABLE" "\nVérifier l'arg FILTRE de la proc. \nOu l'existance du fichier : $file"
        }
        catch {close $fp}
        return $file_data
    }
    proc parse_hl7_msg { debug msg } {
        # Split it into HL7 segments and fields
        # Field separator normally "|"
        set fldsep [string index $msg 3]
        # Get segments
        set segments [split $msg \r]
        # Get fields from MSA segment
        set msaflds [split [lindex $segments 1] $fldsep]
        # Get ACK type from MSA segment and message, if one
        set acktype [lindex $msaflds 1]
        echo "acktype : $acktype"
        set ackmsg [lindex $msaflds 3]    
        echo "ackmsg : $ackmsg"
        if {[lempty $ackmsg]} { 
            set ackmsg "NO MESSAGE"
        }
        switch -exact -- $acktype {
            AA - CA {
                # Good ACK - Clean up
                return "OK"
            }

            AR - CR {
                # AR - resend up to $max_resend times
                return $ackmsg
            }

            AE - CE {
                # AE in non-recoverable
                return $ackmsg
            }

            default {
                # If we get invalid ACK, treat it as an 
                return $ackmsg
            }
        }
    }
}

#AMELIORATION
#Ajouter la gestion w/linux sur le retour à la ligne des Tables & Message ACK HL7 : if  windows_platform


# Name:            pre_validate_reply_predice
# Purpose:      Validate an inbound reply, resend message if necessary.
# UPoC type:    tps
# Args:         tps keyedlist containing the following keys:
#               MODE    run mode ("start" or "run")
#               MSGID   message handle
#               OBMSGID saved ob message handle
#               ARGS    user-supplied arguments:
#                   DEBUG             : increase log traces
#                   ROUTE_REPLY     : continue msg on route reply 
#                   SEND_STATS         : continue msg on STATS route (needs xper_trxId_userdata)
#                   HL7             : 0 = no HL7, 1 = HL7 format
#                   FILTRE             : Specifies the Table.tbl that will determine the action
#                        ACTION LIST
#                                DELETE     : Kills the message without error
#                                STATS     : Send the msg only on the route STATS
#                                ERROR     : Send the msg to error db
#
# Returns: tps disposition list:
#           CONTINUE    = reply OK, continue it
#           KILLREPLY   = reply not OK, kill it
#           PROTO       = reply not OK, resend original message
#
# Notes:
#                  Cette procédure à été créée spécialement pour la gestion des ACK du projet Prédice
#                Elle a pour but de trier de façon intelligible les retours de la plateforme
#                Et de déterminer le traitement de chacun des types d'ACK
#
proc pre_validate_reply_predice_noOB { args } {

    global HciConnName errorTcl
    global HciSiteDir
    global HciRootDir
    
    package require Sitecontrol
    set module "(VALIDATE_REPLY/$HciConnName)"
    set dispList {}

    keylget args MODE mode                  ;# Fetch mode
    keylget args ARGS uargs

    set debug 0                                            ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}                      ;# assume uargs is a keyed list    
    
    set route_reply 0                                    ;# Fetch user argument ROUTE_REPLY and
    catch {keylget uargs ROUTE_REPLY route_reply}        ;# assume uargs is a keyed list
    
    set hl7 0                                            ;# Fetch user argument ROUTE_REPLY and
    catch {keylget uargs HL7 hl7}                        ;# assume uargs is a keyed list    

    #liste des erreurs répertoriées
    set liste_erreur "InvalidValueInRequest;ProfessionalNotFound;EXCEPTION_IDR_NOT_FOUND"    ;# Fetch user argument DEBUG and
    catch {keylget uargs LISTE_ERR_FONC liste_erreur}                                        ;# assume uargs is a keyed list
    
    switch -exact -- $mode {
        start {
            # Perform special init functions
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            keylget args OBMSGID obmh
            if { ![keylget args OBMSGID obmh] } {
                return "{KILLREPLY $mh}"
            }
            if { [cequal $route_reply 1] } {
                return "{CONTINUE $mh} {KILL $obmh}" 
            }
            #Récupération de la configuration du filtres ACK
            set filtre [tableToKeylist $debug $uargs]
            set msg [msgget $mh]
            if {$debug} {
                echo "MSG : $msg"
            }
            # Décapsulation de la data si HL7
            if { $hl7 } {
                if {$debug} {
                    echo "TYPE : HL7"
                }
                set state [parse_hl7_msg $debug $msg]                
            } else {
                if {$debug} {
                    echo "TYPE : NO HL7"
                }              
                
                set state $msg               
            }
            if {$debug} {
                    echo "state : $state"
            }  
            # Traitement des retours OK - Suppression
            if { [cequal $state OK] } {
                if {$debug} {
                    echo "ACK OK, kill msg et reply"
                }
                return "{KILLREPLY $mh} {KILL $obmh}"
            #En cas de retour vide - Rejoue
            } else {
                if { ![cequal $filtre 0] } {
                    set action [errMatch $debug $filtre $state]
                    switch $action {
                        "DELETE" {
                            echo "SWITCH : DELETE"
                            return "{KILLREPLY $mh} {KILL $obmh}" 
                        }
                        "STATS" {
                            echo "SWITCH : STATS"
                            set statmh [send_to_stats $debug $obmh $msg]
                            return "{KILLREPLY $mh} {KILL $obmh} {CONTINUE $statmh}"
                        }
                        "ERROR" {
                            echo "SWITCH : KO"
                            return "{KILLREPLY $mh} {ERROR $obmh}"
                        }
                        default {
                            return "{KILLREPLY $mh} {ERROR $obmh}"
                        }
                    }
                } else {
                    return "{KILLREPLY $mh} {ERROR $obmh}"
                }
            }
        }
    }
    proc send_to_stats { debug obmh msg } {
        if {$debug} {
            echo "SEND_STATS : msg routed... "
        }
        #Concaténation du OBMSG avec son ACK
        set obmsg [msgget $obmh]
        set newmsg "$msg"
        
        #Construction d'un nouveau message de type data
        set statmh [msgcreate -recover ""]
        msgset $statmh $newmsg
        keylset uData TRXID STATS
        #ajout de l'erreur dans les userdata pour recup dans trackcis si c'est du xml - MLA
        #keylset uData MSG $obmsg
        keylset uData ERR $msg
        msgmetaset $statmh USERDATA $uData
        return $statmh
    }
    
    proc errMatch { debug filtre msg } {
        if {$debug} {
            echo "Looking for err match ..."
        }
        foreach {key val} $filtre {
            #Searching for Err match
            if {[string match "*$key*" $msg]} {
                if {$debug} {
                    echo "Err Match : $key - Interruption de la recherche"
                    echo "Action : $val"
                    return $val
                }
                #return {$key $val}
            } else {
                if {$debug} {
                    echo "No Err Match!"
                }
            }
        }
        return 0
    }
    proc tableToKeylist { debug uargs } {
        set filtre 0                                            ;# Fetch user argument DEBUG and
        catch {keylget uargs FILTRE filtre}                  ;# assume uargs is a keyed list
        
        if { ![cequal $filtre 0] } {
            #Récupération du fichier & extraction de la data
            set tableDir $::HciSiteDir/Tables/$filtre
            set file_data [fileToData $debug $tableDir]
            #Transformationl de la data en keylist
            set count 0
            set errorMap {}
            foreach type_err [split $file_data "#"] {
                incr count
                
                if {$count>"4"} {
                    if {$debug} {
                    }
                    set count2 0
                    foreach err [split $type_err "\r\n"] {
                        
                        if {($count2=="1")} {
                            set temp $err
                        }
                        if {($count2=="2")} {
                            lappend errorMap "$temp" "$err"
                        }
                        incr count2
                    }
                }
            }
            if {$debug} {
                echo "Résultat du l'extration de la table : $errorMap"
            }
            return $errorMap
        } else {
            echo "INFO : Aucun filtre paramétré dans les arguments (FILTRE)"
            return 0
        }
    }
    
    proc fileToData { debug file } {
        #Récupération de la donnée contenue de la table
        if { [catch {set fp [open $file r]} errmsg ]} {
            error "FICHIER INTROUVABLE" "\nVérifier l'arg FILTRE de la proc. \nOu l'existance du fichier : $file"
        }
        if { [catch {set file_data [read $fp]} errmsg ]} {
            error "FICHIER INTROUVABLE" "\nVérifier l'arg FILTRE de la proc. \nOu l'existance du fichier : $file"
        }
        catch {close $fp}
        return $file_data
    }
    proc parse_hl7_msg { debug msg } {
        # Split it into HL7 segments and fields
        # Field separator normally "|"
        set fldsep [string index $msg 3]
        # Get segments
        set segments [split $msg \r]
        # Get fields from MSA segment
        set msaflds [split [lindex $segments 1] $fldsep]
        # Get ACK type from MSA segment and message, if one
        set acktype [lindex $msaflds 1]
        echo "acktype : $acktype"
        set ackmsg [lindex $msaflds 3]    
        echo "ackmsg : $ackmsg"
        if {[lempty $ackmsg]} { 
            set ackmsg "NO MESSAGE"
        }
        switch -exact -- $acktype {
            AA - CA {
                # Good ACK - Clean up
                return "OK"
            }

            AR - CR {
                # AR - resend up to $max_resend times
                return $ackmsg
            }

            AE - CE {
                # AE in non-recoverable
                return $ackmsg
            }

            default {
                # If we get invalid ACK, treat it as an 
                return $ackmsg
            }
        }
    }
}

#AMELIORATION
#Ajouter la gestion w/linux sur le retour à la ligne des Tables & Message ACK HL7 : if  windows_platform
