######################################################################
# Name:  enf_tps_changeFileNameOB_v2
# Purpose:  Remplace le nom du fichier sauvegarder en OB. Ce nom aura la forme : NAMECONN_nummsg_datedujour.EXT (ex: SIM_20070601_363.txt)
#      Si, l'argument TEMOIN est défini à "ok", un fichier témoin .ok sera créé (ex: SIM_20070601_363.ok)
# UPoC type: tps
## Args: {NAMECONN Prefix} (optional, default = "nameConnecteur")
#        {EXT Extension} (optional, default = "extension")
#        {TEMOIN TemonExt} (optional, default = "temoin", info = s'il est défini à "oui" ou "ok", il ordonnera la création d'un fichier témoin .ok.)
# Returns: tps disposition list
# History: 03-04-2009 Aurelien Garros, E.Novation France : Creation
#          14-04-2013 v2 Thibaud LOPEZ, E.Novation France : Possibilite de definir l extension du temoin
#          16-09-2014 Thibaud LOPEZ, E.Novation France : Argument NAMECONN facultatif
#          09-01-2015 TLZ EnF : Rend compatible l'argument temoin avec la version precedente (argument "oui" : creation .ok)

proc enf_tps_changeFileNameOB_v2 { args } {
    keylget args MODE mode               ;# Fetch mode
    keylget args ARGS uargs
    set nameConnecteur "nameConnecteur"      ; keylget uargs NAMECONN nameConnecteur
    set extension "extension"        ; keylget uargs EXT extension
    set temoin "temoin"        ;  keylget uargs TEMOIN temoin

    set dispList {}    ;# Nothing to return
    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }
        run {

            keylget args MSGID mh

            set today [clock format [clock seconds] -format "%Y%m%d"]

            # prise de l'information dans la clé MID
            set v_keydatafile [msgmetaget $mh MID]
            keylget v_keydatafile NUM v_datafile

            if { ![cequal $nameConnecteur nameConnecteur] } {
                set v_newNameFile ${nameConnecteur}_
            }
            append v_newNameFile $today
            append v_newNameFile _$v_datafile
            append v_newNameFile .
            set newNameFile ${v_newNameFile}
            append newNameFile ${extension}

            # affectation de la valeur
            set driverctl "{FILESET {{OBFILE ${newNameFile}}}}"
            # affectation de la donnée au driver
            msgmetaset $mh DRIVERCTL ${driverctl}
            lappend dispList "CONTINUE $mh"

            if { ![cequal $temoin temoin] } {
                if { [cequal $temoin oui] } {
                    set temoin ok
                }
                set okNameFile ${v_newNameFile}
                append okNameFile ${temoin}
                set okdriverctl "{FILESET {{OBFILE ${okNameFile}}}}"
                set okmh [msgcreate -recover ""]
                msgmetaset $okmh DRIVERCTL ${okdriverctl}
                lappend dispList "CONTINUE $okmh"
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
# Name:       enf_set_userdata_from_param
# Purpose:    Attribue le USERDATA du message avec les valeurs passées en paramètres.
# UPoC type: tps
# Args:   {PARAM1 VALUE1} (required)
# Returns: tps disposition list

proc enf_set_userdata_from_param { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    switch -exact -- $mode {
        start {
            # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
        }

        run {
        # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set userdata [msgmetaget $mh USERDATA]
            foreach key [keylkeys uargs] {
                keylget uargs $key value
                keylset userdata $key $value
            }
            msgmetaset $mh USERDATA $userdata
#            msgdump $mh

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



######################################################################
# Name:        enf_IB_FileName_to_OB_v2
# Purpose:    Cette procedure permet de nommer un fichier avec le meme nom
#            qu'il avait en entree Le fchier peut porter un nom du type test.t.txt
#            Gestion de . multiples impossible dans la v1
# UPoC type:    tps
# Args: {TEMOIN TemonExt} (optional, default = "temoin", info = s'il est défini à "oui" ou "ok", il ordonnera la création d'un fichier témoin .ok)
#       {EXT extension} (optional, default = "ext")
# Returns: tps disposition list
# History: 03-04-2009 Aurelien Garros, E.Novation France
#          04-07-2012 Aurelien Garros, E.Novation France
#                     Ajout du msgcopy pour la création du .ok
#          09-01-2015 TLZ, EnF : Utilisation du rootname
#          11-05-2015 TLZ, EnF : Possibilite de definir l extension du temoin

proc enf_IB_FileName_to_OB_v2 { args } {
    keylget args MODE mode               ;# Fetch mode
    keylget args ARGS uargs
    set temoin "temoin"  ;  keylget uargs TEMOIN temoin
    set ext "ext"  ;  keylget uargs EXT ext

    set dispList {}    ;# Nothing to return

    switch -exact -- $mode {
    start {
        # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
    }

    run {
        # 'run' mode always has a MSGID; fetch and process it
        keylget args MSGID mh
        set driver [msgmetaget $mh DRIVERCTL]

        set today [clock format [clock seconds] -format "%Y%m%d"]

        # prise de l'information dans la clé MID
        set v_keydatafile [msgmetaget $mh MID]
        keylget v_keydatafile NUM v_datafile


        set fileName "${today}_${v_datafile}.txt"; catch { set fileName [file tail [keylget driver FILENAME]] }
        set firstPart [file rootname $fileName]
        if { ![cequal $ext ext] } {
            set fileName "\{"
            append fileName ${firstPart}.${ext}
            append fileName "\}"
        } else {
            set tempfileName "\{"
            append tempfileName $fileName
            append tempfileName "\}"
            set fileName ${tempfileName}
        }
        # affectation de la valeur
        set driverctl "{FILESET {{OBFILE ${fileName}}}}"
        # affectation de la donnee au driver
        msgmetaset $mh DRIVERCTL $driverctl
        lappend dispList "CONTINUE $mh"

        if { ![cequal $temoin temoin] } {
            if { [cequal $temoin oui] } {
            set temoin ok
            }

            # set v_newNameFile [file rootname $fileName]
            set v_newNameFile $firstPart
            set okNameFile "\{"
            append okNameFile ${v_newNameFile}.${temoin}
            append okNameFile "\}"
            set okdriverctl "{FILESET {{OBFILE ${okNameFile}}}}"

            set okmh [msgcopy $mh]
            msgset $okmh ""
            msgmetaset $okmh DRIVERCTL $okdriverctl
            lappend dispList "CONTINUE $okmh"
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
# Name:        enf_IB_FileName_to_OB_v2_special_chars
# Purpose:    Cette procedure permet de nommer un fichier avec le meme nom
#            qu'il avait en entree Le fchier peut porter un nom du type test.t.txt
#            Gestion de . multiples impossible dans la v1
# UPoC type:    tps
# Args: {TEMOIN TemonExt} (optional, default = "temoin", info = s'il est défini à "oui" ou "ok", il ordonnera la création d'un fichier témoin .ok)
#       {EXT extension} (optional, default = "ext")
# Returns: tps disposition list
# History: 03-04-2009 Aurelien Garros, E.Novation France
#          04-07-2012 Aurelien Garros, E.Novation France
#                     Ajout du msgcopy pour la création du .ok
#          09-01-2015 TLZ, EnF : Utilisation du rootname
#          11-05-2015 TLZ, EnF : Possibilite de definir l extension du temoin

proc enf_IB_FileName_to_OB_v2_special_chars { args } {
    keylget args MODE mode               ;# Fetch mode
    keylget args ARGS uargs
    set temoin "temoin"  ;  keylget uargs TEMOIN temoin
    set ext "ext"  ;  keylget uargs EXT ext

    set dispList {}    ;# Nothing to return

    switch -exact -- $mode {
    start {
        # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
    }

    run {
        # 'run' mode always has a MSGID; fetch and process it
        keylget args MSGID mh
        set driver [msgmetaget $mh DRIVERCTL]

        set today [clock format [clock seconds] -format "%Y%m%d"]

        # prise de l'information dans la clé MID
        set v_keydatafile [msgmetaget $mh MID]
        keylget v_keydatafile NUM v_datafile


        set rawFileName "${today}_${v_datafile}.txt"; catch { set rawFileName [file tail [keylget driver FILENAME]] }
        set fileName [string map {"à" "a" "â" "a" "ä" "a" "ã" "a" "é" "e" "è" "e" "ê" "e" "ë" "e" "î" "i" "ï" "i" "ô" "o" "ö" "o" "õ" "o" "ù" "u" "û" "u" "ü" "u" "ç" "c" "ñ" "n" "À" "A" "Â" "A" "Ä" "A" "Ã" "A" "É" "E" "È" "E" "Ê" "E" "Ë" "E" "Î" "I" "Ï" "I" "Ô" "O" "Ö" "O" "Õ" "O" "Ù" "U" "Û" "U" "Ü" "U" "Ç" "C" "Ñ" "N"} $rawFileName]

        if { ![cequal $ext ext] } {
            set firstPart [file rootname $fileName]
            set fileName "\""
            append fileName ${firstPart}.$ext
            append "\""
        }
        # affectation de la valeur
        set driverctl "{FILESET {{OBFILE $fileName}}}"
        # affectation de la donnee au driver
        msgmetaset $mh DRIVERCTL $driverctl
        lappend dispList "CONTINUE $mh"

        if { ![cequal $temoin temoin] } {
            if { [cequal $temoin oui] } {
                set temoin ok
            }

            set v_newNameFile [file rootname $fileName]
            set okNameFile "\""
            append okNameFile ${v_newNameFile}.$temoin
            append okNameFile "\""
            set okdriverctl "{FILESET {{OBFILE $okNameFile}}}"

            set okmh [msgcopy $mh]
            msgset $okmh ""
            msgmetaset $okmh DRIVERCTL $okdriverctl
            lappend dispList "CONTINUE $okmh"
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
# Name:       enf_temoin_OB_FileName
# Purpose:  Permet de créer un fichier témoin en se basant sur le nom de sortie du fichier
# UPoC type: tps
# Args: {EXT extension} (optional, default = "ext")
# Returns: tps disposition list
# History: 03-04-2009 Aurelien Garros, E.Novation France
#          04-07-2012 Aurelien Garros, E.Novation France
#                     Ajout du msgcopy pour la création du .ok

proc enf_temoin_OB_FileName { args } {
    keylget args MODE mode               ;# Fetch mode
    keylget args ARGS uargs
    set ext "ok"  ;  keylget uargs EXT ext

    set dispList {}    ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set filename [msgmetaget $mh DRIVERCTL]
            keylget filename FILESET fileset
            keylget fileset OBFILE name
            set okNameFile "\""
            append okNameFile [file rootname $name]
            append okNameFile "."
            append okNameFile $ext
            append okNameFile "\""
            set okdriverctl "{FILESET {{OBFILE $okNameFile}}}"

            set okmh [msgcopy $mh]
            msgset $okmh ""
            msgmetaset $okmh DRIVERCTL $okdriverctl
            lappend dispList "CONTINUE $mh"
            lappend dispList "CONTINUE $okmh"
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
# Name:        enf_replaceEOL_CRbyCRLF
# Purpose:    Procédure qui permet de modifier le caractère de fin ligne : 0d en 0d0a
# UPoC type: tps
# Args: none
# Returns: tps disposition list

proc enf_replaceEOL_CRbyCRLF { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set msg [msgget $mh]

            # set msg [gc_replaceChars \r @!!y#!!@ $msg]
            # set msg [gc_replaceChars @!!y#!!@ \r\n $msg]
            set msg [string map {"\r" "\r\n"} $msg]
            msgset $mh $msg
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

######################################################################
# Name:        enf_replaceEOL_CRbyLF
# Purpose:    Procédure qui permet de modifier le caractère de fin ligne : 0d en 0a
# UPoC type: tps
# Args: none
# Returns: tps disposition list

proc enf_replaceEOL_CRbyLF { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set msg [msgget $mh]

            # set msg [gc_replaceChars \r @!!y#!!@ $msg]
            # set msg [gc_replaceChars @!!y#!!@ \n $msg]
            set msg [string map {"\r" "\n"} $msg]
            msgset $mh $msg
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

######################################################################
# Name:       enf_replaceEOL_CRLFbyCR
# Purpose:    Procédure qui permet de modifier le caractère de fin ligne : 0d0a en 0d
# UPoC type:    tps
# Args: none
# Returns: tps disposition list

proc enf_replaceEOL_CRLFbyCR { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set msg [msgget $mh]

            # set msg [gc_replaceChars \r\n @!!y#!!@ $msg]
            # set msg [gc_replaceChars @!!y#!!@ \r $msg]
            set msg [string map {"\r\n" "\r"} $msg]
            msgset $mh $msg
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

######################################################################
# Name:       enf_replaceEOL_CRLFbyLF
# Purpose:    Procédure qui permet de modifier le caractère de fin ligne : 0d0a en 0d
# UPoC type:    tps
# Args: none
# Returns: tps disposition list

proc enf_replaceEOL_CRLFbyLF { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
    start {
        # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
    }

    run {
        # 'run' mode always has a MSGID; fetch and process it
        keylget args MSGID mh
        set msg [msgget $mh]

        # set msg [gc_replaceChars \r\n @!!y#!!@ $msg]
        # set msg [gc_replaceChars @!!y#!!@ \n $msg]
        set msg [string map {"\r\n" "\n"} $msg]
        msgset $mh $msg
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

######################################################################
# Name:        enf_replaceEOL_LFbyCRLF
# Purpose:    Procedure qui permet de modifier le caractere de fin ligne : 0a en 0d0a
# UPoC type:    tps
# Args: none
# Returns: tps disposition list

proc enf_replaceEOL_LFbyCRLF { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set msg [msgget $mh]

            # set msg [gc_replaceChars \n @!!y#!!@ $msg]
            # set msg [gc_replaceChars @!!y#!!@ \r\n $msg]
            set msg [string map {"\n" "\r\n"} $msg]
            msgset $mh $msg
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


######################################################################
# Name:        enf_replaceEOL_LFbyCR
# Purpose:    Procedure qui permet de modifier le caractere de fin ligne : 0a en 0d
# UPoC type:    tps
# Args: none
# Returns: tps disposition list

proc enf_replaceEOL_LFbyCR { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set msg [msgget $mh]

            # set msg [gc_replaceChars \n @!!y#!!@ $msg]
            # set msg [gc_replaceChars @!!y#!!@ \r $msg]
            set msg [string map {"\n" "\r"} $msg]
            msgset $mh $msg
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


######################################################################
# Name:        enf_tps_filtreTypeHL7
# Purpose:    Cette procedure recupère en arguments la liste des types
#             d'évènements a supprimer du flux
#             Elle filtre aussi les messages dont le MEDECIN TRAITANT
#             est renseigné
# UPoC type:    tps
# Args:     {LIST MessageList} (required, default = none, info = EVENEMENT a supprimer
#                                ex : {LIST ADT_A01|ADT_A04|ADT_A08})
# Returns: tps disposition list

proc enf_tps_filtreTypeHL7 { args } {
    keylget args MODE mode                  ;# Fetch mode
    keylget args ARGS ARGS                  ;# Fetch mode
    keylget ARGS LIST liste             ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh


            set datList [datlist]

            # Recuperation de la liste des TYPES D'EVENEMENT a filtrer

            set listChamps [split $liste "|"]

            # Chargement du message et Recuperation du TYPE D'EVENEMENT
            set gh [grmcreate -msg $mh hl7 2.3.1 IHE ORU_R01]
            set dh [grmfetch $gh 0(0).MSH(0).00009(0).\[0\]]
            set evnt [datget $dh VALUE]
            set dh [grmfetch $gh 0(0).MSH(0).00009(0).\[1\]]
            append evnt _ [datget $dh VALUE]

            # Chargement du message et Recuperation du MEDECIN TRAITANT
            set dh [grmfetch $gh 0(0).PV1(0).00149(0).\[0\]]
            set nv [datget $dh VALUE]
            set dh [grmfetch $gh 0(0).PV1(0).00149(0).\[1\]]
            append nv [datget $dh VALUE]
            set dh [grmfetch $gh 0(0).PV1(0).00149(0).\[2\]]
            append nv [datget $dh VALUE]
            set dh [grmfetch $gh 0(0).PV1(0).00149(0).\[3\]]
            append nv [datget $dh VALUE]
            set dh [grmfetch $gh 0(0).PV1(0).00149(0).\[4\]]
            append nv [datget $dh VALUE]
            set dh [grmfetch $gh 0(0).PV1(0).00149(0).\[5\]]
            append nv [datget $dh VALUE]


            # Boucle sur la liste des TYPES D'EVENEMENT traitees

            # CONTINUE si TYPE D'EVENEMENT geree
            set disp NOK

            foreach champ $listChamps {
                if { [cequal $champ $evnt]} {
                    # Continue du messsage si TYPES D'EVENEMENT geree
                    # Suppression du messsage si NUMERO DE VISITE non renseigné
                    if { [string length $nv] > 0 } {
                            set disp OK
                    }
                }
            }


            #libere les ressources
            hcidatlistreset $datList
            grmdestroy $gh

            if { [cequal $disp NOK] } {
                # Suppression du messsage si TYPES D'EVENEMENT non geree
                lappend dispList "KILL $mh"
            } else {
                # CONTINUE si TYPES D'EVENEMENT geree
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
# Name:        enf_killOkFile_v2
# Purpose: Supprime les fichiers témoins en précisant en argument
#          l'extension du fichier à supprimer (.ok par défaut)
# UPoC type: tps
# Args: EXT extension du fichier à supprimer. Ne pas oublier le .
# Returns: tps disposition list
# History :
#Fix : 11/06/12 Prise en charge des noms comportant plusieurs points

proc enf_killOkFile_v2 { args } {
    keylget args MODE mode                  ;# Fetch mode
    set ext "ok"; catch {keylget args ARGS.EXT ext}

    set dispList {}                ;# Nothing to return

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
# Name:        enf_killOkFileAndStopThread
# Purpose:    Supprime les fichiers OK et Stoppe le thread CERNER_CESINT
#           du process CESINT_DB
# UPoC type:    tps
# Args: none
# Returns: tps disposition list

proc enf_killOkFileAndStopThread { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            #initialisation d la variable name
            #pour ne pas avoir de probleme
            #lors de resend par le smat

            set name smat.txt

            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set file [msgmetaget $mh DRIVERCTL]
            keylget file FILENAME name
            set newname [file tail $name]
            set ext [lindex [split $newname "."] 1]

            if { [cequal $ext ok] || [cequal $ext OK] || [cequal $ext oK] || [cequal $ext Ok]} {
                lappend dispList "KILL $mh"
                catch { set result [exec cmd /c hcicmd -p CESINT_DB -c "CERNER_CESINT pstop"] }
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
# Name:        enf_tps_remove_tab_and_space
# Purpose:    Supprime tous les espaces et les tabulations d'un message
# UPoC type: tps
# Args: none
# Returns: tps disposition list

proc enf_tps_remove_tab_and_space { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set content [msgget $mh]
            regsub -all {>\n*\s*\t*<} $content {><} newcontent
            msgset $mh $newcontent
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


######################################################################
# Name:      enf_tps_delete_blank_msg
# Purpose:   Supprime les messages vides correspondant à pattern
# UPoC type: tps
# Args:  {DEBUG 0|1} (optional, default = 0)
#        {PATTERN regexFile} (required, default = "")
# Returns:   tps disposition list

proc enf_tps_delete_blank_msg { args } {
    global HciConnName                             ;# Name of thread

    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
    set pattern "" ; keylget uargs PATTERN pattern

    set module "enf_tps_delete_blank_msg/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
            set process OK

            #si pattern defini
            if { $pattern != "" } {
                #si pattern correspond
                set driver [msgmetaget $mh DRIVERCTL]
                set fileName [keylget driver FILESET.OBFILE]
                if { [regexp -- ${pattern} $fileName] == 1 } {
                    #si message non vide
                    if { [string length [msgget $mh] ] > 0 } {
                        set process OK
                    } else {
                        set process NOK
                    }
                } else {
                    set process OK
                }
            } else {
                set process OK
            }

            if { [cequal $process OK] } {
                lappend dispList "CONTINUE $mh"
            } else {
                lappend dispList "KILL $mh"
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



######################################################################
# Name:        enf_removeEOL
# Purpose:    Supprime le caractère 0a
# UPoC type: tps
# Args: none
# Returns: tps disposition list

proc enf_removeEOL { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set msg [msgget $mh]
            # set msg [gc_replaceChars \n "" $msg]
            set msg [string map {"\r" "" "\n" "" "\r\n" ""} $msg]
            msgset $mh $msg
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



######################################################################
# Name:      enf_tps_replace_eol_hl7
# Purpose:   Permet de remplacer les caracteres de fin de lignes par
#            ceux definit dans la norme HL7 : <CR>
#            Autrement, les messages pourrait etre rejete en Xlate
# UPoC type: tps
# Args: none
# Returns:   tps disposition list
# History:   20120720 - AG E.Novation France - Creation

proc enf_tps_replace_eol_hl7 { args } {
    global HciConnName                             ;# Name of thread

    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "enf_tps_replace_eol_hl7/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
            regsub -all \r\n|\n $data \r data
            msgset $mh $data

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
# Name:      enf_mon_caracSpeciauxFix
# Purpose:   Procedure remplaçant les caractères spéciaux d'un message
# UPoC type: tps
# Args: none
# Returns:   tps disposition list

proc enf_mon_caracSpeciauxFix { args } {
    global HciConnName                             ;# Name of thread

    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
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
            set msg [msgget $mh]

            regsub -all è|é|ê $msg e msg
            regsub -all à $msg a msg
            regsub -all ù|µ|ü|û $msg u msg
            regsub -all ç $msg c msg
            regsub -all ï|î $msg i msg

            msgset $mh $msg
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
# Name:       enf_tps_filename_from_userdata
# Purpose:  Permet de récupérer le nom de fichier en userdata et de nommer le fichier
# UPoC type: tps
# Args:      {USERDATA userdata} default = FILENAME
#                               Specifie dans quelle userdata on recupere le nom du fichier
# Returns: tps disposition list
# History: 15-11-2016 : AGS : Création

proc enf_tps_filename_from_userdata { args } {
    keylget args MODE mode               ;# Fetch mode
    keylget args ARGS uargs

    set dispList {}    ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set driver [msgmetaget $mh DRIVERCTL]

            set userKey TYPE
            keylget uargs USERDATA userKey
            # prise de l'information dans du userdata
            set userdata [msgmetaget $mh USERDATA]
            set userValue ""; keylget userdata $userKey userValue

            # affectation de la valeur
            if { ![cequal $userValue ""] }{
                set driverctl "{FILESET {{OBFILE $userValue}}}"
            }
            # affectation de la donnee au driver
            msgmetaset $mh DRIVERCTL $driverctl
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



######################################################################
# Name:        enf_tps_writeMsgToFile
# Purpose: Ecrit les fichiers en précisant en argument
#          l'extension du fichier à supprimer (txt par défaut)
# UPoC type: tps
# Args: EXT extension du fichier à ecrire. Ne pas ajouter le .
#       DEST destination du fichier à ecrire.
# Returns: tps disposition list
# History :
#Fix : 11/06/12 Prise en charge des noms comportant plusieurs points

proc enf_tps_writeMsgToFile { args } {
    keylget args MODE mode                  ;# Fetch mode
    set ext "txt"; catch {keylget args ARGS.EXT ext}
    set dest "."; catch {keylget args ARGS.DEST dest}

    set dispList {}                ;# Nothing to return

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
            set filename [file tail [file rootname $name]]

            if { [cequal [string toupper $extension] .[string toupper $ext]]} {
                write_file ${dest}/${filename} [msgget $mh]
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



######################################################################
# Name:      enf_tps_set_msg_to_userdata
# Purpose:   Récupere le message en cours de traitement et le pase en en userdata dans 
#           la liste MSG
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
# History:   03/03/2017 AGS : Création
#                 

proc enf_tps_set_msg_to_userdata { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "enf_tps_set_msg_to_userdata/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
            
            keylset keylist MSG [msgget $mh]
            msgmetaset $mh USERDATA $keylist
            
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
# Name:     enf_tps_echoMsg
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc enf_tps_echoMsg { args } {
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "enf_tps_echoMsg/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug "msg"; catch {keylget uargs DEBUG debug}

    set dispList {}                                ;# Nothing to return

    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh
            
            switch -nocase -- $debug {
                msg {
                    echo "\t\t\t\t\t-----===== $HciConnName $ctx msg =====-----\r\n"
                    echo [msgget $mh]
                }
                
                meta {
                    echo "\t\t\t\t\t-----===== $HciConnName $ctx msg metadatas =====-----\r\n"
                    foreach key [msgmetaget $mh] {
                        echo ${key} : [msgmetaget $mh $key]
                    }
                }
                
                dump {
                    echo "\t\t\t\t\t-----===== $HciConnName $ctx msg dump =====-----\r\n"
                    msgdump $mh
                }
                
                default {
                    echo "\t\t\t\t\t-----===== $HciConnName $ctx msg =====-----\r\n"
                    echo [msgget $mh]
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
