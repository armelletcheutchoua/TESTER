######################################################################
# Name:     xper_tps_getConfidentialite_Softway
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc xper_tps_getConfidentialite_Softway { args } {
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_tps_getConfidentialite_Softway/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0
    catch {keylget uargs DEBUG debug}
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
           
            keylget args MSGID mh      
            set datList [datlist]
              
            set fileDest ""
            set driver [msgmetaget $mh DRIVERCTL]
            
            set filePath [keylget driver FILENAME]
            echo "filePath $filePath"
            set fileName [file rootname $filePath]
            echo "fileName $fileName"
            #je recupere le nom du fichier CDAR auquel je jajoute devant DEST
            set nomSortie [file tail $filePath]
            set repertoire  [file dirname $filePath]
            set destFilePath $repertoire/DEST$nomSortie
            
            
             
            echo "destFilePath $destFilePath"
            #lecture du fichier DEST
            set destData [read_file $destFilePath]
           #creation d'un message de type Cloverleaf avec le schema xml schema evenementDocument
            set mhDest [msgcreate $destData]  
            if { [catch { set gh [grmcreate -msg $mhDest -warn warn xml schema evenementDocument] } err] } {
                    #libere les ressources
                    hcidatlistreset $datList
                    #grmdestroy $gh
            } else {
                    #recupere le champ masque PS avec le xpath evenementDocument.document.masquePS 
                    set dh_PS [grmfetch $gh evenementDocument.document.masquePS.#text]    
                    set PS [datget $dh_PS VALUE]
    
                    #recupere le champ Invisible Patient avec le xpath evenementDocument.document.masquePatient 
                    set dh_Pat [grmfetch $gh evenementDocument.document.masquePatient.#text]    
                    set Pat [datget $dh_Pat VALUE]

                    #recupere le champ Invisible representant legaux avec le xpath evenementDocument.document.masqueRL 
                    set dh_RL [grmfetch $gh evenementDocument.document.masqueRL.#text]    
                    set RL [datget $dh_RL VALUE]
    
                    keylset keylist masquePS $PS
                    keylset keylist invisiblePatient $Pat
                    keylset keylist masqueRL $RL
                    msgmetaset $mh USERDATA $keylist
            }
            #libere les ressources
            hcidatlistreset $datList
            grmdestroy $gh
            msgdestroy $mhDest
            #suppression du fichier DEST
            file delete $destFilePath
    
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
