######################################################################
# Name:      xper_add_pdf_to_userdata_fileset
# Purpose:   Récupère le contenu d'un pdf sur un répertoire local pour le mettre dans les USERDATA
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    Il faut renseigner le répertoire où se trouve le fichier PDF de la façon suivante : 
#                                { URL "<Chemin ver le répertoire qui contien les fichiers PDF>" }                                            
#                               exemple pour répertoire C:/document/threadIN : { URL "C:/document/threadIN" }
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   <date> <name> <comments>
#

proc xper_add_pdf_to_userdata_fileset { args } {
    package require base64
    #package require Sitecontrol
    global HciConnName                             ;# Name of thread
    global HciSiteDir                              ;# Name of site directory

    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
    
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
            
            #echo type_protocol : $protocol
            keylget args MSGID mh
            set messageContent [msgget $mh]
            #----------------------------
            set path [msgmetaget $mh DRIVERCTL]
            #On extrait la localisation/nom du fichier
            foreach line [split $messageContent "\r"] {
            set OBXPattern "^OBX\\|.*\\|(.*?\\.pdf)"
            set fileName ""; regexp -nocase ${OBXPattern} $line wholeMatch fileName
                if { [string length $fileName] > 0 } {
                    set fileName [file tail $fileName]
                    if { $debug } {
                        echo "pdf name: $fileName"
                    }
            #Récupératon du chemin du fichier PDF                        
            set URL [keylget uargs URL]
            echo $URL
            #Chercher le fichier PDF associé        
                
            set data_pdf "";
            set pdf_B64 "";
            set PDFassociated "$URL/$fileName"
            #echo PDFASSO : $PDFassociated
            set fsize [file size $PDFassociated]
            #echo fsize : $fsize
            set cont_fic [open $PDFassociated r]
            fconfigure $cont_fic -encoding binary -translation binary 
            append data_pdf [read $cont_fic $fsize] 
            close $cont_fic
            if { $debug } {echo data_pdf : $data_pdf}
            append pdf_B64 [::base64::encode -maxlen 0 $data_pdf]
            if { $debug } {echo pdf_B64 : $pdf_B64}
            keylset userdata PDF $pdf_B64
            msgmetaset $mh USERDATA $userdata 
            #Suppression du fichier PDF
            #file delete $PDFassociated
            #Libération des ressources
            
               
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
