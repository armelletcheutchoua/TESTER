
######################################################################
# Name:        xper_tps_addPDFToUserdataFromFilename_V2
# Purpose:  Ajoute les fichiers PDF dans les userdata
# UPoC type: tps
# Args:     none
# Returns: tps disposition list


proc xper_tps_addPDFToUserdataFromFilename_V2 { args } {
 package require Sitecontrol
    package require base64
    keylget args MODE mode;# Fetch mode
    keylget args ARGS uargs
    global HciSiteDir
    global HciConnName
    set dispList {};# Nothing to return
    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list
    set PDFPattern "^OBX\\|.*\\|(.*?\\.pdf)"                                
    catch {keylget uargs PDF_PATTERN PDFPattern}
    set PDFIsInFile 1                             
    catch {keylget uargs PDF_IN_FILE PDFIsInFile}
    set PDFExtension .pdf                                
    catch {keylget uargs PDF_EXTENSION PDFExtension}

echo "**************** xper_tps_addPDFToUserdataFromFilename_V2**************"
  switch -exact -- $mode {
    start {
      # Perform special init functions
      # N.B.: there may or may not be a MSGID key in args
    }
    run {
        # 'run' mode always has a MSGID; fetch and process it
        keylget args MSGID mh      
        
        # On récupère le dossier d'entrée
        set success 0
        if { [catch {set success [::Sitecontrol::loadNetConfig]} err] || $success == -1} {
            echo "Impossible d'ouvrir le fichier netconfig $err"
            return
        }
        set threadConfig [::Sitecontrol::getThreadData $HciConnName]
        # On récupère le nom de dossier d'entrée
        keylget threadConfig PROTOCOL.IBDIR directory

        set driver [msgmetaget $mh DRIVERCTL]
        set fileName [file tail [keylget driver FILENAME]]
        if { $debug } {            
            echo "Fichier d'entrée : $fileName"
            echo "PDFIsInFile : $PDFIsInFile"
        }

        #Recherche des noms de fichiers
        set pdfList ""
        if {$PDFIsInFile} {
            #On recherche le PDF dans le fichier courant
            set messageContent [msgget $mh]       
      
            foreach line [split $messageContent "\r"] {
                set fileName ""
                regexp -nocase ${PDFPattern} $line wholeMatch fileName
                if { [string length $fileName] > 0 } {
                    set shortFileName [file tail $fileName]
                    lappend pdfList $directory/$shortFileName
                    if { $debug } {
                        echo "PDF trouvé : directory/$shortFileName"
                    }
                }
            }
        } else {
            #On identifie le PDF grâce au nom
            set shortFileName [file rootname $fileName]
            echo "On identifie le PDF grâce au nom : $directory/$shortFileName$PDFExtension"
            
            lappend pdfList $directory/$shortFileName$PDFExtension
        }
        
    
        # On recherche les fichiers PDF associés      
        set fileList ""
        foreach pdfPath $pdfList {
            set fp [open $pdfPath r]
            fconfigure $fp -translation binary
            set inBinData [read $fp]
            close $fp
            set pdfName [file rootname [file tail $pdfPath]]
            if { $debug } {
                echo "Contenu ajouté pour : $pdfName"
            }
            #keylset fileList $pdfName [base64::encode -maxlen 0 $inBinData] 
            keylset fileList PDF64 [base64::encode -maxlen 0 $inBinData]        
            file delete $pdfPath
      }
    
      msgmetaset $mh USERDATA $fileList
     
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
# Name:     PDF_TO_Message
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc PDF_TO_Message { args } {
    package require base64
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "PDF_TO_Message/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0 ; catch {keylget uargs DEBUG debug}
    set base64 1 ; catch {keylget uargs BASE64 base64}
    set key "PDFB64" ; catch {keylget uargs KEY key}
    set dispList {}
    echo "**********PDF_TO_Message*********"
    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh
           
            set metadata [msgmetaget $mh USERDATA]
            
            if { [ catch {keylget metadata $key pdfdata} ] } {
                echo "le pdf avec la clé $key est vide"
                if {$debug} { echo "metadata : $metadata" }
                lappend dispList "KILL $mh"
                return $dispList
            }

            if { $base64 } {
                 set pdfdata [::base64::decode $pdfdata]
                if { $debug } { echo "decode msg : $pdfdata" }
            }
            set pdfmh [ msgcopy $mh ]
            msgset $pdfmh $pdfdata

            set driverctl [msgmetaget $mh DRIVERCTL]
            if { [ catch {keylget driverctl FILENAME filename} ] } {
               keylget driverctl FILESET.OBFILE filename
            }
            set filename [file tail [file rootname $filename]]
            set filename [append filename ".pdf"] ; if { $debug } { echo "pdf filename : $filename" }
            msgmetaset $pdfmh DRIVERCTL "{FILESET {{OBFILE $filename}}}"


            lappend dispList "CONTINUE $mh" "CONTINUE $pdfmh"
            
        }

        time {}
        shutdown {}
        default {
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}
