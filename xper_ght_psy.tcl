######################################################################
# Name:     get_trxid_from_tcpip
# Purpose:  en fonction du message reçu génère le TRXID adéquat HL7 ou XML
# UPoC type: tps
######################################################################

proc get_trxid_from_tcpip { args } {
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "get_trxid_from_tcpip/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0
    catch {keylget uargs DEBUG debug}
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh      
            set datList [datlist]
            set nomSortie "sortie.xml"
            
            # je regarde si on est sur un fichier CDAR            
            if { ![catch { set gh [grmcreate -msg $mh -warn warn xml CDA/Schemas CDA] } err] } {
               set typeFichier cdar
            } 
            if { ![catch { set gh [grmcreate -msg $mh -warn warn xml schema evenementDocument] } err] } {
               set typeFichier dest
            } else {
                 set typeFichier cdar
            }
            echo typeFichier $typeFichier
            switch $typeFichier {
                 dest {
                    echo "OK DEST"
                    #parce qu'il y a des retours chariots !!!!!
                    #set msg [string map {"\r\n" "\n"} $mh]
                    #msgset $mh $msg
                    #echo "mh apres  $mh"
                    set gh [grmcreate -msg $mh -warn warn xml schema evenementDocument]
                    #recupere l'ipp
                    set DESTCDAR_IPP [grmfetch $gh evenementDocument.patient.ipp.#text]    
                    set IPP [datget $DESTCDAR_IPP VALUE]
                   # echo "2 IPP $IPP"
                    set nomSortie CDAR$IPP.dest   
                    grmdestroy $gh    
                 }
                
                 default {
                    echo "OK CDAR"
                    #recupere l'ipp
                    set gh [grmcreate -msg $mh -warn warn xml CDA/Schemas CDA]
                    set CDAR_IPP [grmfetch $gh nm1:ClinicalDocument.nm1:recordTarget(0).nm1:patientRole.nm1:id(0).&extension]    
                    set IPP [datget $CDAR_IPP VALUE]
                    echo "1 IPP $IPP"
                    #nom de fichier CDARIPPP.xml
                    set nomSortie CDAR$IPP.xml
                    set nomtemoin CDAR$IPP.ok
                    #fichier temoin
                    set temoindriverctl "{FILESET {{OBFILE {$nomtemoin}}}}"
                    set messagetemoin [msgcopy $mh]
                    msgset $messagetemoin ""
                    msgmetaset $messagetemoin DRIVERCTL $temoindriverctl
                    lappend dispList "CONTINUE $messagetemoin"
                    grmdestroy $gh
                  }               

            }
                 #default {echo "Cela peut être n'importe quoi."}
                 echo "typeFichier $typeFichier"
                #echo "msg $mh"
                 #libere les ressources
                hcidatlistreset $datList
                 # Affectation du nom du fichier
                set driverctl "{FILESET {{OBFILE {$nomSortie}}}}"
                msgmetaset $mh DRIVERCTL $driverctl
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

