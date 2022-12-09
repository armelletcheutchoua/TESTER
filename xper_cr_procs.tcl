######################################################################
# Name:      xper_add_pdf_to_message_from_filename
# Purpose:   Récupère le contenu d'un pdf sur un FTP pour le mettre dans les USERDATA
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    <describe user-supplied args here>
#            DEBUG 0|1 (optional, default = 0)
#            
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   <date> <name> <comments>
#

proc xper_add_pdf_to_message_from_filename { args } {
    package require base64
    package require Sitecontrol    
    global HciConnName                             ;# Name of thread

    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
    
    set module "xper_add_pdf_to_message_from_filename/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
            
            set driverCTL [msgmetaget $mh DRIVERCTL]
            set filename [file rootname [keylget driverCTL FILENAME]]

            if { [catch {set success [::Sitecontrol::loadNetConfig]} err] || $success == -1} {
                echo "Impossible d'ouvrir le fichier netconfig $err"
                return
            }
            set threadconfig [::Sitecontrol::getThreadData $HciConnName]
            set directory [keylget threadconfig PROTOCOL.IBDIR]

            set pdfPath $directory/$filename.pdf

            set fh [open $pdfPath r]
            fconfigure $fh -translation binary 
            set data_pdf [read $fh] 
            close $fh

            set userdata [msgmetaget $mh USERDATA]
            keylset userdata PDF [::base64::encode -maxlen 0 $data_pdf]
            msgmetaset $mh USERDATA $userdata

            file delete $pdfPath
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
# Name:      xper_add_pdf_to_message
# Purpose:   Récupère le contenu d'un pdf sur un FTP pour le mettre dans les USERDATA
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    <describe user-supplied args here>
#            DEBUG 0|1 (optional, default = 0)
#            FTPHost Hôte du serveur FTP
#            FTPLogin Login du compte FTP
#            FTPPassword Password du compte FTP
#            FTPDirectory Répertoire du FTP pour récupérer le fichier
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   <date> <name> <comments>
#

proc xper_add_pdf_to_message { args } {
    package require ftp
    package require ftp::geturl
    package require base64
    package require smtp
    package require mime
    global HciConnName                             ;# Name of thread

    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
    set FTPHost ""   ; keylget uargs FTPHOST FTPHost
    set FTPLogin ""   ; keylget uargs FTPUSER FTPLogin
    set FTPPassword ""   ; keylget uargs FTPPASSWD FTPPassword
    set FTPDirectory ""   ; keylget uargs FTPIBDIR FTPDirectory
    set SMTPTo ""  ; keylget uargs SMTPTO SMTPTo
    set SMTPFrom ""  ; keylget uargs SMTPFROM SMTPFrom
    set SMTPLogin ""  ; keylget uargs SMTPLOGIN SMTPLogin
    set SMTPPassword ""  ; keylget uargs SMTPPASSWORD SMTPPassword
    set SMTPServer ""  ; keylget uargs SMTPSERVER SMTPServer
    set SMTPPort 25  ; keylget uargs SMTPPORT SMTPPort
    set SMTPUsetls 0  ; catch {keylget uargs SMTPUSETLS SMTPUsetls} ;

    set module "xper_add_pdf_to_message/$HciConnName/$ctx" ;# Use this before every echo/puts,
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

            set messageContent [msgget $mh]
            set userdata [msgmetaget $mh USERDATA]
            set sourceconn [msgmetaget $mh SOURCECONN]

            #Recherche des noms de fichiers
            set fileNameList {}
            foreach line [split $messageContent "\r"] {
                set OBXPattern "^OBX\\|.*\\|(.*?\\.pdf)"
                set fileName ""; regexp -nocase ${OBXPattern} $line wholeMatch fileName
                if { [string length $fileName] > 0 } {
                    lappend fileNameList [file tail $fileName]
                    if { $debug } {
                        echo "pdf trouvé : $fileName"
                    }
                }
            }
            #Init FTP connection
            set handle [::ftp::Open $FTPHost $FTPLogin $FTPPassword]
            ::ftp::Type $handle binary
            ::ftp::Cd $handle $FTPDirectory
            
            #Récupération des PDF
            set hasError 0            
            foreach fileName  $fileNameList {
               echo ftp://$FTPLogin:$FTPPassword@$FTPHost/$FTPDirectory/$fileName
               if {[catch {::ftp::geturl ftp://$FTPLogin:$FTPPassword@$FTPHost/$FTPDirectory/$fileName} msgFile]} {
                    set hasError 1
                    break      
                }
                set pdfContent [::base64::encode -maxlen 0 $msgFile]
                set rootname [file rootname $fileName]
                keylset userdata $rootname $pdfContent
            }

            if { !$hasError } {
                #Suppression des PDF
                foreach fileName  $fileNameList {
                    set hasDeletedFile [::ftp::Delete $handle $fileName]
                    if { !$hasDeletedFile && $debug } {
                        echo "ERROR: FAILED TO DELETE FILE: $fileName"
                    } else {
                        if { $debug } {
                            echo "Delete file, $fileName with success"
                        }
                    }
                }  
            }          
            
            #Close FTP connection
            ::ftp::Close $handle
            msgmetaset $mh USERDATA $userdata

            if { !$hasError } {
                lappend dispList "CONTINUE $mh"
            } else {
                set parts [mime::initialize -canonical text/html -string $messageContent]
                set token [::mime::initialize -canonical multipart/mixed -parts $parts]

                set command [list ::smtp::sendmessage $token\
                            -servers $SMTPServer -ports $SMTPPort -username $SMTPLogin -password $SMTPPassword -usetls $SMTPUsetls \
                            -header [list From "$SMTPFrom"] -header [list To "$SMTPTo"] -header [list Subject "Erreur recuperation PDF thread $sourceconn"]\
                            -header [list Date "[clock format [clock seconds]]"]]
                if {[catch {eval $command} err]} {
                        error "Error when sending mail: $err"
                }
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
# Name:      xper_add_pdf_to_message_V2
# Purpose:   Récupère le contenu d'un pdf sur un FTP pour le mettre dans les USERDATA
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    <describe user-supplied args here>
#            DEBUG 0|1 (optional, default = 0)
#            FTPHost Hôte du serveur FTP
#            FTPLogin Login du compte FTP
#            FTPPassword Password du compte FTP
#            FTPDirectory Répertoire du FTP pour récupérer le fichier
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   <date> <name> <comments>
#               20200629 IHB no use curl instead of local tcl library ftp::
#

proc xper_add_pdf_to_message_v2 { args } {
    package require ftp
    package require ftp::geturl
    package require base64
    package require smtp
    package require mime
    global HciConnName                             ;# Name of thread

    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
    set FTPHost ""   ; keylget uargs FTPHOST FTPHost
    set FTPLogin ""   ; keylget uargs FTPUSER FTPLogin
    set FTPPassword ""   ; keylget uargs FTPPASSWD FTPPassword
    set FTPDirectory ""   ; keylget uargs FTPIBDIR FTPDirectory
    set SMTPTo ""  ; keylget uargs SMTPTO SMTPTo
    set SMTPFrom ""  ; keylget uargs SMTPFROM SMTPFrom
    set SMTPLogin ""  ; keylget uargs SMTPLOGIN SMTPLogin
    set SMTPPassword ""  ; keylget uargs SMTPPASSWORD SMTPPassword
    set SMTPServer ""  ; keylget uargs SMTPSERVER SMTPServer
    set SMTPPort 25  ; keylget uargs SMTPPORT SMTPPort
    set SMTPUsetls 0  ; catch {keylget uargs SMTPUSETLS SMTPUsetls} ;

    set module "xper_add_pdf_to_message/$HciConnName/$ctx" ;# Use this before every echo/puts,
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

            set messageContent [msgget $mh]
            set userdata [msgmetaget $mh USERDATA]
            set sourceconn [msgmetaget $mh SOURCECONN]

            #Recherche des noms de fichiers
            set fileNameList {}
            foreach line [split $messageContent "\r"] {
                set OBXPattern "^OBX\\|.*\\|(.*?\\.pdf)"
                set fileName ""; regexp -nocase ${OBXPattern} $line wholeMatch fileName
                if { [string length $fileName] > 0 } {
                    lappend fileNameList [file tail $fileName]
                    if { $debug } {
                        echo "pdf trouvé : $fileName"
                    }
                }
            }
            #Init FTP connection
            set handle [::ftp::Open $FTPHost $FTPLogin $FTPPassword]
            ::ftp::Type $handle binary
            ::ftp::Cd $handle $FTPDirectory
            
            #Récupération des PDF
            set hasError 0            
            foreach fileName  $fileNameList {
               echo ftp://$FTPLogin:$FTPPassword@$FTPHost/$FTPDirectory/$fileName
               if {[catch {exec bash -c "curl -u $FTPLogin:$FTPPassword ftp://$FTPHost/$FTPDirectory/$fileName -ss"} msgFile]} {
                    set hasError 1
                    break      
                }
                set pdfContent [::base64::encode -maxlen 0 $msgFile]
                set rootname [file rootname $fileName]
                keylset userdata $rootname $pdfContent
            }

            if { !$hasError } {
                #Suppression des PDF
                foreach fileName  $fileNameList {
                    set hasDeletedFile [::ftp::Delete $handle $fileName]
                    if { !$hasDeletedFile && $debug } {
                        echo "ERROR: FAILED TO DELETE FILE: $fileName"
                    } else {
                        if { $debug } {
                            echo "Delete file, $fileName with success"
                        }
                    }
                }  
            }          
            
            #Close FTP connection
            ::ftp::Close $handle
            msgmetaset $mh USERDATA $userdata

            if { !$hasError } {
                lappend dispList "CONTINUE $mh"
            } else {
                set parts [mime::initialize -canonical text/html -string $messageContent]
                set token [::mime::initialize -canonical multipart/mixed -parts $parts]

                set command [list ::smtp::sendmessage $token\
                            -servers $SMTPServer -ports $SMTPPort -username $SMTPLogin -password $SMTPPassword -usetls $SMTPUsetls \
                            -header [list From "$SMTPFrom"] -header [list To "$SMTPTo"] -header [list Subject "Erreur recuperation PDF thread $sourceconn"]\
                            -header [list Date "[clock format [clock seconds]]"]]
                if {[catch {eval $command} err]} {
                        error "Error when sending mail: $err"
                }
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
# Name:      xper_add_pdf_to_message_v2bis
# Purpose:   Récupère le contenu d'un pdf sur un FTP pour le mettre dans les USERDATA
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    <describe user-supplied args here>
#            DEBUG 0|1 (optional, default = 0)
#            FTPHost Hôte du serveur FTP
#            FTPLogin Login du compte FTP
#            FTPPassword Password du compte FTP
#            FTPDirectory Répertoire du FTP pour récupérer le fichier
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   <date> <name> <comments>
#

proc xper_add_pdf_to_message_v2bis { args } {
    package require ftp::geturl
    package require base64
    package require smtp
    package require mime
    global HciConnName                             ;# Name of thread

    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 1  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
    set FTPHost ""   ; keylget uargs FTPHOST FTPHost
    set FTPLogin ""   ; keylget uargs FTPUSER FTPLogin
    set FTPPassword ""   ; keylget uargs FTPPASSWD FTPPassword
    set FTPDirectory ""   ; keylget uargs FTPIBDIR FTPDirectory
    set SMTPTo ""  ; keylget uargs SMTPTO SMTPTo
    set SMTPFrom ""  ; keylget uargs SMTPFROM SMTPFrom
    set SMTPLogin ""  ; keylget uargs SMTPLOGIN SMTPLogin
    set SMTPPassword ""  ; keylget uargs SMTPPASSWORD SMTPPassword
    set SMTPServer ""  ; keylget uargs SMTPSERVER SMTPServer
    set SMTPPort 25  ; keylget uargs SMTPPORT SMTPPort
    set SMTPUsetls 0  ; catch {keylget uargs SMTPUSETLS SMTPUsetls} ;

    set module "xper_add_pdf_to_message/$HciConnName/$ctx" ;# Use this before every echo/puts,
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

            set messageContent [msgget $mh]
            set userdata [msgmetaget $mh USERDATA]
            set sourceconn [msgmetaget $mh SOURCECONN]

            #Recherche des noms de fichiers
            set fileNameList {}
            foreach line [split $messageContent "\r"] {
                set OBXPattern "^OBX\\|.*\\|(.*?\\.pdf)"
                set fileName ""; regexp -nocase ${OBXPattern} $line wholeMatch fileName
                if { [string length $fileName] > 0 } {
                    lappend fileNameList [file tail $fileName]
                    if { $debug } {
                        echo "pdf trouvé : $fileName"
                    }
                }
            }
            #Init FTP connection
            set handle [::ftp::Open $FTPHost $FTPLogin $FTPPassword]
            ::ftp::Type $handle binary
            ::ftp::Cd $handle $FTPDirectory
            
            #Récupération des PDF
            set hasError 0            
            foreach fileName  $fileNameList {
               # ajout EB ligne echo le 04/03/2020
               echo fileName $fileName
               echo ftp://$FTPLogin:$FTPPassword@$FTPHost/$FTPDirectory/$fileName
               
               if {[catch { ::ftp::Get $handle $fileName -variable msgFile} errMsg]} {
                    set hasError 1
                    break      
                }
                #if { $debug } {
                #    echo "errMsg : $errMsg"
                #    echo "msgFile : $msgFile  "
                #}

                                
                #if {[catch { ::ftp::geturl ftp://$FTPLogin:$FTPPassword@$FTPHost/$FTPDirectory/$fileName} msgFile]} {
                #    set hasError 1
                #    echo Erreur:$msgFile
                #    break      
                #}
                set pdfContent [::base64::encode -maxlen 0 $msgFile]
                set rootname [file rootname $fileName]
                keylset userdata $rootname $pdfContent
            }

            if { !$hasError } {
                #Suppression des PDF
                foreach fileName  $fileNameList {
                    set hasDeletedFile [::ftp::Delete $handle $fileName]
                    if { !$hasDeletedFile && $debug } {
                        echo "ERROR: FAILED TO DELETE FILE: $fileName"
                    } else {
                        if { $debug } {
                            echo "Delete file, $fileName with success"
                        }
                    }
                }  
            }          
            
            #Close FTP connection
            ::ftp::Close $handle
            msgmetaset $mh USERDATA $userdata

            if { !$hasError } {
                lappend dispList "CONTINUE $mh"
            } else {
                set parts [mime::initialize -canonical text/html -string $messageContent]
                set token [::mime::initialize -canonical multipart/mixed -parts $parts]

                set command [list ::smtp::sendmessage $token\
                            -servers $SMTPServer -ports $SMTPPort -username $SMTPLogin -password $SMTPPassword -usetls $SMTPUsetls \
                            -header [list From "$SMTPFrom"] -header [list To "$SMTPTo"] -header [list Subject "Erreur recuperation PDF thread $sourceconn"]\
                            -header [list Date "[clock format [clock seconds]]"]]
                if {[catch {eval $command} err]} {
                        error "Error when sending mail: $err"
                }
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
# Name:        xper_cut_data_to_list
# Purpose:     <description>
# UPoC type:   xltp
# Args:        none
# Notes:       All data is presented through special variables.  The initial
#              upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#

proc xper_cut_data_to_list {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName 
          
    set inputData [lindex $xlateInVals 0]
    set maxLength [lindex $xlateInVals 1]

    set list ""
    while { [string length $inputData] > $maxLength } {
        set temp [crange $inputData 0 [ expr $maxLength - 1]]
        set inputData [crange $inputData $maxLength end]
        lappend list $temp
    }
    lappend list $inputData

    set xlateOutVals \{$list\}    

}

######################################################################
# Name:        xper_tps_writeMsgFromUserdata
# Purpose:  Récupère la réponse PDQ pour l'intégrer au message HPRIM d'origine
# UPoC type: tps
# Args:     none
# Returns: tps disposition list

proc xper_tps_writeMsgFromUserdata { args } {
    package require base64
    global HciSiteDir
    global HciConnName
    set dispList {}             ;# Nothing to return

    keylget args MODE mode
    keylget args CONTEXT ctx
    keylget args ARGS uargs

    set debug 0     ; keylget uargs DEBUG debug
    set temoin 0     ; keylget uargs TEMOIN temoin

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
      
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set userdata [msgmetaget $mh USERDATA]

            foreach fileName [keylkeys userdata] {
                set value [keylget userdata $fileName]
                set value [::base64::decode $value]
                echo fileName$fileName
                #echo value$value

                #set messageContent [keylget userdata CONTENT]
                #set fileName [keylget userdata FILENAME]
                set newMessage [msgcreate -recover -type data $value]
                set newMessageDriverCtl "{FILESET {{OBFILE {$fileName.pdf}}}}"
                msgmetaset $newMessage DRIVERCTL $newMessageDriverCtl
                lappend dispList "CONTINUE $newMessage"
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
# Name:        xper_tps_setFilenameFromMAILHNET
# Purpose:  On place le filename de sortie à partir des USERDATA
# UPoC type: tps
# Args:     none
# Returns: tps disposition list

proc xper_tps_setFilenameFromMAILHNET { args } {
    
    global HciSiteDir
    global HciConnName
    set dispList {}             ;# Nothing to return

    keylget args MODE mode
    keylget args CONTEXT ctx
    keylget args ARGS uargs

    set debug 0     ; keylget uargs DEBUG debug
    set pattern 0     ; keylget uargs PATTERN pattern

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
      
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set userdata [msgmetaget $mh USERDATA]
            set fileName [keylget userdata MAIL_FILENAME]

            set mailSubject [keylget userdata MAIL_SUBJECT]
            set mailSubject [string map {/ _ \\ _ " " _ + _ $ _ * _ . _ ' _ : _ ( _ ) _ # _ & _} $mailSubject]
            set extension [file extension $fileName]
            set fileName $mailSubject$extension
              
            set newMessageDriverCtl "{FILESET {{OBFILE {$fileName}}}}"
            msgmetaset $mh DRIVERCTL $newMessageDriverCtl
               
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
# Name:        xper_tps_setFilenameFromZIPName
# Purpose:  On place le filename de sortie à partir des USERDATA
# UPoC type: tps
# Args:     none
# Returns: tps disposition list

proc xper_tps_setFilenameFromZIPName { args } {
    
    global HciSiteDir
    global HciConnName
    set dispList {}             ;# Nothing to return

    keylget args MODE mode
    keylget args CONTEXT ctx
    keylget args ARGS uargs

    set debug 0     ; keylget uargs DEBUG debug
    set pattern 0     ; keylget uargs PATTERN pattern

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
      
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set userdata [msgmetaget $mh USERDATA]
            set driverCTL [msgmetaget $mh DRIVERCTL]
            set fileName [file rootname [keylget userdata ZIP_NAME]]
            set currentExtension [file extension [keylget driverCTL FILENAME]]
            append fileName $currentExtension

                         
            set newMessageDriverCtl "{FILENAME $fileName}"
            msgmetaset $mh DRIVERCTL $newMessageDriverCtl
               
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
# Name:        xper_tps_filenameFilter
# Purpose:  On filtre le message en fonction de son nom defini par un pattern. L'argument suppress permet de faire un filtre negatif ou positif
# UPoC type: tps
# Args:     none
# Returns: tps disposition list

proc xper_tps_filenameFilter { args } {
    
    global HciSiteDir
    global HciConnName
    set dispList {}             ;# Nothing to return

    keylget args MODE mode
    keylget args CONTEXT ctx
    keylget args ARGS uargs

    set debug 0     ; keylget uargs DEBUG debug
    set suppress 0       ; keylget uargs SUPPRESS suppress
    set pattern 0       ; keylget uargs PATTERN pattern

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {           
      
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set driverCTL [msgmetaget $mh DRIVERCTL]
            set fileName ""
            if {![keylget driverCTL FILENAME fileName]} {
                set fileName [keylget driverCTL FILESET.OBFILE]
            }

            if {$debug} {
                echo "Nom de fichier : $fileName"
            }

            set patternMatch 0
            if {[regexp $pattern $fileName]} {
                set patternMatch 1
            }

            if {$debug} {
                echo "On cherche $pattern : $patternMatch"
            }

            if {($patternMatch && $suppress || (!$patternMatch && !$suppress))} {
                lappend dispList "KILL $mh" 
                if {$debug} {
                    echo "On supprime"
                }
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
# Name:     xper_cda_to_envelop
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc xper_cda_to_envelop { args } {
    package require base64
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_cda_to_envelop/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0 ; catch {keylget uargs DEBUG debug}
    catch {keylget uargs DEBUG debug}
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh
            set msg [msgget $mh]
            set userdata [msgmetaget $mh USERDATA]
            set isAutoCDAR23 0;catch {keylget userdata AUTO_CDAR2_3 isAutoCDAR23}

            if { $isAutoCDAR23 } {
                #On charge le contenu du message à l'aide du CDA contenu dans les userdata
                #set cdaContent [encoding convertfrom utf-8 [binary decode base64 [keylget userdata CDAB64] ]]
                set msg [encoding convertto utf-8 [msgget $mh]]
                set cdaContent  [binary decode base64 [keylget userdata CDAB64] ]
                set result [regexp {(.*)<ClinicalDocument.*</ClinicalDocument>(.*)} $cdaContent match begin end]                
                
                if {$result} {
                    set new_msg $begin
                    append new_msg $msg
                    append new_msg $end
                
                    #set msg [regsub {(<ClinicalDocument.*</ClinicalDocument>)} $cdaContent $msg]
                    if { $debug } {
                        echo "message après injection du stylesheet : $new_msg"
                    }
                }
                
                set cdab64 [::base64::encode -wrapchar "" $new_msg]
            } else {
                set cdab64 [::base64::encode -wrapchar "" [encoding convertto utf-8 $msg]]
            }
            
            keylset userdata CDAB64 $cdab64
            msgmetaset $mh USERDATA $userdata
            #msgset $mh $msg

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

######################################################################
# Name:     xper_keep_cda_only
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc xper_keep_cda_only { args } {
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_keep_cda_only/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0
    catch {keylget uargs DEBUG debug}
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh
            set msg [msgget $mh]

            set isAutoCDAR23 [regexp {<\?xml-stylesheet} $msg returnAutoCDAR23]            
            set userdata [msgmetaget $mh USERDATA]
            keylset userdata AUTO_CDAR2_3 $isAutoCDAR23
            msgmetaset $mh USERDATA $userdata
            set result [regexp {(<c:ClinicalDocument.*</c:ClinicalDocument>)} $msg returnStr]            

            if {$result} {
                set returnStr [string map {<c: < </c: </} $returnStr]
                set returnStr [string map {\"c: \"} $returnStr]
                set returnStr [string map {<lab: < </lab: </} $returnStr]
            } else {
                regexp {(<ClinicalDocument.*</ClinicalDocument>)} $msg returnStr
            }
            msgset $mh $returnStr
            
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


