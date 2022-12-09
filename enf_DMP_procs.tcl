######################################################################
# Name:      enf_validFormat_ack_v2
# Purpose:   Procedure permettant de vï¿½rifier le format d'un fichier
#            et de gï¿½nerer un ack xml le cas echeant.
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                   XMLPATH : path du schema xml
#                   NOMOCM : nom du schema xml
#                   FORMAT : nom du format pour le message d'erreur
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   20140319 TLZ : Optimisations
#   
proc enf_validFormat_dmp_ack_v2 { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""     ; keylget args CONTEXT ctx      ;# Fetch tps caller context
    set uargs {}   ; keylget args ARGS uargs       ;# Fetch user-supplied args
    set xmlPath "" ; keylget uargs XMLPATH xmlPath
    set nomOCM ""  ; keylget uargs NOMOCM nomOCM
    set format ""  ; keylget uargs FORMAT format

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "enf_validFormat_ack/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
        set error false
        
    #Test du message avec grm
    if { [ catch {set gh [grmcreate -msg $mh xml $xmlPath $nomOCM] } fid ] } {
        echo $fid
        set error true
        set messErr "Message non conforme au format $format"
    } else { grmdestroy $gh }

    #Si une erreur se produit
    if [cequal $error true] {

        #Gestion de l'ACK si il y a une erreur
            
        #Recuperation du nom du fichier
            set driver [msgmetaget $mh DRIVERCTL]
            set fileName [keylget driver FILENAME]

        #Suppression du pdf
            append fichierDelpdf [file rootname $fileName] .pdf
            echo suppression de : $fichierDelpdf
            file delete $fichierDelpdf

        #Suppression du ok
            #append fichierDelok [file rootname $fileName] .ok
            #echo suppression de : $fichierDelok
            #file delete $fichierDelok

        # Recuperation du message
            set msgContent [msgget $mh]

        #Creation de l'ack avec grm
            set grmAck [grmcreate xml schema retourDMP]
            grmstore $grmAck reponse_dmp.message.statut.#text d -c "false"
            grmstore $grmAck reponse_dmp.message.libelle.&code d -c "ErrFormat"
            grmstore $grmAck reponse_dmp.message.libelle.#text d -c $messErr
            grmstore $grmAck reponse_dmp.message.log_erreur.#text d -c \<\!\[CDATA\[$fid\]\]\>
            grmstore $grmAck reponse_dmp.message.trame.#text d -c \<\!\[CDATA\[$msgContent\]\]\>
            set msgAck [grmencode -type reply $grmAck]

        #Nommage de l'ack
            keylset keyfilename FILENAME $fileName.ack
            
        #Envoi du message en erreur et de l'ACK vers la source
            msgmetaset $msgAck DRIVERCTL $keyfilename DESTCONN ack_ERR
            lappend dispList "ERROR $mh"
            lappend dispList "CONTINUE $msgAck"

        #Nettoyage des variables
            grmdestroy $grmAck
    
    } else { lappend dispList "CONTINUE $mh" }
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
# Name:        enf_trxid_ackdmp
# Purpose:    <description>
# UPoC type:    trxid
# Args:        msgId = message handle
#         args  = (optional) user arguments 
# Returns:    The message's transaction ID
#
# Notes:
#    The message is both modify- and destroy-locked -- attempts to modify
#    or destroy it will error out.
#

proc enf_trxid_ackdmp { mh {args {}} } {
    global HciConnName                          ;# Name of thread
    set module "enf_trxid_ackdmp/$HciConnName"   ;# Use this before every echo/puts
    set msgSrcThd [msgmetaget $mh SOURCECONN]   ;# Name of source thread where message came from
                                                ;# Use this before necessary echo/puts
    ;# args is keyed list when available

    set datList [datlist]
    
    set gh [grmcreate -msg $mh xml schema retourDMP]
    set datum [grmfetch $gh reponse_dmp.message.statut.#text] ;#recuperation du statut de la reponse
    if { [cequal [datget $datum VALUE] true] } {
      set trxId ok ;# determine the trxid
    } else {
      set datum [grmfetch $gh reponse_dmp.message.libelle.&code] ;#recuperation du code erreur de la reponse
        if { [cequal [datget $datum VALUE] noexist] || [cequal [datget $datum VALUE] dmpferme] } {
          set trxId noexist ;# determine the trxid
        } else {
          set trxId ko ;# determine the trxid
        }
    }
    
    grmdestroy $gh
    hcidatlistreset $datList

    return $trxId                ;# return it
}




######################################################################
# Name:        enf_xltp_today_UTC_YYYYMMJJHHMISS
# Purpose:    <description>
# UPoC type:    xltp
# Args:        none
# Notes:    All data is presented through special variables.  The initial
#        upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#

proc enf_xltp_today_UTC_YYYYMMJJHHMISS {} {
    upvar xlateId       xlateId        \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals

    set xlateOutVals [clock format [clock seconds] -format "%Y%m%d%H%M%S" -gmt true]
}


######################################################################
# Name:        enf_xltp_today_UTC_YYYYMMJJ
# Purpose:    <description>
# UPoC type:    xltp
# Args:        none
# Notes:    All data is presented through special variables.  The initial
#        upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#

proc enf_xltp_today_UTC_YYYYMMJJ {} {
    upvar xlateId       xlateId        \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals

    set xlateOutVals [clock format [clock seconds] -format "%Y%m%d" -gmt true]
}


######################################################################
# Name:          enf_xltp_CDA_toDate_STATBDD
# Purpose:       <description>
# UPoC type:    xltp
# Args:        none
# Notes:        All data is presented through special variables.  The initial
#        upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#               

 

proc enf_xltp_CDA_toDate_STATBDD {} {
        upvar xlateId       xlateId    \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals
    
    set date [ string range $xlateInVals 0 7]
    set heure [ string range $xlateInVals 8 13]
    set op [ string range $xlateInVals 14 14]
    if { [cequal $op +] || [cequal $op -]} {
        set decalh [ string range $xlateInVals 15 16]
        if { $decalh=="" } {
            set decalh 00
        }
        set decalm [ string range $xlateInVals 17 18]
        if { $decalm=="" } {
            set decalm 00
        }
        
        if { [cequal $op +] } {
            set op -
        } else {
            set op +
        }
        set xlateOutVals [clock format [clock scan "$date $heure ${op}$decalh hour ${op}$decalm minute"] -format "%Y-%m-%d %H:%M:%S"] 
    } else {
        set xlateOutVals [clock format [clock scan "$date $heure"] -format "%Y-%m-%d %H:%M:%S" -gmt 1]
    }
}




######################################################################
# Name:          enf_xltp_CDA_toDate_XDS
# Purpose:       <description>
# UPoC type:    xltp
# Args:        none
# Notes:        All data is presented through special variables.  The initial
#        upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#               

 

proc enf_xltp_CDA_toDate_XDS {} {
        upvar xlateId       xlateId    \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals
    
    set date [ string range $xlateInVals 0 7]
    set heure [ string range $xlateInVals 8 13]
    set op [ string range $xlateInVals 14 14]
    if { [cequal $op +] || [cequal $op -]} {
        set decalh [ string range $xlateInVals 15 16]
        if { $decalh=="" } {
            set decalh 00
        }
        set decalm [ string range $xlateInVals 17 18]
        if { $decalm=="" } {
            set decalm 00
        }
        
        if { [cequal $op +] } {
            set op -
        } else {
            set op +
        }
        set xlateOutVals [clock format [clock scan "$date $heure ${op}$decalh hour ${op}$decalm minute"] -format "%Y%m%d%H%M%S"] 
    } else {
        set xlateOutVals [clock format [clock scan "$date $heure"] -format "%Y%m%d%H%M%S" -gmt 1]
    }
}


######################################################################
# Name:        enf_xltp_ctr
# Purpose:    <description>
# UPoC type:    xltp
# Args:        none
# Notes:    All data is presented through special variables.  The initial
#        upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#

proc enf_xltp_ctr {} {
    upvar xlateId       xlateId        \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals

    set ctrfile [lindex $xlateInVals 0]
    set value [lindex $xlateInVals 1]
    if {![file exists "$ctrfile.ctr"] } {
        CtrInitCounter $ctrfile file 0 999999999 1
    }
    
    set ctrval [CtrNextValue $ctrfile file]

    set xlateOutVals ${value}$ctrval
}


######################################################################
# Name:        enf_xltp_oid
# Purpose:    <description>
# UPoC type:    xltp
# Args:        none
# Notes:    All data is presented through special variables.  The initial
#        upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#

proc enf_xltp_oid {} {
    upvar xlateId       xlateId        \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals
    
    set time [clock seconds]
    set mid [xpmmetaget $xlateId MID]
    keylget mid NUM num 
    
    set racine [lindex $xlateInVals 0]
    set branche [lindex $xlateInVals 1]

    set xlateOutVals ${racine}.${branche}.${time}${num}
}


######################################################################
# Name:        enf_xltp_oid_noroot
# Purpose:    <description>
# UPoC type:    xltp
# Args:        none
# Notes:    All data is presented through special variables.  The initial
#        upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#

proc enf_xltp_oid_noroot {} {
    upvar xlateId       xlateId        \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals
    
    set time [clock seconds]
    set mid [xpmmetaget $xlateId MID]
    keylget mid NUM num 

    set xlateOutVals ${time}${num}
}

######################################################################
# Name:      enf_validFormat_ack_v3
# Purpose:   Procedure permettant de vï¿½rifier le format d'un fichier
#            et de gï¿½nerer un ack xml le cas echeant.
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                   XMLPATH : path du schema xml
#                   NOMOCM : nom du schema xml
#                   FORMAT : nom du format pour le message d'erreur
#        DEST : nom du Thread de destination des accuses
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   v2 20140319 TLZ : Optimisations
#            v3 20140321 TLZ : Passage du thread de destination en variable
#   
proc enf_validFormat_ack_v3 { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""     ; keylget args CONTEXT ctx      ;# Fetch tps caller context
    set uargs {}   ; keylget args ARGS uargs       ;# Fetch user-supplied args
    set xmlPath "" ; keylget uargs XMLPATH xmlPath
    set nomOCM ""  ; keylget uargs NOMOCM nomOCM
    set format ""  ; keylget uargs FORMAT format
    set dest "" ; keylget uargs DEST dest

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "enf_validFormat_ack/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
        set error false
        
    #Test du message avec grm
    if { [ catch {set gh [grmcreate -msg $mh xml $xmlPath $nomOCM] } fid ] } {
        echo $fid
        set error true
        set messErr "Message non conforme au format $format"
    } else { grmdestroy $gh }

    #Si une erreur se produit
    if [cequal $error true] {

        #Gestion de l'ACK si il y a une erreur
            
        #Recuperation du nom du fichier
            set driver [msgmetaget $mh DRIVERCTL]
            set fileName [keylget driver FILENAME]

        #Suppression du pdf
            append fichierDelpdf [file rootname $fileName] .pdf
            echo suppression de : $fichierDelpdf
            file delete $fichierDelpdf

        #Suppression du ok
            #append fichierDelok [file rootname $fileName] .ok
            #echo suppression de : $fichierDelok
            #file delete $fichierDelok


        # Recuperation du message
            set msgContent [msgget $mh]

        #Creation de l'ack avec grm
            set grmAck [grmcreate xml schema retourDMP]
            grmstore $grmAck reponse_dmp.message.statut.#text d -c "false"
            grmstore $grmAck reponse_dmp.message.libelle.&code d -c "ErrFormat"
            grmstore $grmAck reponse_dmp.message.libelle.#text d -c $messErr
            grmstore $grmAck reponse_dmp.message.log_erreur.#text d -c \<\!\[CDATA\[$fid\]\]\>
            grmstore $grmAck reponse_dmp.message.trame.#text d -c \<\!\[CDATA\[$msgContent\]\]\>
            set msgAck [grmencode -type reply $grmAck]

        #Nommage de l'ack
            keylset keyfilename FILENAME $fileName.ack
            
        #Envoi du message en erreur et de l'ACK vers la source
            msgmetaset $msgAck DRIVERCTL $keyfilename DESTCONN $dest
            lappend dispList "ERROR $mh"
            lappend dispList "CONTINUE $msgAck"

        #Nettoyage des variables
            grmdestroy $grmAck
    
    } else { lappend dispList "CONTINUE $mh" }
    }

    time {
        # Timer-based processing
        # N.B.: there may or may not be a MSGID key in args
        
    }
    
    default {
        error "Unknown mode '$mode' in $module"
    }
    }

    return $dispList
}

######################################################################
# Name:      enf_validFormat_ack_vExterieurCR
# Purpose:   Procedure permettant de vï¿½rifier le format d'un fichier
#            et de gï¿½nerer un ack xml le cas echeant.
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                   XMLPATH : path du schema xml
#                   NOMOCM : nom du schema xml
#                   FORMAT : nom du format pour le message d'erreur
#        DEST : nom du Thread de destination des accuses
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   v2 20140319 TLZ : Optimisations
#            v3 20140321 TLZ : Passage du thread de destination en variable
#            vExterieuCR 20140321 TLZ : Filtrage des messages xml et renommage en del si erreur
#   
proc enf_validFormat_ack_vExterieurCR { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""     ; keylget args CONTEXT ctx      ;# Fetch tps caller context
    set uargs {}   ; keylget args ARGS uargs       ;# Fetch user-supplied args
    set xmlPath "" ; keylget uargs XMLPATH xmlPath
    set nomOCM ""  ; keylget uargs NOMOCM nomOCM
    set format ""  ; keylget uargs FORMAT format
    set dest "" ; keylget uargs DEST dest

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "enf_validFormat_ack/$HciConnName/$ctx" ;# Use this before every echo/puts,
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

              set error false

        keylget args MSGID mh
              set driver [msgmetaget $mh DRIVERCTL]    
              set fileName [file tail [keylget driver FILENAME]]
              set fileNameNoext [file rootname $fileName]
              set extension [file extension $fileName]
              set dirName [file dirname [keylget driver FILENAME]]

          if [cequal $extension .xml] {

    #Test du message avec grm
    if { [ catch {set gh [grmcreate -msg $mh xml $xmlPath $nomOCM] } fid ] } {
        echo $fid
        set error true
        set messErr "Message non conforme au format $format"
    } else { grmdestroy $gh }

    #Si une erreur se produit
    if [cequal $error true] {

        #Gestion de l'ACK si il y a une erreur
            
        #Recuperation du nom du fichier
            set driver [msgmetaget $mh DRIVERCTL]
            set fileName [keylget driver FILENAME]

        # Recuperation du message
            set msgContent [msgget $mh]

        #Creation de l'ack avec grm
            set grmAck [grmcreate xml schema retourDMP]
            grmstore $grmAck reponse_dmp.message.statut.#text d -c "false"
            grmstore $grmAck reponse_dmp.message.libelle.&code d -c "ErrFormat"
            grmstore $grmAck reponse_dmp.message.libelle.#text d -c $messErr
            grmstore $grmAck reponse_dmp.message.log_erreur.#text d -c \<\!\[CDATA\[$fid\]\]\>
            grmstore $grmAck reponse_dmp.message.trame.#text d -c \<\!\[CDATA\[$msgContent\]\]\>
            set msgAck [grmencode -type reply $grmAck]

        #Renommage du fichier d'origine
            keylset keyfilename FILENAME $dirName/$fileNameNoext.del
            msgmetaset $mh DRIVERCTL $keyfilename
            
        #Nommage de l'ack
            append fileName _ERR_Format .ack
            keylset keyfilename FILENAME $fileName

        #Envoi du message en erreur et de l'ACK vers la source
            msgmetaset $msgAck DRIVERCTL $keyfilename DESTCONN $dest
            
            lappend dispList "CONTINUE $msgAck"

        #Nettoyage des variables
            grmdestroy $grmAck
    
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
    
    default {
        error "Unknown mode '$mode' in $module"
    }
    }

    return $dispList
}

######################################################################
# Name:        xper_reply_constructCDAResponse
# Purpose:  RÃ©cupÃ¨re la rÃ©ponse PDQ pour l'intÃ©grer au message HPRIM d'origine
# UPoC type: tps
# Args:     none
# Returns: tps disposition list

proc xper_reply_constructCDAResponse { args } {
    keylget args MODE mode;# Fetch mode
    package require smtp
    package require mime 
    global HciSiteDir
    global HciConnName
    set dispList {}             ;# Nothing to return

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            #On charge les 2 messages (HL7 reÃ§u de PDQ, HL7 d'origine qui contient le HPR et les PDF)
            keylget args MSGID hl7_from_pdq
            keylget args OBMSGID originalMsg
            set userdata [msgmetaget $originalMsg USERDATA]
            set driverCtl [msgmetaget $originalMsg DRIVERCTL]
            set filename [keylget driverCtl FILENAME]
            # On crÃ©Ã© le CDA final
            #echo message CDA IN [keylget userdata CONTENT]
            set new_cda [msgcreate -recover -type data [keylget userdata CONTENT]]            
            
            keyldel userdata CONTENT                
            msgmetaset $new_cda USERDATA $userdata
            #echo "pdq response:"
            #msgdump $hl7_from_pdq

            if { $debug } {
                echo $originalCDA
            }           


            #on rÃ©cupÃ¨re l'INSC de la rÃ©ponse du PDQ
            set datList [datlist]
            set gh_hl7 [grmcreate -msg $hl7_from_pdq hl7 2.5 QBP_ZV1 RSP_K22]            
            set dh_insc [grmfetch $gh_hl7 1(0).0(0).PID(0).#3(1).\[0\]]    
            set insc [datget $dh_insc VALUE]
            echo "INSC: $insc"
            #set insc "0440914429993761844205"
            #set insc "04409144299937618442"
            if { $insc == "" } {
                
                echo "Il n'y a pas d'INSC pour cet IPP"

                set msgContent [msgget $new_cda]
                
                #Creation de l'ack avec grm
                set grmAck [grmcreate xml DMP_RESPONSE dmp_response_to_cis_v2]
                grmstore $grmAck dmp_response_to_cis_v2.transaction_type.#text d -c "alimentation"
                grmstore $grmAck dmp_response_to_cis_v2.message.status.#text d -c "false"
                grmstore $grmAck dmp_response_to_cis_v2.message.detail.&code d -c "INSnoexist"
                grmstore $grmAck dmp_response_to_cis_v2.message.detail.#text d -c "Aucun INSC retrouvÃ© pour ce patient"
                grmstore $grmAck dmp_response_to_cis_v2.message.dmp_raw_response.#text d -c \<\!\[CDATA\[$msgContent\]\]\>
                set msgAck [grmencode -type reply $grmAck]
                
                #Nommage de l'ack
                keylset keyfilename FILENAME $filename.ack
                
                #Envoi du message en erreur et de l'ACK vers la source
                msgmetaset $msgAck DRIVERCTL $keyfilename DESTCONN ACK_KO
                lappend dispList "SEND $msgAck"
                
                #Nettoyage des variables
                grmdestroy $grmAck
            } else {
                #on parse le message d'origine         
                set gh_xml_cda [grmcreate -msg $new_cda xml CDA\\Schemas CDA]

                grmstore $gh_xml_cda nm1:ClinicalDocument.nm1:recordTarget(0).nm1:patientRole.nm1:id(0).&extension c $insc
                set new_cda_mh [ grmencode -recover -type data -warn w $gh_xml_cda ]            
    
                msgmetaset $new_cda_mh USERDATA $userdata
                msgmetaset $new_cda_mh DRIVERCTL $driverCtl
    
                #libere les ressources
                hcidatlistreset $datList
                grmdestroy $gh_xml_cda
                echo OVER
                lappend dispList "CONTINUE $new_cda_mh"    
            }
            grmdestroy $gh_hl7 
            lappend dispList "KILLREPLY $hl7_from_pdq"
            lappend dispList "KILL $originalMsg"
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

#####################################################################
# Name:        xper_reply_constructResponse
# Purpose:  Récupère la réponse PDQ pour l'intégrer au message d'origine
# UPoC type: tps
# Args:     none
# Returns: tps disposition list

proc xper_reply_constructResponse { args } {
    keylget args MODE mode;# Fetch mode
    package require smtp
    package require mime 
    global HciSiteDir
    global HciConnName
    set dispList {}             ;# Nothing to return

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            #On charge les 2 messages (HL7 reÃ§u de PDQ, HL7 d'origine qui contient le HPR et les PDF)
            keylget args MSGID hl7_from_pdq
            keylget args OBMSGID originalMsg
            set userdata [msgmetaget $originalMsg USERDATA]
            set driverCtl [msgmetaget $originalMsg DRIVERCTL]
            set filename [keylget driverCtl FILENAME]
            # On crÃ©Ã© le CDA final
            #echo message CDA IN [keylget userdata CONTENT]
            set new_cda [msgcreate -recover -type data [keylget userdata CONTENT]]            
            
            keyldel userdata CONTENT                
            msgmetaset $new_cda USERDATA $userdata
            #echo "pdq response:"
            #msgdump $hl7_from_pdq

            if { $debug } {
                echo $originalCDA
            }           


            #on rÃ©cupÃ¨re l'INSC de la rÃ©ponse du PDQ
            set datList [datlist]
            set gh_hl7 [grmcreate -msg $hl7_from_pdq hl7 2.5 QBP_ZV1 RSP_K22]            
            set dh_insc [grmfetch $gh_hl7 1(0).0(0).PID(0).#3(1).\[0\]]    
            set insc [datget $dh_insc VALUE]
            echo "INSC: $insc"
            #set insc "0440914429993761844205"
            #set insc "04409144299937618442"
            if { $insc == "" } {
                
                echo "Il n'y a pas d'INSC pour cet IPP"

                set msgContent [msgget $new_cda]
                
                #Creation de l'ack avec grm
                set grmAck [grmcreate xml DMP_RESPONSE dmp_response_to_cis_v2]
                grmstore $grmAck dmp_response_to_cis_v2.transaction_type.#text d -c "alimentation"
                grmstore $grmAck dmp_response_to_cis_v2.message.status.#text d -c "false"
                grmstore $grmAck dmp_response_to_cis_v2.message.detail.&code d -c "INSnoexist"
                grmstore $grmAck dmp_response_to_cis_v2.message.detail.#text d -c "Aucun INSC retrouvÃ© pour ce patient"
                grmstore $grmAck dmp_response_to_cis_v2.message.dmp_raw_response.#text d -c \<\!\[CDATA\[$msgContent\]\]\>
                set msgAck [grmencode -type reply $grmAck]
                
                #Nommage de l'ack
                keylset keyfilename FILENAME $filename.ack
                
                #Envoi du message en erreur et de l'ACK vers la source
                msgmetaset $msgAck DRIVERCTL $keyfilename DESTCONN ACK_KO
                lappend dispList "SEND $msgAck"
                
                #Nettoyage des variables
                grmdestroy $grmAck
            } else {
                #on parse le message d'origine         
                keylset metadata INS $insc
                msgmetaset $new_cda USERDATA $metadata
                msgmetaset $new_cda DRIVERCTL $driverCtl
    
                #libere les ressources
                hcidatlistreset $datList
                #grmdestroy $gh_xml_cda
                #echo OVER
                lappend dispList "CONTINUE $new_cda"    
            }
            grmdestroy $gh_hl7 
            lappend dispList "KILLREPLY $hl7_from_pdq"
            lappend dispList "KILL $originalMsg"
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
# Name:        xper_tps_addMsgToUserdata
# Purpose:  Ajoute les messages courants dans les userdata
# UPoC type: tps
# Args:     none
# Returns: tps disposition list

proc xper_tps_addMsgToUserdata { args } {
    package require Sitecontrol
    package require Tcl
    keylget args MODE mode                  ;# Fetch mode
    global HciSiteDir
    global HciConnName
    set uargs {} ; keylget args ARGS uargs
    set content CONTENT; catch {keylget uargs CONTENT content}
    set dispList {}             ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh                                 
            set currentMsg ""                        
            keylset currentMsg $content [msgget $mh]                    
            # echo $currentMsg
            msgmetaset $mh USERDATA $currentMsg    
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




