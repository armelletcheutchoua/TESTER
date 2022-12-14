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
#                   Exemple d'arguments:    test*.hl7
#                                           .pdf 
#                                           .ok
#                                           %debug%
#                   En complement, les variables suivantes peuvent etre utilisees :
#                       %debug% : Lance la procedure en mode debug
#                       %regex% : Autorise la saisie d'expressions regulieres
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ : Creation de la procedure
#           20170217 TLZ : Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les pieces jointes
#                 

proc xper_select_files { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    #catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
    set regex 0  ;                                 ;# Fetch user argument DEBUG and
    #catch {keylget uargs REGEX regex}              ;# assume uargs is a keyed list
    
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

            ## Initialisation des arguments
            set arg_list [split $uargs \n]  ; # Creation d'une liste d'arguments
            set index_arg 0
            foreach arg $arg_list {
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
                    }
                    default {incr index_arg}
                }
            } 
            if { $regex } {
                if {$debug} {
                    puts stdout "Regex mode..."
                }
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
                set file_list [lsearch -all -inline -regexp $mh_list $arg]
                if {$debug} { echo Critire de recherche : $arg , Resultats : $file_list }
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
                        if {$debug} { echo Fichier en cours de recherche : ^$lite_file_name[lindex $arg_list $index_arg] }
                        set file_match [lsearch -inline -regexp [lindex $x_file_list $index_arg] ^$lite_file_name[lindex $arg_list $index_arg]]
                        if { [cequal $file_match ""] } {
                            # Le fichier ne correspond pas a tous les arguments
                            if {$debug} { echo Aucun fichier associe $lite_file_name[lindex $arg_list $index_arg] n'a ete retrouve. }
                            set _break 1
                            break
                        } else { 
                            lappend take_list $file_match
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
#                       %multi% : (d??sactiv??) Permet de pr??lever plusieurs pi??ces jointes (ex : test.j1.pdf et test.j2.pdf)
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170328 TLZ - v2 - (d??sactiv?? - ?? tester) Ajout du mode Multi permettant de r??cup??rer plusieurs pi??ces jointes (-all)
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           Am??lioration n??cessaires : ??chapper les caract??res sp??ciaux des noms des fichiers
#                                      rendre des ??l??ments facultatifs
#                                      supprimer la d??pendance xper_replaceChars
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
                    if {$debug} { echo Aucun r??sultat pour l'argument $nocase$arg ne se trouve dans le r??pertoire }
                    return
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
#                       %multi% : (d??sactiv??) Permet de pr??lever plusieurs pi??ces jointes (ex : test.j1.pdf et test.j2.pdf)
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           20180803 TLZ - v3 - Correction d'une fuite m??moire
#           Am??lioration n??cessaires : Ajout du mode Multi permettant de r??cup??rer plusieurs pi??ces jointes (-all)
#                                      ??chapper les caract??res sp??ciaux des noms des fichiers
#                                      rendre des ??l??ments facultatifs
#                                      supprimer la d??pendance xper_replaceChars
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
                    if {$debug} { echo Aucun r??sultat pour l'argument $nocase$arg ne se trouve dans le r??pertoire }
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
#                       %multi% : (d??sactiv??) Permet de pr??lever plusieurs pi??ces jointes (ex : test.j1.pdf et test.j2.pdf)
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           20180803 TLZ - v3 - Correction d'une fuite m??moire
#           Am??lioration n??cessaires : Ajout du mode Multi permettant de r??cup??rer plusieurs pi??ces jointes (-all)
#                                      ??chapper les caract??res sp??ciaux des noms des fichiers
#                                      rendre des ??l??ments facultatifs
#                                      supprimer la d??pendance xper_replaceChars
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
                    if {$debug} { echo Aucun r??sultat pour l'argument $nocase$arg ne se trouve dans le r??pertoire }
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
#                 ?? "pattern" ayant comme fichier ack "ack" 
#                 (optionnel) et comme fichier d'accompagnement "file" (optionnel).
#                  "excludeFile" ?? 1 permet de ne pas parser les fichiers d'accompagnement.
# Exemples:       PATTERN \.hpr$, ACK \.ok$ et FILE \.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et test.pdf)
#                 Pour r??cup??rer plusieurs fichiers t??moins, il faut adapter la regexp FILE comme ceci
#                 PATTERN \.hpr$, ACK \.ok$ et FILE \[0-9]{3}.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et tous les fichiers testXXX.pdf)
#                 Pour que les fichiers file ne soient pas pars??s, rajouter l'option EXCLUDEFILE ?? 1. Ceci permet d'attendre par exemple qu'un triplet de fichiers
#                 soit pr??sent avant d'envoyer seulement le doublet au parsing    
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

            # On r??duit la taille des listes sur lesquelles on travaille
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
            
            # On parcourt la liste des fichiers r??pondant au pattern
            foreach patternListElement $patternList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""
                
                # On r??cup??re le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}
                
                # On recherche le t??moin associ??
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}
                    
                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }
                
                # On recherche le fichier associ??
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }
                
                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                    lappend match_list $ackFilename                    
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    lappend match_list $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est d??fini
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
#    {DEBUG 0} {SERVER chrmt-smtp01} {PORT 25} {FROM hciuser.win-eai@chr-metz-thionville.fr} {TO bernadette.collignon@ch-briey.fr,am.pontus@chr-metz-thionville.fr,f.zimmer@chr-metz-thionville.fr,support@xperis.fr} {SUBJECT "Cloverleaf: nombre de fichier LOGIMED METZ" } {BODY "Les fichiers LOGIMED ne sont pas pr??lev??s car le nombre de fichier en attente de pr??l??vement n'est pas de 13. Veuillez v??rifier Merci." } {NBFILE 13}

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
            echo "nombre de fichiers pr??sent dans le r??pertoire : $i"
            echo "nombre de fichiers demandes : $nbfile"
            if {$i != $nbfile } {
                echo "le nombre de fichiers pr??sent : $i est different du nombre de fichier demandes $nbfile"
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
#                       %multi% : (d??sactiv??) Permet de pr??lever plusieurs pi??ces jointes (ex : test.j1.pdf et test.j2.pdf)
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           20180803 TLZ - v3 - Correction d'une fuite m??moire
#           Am??lioration n??cessaires : Ajout du mode Multi permettant de r??cup??rer plusieurs pi??ces jointes (-all)
#                                      ??chapper les caract??res sp??ciaux des noms des fichiers
#                                      rendre des ??l??ments facultatifs
#                                      supprimer la d??pendance xper_replaceChars
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
                    if {$debug} { echo Aucun r??sultat pour l'argument $nocase$arg ne se trouve dans le r??pertoire }
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
#                 ?? "pattern" ayant comme fichier ack "ack"
#                 (optionnel) et comme fichier d'accompagnement "file" (optionnel).
#                  "excludeFile" ?? 1 permet de ne pas parser les fichiers d'accompagnement.
# Exemples:       PATTERN \.hpr$, ACK \.ok$ et FILE \.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et test.pdf)
#                 Pour r??cup??rer plusieurs fichiers t??moins, il faut adapter la regexp FILE comme ceci
#                 PATTERN \.hpr$, ACK \.ok$ et FILE \[0-9]{3}.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et tous les fichiers testXXX.pdf)
#                 Pour que les fichiers file ne soient pas pars??s, rajouter l'option EXCLUDEFILE ?? 1. Ceci permet d'attendre par exemple qu'un triplet de fichiers
#                 soit pr??sent avant d'envoyer seulement le doublet au parsing
# UPoC type:      tps
# Args:           {DEBUG 0|1} (optional, defaults = 0)
#                 {PATTERN PatternValue} (optional, defaults = ".")
#                 {ACK AckPattern} (optional, defaults = "")
#                 {FILE FilePattern} (optional, defaults = "")
#                 {EXCLUDEFILE ExcludeFile} (optional, defaults = 0)
#                 {DELAY DelaySec} (optional, defaults = 0)
# Returns:        tps disposition list
# History: 10-04-2019 TLZ : enf_dirParseUsingRegexp_v3_delay avec decryptage du mot de passe 
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

            # On r??duit la taille des listes sur lesquelles on travaille
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
                    if { $protocol == "fileset/ftp" } {
                        keylget threadconfig PROTOCOL.FTPHOST host
                        keylget threadconfig PROTOCOL.FTPUSER login
                        keylget threadconfig PROTOCOL.FTPPASSWD password
                        keylget threadconfig PROTOCOL.FTPIBDIR directory
                        # Decryptage du mot de passe sur la version 6.2
                        catch {exec hcicrypt decrypt $password} password
                        set password  [::base64::decode $password]
                        # Fin Decryptage
                        set msg "";set rc [ catch {exec curl -I ftp://$login:$password@$host/$directory/$patternListElement} msg]
                        if { $rc == 1 } {
                            set date [string trim [lindex [split [lindex [split $msg \n] 0] :] 1] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 2] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 3] ]
                            set scan_date [clock scan $date]
                            if { [expr [clock seconds] - $scan_date] >= $delay } {
                                lappend delayList $patternListElement
                            }
                        }
                    }
                }
                set patternList $delayList
            }

            # End of Delay

            # On parcourt la liste des fichiers r??pondant au pattern
            foreach patternListElement $patternList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""

                # On r??cup??re le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}

                # On recherche le t??moin associ??
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }

                # On recherche le fichier associ??
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }

                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                    lappend match_list $ackFilename
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    lappend match_list $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est d??fini
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
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           20180803 TLZ - v3 - Correction d'une fuite m??moire
#           20190412 TLZ - v6 - Correction critique sur le pr??l??vement des fichiers
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
            keylget args MSGID mh  
            #Controles de conformite
            if { [cequal $uargs ""]} {
                puts stderr "Erreur: Veuillez inserer un argument dans la procedure xper_selectFiles"
                # Correction v6
                msgset $mh "" 
                lappend dispList "CONTINUE $mh"
                return $dispList
            }              
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
                    default {incr index_arg}
                }
            }
            
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
                    if {$debug} { echo Aucun r??sultat pour l'argument $nocase$arg ne se trouve dans le r??pertoire }
                    msgset $mh "" ; # Correction v6
                    lappend dispList "CONTINUE $mh" ; # Correction v3
                    return $dispList
                }
                lappend x_file_list $file_list
            }
            if {$nb_arg >1} {            
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
#                 ?? "pattern" ayant comme fichier ack "ack"
#                 (optionnel) et comme fichier d'accompagnement "file" (optionnel).
#                  "excludeFile" ?? 1 permet de ne pas parser les fichiers d'accompagnement.
# Exemples:       PATTERN \.hpr$, ACK \.ok$ et FILE \.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et test.pdf)
#                 Pour r??cup??rer plusieurs fichiers t??moins, il faut adapter la regexp FILE comme ceci
#                 PATTERN \.hpr$, ACK \.ok$ et FILE \[0-9]{3}.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et tous les fichiers testXXX.pdf)
#                 Pour que les fichiers file ne soient pas pars??s, rajouter l'option EXCLUDEFILE ?? 1. Ceci permet d'attendre par exemple qu'un triplet de fichiers
#                 soit pr??sent avant d'envoyer seulement le doublet au parsing
# UPoC type:      tps
# Args:           {DEBUG 0|1} (optional, defaults = 0)
#                 {PATTERN PatternValue} (optional, defaults = ".")
#                 {ACK AckPattern} (optional, defaults = "")
#                 {FILE FilePattern} (optional, defaults = "")
#                 {EXCLUDEFILE ExcludeFile} (optional, defaults = 0)
#                 {DELAY DelaySec} (optional, defaults = 0)
# Returns:        tps disposition list
# History: 10-04-2019 TLZ : enf_dirParseUsingRegexp_v3_delay avec decryptage du mot de passe 
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

            # On r??duit la taille des listes sur lesquelles on travaille
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
                    if { $protocol == "fileset/ftp" } {
                        keylget threadconfig PROTOCOL.FTPHOST host
                        keylget threadconfig PROTOCOL.FTPUSER login
                        keylget threadconfig PROTOCOL.FTPPASSWD password
                        keylget threadconfig PROTOCOL.FTPIBDIR directory
                        # Decryptage du mot de passe sur la version 6.2
                        catch {exec hcicrypt decrypt $password} password
                        set password  [::base64::decode $password]
                        # Fin Decryptage
                        set msg "";set rc [ catch {exec curl -I ftp://$login:$password@$host/$directory/$patternListElement} msg]
                        if { $rc == 1 } {
                            set date [string trim [lindex [split [lindex [split $msg \n] 0] :] 1] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 2] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 3] ]
                            set scan_date [clock scan $date]
                            if { [expr [clock seconds] - $scan_date] >= $delay } {
                                lappend delayList $patternListElement
                            }
                        }
                    }
                }
                set patternList $delayList
            }

            # End of Delay

            # On parcourt la liste des fichiers r??pondant au pattern
            foreach patternListElement $patternList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""

                # On r??cup??re le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}

                # On recherche le t??moin associ??
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }

                # On recherche le fichier associ??
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }

                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                    lappend match_list $ackFilename
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    lappend match_list $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est d??fini
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
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           20180803 TLZ - v3 - Correction d'une fuite m??moire
#           20190412 TLZ - v6 - Correction critique sur le pr??l??vement des fichiers
#           20190506 PFK - v7 - Rajout de la v??rification de la version de CIS pour le d??cryptage des MdP
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
            keylget args MSGID mh  
            #Controles de conformite
            if { [cequal $uargs ""]} {
                puts stderr "Erreur: Veuillez inserer un argument dans la procedure xper_selectFiles"
                # Correction v6
                msgset $mh "" 
                lappend dispList "CONTINUE $mh"
                return $dispList
            }              
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
                    default {incr index_arg}
                }
            }
            
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
                    if {$debug} { echo Aucun r??sultat pour l'argument $nocase$arg ne se trouve dans le r??pertoire }
                    msgset $mh "" ; # Correction v6
                    lappend dispList "CONTINUE $mh" ; # Correction v3
                    return $dispList
                }
                lappend x_file_list $file_list
            }
            if {$nb_arg >1} {            
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
#                 ?? "pattern" ayant comme fichier ack "ack"
#                 (optionnel) et comme fichier d'accompagnement "file" (optionnel).
#                  "excludeFile" ?? 1 permet de ne pas parser les fichiers d'accompagnement.
# Exemples:       PATTERN \.hpr$, ACK \.ok$ et FILE \.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et test.pdf)
#                 Pour r??cup??rer plusieurs fichiers t??moins, il faut adapter la regexp FILE comme ceci
#                 PATTERN \.hpr$, ACK \.ok$ et FILE \[0-9]{3}.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et tous les fichiers testXXX.pdf)
#                 Pour que les fichiers file ne soient pas pars??s, rajouter l'option EXCLUDEFILE ?? 1. Ceci permet d'attendre par exemple qu'un triplet de fichiers
#                 soit pr??sent avant d'envoyer seulement le doublet au parsing
# UPoC type:      tps
# Args:           {DEBUG 0|1} (optional, defaults = 0)
#                 {PATTERN PatternValue} (optional, defaults = ".")
#                 {ACK AckPattern} (optional, defaults = "")
#                 {FILE FilePattern} (optional, defaults = "")
#                 {EXCLUDEFILE ExcludeFile} (optional, defaults = 0)
#                 {DELAY DelaySec} (optional, defaults = 0)
# Returns:        tps disposition list
# History: 10-04-2019 TLZ : enf_dirParseUsingRegexp_v3_delay avec decryptage du mot de passe 
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

            # On r??duit la taille des listes sur lesquelles on travaille
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
                    if { $protocol == "fileset/ftp" } {
                        keylget threadconfig PROTOCOL.FTPHOST host
                        keylget threadconfig PROTOCOL.FTPUSER login
                        keylget threadconfig PROTOCOL.FTPPASSWD password
                        keylget threadconfig PROTOCOL.FTPIBDIR directory
						set cisversion $::env(HCIVERSION)
                        # Decryptage du mot de passe sur la version 6.2
						if {$cisversion >= 6.2 } {
							if {$debug} { echo "password (before decrypt) : $password" }
							catch {exec hcicrypt decrypt $password} password
							set password  [::base64::decode $password]
							if {$debug} { echo "password (after decrypt) : $password" }
                        } else {
							if {$debug} { echo "password (not crypt at all) : $password" }
						}
                        # Fin Decryptage
                        set msg "";set rc [ catch {exec curl -I ftp://$login:$password@$host/$directory/$patternListElement} msg]
                        if { $rc == 1 } {
                            set date [string trim [lindex [split [lindex [split $msg \n] 0] :] 1] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 2] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 3] ]
                            set scan_date [clock scan $date]
                            if { [expr [clock seconds] - $scan_date] >= $delay } {
                                lappend delayList $patternListElement
                            }
                        }
                    }
                }
                set patternList $delayList
            }

            # End of Delay

            # On parcourt la liste des fichiers r??pondant au pattern
            foreach patternListElement $patternList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""

                # On r??cup??re le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}

                # On recherche le t??moin associ??
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }

                # On recherche le fichier associ??
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }

                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                    lappend match_list $ackFilename
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    lappend match_list $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est d??fini
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
# Purpose:   Procs permettant de compter les fichiers en retour d'une dirparse. Si nombre de message ne correspond $mh est vid??, veillez ?? placer la proc en dirpase TPS Inbound apr??s une dirparse
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
#    {DEBUG 0} {SERVER serveursmtp.fr} {PORT 25} {FROM cloverleaf@site.fr} {TO cloverleaf@infor.com,support@xperis.fr} {SUBJECT "Cloverleaf: nombre de fichier" } {BODY "Les fichiers ne sont pas pr??lev??s car le nombre de fichier en attente de pr??l??vement ne correspond pas. Veuillez v??rifier Merci." } {NBFILE 13}
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
#    {DEBUG 0} {IGNORE 1} {SERVER chrmt-smtp01} {PORT 25} {FROM hciuser.win-eai@chr-metz-thionville.fr} {TO bernadette.collignon@ch-briey.fr,am.pontus@chr-metz-thionville.fr,f.zimmer@chr-metz-thionville.fr,support@xperis.fr} {SUBJECT "Cloverleaf: nombre de fichier LOGIMED METZ" } {BODY "Les fichiers LOGIMED ne sont pas pr??lev??s car le nombre de fichier en attente de pr??l??vement n'est pas de 13. Veuillez v??rifier Merci." } {NBFILE 13}
# Args IGNORE, if set at 1 (true) files are not sended and an alert is sent if the nbfiles don't match
#              if set at 0 (false)the file are sended and an alert is sent if nbfiles don't match 
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
    set usetls 0        ; keylget uargs USETLS usetls
    set from {}         ; keylget uargs FROM from
    set to {}           ; keylget uargs TO to
    set subject {}      ; keylget uargs SUBJECT subject
    set body {}         ; keylget uargs BODY body
    set nbfile 10       ; keylget uargs NBFILE nbfile
    set ignore 1        ; keylget uargs IGNORE ignore
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
            set i [ llength [msgget  $mh ]]
            set test [msgget $mh]
            echo "nombre de fichiers pr??sent dans le r??pertoire : $i"
            echo "nombre de fichiers demandes : $nbfile"
            if {$i != $nbfile } {
                echo "le nombre de fichiers pr??sent : $i est different du nombre de fichier demandes $nbfile"
                if {$ignore == 1 } {
                    msgset $mh {}
                    echo "Les fichiers ne sont pas preleves (ignore = $ignore) "
                    if {$debug} { echo "mh : $test"  }
                    } else {
                    echo "Les fichiers sont preleves (ignore = $ignore) "
                    if {$debug} { echo "mh : $test" }
                    }
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
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           20180803 TLZ - v3 - Correction d'une fuite m??moire
#           20190412 TLZ - v6 - Correction critique sur le pr??l??vement des fichiers
#           20190506 PFK - v7 - Rajout de la v??rification de la version de CIS pour le d??cryptage des MdP
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
            keylget args MSGID mh  
            #Controles de conformite
            if { [cequal $uargs ""]} {
                puts stderr "Erreur: Veuillez inserer un argument dans la procedure xper_selectFiles"
                # Correction v6
                msgset $mh "" 
                lappend dispList "CONTINUE $mh"
                return $dispList
            }              
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
                    default {incr index_arg}
                }
            }
            
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
                    if {$debug} { echo Aucun r??sultat pour l'argument $nocase$arg ne se trouve dans le r??pertoire }
                    msgset $mh "" ; # Correction v6
                    lappend dispList "CONTINUE $mh" ; # Correction v3
                    return $dispList
                }
                lappend x_file_list $file_list
            }
            if {$nb_arg >1} {            
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
#                 ?? "pattern" ayant comme fichier ack "ack"
#                 (optionnel) et comme fichier d'accompagnement "file" (optionnel).
#                  "excludeFile" ?? 1 permet de ne pas parser les fichiers d'accompagnement.
# Exemples:       PATTERN \.hpr$, ACK \.ok$ et FILE \.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et test.pdf)
#                 Pour r??cup??rer plusieurs fichiers t??moins, il faut adapter la regexp FILE comme ceci
#                 PATTERN \.hpr$, ACK \.ok$ et FILE \[0-9]{3}.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et tous les fichiers testXXX.pdf)
#                 Pour que les fichiers file ne soient pas pars??s, rajouter l'option EXCLUDEFILE ?? 1. Ceci permet d'attendre par exemple qu'un triplet de fichiers
#                 soit pr??sent avant d'envoyer seulement le doublet au parsing
# UPoC type:      tps
# Args:           {DEBUG 0|1} (optional, defaults = 0)
#                 {PATTERN PatternValue} (optional, defaults = ".")
#                 {ACK AckPattern} (optional, defaults = "")
#                 {FILE FilePattern} (optional, defaults = "")
#                 {EXCLUDEFILE ExcludeFile} (optional, defaults = 0)
#                 {DELAY DelaySec} (optional, defaults = 0)
# Returns:        tps disposition list
# History: 10-04-2019 TLZ : enf_dirParseUsingRegexp_v3_delay avec decryptage du mot de passe 
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

            # On r??duit la taille des listes sur lesquelles on travaille
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
                    if { $protocol == "fileset/ftp" } {
                        keylget threadconfig PROTOCOL.FTPHOST host
                        keylget threadconfig PROTOCOL.FTPUSER login
                        keylget threadconfig PROTOCOL.FTPPASSWD password
                        keylget threadconfig PROTOCOL.FTPIBDIR directory
						set cisversion $::env(HCIVERSION)
                        # Decryptage du mot de passe sur la version 6.2
						if {$cisversion >= 6.2 } {
							if {$debug} { echo "password (before decrypt) : $password" }
							catch {exec hcicrypt decrypt $password} password
							set password  [::base64::decode $password]
							if {$debug} { echo "password (after decrypt) : $password" }
                        } else {
							if {$debug} { echo "password (not crypt at all) : $password" }
						}
                        # Fin Decryptage
                        set msg "";set rc [ catch {exec curl -I ftp://$login:$password@$host/$directory/$patternListElement} msg]
                        if { $rc == 1 } {
                            set date [string trim [lindex [split [lindex [split $msg \n] 0] :] 1] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 2] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 3] ]
                            set scan_date [clock scan $date]
                            if { [expr [clock seconds] - $scan_date] >= $delay } {
                                lappend delayList $patternListElement
                            }
                        }
                    }
                }
                set patternList $delayList
            }

            # End of Delay

            # On parcourt la liste des fichiers r??pondant au pattern
            foreach patternListElement $patternList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""

                # On r??cup??re le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}

                # On recherche le t??moin associ??
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }

                # On recherche le fichier associ??
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }

                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                    lappend match_list $ackFilename
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    lappend match_list $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est d??fini
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
# Purpose:   Procs permettant de compter les fichiers en retour d'une dirparse. Si nombre de message ne correspond $mh est vid??, veillez ?? placer la proc en dirpase TPS Inbound apr??s une dirparse
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
#    {DEBUG 0} {SERVER serveursmtp.fr} {PORT 25} {FROM cloverleaf@site.fr} {TO cloverleaf@infor.com,support@xperis.fr} {SUBJECT "Cloverleaf: nombre de fichier" } {BODY "Les fichiers ne sont pas pr??lev??s car le nombre de fichier en attente de pr??l??vement ne correspond pas. Veuillez v??rifier Merci." } {NBFILE 13}
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
#    {DEBUG 0} {IGNORE 1} {SERVER chrmt-smtp01} {PORT 25} {FROM hciuser.win-eai@chr-metz-thionville.fr} {TO bernadette.collignon@ch-briey.fr,am.pontus@chr-metz-thionville.fr,f.zimmer@chr-metz-thionville.fr,support@xperis.fr} {SUBJECT "Cloverleaf: nombre de fichier LOGIMED METZ" } {BODY "Les fichiers LOGIMED ne sont pas pr??lev??s car le nombre de fichier en attente de pr??l??vement n'est pas de 13. Veuillez v??rifier Merci." } {NBFILE 13}
# Args IGNORE, if set at 1 (true) files are not sended and an alert is sent if the nbfiles don't match
#              if set at 0 (false)the file are sended and an alert is sent if nbfiles don't match 
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
    set usetls 0        ; keylget uargs USETLS usetls
    set from {}         ; keylget uargs FROM from
    set to {}           ; keylget uargs TO to
    set subject {}      ; keylget uargs SUBJECT subject
    set body {}         ; keylget uargs BODY body
    set nbfile 10       ; keylget uargs NBFILE nbfile
    set ignore 1        ; keylget uargs IGNORE ignore
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
            set i [ llength [msgget  $mh ]]
            set test [msgget $mh]
            echo "nombre de fichiers pr??sent dans le r??pertoire : $i"
            echo "nombre de fichiers demandes : $nbfile"
            if {$i != $nbfile } {
                echo "le nombre de fichiers pr??sent : $i est different du nombre de fichier demandes $nbfile"
                if {$ignore == 1 } {
                    msgset $mh {}
                    echo "Les fichiers ne sont pas preleves (ignore = $ignore) "
                    if {$debug} { echo "mh : $test"  }
                    } else {
                    echo "Les fichiers sont preleves (ignore = $ignore) "
                    if {$debug} { echo "mh : $test" }
                    }
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
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           20180803 TLZ - v3 - Correction d'une fuite m??moire
#           20190412 TLZ - v6 - Correction critique sur le pr??l??vement des fichiers
#           20190506 PFK - v7 - Rajout de la v??rification de la version de CIS pour le d??cryptage des MdP
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
            keylget args MSGID mh  
            #Controles de conformite
            if { [cequal $uargs ""]} {
                puts stderr "Erreur: Veuillez inserer un argument dans la procedure xper_selectFiles"
                # Correction v6
                msgset $mh "" 
                lappend dispList "CONTINUE $mh"
                return $dispList
            }              
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
                    default {incr index_arg}
                }
            }
            
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
                    if {$debug} { echo Aucun r??sultat pour l'argument $nocase$arg ne se trouve dans le r??pertoire }
                    msgset $mh "" ; # Correction v6
                    lappend dispList "CONTINUE $mh" ; # Correction v3
                    return $dispList
                }
                lappend x_file_list $file_list
            }
            if {$nb_arg >1} {            
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
#                 ?? "pattern" ayant comme fichier ack "ack"
#                 (optionnel) et comme fichier d'accompagnement "file" (optionnel).
#                  "excludeFile" ?? 1 permet de ne pas parser les fichiers d'accompagnement.
# Exemples:       PATTERN \.hpr$, ACK \.ok$ et FILE \.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et test.pdf)
#                 Pour r??cup??rer plusieurs fichiers t??moins, il faut adapter la regexp FILE comme ceci
#                 PATTERN \.hpr$, ACK \.ok$ et FILE \[0-9]{3}.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et tous les fichiers testXXX.pdf)
#                 Pour que les fichiers file ne soient pas pars??s, rajouter l'option EXCLUDEFILE ?? 1. Ceci permet d'attendre par exemple qu'un triplet de fichiers
#                 soit pr??sent avant d'envoyer seulement le doublet au parsing
# UPoC type:      tps
# Args:           {DEBUG 0|1} (optional, defaults = 0)
#                 {PATTERN PatternValue} (optional, defaults = ".")
#                 {ACK AckPattern} (optional, defaults = "")
#                 {FILE FilePattern} (optional, defaults = "")
#                 {EXCLUDEFILE ExcludeFile} (optional, defaults = 0)
#                 {DELAY DelaySec} (optional, defaults = 0)
# Returns:        tps disposition list
# History: 10-04-2019 TLZ : enf_dirParseUsingRegexp_v3_delay avec decryptage du mot de passe 
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

            # On r??duit la taille des listes sur lesquelles on travaille
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
                    if { $protocol == "fileset/ftp" } {
                        keylget threadconfig PROTOCOL.FTPHOST host
                        keylget threadconfig PROTOCOL.FTPUSER login
                        keylget threadconfig PROTOCOL.FTPPASSWD password
                        keylget threadconfig PROTOCOL.FTPIBDIR directory
						set cisversion $::env(HCIVERSION)
                        # Decryptage du mot de passe sur la version 6.2
						if {$cisversion >= 6.2 } {
							if {$debug} { echo "password (before decrypt) : $password" }
							catch {exec hcicrypt decrypt $password} password
							set password  [::base64::decode $password]
							if {$debug} { echo "password (after decrypt) : $password" }
                        } else {
							if {$debug} { echo "password (not crypt at all) : $password" }
						}
                        # Fin Decryptage
                        set msg "";set rc [ catch {exec curl -I ftp://$login:$password@$host/$directory/$patternListElement} msg]
                        if { $rc == 1 } {
                            set date [string trim [lindex [split [lindex [split $msg \n] 0] :] 1] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 2] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 3] ]
                            set scan_date [clock scan $date]
                            if { [expr [clock seconds] - $scan_date] >= $delay } {
                                lappend delayList $patternListElement
                            }
                        }
                    }
                }
                set patternList $delayList
            }

            # End of Delay

            # On parcourt la liste des fichiers r??pondant au pattern
            foreach patternListElement $patternList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""

                # On r??cup??re le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}

                # On recherche le t??moin associ??
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }

                # On recherche le fichier associ??
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }

                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                    lappend match_list $ackFilename
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    lappend match_list $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est d??fini
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
# Purpose:   Procs permettant de compter les fichiers en retour d'une dirparse. Si nombre de message ne correspond $mh est vid??, veillez ?? placer la proc en dirpase TPS Inbound apr??s une dirparse
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
#    {DEBUG 0} {SERVER serveursmtp.fr} {PORT 25} {FROM cloverleaf@site.fr} {TO cloverleaf@infor.com,support@xperis.fr} {SUBJECT "Cloverleaf: nombre de fichier" } {BODY "Les fichiers ne sont pas pr??lev??s car le nombre de fichier en attente de pr??l??vement ne correspond pas. Veuillez v??rifier Merci." } {NBFILE 13}
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
#    {DEBUG 0} {IGNORE 1} {SERVER chrmt-smtp01} {PORT 25} {FROM hciuser.win-eai@chr-metz-thionville.fr} {TO bernadette.collignon@ch-briey.fr,am.pontus@chr-metz-thionville.fr,f.zimmer@chr-metz-thionville.fr,support@xperis.fr} {SUBJECT "Cloverleaf: nombre de fichier LOGIMED METZ" } {BODY "Les fichiers LOGIMED ne sont pas pr??lev??s car le nombre de fichier en attente de pr??l??vement n'est pas de 13. Veuillez v??rifier Merci." } {NBFILE 13}
# Args IGNORE, if set at 1 (true) files are not sended and an alert is sent if the nbfiles don't match
#              if set at 0 (false)the file are sended and an alert is sent if nbfiles don't match 
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
    set usetls 0        ; keylget uargs USETLS usetls
    set from {}         ; keylget uargs FROM from
    set to {}           ; keylget uargs TO to
    set subject {}      ; keylget uargs SUBJECT subject
    set body {}         ; keylget uargs BODY body
    set nbfile 10       ; keylget uargs NBFILE nbfile
    set ignore 1        ; keylget uargs IGNORE ignore
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
            set i [ llength [msgget  $mh ]]
            set test [msgget $mh]
            echo "nombre de fichiers pr??sent dans le r??pertoire : $i"
            echo "nombre de fichiers demandes : $nbfile"
            if {$i != $nbfile } {
                echo "le nombre de fichiers pr??sent : $i est different du nombre de fichier demandes $nbfile"
                if {$ignore == 1 } {
                    msgset $mh {}
                    echo "Les fichiers ne sont pas preleves (ignore = $ignore) "
                    if {$debug} { echo "mh : $test"  }
                    } else {
                    echo "Les fichiers sont preleves (ignore = $ignore) "
                    if {$debug} { echo "mh : $test" }
                    }
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
#                   Exemple d'arguments:    test*.hl7  ou   ^test.*\.[Hh][Ll]7$
#                                           .pdf            \.[Pp][Dd][Ff]$
#                                           .ok             \.[Oo][Kk]$
#                                                           %regex%
#                   En complement, les variables suivantes peuvent etre utilisees :
#                       %debug% : Lance la procedure en mode debug
#                       %regex% : Autorise la saisie d'expressions regulieres
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           20180803 TLZ - v3 - Correction d'une fuite m??moire
#           20190412 TLZ - v6 - Correction critique sur le pr??l??vement des fichiers
#           20190506 PFK - v7 - Rajout de la v??rification de la version de CIS pour le d??cryptage des MdP
#           20190903 TLZ - v9 - Suppression de la d??pendance xper_replaceChars
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
            keylget args MSGID mh  
            #Controles de conformite
            if { [cequal $uargs ""]} {
                puts stderr "Erreur: Veuillez inserer un argument dans la procedure xper_selectFiles"
                # Correction v6
                msgset $mh "" 
                lappend dispList "CONTINUE $mh"
                return $dispList
            }              
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
                    default {incr index_arg}
                }
            }
            
            if { $regex } {
                if {$debug} { puts stdout "Regex mode..." }
            } else {
                # Simplifications des recherches dans le mode classique
                set arg_list [string map {. \\\\. * .*} $arg_list]     ; # v9 : On remplace le . par \. et * par .*
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
                    if {$debug} { echo Aucun r??sultat pour l'argument $nocase$arg ne se trouve dans le r??pertoire }
                    msgset $mh "" ; # Correction v6
                    lappend dispList "CONTINUE $mh" ; # Correction v3
                    return $dispList
                }
                lappend x_file_list $file_list
            }
            if {$nb_arg >1} {            
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
#                 ?? "pattern" ayant comme fichier ack "ack"
#                 (optionnel) et comme fichier d'accompagnement "file" (optionnel).
#                  "excludeFile" ?? 1 permet de ne pas parser les fichiers d'accompagnement.
# Exemples:       PATTERN \.hpr$, ACK \.ok$ et FILE \.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et test.pdf)
#                 Pour r??cup??rer plusieurs fichiers t??moins, il faut adapter la regexp FILE comme ceci
#                 PATTERN \.hpr$, ACK \.ok$ et FILE \[0-9]{3}.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et tous les fichiers testXXX.pdf)
#                 Pour que les fichiers file ne soient pas pars??s, rajouter l'option EXCLUDEFILE ?? 1. Ceci permet d'attendre par exemple qu'un triplet de fichiers
#                 soit pr??sent avant d'envoyer seulement le doublet au parsing
# UPoC type:      tps
# Args:           {DEBUG 0|1} (optional, defaults = 0)
#                 {PATTERN PatternValue} (optional, defaults = ".")
#                 {ACK AckPattern} (optional, defaults = "")
#                 {FILE FilePattern} (optional, defaults = "")
#                 {EXCLUDEFILE ExcludeFile} (optional, defaults = 0)
#                 {DELAY DelaySec} (optional, defaults = 0)
# Returns:        tps disposition list
# History: 10-04-2019 TLZ : enf_dirParseUsingRegexp_v3_delay avec decryptage du mot de passe 
#          28-02-2016 AGS : Compatible avec les partages Windows
#          18-11-2015 TLZ : Ajout du Delay
#          13-08-2015 TLZ : Compatibilite avec CIS 5.8
#          03-2015 GJZ : Creation de la v3
#          27-07-2007 Aurelien Garros, E.Novation France
#          07-10-2005 AH, E.Novation lifeLine Networks bv
#                     Added DEBUG argument, to get full output#
# Notes:          It's unlikely this will work for all possible regexps!
#                 Further testing is required.

proc xper_resolve_gv { gv_to_resolve } {
	global HciConnName
	package require Sitecontrol
	set cisversion $::env(HCIVERSION)
	if {$cisversion >= 6.2 } {
		set gv_pattern {(\$\$[a-zA-Z0-9_]*)}
		set gv_list ""; set gv_state 0; set gv_map ""; set gv_resolved "";
		set gv_list [regexp -inline $gv_pattern $gv_to_resolve]
		set gv_state [ llength $gv_list]
		if { $gv_state > 0 } {
			foreach gv_element $gv_list {
				set gv_map [gvgetvar [string range $gv_element 2 end]]
				set gv_resolved [ string map [list $gv_element $gv_map] $gv_to_resolve ]
			}
		} else { 
			set gv_resolved $gv_to_resolve
		}
	} else {
		set gv_pattern {(\$\$[a-zA-Z0-9_]*)}
		set gv_list ""; set gv_state 0; set gv_map ""; set gv_resolved "";
		set gv_list [regexp -inline $gv_pattern $gv_to_resolve]
		set gv_state [ llength $gv_list]
		if { $gv_state >= 0 } {echo "Attention, votre version de cloverleaf, ne prend pas en charge la r??solution des Variables Globales en tcl"}
		set gv_resolved $gv_to_resolve
		}
	return $gv_resolved
}

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
            if {$debug} {echo mhList avant filtre : $mhList}
            # Start of enf_dirParseUsingRegexp_v3

            # On r??duit la taille des listes sur lesquelles on travaille
            set patternListList [lsearch -all -inline -regexp $mhList $pattern]
            if { ![cequal $ack ""] } {
                set ackList [lsearch -all -inline -regexp $mhList $ack]
            }
            if { ![cequal $file ""] } {
                set fileList [lsearch -all -inline -regexp $mhList $file]
            }
            if {$debug} {echo patternListList avant d??lai : $patternListList}

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
                    set myfile ""
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
						set ibdir [xper_resolve_gv ${ibdir} ]
						
                         if { ![cequal [crange $ibdir 0 1] ..] } {
                            set myfile ${ibdir}/$patternListElement
                        } else {
                            set myfile [pwd]/${ibdir}/$patternListElement
                        }
                        if {$debug} {echo chemin du fichier : $myfile}
                        #set scan_date [file mtime $myfile]
                        if { [cequal [file exists $myfile] 1] } {
                            set scan_date "";set rc "";set rc [ catch { file mtime $myfile } scan_date]
                            if {$debug} { 
                                echo rc : $rc
                                echo scan_date : $scan_date
                            }
                            if { $rc == 0 } {
                                if {$debug} {echo mtime du fichier $scan_date}
                                if {$debug} {echo heure actuelle [clock seconds]}
                                if { [expr [clock seconds] - $scan_date] >= $delay } {
                                    lappend delayList $patternListElement
                                    if {$debug} {echo delay respect?? pour fichier : $myfile}
                                    if {$debug} {echo delay respect?? pour la liste en cours : $delayList}
                                } else {
                                    if {$debug} {echo delay non respect?? pour le fichier : $myfile}
                                }
                            }
                        } else {
                            if {$debug} {echo Le fichier suivant n'existe pas : $myfile}
                        }
                    }
                    if { $protocol == "fileset/ftp" } {
                        keylget threadconfig PROTOCOL.FTPHOST host
						set host [xper_resolve_gv ${host} ]
                        keylget threadconfig PROTOCOL.FTPUSER login
						set login [xper_resolve_gv ${login} ]
                        keylget threadconfig PROTOCOL.FTPPASSWD password
						set password [xper_resolve_gv ${password} ]
                        keylget threadconfig PROTOCOL.FTPIBDIR directory
						set directory [xper_resolve_gv ${directory} ]
						keylget threadconfig PROTOCOL.FTPPORT port
						set port [xper_resolve_gv ${port} ]
                        set cisversion $::env(HCIVERSION)
                        # Decryptage du mot de passe sur la version 6.2
                        if {$cisversion >= 6.2 } {
                            if {$debug} { echo "password (before decrypt) : $password" }
                            catch {exec hcicrypt decrypt $password} password
                            set password  [::base64::decode $password]
                            if {$debug} { echo "password (after decrypt) : $password" }
                        } else {
                            if {$debug} { echo "password (not crypt at all) : $password" }
                        }
                        # Fin Decryptage
                        set msg "";set rc [ catch {exec curl -I ftp://$login:$password@$host:$port/$directory/$patternListElement} msg]
                        if { $rc == 1 } {
                            set date [string trim [lindex [split [lindex [split $msg \n] 0] :] 1] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 2] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 3] ]
                            set scan_date [clock scan $date]
                            if { [expr [clock seconds] - $scan_date] >= $delay } {
                                lappend delayList $patternListElement
                            }
                        }
                    }
                }
                set patternList $delayList
            }
            if {$debug} { echo delay respect?? pour la liste definitive suivante,delayList : $delayList}
            # End of Delay

            # On parcourt la liste des fichiers r??pondant au pattern
            foreach patternListElement $patternList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""

                # On r??cup??re le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}

                # On recherche le t??moin associ??
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }

                # On recherche le fichier associ??
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }

                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                    lappend match_list $ackFilename
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    lappend match_list $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est d??fini
                    lappend match_list $patternListElement
                }
            }

            # End of enf_dirParseUsingRegexp_v3

            if {$debug} {echo match_list : $match_list}
            msgset $mh $match_list
            lappend dispList "CONTINUE $mh"
            set lmatch_list [llength $match_list]
            if { $debug } {
                puts stdout "$module: Retrieved directory listing: \n\t [msgget $mh]"
                puts stdout "$module: Matching against pattern $pattern"
                puts stdout "$module: Found $lmatch_list matches: \n\t$match_list"
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
# Name:      xper_dirParse_size_alerte
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
#            In filesystem  please use  ListFullDirectory
#            In FTP please use nlst
#            To send alerte set args : {SENDMAIL 1} and recipient {To user1@domain1.com, user2@domaine2.com}
#Exemple :   { PATTERN \\.[tT][xX][tT]$ } {DEBUG 0} {SIZE 200000} {FILE \\.[cC][sS][vV]$} {ACK \\.[oO][kK]$} {SENDMAIL 1} {TO user1@domain1.com,user2@domaine2.com}
#
# History:   <date> <name> <comments>
#                20190513 IHB creation de la V8_size_alerte en ftp  int??gr?? ?? la xper_dirparse_procs_v8.tcl  

       

proc xper_dirParse_size_alerte { args } {
    package require Sitecontrol
    package require base64
    package require smtp
    package require mime 
    
    global HciConnName                             ;# Name of thread
    
    
    if { [catch {set success [::Sitecontrol::loadNetConfig]} err] || $success == -1} {
        ::DoctoolsUtil::logger FATAL "Skipping $runVars(CURRFILE) because it was invalid... $err"
        return
    }
    set threadconfig [::Sitecontrol::getThreadData $HciConnName]
    
    
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0           ;                                 ;# Fetch user argument DEBUG and
    set full 0            ; catch {keylget threadconfig PROTOCOL.LISTFULLDIR full}
    set protocol ""       ; catch {keylget threadconfig PROTOCOL.TYPE protocol}
    set pattern "."       ; keylget uargs PATTERN pattern
    set ack ""            ; keylget uargs ACK ack
    set file ""           ; keylget uargs FILE file
    set excludeFile 0     ; keylget uargs EXCLUDEFILE excludeFile
    set size 104857600    ; keylget uargs SIZE size
    set cisversion $::env(HCIVERSION)
    
    set sendMail 0          ; keylget uargs SENDMAIL sendMail
    ReadKeyFile [file join $::env(HCISitedir) siteInfo] siteInfo
    set mailserver [keylget siteInfo mailserver]; keylget uargs MAILSERVER mailserver
    set mailport [keylget siteInfo mailport]; keylget uargs MAILPORT mailport
    set mailusername [keylget siteInfo mailloginuser]; keylget uargs MAILUSERNAME mailusername
    set mailpassword [keylget siteInfo mailpassword]; keylget uargs MAILPASSWORD mailpassword
    set usetls [keylget siteInfo mailusetls]; keylget uargs USETLS usetls
    set from [keylget siteInfo mailfrom]; keylget uargs FROM from
    set to "support@xperis.fr"; keylget uargs TO to

    
    set sizeList ""       ; 
    set overSizeList ""   ;# liste des fichiers trop volumineux
    set fileSize "";
    set matchList "";
    set patternListList {};
    set patternList {};
    set site $::env(HCISite) ;

    
    # Extraction du type de protocole
    if { [cequal $protocol fileset] && [keylget threadconfig PROTOCOL.MODE protoSubType] == 1 } { append protocol "/$protoSubType" }
    # Version 5.4 and up has subtype for ihb stuff
    if { [keylget threadconfig PROTOCOL.SUBTYPE protoSubType] } { append protocol "/$protoSubType" }
    
        
    if {$debug} {
        echo protocol : $protocol
        }
    
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "enf_dirParseUsingRegexp_v4_size/$HciConnName/$ctx" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            
            if { $debug } {
                puts stdout "$module: Starting in debug mode..."
                        echo "full : $full"
                        echo "debug : $debug"
                        echo "pattern : $pattern"
                        echo "ack : $ack"
                        echo "file : $file"
                        echo "excludeFile : $excludeFile"
                        echo "size : $size"
                        echo "protocol: $protocol"
                        echo "sendmail : $sendMail"
            }
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            
            keylget args MSGID mh
            set mhList [msgget $mh]
            if {$debug} {echo "mh: $mh"}

            if { $protocol == "fileset/ftp" } {
                # On r??duit la taille des listes sur lesquelles on travaille
                set patternListList [ lsearch -all -inline -regexp $mhList $pattern ]
                if { ![cequal $file ""] } {append patternListList " " ; append patternListList [lsearch -all -inline -regexp $mhList $file]}
                if { ![cequal $ack ""] } {append patternListList " " ; append patternListList [lsearch -all -inline -regexp $mhList $ack]}
                if {$debug} {echo "patternListList : $patternListList" }
                # On parcourt une premiere fois la liste des fichiers r??pondant au pattern
                
                #1er cas, traitement de la liste pour le ftp
                foreach patternListListElement $patternListList {
 
                
                
                    keylget threadconfig PROTOCOL.FTPHOST host
                    keylget threadconfig PROTOCOL.FTPUSER login
                    keylget threadconfig PROTOCOL.FTPPASSWD password
                    keylget threadconfig PROTOCOL.FTPIBDIR directory
                    
                    set cisversion $::env(HCIVERSION)
                    if {$cisversion >= 6.2 } {
                        if {$debug} { echo "password (before decrypt) : $password" }
                        catch {exec hcicrypt decrypt $password} password
                        set password  [::base64::decode $password]
                        if {$debug} { echo "password (after decrypt) : $password" }
                        } else { if {$debug} { echo "password (not crypt at all) : $password" }}
                        
                    if {$debug} {echo "host : $host";    echo "login : $login";    echo "directory : $directory";    echo "cisversion : $cisversion";    echo "patternListListElement: $patternListListElement"; }

                    if { $protocol == "fileset/ftp" } {   
                    set msg {};set rc [ catch {exec curl -I ftp://${login}:${password}@${host}/${directory}/${patternListListElement}} msg]
                    }
                    if { $protocol == "fileset/sftp" } {   
                    set msg {};set rc [ catch {exec curl -I sftp://${login}:${password}@${host}/${directory}/${patternListListElement --insecure}} msg]
                    }
                    if { $protocol == "fileset/ftps" } {   
                    set msg {};set rc [ catch {exec curl -I ftps://${login}:${password}@${host}/${directory}/${patternListListElement --insecure}} msg]
                    }
                    
                    if { $rc == 1 } {
                        if {$debug} { echo "msg : $msg" }
                        set fileSize [string trim [lindex [split [lindex [split $msg \n] 1] :] 1]]
                        
                        echo fileSize : $fileSize
                        if { $fileSize <= $size } {
                            #echo "La taille du fichier \"$patternListListElement\" est de $fileSize Octets (max $size Octets), le fichier sera preleve";
                            lappend sizeList $patternListListElement;
                            
                        } else {
                            #echo "La taille du fichier \"$patternListListElement\" ; $fileSize Octets; est trop importante(max $size Octets), le fichier ne sera pas preleve";
                            #set temp ""; set temp [string map {{.} {.}} $patternListListElement]
                            #echo temp: $temp
                            keylset overSizeList ${patternListListElement} ${fileSize};
                        }
                        
                        
                    }
                }
            }
                if { $protocol == "fileset/local-tps" } {

                    set patternListList $mhList
                    set filtreList "";
                #1er cas, traitement de la liste pour le fileset
                    foreach patternListListElement $patternListList {

                        foreach element $patternListListElement {

                            set fileSize [lindex $element end-1]
                            set filename [lrange $element 0 end-2]
                            if { $fileSize <= $size } {
                                if {$debug} {echo  filename : $filename}
                                lappend sizeList $filename ;
                                #echo "La taille du fichier \"$filename\" est de $fileSize Octets (max $size Octets), le fichier sera preleve";
                            } else {
                                keylset overSizeList ${filename} ${fileSize} ;
                                lappend  filtreList ${filename};                              
                                #echo "La taille du fichier \"$filename\" ; $fileSize Octets; est trop importante(max $size Octets), le fichier ne sera pas preleve";
                            }
                            if {$debug} {echo fileSize for $filename : $fileSize}

                        }

                    }
                    if {$debug} {echo "filtreList : $filtreList";}
                    set tempFiltreList {};
                    set tempFiltreList [lsearch -all -inline -regexp $filtreList $pattern]
                    if { ![cequal $ack ""] } {append tempFiltreList " " ; append tempFiltreList [lsearch -all -inline -regexp $filtreList $ack]}
                    if { ![cequal $file ""] } {append tempFiltreList " " ; append tempFiltreList [lsearch -all -inline -regexp $filtreList $file]}
                    if {$debug} {echo "tempFiltreList : $tempFiltreList";}
                    set tempOverSizeList {};
                    set temp {} ;
                    foreach tempFiltreListElement  $tempFiltreList {
                        set temp [keylget overSizeList $tempFiltreListElement]
                        keylset tempOverSizeList $tempFiltreListElement [ keylget overSizeList $tempFiltreListElement ]
                    }
                    if {$debug} {echo "tempOverSizeList : $tempOverSizeList";}
                    set overSizeList $tempOverSizeList;
                    if {$debug} {echo "overSizeList : $overSizeList;"}
            }
            set temp {};
            foreach overSizeListElement [keylget overSizeList] {
                foreach overSizeListElementElement [keylget overSizeList $overSizeListElement] {
                    lappend temp "Fichier : ${overSizeListElement}.${overSizeListElementElement} Octets"
                }
            }
            set overSizeList $temp
            # Production du fichier d'alerte
            
            #set filename path
            set pathAlerteFile ""; append pathAlerteFile $::env(HCISitedir) \\OversizeAlerteFile.txt
            set content [string range [split [read_file $pathAlerteFile] "\r\n"] 1 end-4]
             if {$debug} {
                echo "pathAlerteFile : $pathAlerteFile;"
                echo "Final overSizeList : $overSizeList;"
                echo "content : $content;"
             }
            
            if {(![cequal $content $overSizeList]) && ($sendMail)} {
                
                #keylkeys siteInfo
                set subject "EAI site $site : Fichiers trop volumineux, non preleves"
                set body "Bonjour,\r\nLe fichier suivant presente une taille trop importante pour ??tre pr??lev?? ( taille max autoris??e : $size Octets).\r\n$overSizeList.\r\nVeuillez v??rifier le fichier."
    
                if {$cisversion >= 6.2 } {
                    if {$debug} { echo "mailpassword (before decrypt) : $mailpassword" }
                    catch {exec hcicrypt decrypt $mailpassword} mailpassword
                    set mailpassword  [::base64::decode $mailpassword]
                    if {$debug} { echo "mailpassword (after decrypt) : $mailpassword" }
                    } else { if {$debug} { echo "mailpassword (not crypt at all) : $mailpassword" }}
                        
                if {$debug} {
                    echo "mailserver : $mailserver" 
                    echo "mailport : $mailport"
                    echo "mailusername : $mailusername"
                    echo "mailpassword : $mailpassword"
                    echo "usetls : $usetls"
                    echo "from : $from"
                    echo "to : $to"
                    echo "subject : $subject"
                    echo "body : $body"
                }
                
                set token [::mime::initialize -canonical text/plain -string "$body"]
                set command [list ::smtp::sendmessage $token\
                -servers $mailserver -ports $mailport -username $mailusername -password $mailpassword -usetls $usetls \
                -header [list From "$from"] -header [list To "$to"] -header [list Subject "$subject"] \
                -header [list Date "[clock format [clock seconds]]"] -debug $debug]
                if {$debug} { echo "command: $command" }
                eval $command
                
                #Modification et fermeture du fichier
            write_file $pathAlerteFile $overSizeList
            }
            #Production de la liste transmise ?? la V3
            set patternList $sizeList
            echo "sizeList : $sizeList" ;         
            echo "overSizeList : ${overSizeList};"
            #Debut de la V3 "classique"
            
            set patternListList {};
            set ackList {};
            set fileList {]};
            set patternListList [lsearch -all -inline -regexp $patternList $pattern]
            
            if { ![cequal $ack ""] } {set ackList [lsearch -all -inline -regexp $patternList $ack]}
            
            if { ![cequal $file ""] } {set fileList [lsearch -all -inline -regexp $patternList $file]}
            
            # On parcourt la liste des fichiers r??pondant au pattern
            foreach patternListElement $patternListList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""

                # On r??cup??re le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}

                # On recherche le t??moin associ??
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }

                # On recherche le fichier associ??
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }

                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont d??finis
                    lappend matchList $patternListElement
                    if { $excludeFile == 0 } {
                        set matchList [concat $matchList $fileFilenameList]
                    }
                    lappend matchList $ackFilename
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont d??finis 
                    lappend matchList $patternListElement
                    lappend matchList $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont d??finis
                    lappend matchList $patternListElement
                    if { $excludeFile == 0 } {
                        set matchList [concat $matchList $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est d??fini
                    lappend matchList $patternListElement
                }
            }
            msgset $mh $matchList
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
#                   Exemple d'arguments:    test*.hl7  ou   ^test.*\.[Hh][Ll]7$
#                                           .pdf            \.[Pp][Dd][Ff]$
#                                           .ok             \.[Oo][Kk]$
#                                                           %regex%
#                   En complement, les variables suivantes peuvent etre utilisees :
#                       %debug% : Lance la procedure en mode debug
#                       %regex% : Autorise la saisie d'expressions regulieres
#
# Returns:  tps disposition list:
#           <describe dispositions used here>
#
# Notes:    <put your notes here>
#
# History:  20160803 TLZ - v0 - Creation de la procedure
#           20170217 TLZ - v1 - Correction lors d'un seul argument, ajout ^ et $ en mode simple et ^ pour les fichiers joints
#           20170811 TLZ - v2 - Recherche sans tenir compte des majuscules pour le mode simple (?i)
#           20180803 TLZ - v3 - Correction d'une fuite m??moire
#           20190412 TLZ - v6 - Correction critique sur le pr??l??vement des fichiers
#           20190506 PFK - v7 - Rajout de la v??rification de la version de CIS pour le d??cryptage des MdP
#           20190903 TLZ - v9 - Suppression de la d??pendance xper_replaceChars
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
            keylget args MSGID mh  
            #Controles de conformite
            if { [cequal $uargs ""]} {
                puts stderr "Erreur: Veuillez inserer un argument dans la procedure xper_selectFiles"
                # Correction v6
                msgset $mh "" 
                lappend dispList "CONTINUE $mh"
                return $dispList
            }              
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
                    default {incr index_arg}
                }
            }
            
            if { $regex } {
                if {$debug} { puts stdout "Regex mode..." }
            } else {
                # Simplifications des recherches dans le mode classique
                set arg_list [string map {. \\\\. * .*} $arg_list]     ; # v9 : On remplace le . par \. et * par .*
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
                    if {$debug} { echo Aucun r??sultat pour l'argument $nocase$arg ne se trouve dans le r??pertoire }
                    msgset $mh "" ; # Correction v6
                    lappend dispList "CONTINUE $mh" ; # Correction v3
                    return $dispList
                }
                lappend x_file_list $file_list
            }
            if {$nb_arg >1} {            
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
#                 ?? "pattern" ayant comme fichier ack "ack"
#                 (optionnel) et comme fichier d'accompagnement "file" (optionnel).
#                  "excludeFile" ?? 1 permet de ne pas parser les fichiers d'accompagnement.
# Exemples:       PATTERN \.hpr$, ACK \.ok$ et FILE \.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et test.pdf)
#                 Pour r??cup??rer plusieurs fichiers t??moins, il faut adapter la regexp FILE comme ceci
#                 PATTERN \.hpr$, ACK \.ok$ et FILE \[0-9]{3}.pdf$ va r??cup??rer et parser les fichiers associ??s (exemple test.hpr, test.ok et tous les fichiers testXXX.pdf)
#                 Pour que les fichiers file ne soient pas pars??s, rajouter l'option EXCLUDEFILE ?? 1. Ceci permet d'attendre par exemple qu'un triplet de fichiers
#                 soit pr??sent avant d'envoyer seulement le doublet au parsing
# UPoC type:      tps
# Args:           {DEBUG 0|1} (optional, defaults = 0)
#                 {PATTERN PatternValue} (optional, defaults = ".")
#                 {ACK AckPattern} (optional, defaults = "")
#                 {FILE FilePattern} (optional, defaults = "")
#                 {EXCLUDEFILE ExcludeFile} (optional, defaults = 0)
#                 {DELAY DelaySec} (optional, defaults = 0)
# Returns:        tps disposition list
# History: 10-04-2019 TLZ : enf_dirParseUsingRegexp_v3_delay avec decryptage du mot de passe 
#          28-02-2016 AGS : Compatible avec les partages Windows
#          18-11-2015 TLZ : Ajout du Delay
#          13-08-2015 TLZ : Compatibilite avec CIS 5.8
#          03-2015 GJZ : Creation de la v3
#          27-07-2007 Aurelien Garros, E.Novation France
#          07-10-2005 AH, E.Novation lifeLine Networks bv
#                     Added DEBUG argument, to get full output#
# Notes:          It's unlikely this will work for all possible regexps!
#                 Further testing is required.

proc xper_resolve_gv { gv_to_resolve } {
	global HciConnName
	package require Sitecontrol
	set cisversion $::env(HCIVERSION)
	if {$cisversion >= 6.2 } {
		set gv_pattern {(\$\$[a-zA-Z0-9_]*)}
		set gv_list ""; set gv_state 0; set gv_map ""; set gv_resolved "";
		set gv_list [regexp -inline $gv_pattern $gv_to_resolve]
		set gv_state [ llength $gv_list]
		if { $gv_state > 0 } {
			foreach gv_element $gv_list {
				set gv_map [gvgetvar [string range $gv_element 2 end]]
				set gv_resolved [ string map [list $gv_element $gv_map] $gv_to_resolve ]
			}
		} else { 
			set gv_resolved $gv_to_resolve
		}
	} else {
		set gv_pattern {(\$\$[a-zA-Z0-9_]*)}
		set gv_list ""; set gv_state 0; set gv_map ""; set gv_resolved "";
		set gv_list [regexp -inline $gv_pattern $gv_to_resolve]
		set gv_state [ llength $gv_list]
		if { $gv_state >= 0 } {echo "Attention, votre version de cloverleaf, ne prend pas en charge la r??solution des Variables Globales en tcl"}
		set gv_resolved $gv_to_resolve
		}
	return $gv_resolved
}

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
            if {$debug} {echo mhList avant filtre : $mhList}
            # Start of enf_dirParseUsingRegexp_v3

            # On r??duit la taille des listes sur lesquelles on travaille
            set patternListList [lsearch -all -inline -regexp $mhList $pattern]
            if { ![cequal $ack ""] } {
                set ackList [lsearch -all -inline -regexp $mhList $ack]
            }
            if { ![cequal $file ""] } {
                set fileList [lsearch -all -inline -regexp $mhList $file]
            }
            if {$debug} {echo patternListList avant d??lai : $patternListList}

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
                    set myfile ""
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
						set ibdir [xper_resolve_gv ${ibdir} ]
						
                         if { ![cequal [crange $ibdir 0 1] ..] } {
                            set myfile ${ibdir}/$patternListElement
                        } else {
                            set myfile [pwd]/${ibdir}/$patternListElement
                        }
                        if {$debug} {echo chemin du fichier : $myfile}
                        #set scan_date [file mtime $myfile]
                        if { [cequal [file exists $myfile] 1] } {
                            set scan_date "";set rc "";set rc [ catch { file mtime $myfile } scan_date]
                            if {$debug} { 
                                echo rc : $rc
                                echo scan_date : $scan_date
                            }
                            if { $rc == 0 } {
                                if {$debug} {echo mtime du fichier $scan_date}
                                if {$debug} {echo heure actuelle [clock seconds]}
                                if { [expr [clock seconds] - $scan_date] >= $delay } {
                                    lappend delayList $patternListElement
                                    if {$debug} {echo delay respect?? pour fichier : $myfile}
                                    if {$debug} {echo delay respect?? pour la liste en cours : $delayList}
                                } else {
                                    if {$debug} {echo delay non respect?? pour le fichier : $myfile}
                                }
                            }
                        } else {
                            if {$debug} {echo Le fichier suivant n'existe pas : $myfile}
                        }
                    }
                    if { $protocol == "fileset/ftp" } {
                        keylget threadconfig PROTOCOL.FTPHOST host
						set host [xper_resolve_gv ${host} ]
                        keylget threadconfig PROTOCOL.FTPUSER login
						set login [xper_resolve_gv ${login} ]
                        keylget threadconfig PROTOCOL.FTPPASSWD password
						set password [xper_resolve_gv ${password} ]
                        keylget threadconfig PROTOCOL.FTPIBDIR directory
						set directory [xper_resolve_gv ${directory} ]
						keylget threadconfig PROTOCOL.FTPPORT port
						set port [xper_resolve_gv ${port} ]
                        set cisversion $::env(HCIVERSION)
                        # Decryptage du mot de passe sur la version 6.2
                        if {$cisversion >= 6.2 } {
                            if {$debug} { echo "password (before decrypt) : $password" }
                            catch {exec hcicrypt decrypt $password} password
                            set password  [::base64::decode $password]
                            if {$debug} { echo "password (after decrypt) : $password" }
                        } else {
                            if {$debug} { echo "password (not crypt at all) : $password" }
                        }
                        # Fin Decryptage
                        set msg "";set rc [ catch {exec curl -I ftp://$login:$password@$host:$port/$directory/$patternListElement} msg]
                        if { $rc == 1 } {
                            set date [string trim [lindex [split [lindex [split $msg \n] 0] :] 1] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 2] ]
                            append date ":"
                            append date [string trim [lindex [split [lindex [split $msg \n] 0] :] 3] ]
                            set scan_date [clock scan $date]
                            if { [expr [clock seconds] - $scan_date] >= $delay } {
                                lappend delayList $patternListElement
                            }
                        }
                    }
                }
                set patternList $delayList
            }
            if {$debug} { echo delay respect?? pour la liste definitive suivante,delayList : $delayList}
            # End of Delay

            # On parcourt la liste des fichiers r??pondant au pattern
            foreach patternListElement $patternList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""

                # On r??cup??re le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}

                # On recherche le t??moin associ??
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }

                # On recherche le fichier associ??
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }

                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                    lappend match_list $ackFilename
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    lappend match_list $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont d??finis
                    lappend match_list $patternListElement
                    if { $excludeFile == 0 } {
                        set match_list [concat $match_list $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est d??fini
                    lappend match_list $patternListElement
                }
            }

            # End of enf_dirParseUsingRegexp_v3

            if {$debug} {echo match_list : $match_list}
            msgset $mh $match_list
            lappend dispList "CONTINUE $mh"
            set lmatch_list [llength $match_list]
            if { $debug } {
                puts stdout "$module: Retrieved directory listing: \n\t [msgget $mh]"
                puts stdout "$module: Matching against pattern $pattern"
                puts stdout "$module: Found $lmatch_list matches: \n\t$match_list"
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
# Name:      xper_dirParse_size_alerte
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
#            In filesystem  please use  ListFullDirectory
#            In FTP please use nlst
#            To send alerte set args : {SENDMAIL 1} and recipient {To user1@domain1.com, user2@domaine2.com}
#Exemple :   { PATTERN \\.[tT][xX][tT]$ } {DEBUG 0} {SIZE 200000} {FILE \\.[cC][sS][vV]$} {ACK \\.[oO][kK]$} {SENDMAIL 1} {TO user1@domain1.com,user2@domaine2.com}
#
# History:   <date> <name> <comments>
#                20190513 IHB creation de la V8_size_alerte en ftp  int??gr?? ?? la xper_dirparse_procs_v8.tcl  

       

proc xper_dirParse_size_alerte { args } {
    package require Sitecontrol
    package require base64
    package require smtp
    package require mime 
    
    global HciConnName                             ;# Name of thread
    
    
    if { [catch {set success [::Sitecontrol::loadNetConfig]} err] || $success == -1} {
        ::DoctoolsUtil::logger FATAL "Skipping $runVars(CURRFILE) because it was invalid... $err"
        return
    }
    set threadconfig [::Sitecontrol::getThreadData $HciConnName]
    
    
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0           ;                                 ;# Fetch user argument DEBUG and
    set full 0            ; catch {keylget threadconfig PROTOCOL.LISTFULLDIR full}
    set protocol ""       ; catch {keylget threadconfig PROTOCOL.TYPE protocol}
    set pattern "."       ; keylget uargs PATTERN pattern
    set ack ""            ; keylget uargs ACK ack
    set file ""           ; keylget uargs FILE file
    set excludeFile 0     ; keylget uargs EXCLUDEFILE excludeFile
    set size 104857600    ; keylget uargs SIZE size
    set cisversion $::env(HCIVERSION)
    
    set sendMail 0          ; keylget uargs SENDMAIL sendMail
    ReadKeyFile [file join $::env(HCISitedir) siteInfo] siteInfo
    set mailserver [keylget siteInfo mailserver]; keylget uargs MAILSERVER mailserver
    set mailport [keylget siteInfo mailport]; keylget uargs MAILPORT mailport
    set mailusername [keylget siteInfo mailloginuser]; keylget uargs MAILUSERNAME mailusername
    set mailpassword [keylget siteInfo mailpassword]; keylget uargs MAILPASSWORD mailpassword
    set usetls [keylget siteInfo mailusetls]; keylget uargs USETLS usetls
    set from [keylget siteInfo mailfrom]; keylget uargs FROM from
    set to "support@xperis.fr"; keylget uargs TO to

    
    set sizeList ""       ; 
    set overSizeList ""   ;# liste des fichiers trop volumineux
    set fileSize "";
    set matchList "";
    set patternListList {};
    set patternList {};
    set site $::env(HCISite) ;

    
    # Extraction du type de protocole
    if { [cequal $protocol fileset] && [keylget threadconfig PROTOCOL.MODE protoSubType] == 1 } { append protocol "/$protoSubType" }
    # Version 5.4 and up has subtype for ihb stuff
    if { [keylget threadconfig PROTOCOL.SUBTYPE protoSubType] } { append protocol "/$protoSubType" }
    
        
    if {$debug} {
        echo protocol : $protocol
        }
    
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "enf_dirParseUsingRegexp_v4_size/$HciConnName/$ctx" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            
            if { $debug } {
                puts stdout "$module: Starting in debug mode..."
                        echo "full : $full"
                        echo "debug : $debug"
                        echo "pattern : $pattern"
                        echo "ack : $ack"
                        echo "file : $file"
                        echo "excludeFile : $excludeFile"
                        echo "size : $size"
                        echo "protocol: $protocol"
                        echo "sendmail : $sendMail"
            }
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            
            keylget args MSGID mh
            set mhList [msgget $mh]
            if {$debug} {echo "mh: $mh"}

            if { $protocol == "fileset/ftp" } {
                # On r??duit la taille des listes sur lesquelles on travaille
                set patternListList [ lsearch -all -inline -regexp $mhList $pattern ]
                if { ![cequal $file ""] } {append patternListList " " ; append patternListList [lsearch -all -inline -regexp $mhList $file]}
                if { ![cequal $ack ""] } {append patternListList " " ; append patternListList [lsearch -all -inline -regexp $mhList $ack]}
                if {$debug} {echo "patternListList : $patternListList" }
                # On parcourt une premiere fois la liste des fichiers r??pondant au pattern
                
                #1er cas, traitement de la liste pour le ftp
                foreach patternListListElement $patternListList {
 
                
                
                    keylget threadconfig PROTOCOL.FTPHOST host
                    keylget threadconfig PROTOCOL.FTPUSER login
                    keylget threadconfig PROTOCOL.FTPPASSWD password
                    keylget threadconfig PROTOCOL.FTPIBDIR directory
                    
                    set cisversion $::env(HCIVERSION)
                    if {$cisversion >= 6.2 } {
                        if {$debug} { echo "password (before decrypt) : $password" }
                        catch {exec hcicrypt decrypt $password} password
                        set password  [::base64::decode $password]
                        if {$debug} { echo "password (after decrypt) : $password" }
                        } else { if {$debug} { echo "password (not crypt at all) : $password" }}
                        
                    if {$debug} {echo "host : $host";    echo "login : $login";    echo "directory : $directory";    echo "cisversion : $cisversion";    echo "patternListListElement: $patternListListElement"; }

                    if { $protocol == "fileset/ftp" } {   
                    set msg {};set rc [ catch {exec curl -I ftp://${login}:${password}@${host}/${directory}/${patternListListElement}} msg]
                    }
                    if { $protocol == "fileset/sftp" } {   
                    set msg {};set rc [ catch {exec curl -I sftp://${login}:${password}@${host}/${directory}/${patternListListElement --insecure}} msg]
                    }
                    if { $protocol == "fileset/ftps" } {   
                    set msg {};set rc [ catch {exec curl -I ftps://${login}:${password}@${host}/${directory}/${patternListListElement --insecure}} msg]
                    }
                    
                    if { $rc == 1 } {
                        if {$debug} { echo "msg : $msg" }
                        set fileSize [string trim [lindex [split [lindex [split $msg \n] 1] :] 1]]
                        
                        echo fileSize : $fileSize
                        if { $fileSize <= $size } {
                            #echo "La taille du fichier \"$patternListListElement\" est de $fileSize Octets (max $size Octets), le fichier sera preleve";
                            lappend sizeList $patternListListElement;
                            
                        } else {
                            #echo "La taille du fichier \"$patternListListElement\" ; $fileSize Octets; est trop importante(max $size Octets), le fichier ne sera pas preleve";
                            #set temp ""; set temp [string map {{.} {.}} $patternListListElement]
                            #echo temp: $temp
                            keylset overSizeList ${patternListListElement} ${fileSize};
                        }
                        
                        
                    }
                }
            }
                if { $protocol == "fileset/local-tps" } {

                    set patternListList $mhList
                    set filtreList "";
                #1er cas, traitement de la liste pour le fileset
                    foreach patternListListElement $patternListList {

                        foreach element $patternListListElement {

                            set fileSize [lindex $element end-1]
                            set filename [lrange $element 0 end-2]
                            if { $fileSize <= $size } {
                                if {$debug} {echo  filename : $filename}
                                lappend sizeList $filename ;
                                #echo "La taille du fichier \"$filename\" est de $fileSize Octets (max $size Octets), le fichier sera preleve";
                            } else {
                                keylset overSizeList ${filename} ${fileSize} ;
                                lappend  filtreList ${filename};                              
                                #echo "La taille du fichier \"$filename\" ; $fileSize Octets; est trop importante(max $size Octets), le fichier ne sera pas preleve";
                            }
                            if {$debug} {echo fileSize for $filename : $fileSize}

                        }

                    }
                    if {$debug} {echo "filtreList : $filtreList";}
                    set tempFiltreList {};
                    set tempFiltreList [lsearch -all -inline -regexp $filtreList $pattern]
                    if { ![cequal $ack ""] } {append tempFiltreList " " ; append tempFiltreList [lsearch -all -inline -regexp $filtreList $ack]}
                    if { ![cequal $file ""] } {append tempFiltreList " " ; append tempFiltreList [lsearch -all -inline -regexp $filtreList $file]}
                    if {$debug} {echo "tempFiltreList : $tempFiltreList";}
                    set tempOverSizeList {};
                    set temp {} ;
                    foreach tempFiltreListElement  $tempFiltreList {
                        set temp [keylget overSizeList $tempFiltreListElement]
                        keylset tempOverSizeList $tempFiltreListElement [ keylget overSizeList $tempFiltreListElement ]
                    }
                    if {$debug} {echo "tempOverSizeList : $tempOverSizeList";}
                    set overSizeList $tempOverSizeList;
                    if {$debug} {echo "overSizeList : $overSizeList;"}
            }
            set temp {};
            foreach overSizeListElement [keylget overSizeList] {
                foreach overSizeListElementElement [keylget overSizeList $overSizeListElement] {
                    lappend temp "Fichier : ${overSizeListElement}.${overSizeListElementElement} Octets"
                }
            }
            set overSizeList $temp
            # Production du fichier d'alerte
            
            #set filename path
            set pathAlerteFile ""; append pathAlerteFile $::env(HCISitedir) \\OversizeAlerteFile.txt
            set content [string range [split [read_file $pathAlerteFile] "\r\n"] 1 end-4]
             if {$debug} {
                echo "pathAlerteFile : $pathAlerteFile;"
                echo "Final overSizeList : $overSizeList;"
                echo "content : $content;"
             }
            
            if {(![cequal $content $overSizeList]) && ($sendMail)} {
                
                #keylkeys siteInfo
                set subject "EAI site $site : Fichiers trop volumineux, non preleves"
                set body "Bonjour,\r\nLe fichier suivant presente une taille trop importante pour ??tre pr??lev?? ( taille max autoris??e : $size Octets).\r\n$overSizeList.\r\nVeuillez v??rifier le fichier."
    
                if {$cisversion >= 6.2 } {
                    if {$debug} { echo "mailpassword (before decrypt) : $mailpassword" }
                    catch {exec hcicrypt decrypt $mailpassword} mailpassword
                    set mailpassword  [::base64::decode $mailpassword]
                    if {$debug} { echo "mailpassword (after decrypt) : $mailpassword" }
                    } else { if {$debug} { echo "mailpassword (not crypt at all) : $mailpassword" }}
                        
                if {$debug} {
                    echo "mailserver : $mailserver" 
                    echo "mailport : $mailport"
                    echo "mailusername : $mailusername"
                    echo "mailpassword : $mailpassword"
                    echo "usetls : $usetls"
                    echo "from : $from"
                    echo "to : $to"
                    echo "subject : $subject"
                    echo "body : $body"
                }
                
                set token [::mime::initialize -canonical text/plain -string "$body"]
                set command [list ::smtp::sendmessage $token\
                -servers $mailserver -ports $mailport -username $mailusername -password $mailpassword -usetls $usetls \
                -header [list From "$from"] -header [list To "$to"] -header [list Subject "$subject"] \
                -header [list Date "[clock format [clock seconds]]"] -debug $debug]
                if {$debug} { echo "command: $command" }
                eval $command
                
                #Modification et fermeture du fichier
            write_file $pathAlerteFile $overSizeList
            }
            #Production de la liste transmise ?? la V3
            set patternList $sizeList
            echo "sizeList : $sizeList" ;         
            echo "overSizeList : ${overSizeList};"
            #Debut de la V3 "classique"
            
            set patternListList {};
            set ackList {};
            set fileList {]};
            set patternListList [lsearch -all -inline -regexp $patternList $pattern]
            
            if { ![cequal $ack ""] } {set ackList [lsearch -all -inline -regexp $patternList $ack]}
            
            if { ![cequal $file ""] } {set fileList [lsearch -all -inline -regexp $patternList $file]}
            
            # On parcourt la liste des fichiers r??pondant au pattern
            foreach patternListElement $patternListList {
                # On initialise les variables
                set ackFilename  ""
                set fileFilename ""

                # On r??cup??re le nom sans l'extension
                set patternFilename [file rootname $patternListElement]
                if {$debug} {echo patternFilename : $patternFilename}

                # On recherche le t??moin associ??
                if { ![cequal $ack ""] } {
                    set ackNamePattern ${patternFilename}${ack}
                    if {$debug} {echo ackNamePattern : $ackNamePattern}
                    set ackFilename [lsearch -inline -regexp $ackList $ackNamePattern]
                    if {$debug} {echo ackFilename : $ackFilename}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $ackFilename ""] } {
                        continue
                    }
                }

                # On recherche le fichier associ??
                if { ![cequal $file ""] } {
                    set fileNamePattern ${patternFilename}${file}
                    if {$debug} {echo fileNamePattern : $fileNamePattern}
                    set fileFilenameList [lsearch -all -inline -regexp $fileList $fileNamePattern]
                    if {$debug} {echo fileFilenameList : $fileFilenameList}

                    # Si il n'est pas trouv??, alors on continue l'it??ration
                    if { [cequal $fileFilenameList ""] } {
                        continue
                    }
                }

                if { (![cequal $ack ""]) && (![cequal $file ""]) } {
                    # Si ACK, FILE et PATTERN sont d??finis
                    lappend matchList $patternListElement
                    if { $excludeFile == 0 } {
                        set matchList [concat $matchList $fileFilenameList]
                    }
                    lappend matchList $ackFilename
                } elseif { (![cequal $ack ""]) } {
                    # Si ACK et PATTERN sont d??finis 
                    lappend matchList $patternListElement
                    lappend matchList $ackFilename
                } elseif { (![cequal $file ""]) } {
                    # Si FILE et PATTERN sont d??finis
                    lappend matchList $patternListElement
                    if { $excludeFile == 0 } {
                        set matchList [concat $matchList $fileFilenameList]
                    }
                } else {
                    # Si seul PATTERN est d??fini
                    lappend matchList $patternListElement
                }
            }
            msgset $mh $matchList
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
