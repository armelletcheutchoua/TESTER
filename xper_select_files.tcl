
# Evolution souhaitées : 
# Ajout du mode Multi permettant de récupérer plusieurs pièces jointes (-all)
# Echapper les caractères spéciaux des noms des fichiers
# Rendre des éléments facultatifs


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
#           20190412 TLZ - v6 - Correction critique sur le prélèvement des fichiers
#           20190903 TLZ - v9 - Suppression de la dépendance xper_replaceChars
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
                    if {$debug} { echo Aucun résultat pour l'argument $nocase$arg ne se trouve dans le répertoire }
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