######################################################################
# Name:      xper_select_files
# Purpose:   Nouvelle procedure DirParse de selection de fichiers a prelever qui apporte les nouveautes suivantes
#               - Arguments illimites
#               - Saisie des arguments simplifiee
#               - Pas besoin de maitriser les regex
#               - Pas besoin de doubler le caractere \ si utilisation de regex
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS   Les arguments precisent les regles de prelevement des fichiers.
#                   Ils doivent etre separes par un retour a la ligne.
#                   Le premier argument precise la forme du fichier recherche.
#                   Les arguments suivants precisent les extensions des fichiers associes.
#                   Ces regles peuvent utiliser le caractere * pour remplacer un ou plusieurs caracteres inconnus.
#                   Exemple d'arguments:    test*.hl7  ou   ^test*.\.[Hh][Ll]7$
#                                           .pdf            \.[Pp][Dd][Ff]$
#                                           .ok             \.[Oo][Kk]$
#                                                           %regex%
#                   En complement, les variables suivantes peuvent etre utilisees :
#                       %debug% : Lance la procedure en mode debug
#                       %regex% : Autorise la saisie d'expressions regulieres
#                       %multi% : (désactivé) Permet de prélever plusieurs pièces jointes (ex : test.j1.pdf et test.j2.pdf)
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           20180803 TLZ - v3 - Correction d'une fuite mémoire
#           Amélioration nécessaires : Ajout du mode Multi permettant de récupérer plusieurs pièces jointes (-all)
#                                      échapper les caractères spéciaux des noms des fichiers
#                                      rendre des éléments facultatifs
#                                      supprimer la dépendance xper_replaceChars
#                 

proc xper_select_files { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0
    set regex 0
    set multi 0
    set module "selection_fichiers/$HciConnName/$ctx" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }
        
        run {
            #Controles de conformite
            if { [cequal $uargs ""]} {
                puts stderr "Erreur: Veuillez inserer un argument dans la procedure xper_selectFiles"
                return
            }

            keylget args MSGID mh                
            set mh_list [msgget $mh]            ; # Liste des fichiers du repertoire

            set nocase "(?i)" ; #Argument pour faire les recherches sans tenir compte des majuscules
            set all "" ; #Argument pour faire des recherches multiples
            
            ## Initialisation des arguments
            set arg_list [split $uargs \n]  ; # Creation d'une liste d'arguments
            set index_arg 0
            foreach arg $arg_list {
                set arg [string toupper $arg]
                switch $arg {
                    "%DEBUG%" {
                        # Detection du mode Debug
                        set debug 1
                        puts stdout "Debug mode..."
                        set arg_list [lreplace $arg_list $index_arg $index_arg] ; # On retire l'argument de la liste
                    }
                    "%REGEX%" {
                        # Detection du mode Regex
                        set regex 1
                        set arg_list [lreplace $arg_list $index_arg $index_arg] ; # On retire l'argument de la liste
                        set nocase ""
                    }
                    #"%MULTI%" {
                    #    # Detection du mode Multiple
                    #    set multi 1
                    #    set all "-all "
                    #    set arg_list [lreplace $arg_list $index_arg $index_arg] ; # On retire l'argument de la liste
                    #}
                    default {incr index_arg}
                }
            }
            
            #if { $multi && $debug } { puts stdout "Multi mode..." }
            if { $regex } {
                if {$debug} { puts stdout "Regex mode..." }
            } else {
                # Simplifications des recherches dans le mode classique
                set arg_list [xper_replaceChars . @!!y#!!@ $arg_list]     ; # On remplace le . par \.
                set arg_list [xper_replaceChars @!!y#!!@ \\\\. $arg_list]
                set arg_list [xper_replaceChars * @!!y#!!@ $arg_list]     ; # On remplace le * par .*
                set arg_list [xper_replaceChars @!!y#!!@ .* $arg_list]
                # On ajoute les arguments ^ et $
                append first ^ [lindex $arg_list 0] $
                set arg_list [lreplace $arg_list 0 0 $first]
            }
            
            ## Debut des traitements
            if {$debug} { echo Fichiers presents dans le repertoire : $mh_list }
            set nb_arg [llength $arg_list]      ; # Nombre d'arguments utilisateur
            set file_list ""                    ; # Une liste de fichiers correspondant a un argument
            set x_file_list ""                  ; # Liste des listes de fichiers correspondant aux arguments
            set match_list ""                   ; # Liste des fichiers a prelever
            # On reduit la taille des listes sur lesquelles on travaille
            foreach arg $arg_list {
                # Pour chaque argument on genere la liste des fichiers
                set file_list [lsearch -all -inline -regexp $mh_list $nocase$arg]
                if {$debug} { echo Critire de recherche : $nocase$arg , Resultats : $file_list }
                if { [cequal $file_list ""] } {
                    if {$debug} { echo Aucun résultat pour l'argument $nocase$arg ne se trouve dans le répertoire }
                    # Correction v3
                    lappend dispList "CONTINUE $mh"
                    return $dispList
                }
                lappend x_file_list $file_list
            }
            #Controles de conformite
            if { $nb_arg == 0 } {
                puts stderr "Erreur: Veuillez inserer un argument dans la procedure xper_selectFiles"
                return
            } elseif {$nb_arg >1} {            
                #Pour chaque element repondant a la premiere expression reguliere
                foreach file_name [lindex $x_file_list 0] {
                    set take_list ""    ; # Liste des fichiers a prelever associes a file_name
                    set _break 0
                    set lite_file_name [file rootname $file_name]   ; # On recupere le nom sans l'extension
                    # On verifie qu'il existe un fichier pour chacun des arguments
                    for {set index_arg 1} {$index_arg < $nb_arg } {incr index_arg} {
                        if {$debug} { echo Fichier en cours de recherche : ${nocase}^$lite_file_name[lindex $arg_list $index_arg] }
                        set file_match [lsearch ${all}-inline -regexp [lindex $x_file_list $index_arg] ${nocase}^$lite_file_name[lindex $arg_list $index_arg]]
                        if { [cequal $file_match ""] } {
                            # Le fichier ne correspond pas a tous les arguments
                            if {$debug} { echo Aucun fichier associe $lite_file_name[lindex $arg_list $index_arg] n'a ete retrouve. }
                                set _break 1
                                break
                        } else { 
                            foreach file_match_elem $file_match {
                                lappend take_list $file_match_elem
                            }
                            if {$debug} {echo Le fichier $file_match a ete ajoute a la liste de prelevement.}
                        }
                    }
                    if {$_break == 0} {
                        lappend match_list $file_name 
                        foreach take_file $take_list {
                            lappend match_list $take_file
                        }
                        if {$debug} {echo Les fichiers $file_name $take_list seront preleves.}
                    }
                }
            } elseif { $nb_arg == 1 } {
                set match_list [lindex $x_file_list 0]
                if {$debug} {echo Le(s) fichier(s) $match_list sera preleve.}
            }
            if {$debug} {echo Liste finale de fichiers a prelever : $match_list}
            msgset $mh $match_list
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
# Name:           xper_dirParseUsingRegexp_v62_delay
# Purpose:        Permet de lire seulement les fichiers correspondant
#                 à "pattern" ayant comme fichier ack "ack" 
#                 (optionnel) et comme fichier d'accompagnement "file" (optionnel).
#                  "excludeFile" à 1 permet de ne pas parser les fichiers d'accompagnement.
# Exemples:       PATTERN \.hpr$, ACK \.ok$ et FILE \.pdf$ va récupérer et parser les fichiers associés (exemple test.hpr, test.ok et test.pdf)
#                 Pour récupérer plusieurs fichiers témoins, il faut adapter la regexp FILE comme ceci
#                 PATTERN \.hpr$, ACK \.ok$ et FILE \[0-9]{3}.pdf$ va récupérer et parser les fichiers associés (exemple test.hpr, test.ok et tous les fichiers testXXX.pdf)
#                 Pour que les fichiers file ne soient pas parsés, rajouter l'option EXCLUDEFILE à 1. Ceci permet d'attendre par exemple qu'un triplet de fichiers
#                 soit présent avant d'envoyer seulement le doublet au parsing    
# UPoC type:      tps
# Args:           {DEBUG 0|1} (optional, defaults = 0)
#                 {PATTERN PatternValue} (optional, defaults = ".")
#                 {ACK AckPattern} (optional, defaults = "")
#                 {FILE FilePattern} (optional, defaults = "") 
#                 {EXCLUDEFILE ExcludeFile} (optional, defaults = 0)
#                 {DELAY DelaySec} (optional, defaults = 0)
# Returns:        tps disposition list                
# History: 28-09-2018 TLZ : Compatible version 6.2 et SFTP
#          28-02-2016 AGS : Compatible avec les partages Windows
#          18-11-2015 TLZ : Ajout du Delay
#          13-08-2015 TLZ : Compatibilite avec CIS 5.8
#          03-2015 GJZ : Creation de la v3
#          27-07-2007 Aurelien Garros, E.Novation France
#          07-10-2005 AH, E.Novation lifeLine Networks bv
#                     Added DEBUG argument, to get full output#
# Notes:          It's unlikely this will work for all possible regexps! 
#                 Further testing is required.

proc xper_dirParseUsingRegexp_v62_delay { args } {
    global HciConnName
    package require Sitecontrol
    package require base64

    keylget args MODE mode
    keylget args CONTEXT ctx
    keylget args ARGS uargs

    set debug 0     ; keylget uargs DEBUG debug
    set pattern "." ; keylget uargs PATTERN pattern
    set ack ""      ; keylget uargs ACK ack
    set file ""      ; keylget uargs FILE file
    set excludeFile 0   ; keylget uargs EXCLUDEFILE excludeFile
    set delay ""   ; keylget uargs DELAY delay

    # Use '$module' before every echo/puts, so you know where the text came from
    set module "[lindex [info level 0] 0]/$HciConnName/$ctx" 

    set dispList {}                                ;# Nothing to return
    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            if { $debug } {
                puts stdout "$module: Starting in debug mode with args: '${uargs}'"
            }
            return ""
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
         
            set match_list ""
            set mhList [msgget $mh]
            
            # Start of enf_dirParseUsingRegexp_v3

            # On réduit la taille des listes sur lesquelles on travaille
            set patternListList [lsearch -all -inline -regexp $mhList $pattern]
            if { ![cequal $ack ""] } {
                set ackList [lsearch -all -inline -regexp $mhList $ack]
            }
            if { ![cequal $file ""] } {
                set fileList [lsearch -all -inline -regexp $mhList $file]
            }
            
            # Start of Delay  

            if { $debug } {
                puts stdout "----[fmtclock [getclock] %c]----"
            }
            
            if { ![cequal delay ""] } {

                set delayList ""
                
                set success 0
                if { [catch {set success [::Sitecontrol::loadNetConfig]} err] || $success == -1} {
                    echo "Impossible d'ouvrir le fichier netconfig $err"
                    return
                }
                set threadconfig [::Sitecontrol::getThreadData $HciConnName]
                keylget threadconfig PROTOCOL.TYPE protocol

                foreach patternListElement $patternListList {
                    echo Protocole $protocol

                    # Extraction du type de protocole
                    if { [cequal $protocol fileset] &&
                         [keylget threadconfig PROTOCOL.MODE protoSubType] == 1 } { 
                        append protocol "/$protoSubType" 
                    }
                    # Version 5.4 and up has subtype for ihb stuff
                    if { [keylget threadconfig PROTOCOL.SUBTYPE protoSubType] } { 
                        append protocol "/$protoSubType"
                    }
                    
                    if { $protocol == "fileset/local-tps" } {
                        keylget threadconfig PROTOCOL.IBDIR ibdir
                         if { ![cequal [crange $ibdir 0 1] ..] } {
                            set myfile ${ibdir}/$patternListElement    
                        } else {
                            set myfile [pwd]/${ibdir}/$patternListElement
                        }
                        if {$debug} {echo chemin du fichier $myfile}
                        set scan_date [file mtime $myfile]
                        if {$debug} {echo mtime du fichier $scan_date}
                        if {$debug} {echo heure actuelle [clock seconds]}
                        if { [expr [clock seconds] - $scan_date] >= $delay } {
                            lappend delayList $patternListElement
                        }
                    }
                    if { $protocol == "fileset/ftp" || $protocol == "fileset-sftp"} {
                        keylget threadconfig PROTOCOL.FTPHOST host
                        keylget threadconfig PROTOCOL.FTPUSER login
                        keylget threadconfig PROTOCOL.FTPPASSWD password
                        # Decryptage du mot de passe sur la version 6.2
                        catch {exec hcicrypt decrypt $password} password
                        set password  [::base64::decode $password]
                        # Fin Decryptage
                        keylget threadconfig PROTOCOL.FTPIBDIR directory

                        if { $protocol == "fileset-sftp" } {
                            echo protocole sftp
                            set msg "";set rc [ catch {exec curl -z "2019 Nov 6" -l sftp://$login:$password@$host/$directory/$patternListElement --insecure -q ls} msg]
                        } else {
                            echo protocole ftp
                            set msg "";set rc [ catch {exec curl -z "2019 Nov 6" ftp://$login:$password@$host/$directory/$patternListElement } msg]
                        }
                        if { $rc == 1 } {
                            echo Liste : $msg
                            set find [lsearch -all -inline -regexp $msg $patternListElement]
                            echo find : $find
                        #    set date [string trim [lindex [split [lindex [split $msg \n] 0] :] 1] ]
                        #    append date ":"
                        #    append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 2] ]
                        #    append date ":"
                        #    append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 3] ]
                        #    echo date : $date
                        #    set scan_date [clock scan $date]
                        #    if { [expr [clock seconds] - $scan_date] >= $delay } {
                        if { ![cequal $find ""]} {
                                lappend delayList $patternListElement
                        }
                        #    }
                        }
                    }
                }
                set patternList $delayList
            }
            
            # End of Delay
            
            # On parcourt la liste des fichiers répondant au pattern
            foreach patternListElement $patternList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""
                
                # On récupère le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}
                
                # On recherche le témoin associé
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}
                    
                    # Si il n'est pas trouvé, alors on continue l'itération
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }
                
                # On recherche le fichier associé
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouvé, alors on continue l'itération
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }
                
                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont définis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                    lappend match_list $ackFilename                    
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont définis
                    lappend match_list $patternListElement
                    lappend match_list $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont définis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est défini
                    lappend match_list $patternListElement
                }
            }

            # End of enf_dirParseUsingRegexp_v3

            if {$debug} {echo match_list : $match_list}
            msgset $mh $match_list
            lappend dispList "CONTINUE $mh"

            if { $debug } {
                puts stdout "$module: Retrieved directory listing: \n\t[msgget $mh]"
                puts stdout "$module: Matching against pattern $pattern"
                puts stdout "$module: Found [llength $match_list] matches: \n\t$match_list"
            }
        }

        shutdown {
            # shutdown mode - no action
        }

        default {
            error "Unknown mode '$mode' in $module"
        }
    }
    return $dispList
}


######################################################################
# Name:      xper_dirparse_alerte_nb_file
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
#               2019 04 19 IHB please call this proc from inbound dirparse TPS
# Exemple: {DEBUG 1} {SERVER serversmtp.com} {PORT 25} {USERNAME login]} {PASSWORD password} {USETLS 0} {FROM cloverleaf@infor.com} {TO support@infor.com,infor@infor.com} {SUBJECT sujet} {BODY Corp du mail} {NBFILE 13}
#    {DEBUG 0} {SERVER chrmt-smtp01} {PORT 25} {FROM hciuser.win-eai@chr-metz-thionville.fr} {TO bernadette.collignon@ch-briey.fr,am.pontus@chr-metz-thionville.fr,f.zimmer@chr-metz-thionville.fr,support@xperis.fr} {SUBJECT "Cloverleaf: nombre de fichier LOGIMED METZ" } {BODY "Les fichiers LOGIMED ne sont pas prélevés car le nombre de fichier en attente de prélèvement n'est pas de 13. Veuillez vérifier Merci." } {NBFILE 13}

proc xper_dirparse_alerte_nb_file { args } {
    global HciConnName                             ;# Name of thread
    package require smtp
    package require mime    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""          ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {}        ; keylget args ARGS uargs         ;# Fetch user-supplied args
    set debug 0         ; keylget uargs DEBUG debug
    set server {}       ; keylget uargs SERVER server
    set port {25}       ; keylget uargs PORT port
    set username {}     ; keylget uargs USERNAME username
    set password {}     ; keylget uargs PASSWORD password
    set usetls 0       ; keylget uargs USETLS usetls
    set from {}         ; keylget uargs FROM from
    set to {}           ; keylget uargs TO to
    set subject {}      ; keylget uargs SUBJECT subject
    set body {}         ; keylget uargs BODY body
    set nbfile 10       ; keylget uargs NBFILE nbfile
    set i 0;
 
    set module "xper_dirparse_alerte_nb_file/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
            if {$debug} {
                    echo "server : $server"
                    echo "port : $port"
                    echo "username : $username"
                    echo "password : $password"
                    echo "usetls : $usetls"
                    echo "from : $from"
                    echo "to : $to"
                    echo "subject : $subject"
                    echo "body : $body"
                    echo "nbfile : $nbfile"
                    echo "i : $i"
            }
            keylget args MSGID mh
            set i [ llength $mh ]
            echo "nombre de fichiers présent dans le répertoire : $i"
            echo "nombre de fichiers demandes : $nbfile"
            if {$i != $nbfile } {
                echo "le nombre de fichiers présent : $i est different du nombre de fichier demandes $nbfile"
                msgset $mh {}
                set token [::mime::initialize -canonical text/plain -string "$body"]
                set command [list ::smtp::sendmessage $token\
                -servers $server -ports $port -username $username -password $password -usetls $usetls \
                -header [list From "$from"] -header [list To "$to"] -header [list Subject "$subject"] \
                -header [list Date "[clock format [clock seconds]]"] -debug $debug]
                if {$debug} { echo "command: $command" }
                eval $command
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
