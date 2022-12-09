#
# Wishlist :
# Détecter les erreurs de connexion : actuellement même si la connexion echoue le retour de la condition est positif
# Isoler les erreurs de connexions et les écrire dans le rapport CSV
# Mettre au propre le retour à l'écran (echos)
# Appeler cettre procédure depuis un bat
# Mettre la condition >=CIS62 pour le décryptage du mot de passe.
#

######################################################################
# Name:      xper_check_ftp
# Purpose:   Procédure vérifiant les connexions FTP d'un site et écrivant un rapport CSV
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

proc xper_check_ftp { args } {
    #global HciConnName                             ;# Name of thread
    #global IBDir                                   ;# Inbound directory
    package require base64
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    #set module "xper_report_config/$HciConnName/$ctx" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    #set dispList {}                                ;# Nothing to return



            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            
            if { $debug } {
                puts stdout "$module: Starting in debug mode..."
            }

            netconfig load
            # Chargement des process
            set processes [netconfig get process list]
            #echo $processes
            set CSV "Process;Thread;Protocole;Serveur;Repertoire;Etat;Erreur"
            foreach process $processes {
                echo "Process : $process"
                set threads [netconfig get process connections $process]
                #echo $threads
                foreach thread $threads {
                    echo "    Thread : $thread"
                    set destList ""
                    set server ""
                    set directory ""
                    set etat ""
                    set erreur ""
                    set threadconfig [netconfig get connection data $thread]
                    keylget threadconfig PROTOCOL.TYPE protocol
                    if { [cequal $protocol fileset] && [keylget threadconfig PROTOCOL.MODE protoSubType] } { 
                        append protocol "/$protoSubType" 
                    }
                    echo "        Protocole : $protocol"
                    switch $protocol {
                        "fileset/ftp" - "fileset-sftp" - "fileset-ftps" {
                            keylget threadconfig PROTOCOL.FTPHOST host
                            keylget threadconfig PROTOCOL.FTPUSER login
                            keylget threadconfig PROTOCOL.FTPPASSWD password
                            keylget threadconfig PROTOCOL.FTPIBDIR directory
                            if { [cequal $directory ""] } {
                                keylget threadconfig PROTOCOL.FTPOBDIR directory
                            } 
                            # specificite 6.2
                            catch {exec hcicrypt decrypt $password} password
                            set password  [::base64::decode $password]
                            set server ftp://${login}:${password}@${host}
                            echo "        Adresse : $server"
                            echo "        Test de la connexion :"
                            set msg "";
                            if { [ catch {exec curl -v ftp://$login:$password@$host/$directory/ } msg]} {
                                echo "        La connexion fonctionne"
                                echo $msg
                                set etat "OK"
                            } else {
                                echo "        La connexion ne fonctionne pas"
                                echo $msg
                                set etat "KO"
                                set erreur $msg
                            }
                            append CSV "\r${process};${thread};${protocol};${server};${directory};${etat};${erreur}"
                        }
                    }
                }
            }
            #echo $CSV
            set filename rapport[clock format [clock seconds] -format %Y%m%d].csv
            # open the filename for writing
            set fileId [open $filename "w"]
            # send the data to the file -
            #  omitting '-nonewline' will result in an extra newline
            # at the end of the file
            puts -nonewline $fileId $CSV
            # close the file, ensuring the data is written out before you continue
            #  with processing.
            close $fileId
            #set msg [msgcreate -type data -recover $CSV]
            #lappend dispList "PROTO $msg"
}
