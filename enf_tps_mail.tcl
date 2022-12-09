######################################################################
# Name:      enf_tps_send_pivot_mail
# Purpose:   <description>
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    HOST : IP/NOM du serveur SMTP (par defaut localhost)
#                    PORT : PORT du serveur SMTP (par defaut 25)
#                    LOGIN : Compte SMTP
#                    PASSWORD : MdP SMTP
#                    EXT : Extension des fichiers sans nom (par defaut txt). Ne pas mettre le "."
#                    DELETE : Suppression des PJ (par defaut 0). Valeur possible : 0 / 1
#                    USETLS : Utilisation du TLS (par defaut 0). Valeur possible : 0 / 1
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   16/02/2016 - PFK : Version initiale
#                 

proc enf_tps_send_pivot_mail { args } {
    global HciConnName                             ;# Name of thread
    package require smtp
    package require base64
    package require mime    
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
    
    set host localhost  ; catch {keylget uargs HOST host} ;
    set port 25  ; catch {keylget uargs PORT port} ;
    set login ""  ; catch {keylget uargs LOGIN login} ;
    set password ""  ; catch {keylget uargs PASSWORD password} ;
    set ext txt  ; catch {keylget uargs EXT ext} ;
    set delete 0  ; catch {keylget uargs DELETE delete} ;
    set usetls 0  ; catch {keylget uargs USETLS usetls} ;

    set module "enf_tps_send_pivot_mail/$HciConnName/$ctx" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return
    set datList [datlist]

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
            #REMOVE THIS LINE !!!
            keylget args MSGID mh
            set package "Mail"
            set ocmfile "pivot_mail"
            set from from
            set to to
            set subject subject
            set body body

            if { [catch { set gh [grmcreate -msg $mh -warn warn xml $package $ocmfile] } err] } {
                #libere les ressources
                hcidatlistreset $datList
                #grmdestroy $gh
            } else {
                #recupere le mail de l_expediteur
                set dh_from [grmfetch $gh pivot_mail.emetteur.mail.#text]    
                set from [datget $dh_from VALUE]

                #iteration sur les destinataires
                set nbIterTO [regexp -all -- "<destinataire>" [msgget $mh]]

                #recupere le mail du destinataire
                set dh_to [grmfetch $gh pivot_mail.destinataires.destinataire(0).mail.#text]    
                set to [datget $dh_to VALUE]
                if { $nbIterTO > 1 } {
                    set h 1
                    while { $h < $nbIterTO } {
                        #recupere le mail du destinataire
                        set dh_to [grmfetch $gh pivot_mail.destinataires.destinataire($h).mail.#text]    
                        append to ","
                        append to [datget $dh_to VALUE]
                        incr h
                    }
                }
                
                #recupere l_objet
                set dh_subject [grmfetch $gh pivot_mail.objet.#text]    
                set subject [datget $dh_subject VALUE]

                #recupere le corps
                set dh_body [grmfetch $gh pivot_mail.corps.#text]    
                set body [datget $dh_body VALUE]
                
                #iteration sur les PJ
                set nbIterPJ [regexp -all -- "<attachment>" [msgget $mh]]
                
                #creation du mail
                set parts [mime::initialize -canonical text/plain -string $body]

                if { $nbIterPJ > 0 } {
                    set i 0
                    while { $i < $nbIterPJ } {
                        #recupere le contenu de la PJ en b64
                        set dh_attachmentContent [grmfetch $gh pivot_mail.attachments.attachment($i).content.#text]    
                        set attachmentsContent($i) [datget $dh_attachmentContent VALUE]
                        if { [string length $attachmentsContent($i)] > 0 } {
                            #recupere le nom de la PJ
                            set dh_attachment [grmfetch $gh pivot_mail.attachments.attachment($i).name.#text]
                            #ecrire le contenu dans un fichier local
                            set fullFilename [datget $dh_attachment VALUE]
                            #verifier la presence du fichier
                            if { ![file exists $fullFilename] } {
                                set filename [file tail $fullFilename]
                                if { [string length $filename] < 1} {
                                    set filename document_[expr $i +1 ].$ext
                                }
                                set attachmentContent [string map { "{" "" "}" "" } [::base64::decode $attachmentsContent($i)]]
                                if {$debug} {echo attachmentContent : $attachmentContent}
                                write_file $filename $attachmentContent
                                set attachments($i) $filename
                                lappend parts [mime::initialize -canonical "application/octet-stream; name=\"[file tail $filename]\"" -header {Content-Disposition attachment} -file $filename]

                            } else {
                                #recupere le nom de la PJ
                                set attachments($i) $fullFilename
                                lappend parts [mime::initialize -canonical "application/octet-stream; name=\"[file tail $fullFilename]\"" -header {Content-Disposition attachment} -file $fullFilename]
                            }
                        } else {
                            #recupere le nom de la PJ
                            set dh_attachment [grmfetch $gh pivot_mail.attachments.attachment($i).name.#text]    
                            set fullFilename [datget $dh_attachment VALUE]
                            set attachments($i) $fullFilename
                            lappend parts [mime::initialize -canonical "application/octet-stream; name=\"[file tail $fullFilename]\"" -header {Content-Disposition attachment} -file $fullFilename]
                        }
                        incr i
                    }
                }
                #envoi des mails
                # set parts [mime::initialize -canonical text/plain -string $body]
                # lappend parts [mime::initialize -canonical "application/pdf; name=\"[file tail $pdfname]\"" -encoding base64\
                        # -header {Content-Disposition attachment} -file $pdfname]
                set token [::mime::initialize -canonical multipart/mixed -parts $parts]
                set command [list ::smtp::sendmessage $token \
                        -servers $host -ports $port -username $login -password $password -usetls $usetls \
                        -header [list From "$from"] -header [list To "$to"] -header [list Subject "$subject"] \
                        -header [list Date "[clock format [clock seconds]]"] \
                        -debug $debug]
                if {[catch {eval $command} err]} {
                        error "Error when sending mail: $err"
                }
                catch {::mime::finalize $token -subordinates all
                    #suppression des PJ
                    if { $delete } {
                        set j 0
                        while { $j < $nbIterPJ } {
                            if { [file exists $attachments($j)] } {
                                file delete $attachments($j)
                            }
                            incr j
                        }
                    }
                }

                #libere les ressources
                hcidatlistreset $datList
                grmdestroy $gh
                
                
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
# Name:      enf_tps_sendMail
# Purpose:   Procédure d'envoi de mail basé sur les arguments uniquement
#              %date% est remplacé par la date
#              %filename% est remplacé par le nom du fichier
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#               {DEBUG 0|1} (optional, default = 0)
#               {TO toEmail} (optional, default = "support@xperis.fr",
#                            info = adresse de destination)
#                {SUBJECT subject} (optional, default = "Subject")
#                {FROM fromEmail} (optional, default = "cloverleaf@xperis.fr")
#                {BODY body} (optional, default = "body")
#                {LOGIN SMTPLogin} (optional, default = "")
#                {PASSWORD SMTPPassword} (optional, default = "")
#                {SERVER SMTPHost} (optional, default = "localhost")
#                {PORT SMTPPort} (optional, default = 25)
#                {USETLS 0} Utilisation du TLS (par defaut 0). Valeur possible : 0 / 1
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   14/11/2016 AGS : Procedure d'envoi de mail
#                 

proc enf_tps_sendMail { args } {
    package require smtp
    package require mime    

    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set to "support@xperis.fr"  ; keylget uargs TO to
    set subj "Subject"  ; keylget uargs SUBJECT subj
    set body "body"  ; catch {keylget uargs BODY body}
    set from "cloverleaf@xperis.fr"  ; catch {keylget uargs FROM from}
    set login ""  ; catch {keylget uargs LOGIN login}
    set pass ""  ; catch {keylget uargs PASSWORD pass}
    set server "localhost"  ; catch {keylget uargs SERVER server}
    set port 25  ; catch {keylget uargs PORT port}
    set usetls 0  ; catch {keylget uargs USETLS usetls}
    
    set debug 0  ; catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "enf_tps_sendMail/$HciConnName/$ctx" ;# Use this before every echo/puts,
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

            set date [clock format [clock seconds] -format "%d/%m/%Y à %H:%M:%S"]
            set filename ""; catch {set filename [msgmetaget $mh DRIVERCTL.FILENAME]}

            regsub -all %date% $body $date body
            regsub -all %filename% $body $filename body
           
            if {[cequal $body "body"]} {
                set body [string map {"\r\n" "<br/>"} [msgget $mh]]
            }
            
            set parts [mime::initialize -canonical text/html -string $body]
            set token [::mime::initialize -canonical multipart/mixed -parts $parts]

            set command [list ::smtp::sendmessage $token\
                        -servers $server -ports $port -username $login -password $pass -usetls $usetls \
                        -header [list From "$from"] -header [list To "$to"] -header [list Subject "$subj"]\
                        -header [list Date "[clock format [clock seconds]]"] \
                        -debug $debug]
            if {[catch {eval $command} err]} {
                    error "Error when sending mail: $err"
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
