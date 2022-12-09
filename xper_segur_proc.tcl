######################################################################
# Name:     convert_or_add_date_xltp
# Purpose:  <description>
# UPoC type: xltp
######################################################################

proc convert_or_add_date_xltp {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName

    set inVal [lindex $xlateInVals 0]
    set outVal "";
    set lmonth 0; catch {set lmonth [lindex $xlateInVals 1]}
    if { $lmonth != 0 && $lmonth !="" } {
        set outVal [clock format [clock add $inVal $lmonth month] -format "%Y-%m"]
        set outVal [concat $outVal-01 00:00:00]
    } else {
        set outVal [clock format $inVal -format "%Y-%m"]
        set outVal [concat $outVal-01 00:00:00]
    }
    set xlateOutVals [list $outVal]
}

######################################################################
# Name:     convert_custom_date_xltp
# Purpose:  <description>
# UPoC type: xltp
######################################################################

proc convert_custom_date_xltp {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName

    set inVal [lindex $xlateInVals 0]
    set outVal "";
    set lmonth 0; catch {set lmonth [lindex $xlateInVals 1]}
  
    set outVal [clock format $inVal -format "%Y-%m-%d"]
    set outVal [concat $outVal 00:00:00]
    
    set xlateOutVals [list $outVal]
}

######################################################################
# Name:     xper_tps_segur_db
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc xper_tps_segur_db { args } {
    package require csv
    
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_tps_segur_db/$HciConnName/$ctx"
    
    set uargs {} ; keylget args ARGS uargs
    set debug 0 ; catch {keylget uargs DEBUG debug}
    set dblogin "xperis" ; catch {keylget uargs DBLOGIN dblogin}
    set dbpassword "Xperis33!" ; catch {keylget uargs DBPASSWORD dbpassword}
    set dbhost 10.247.17.15 ; catch {keylget uargs DBHOST dbhost}
    set dbport 5432 ; catch {keylget uargs DBPORT dbport}
    set dbschema "flux_test" ; catch {keylget uargs DBSCHEMA dbschema}
    set dbtable "" ; catch {keylget uargs DBTABLE dbtable}
    
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
            if { $debug } {
                echo "*********************************************"
            }
            keylget args MSGID mh
            

            set userdata [msgmetaget $mh USERDATA]
            keylget userdata IDCLIENT idclient
            keylget userdata STARTDATE startdate
            keylget userdata ENDDATE enddate
            if { $debug } {
                echo ID CLIENT : $idclient
                echo STARTDATE : $startdate
                echo ENDDATE : $enddate
            }
            set dbrequest "SELECT id_client As Identifiant_Client, sub_criteria AS Application_Source, transaction_type AS Type_Transaction, date_msg AS Date_Transaction, ack_state AS Etat_Acquittement, ack_detail Detail_Acquittement,visit_number AS Numero_Sejour, id_document AS Identifiant_Document, Date_Creation_Doc as date_creation_document, document_type AS Type_Document, id_patient AS Identifiant_Patient, id_structure AS Identifiant_Structure FROM $dbtable WHERE id_client='$idclient' AND transaction_type='dmp_submitv2' AND date_ack BETWEEN CAST(\'$startdate\' AS TIMESTAMP) AND CAST(\'$enddate\' AS TIMESTAMP) ORDER BY date_msg"
             if { $debug } {
                echo REQUEST : $dbrequest
            }
        
            set resultDict [xper_segur_requestDB $uargs $dbrequest]
            set resultDict [csv::joinlist $resultDict {;}]
            if { $debug } {
                echo RESULTAT : $resultDict
            }
            
            if { $debug } {
                echo "*********************************************"
            }
            
            msgset $mh $resultDict
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
# Name:     xper_segur_requestDB
# Purpose:  <description>
# UPoC type: other
######################################################################


proc xper_segur_requestDB { uargs dbrequest } {
    package require pgintcl
    
    set dblogin "xperis" ; catch {keylget uargs DBLOGIN dblogin}
    set dbpassword "gofish" ; catch {keylget uargs DBPASSWORD dbpassword}
    set dbhost localhost ; catch {keylget uargs DBHOST dbhost}
    set dbport 5432 ; catch {keylget uargs DBPORT dbport}
    set dbschema "" ; catch {keylget uargs DBSCHEMA dbschema}
    if  { [ catch  { set conn [pg_connect -conninfo [list host = $dbhost user = $dblogin dbname = $dbschema password = $dbpassword port = $dbport ] ] } ] }  { 
       set resultDict {}
    } else {
        set result [pg_exec $conn "${dbrequest};"]

        lappend resultDict [pg_result $result -attributes]
        
        set ntups [pg_result $result -numTuples]
        for {set i 0} {$i < $ntups} {incr i} {
            lappend resultDict [pg_result $result -getTuple $i]
        }
    
        pg_result $result -clear
        pg_disconnect $conn   
    }
    
    return $resultDict
}

######################################################################
# Name:     xper_rapport_editor
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc xper_rapport_editor { args } {
    package require base64
    package require smtp
    package require mime
    global HciConnName
    global HciRootDir
    global HciSite
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_rapport_editor/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0 ; keylget uargs DEBUG debug
    set tablename xper_configstats_segur_test; keylget uargs TABLENAME tablename
    set deleteSource 0; keylget uargs DELETESOURCE deleteSource
    set dispList {}

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            if { $debug } {
                puts stdout "$module: Starting in debug mode..."
            }
        }

        run { 
            keylget args MSGID mh

            echo ==================== Début du script =============================
            #Definition des parametres du script
            set currentSite $HciSite
            set mailserver   [tbllookup $tablename mailserver]
            set mailfrom     [tbllookup $tablename mailfrom] 
            set mailport [tbllookup $tablename mailport]
            set usetls [tbllookup $tablename usetls]
            set maillogin [tbllookup $tablename maillogin]
            set mailpassword [tbllookup $tablename mailpassword]
            set mailto [tbllookup $tablename mailto] 
            
            # recup des userdatas
            set userdata [msgmetaget $mh USERDATA]
            keylget userdata ADRESS_MAIL mailto
            keylget userdata IDCLIENT idclient
            keylget userdata STARTDATE startdate
            set startdateForPrint [clock format [clock scan $startdate -format {%Y-%m-%d %T}] -format "%d-%m-%Y"]
            keylget userdata ENDDATE enddate
            set enddateForPrint [clock format [clock scan $enddate -format {%Y-%m-%d %T}] -format "%d-%m-%Y"]
            #fin recup
            
            set lastrun [tbllookup $tablename lastrun]
            set pathintegrator $::HciRoot
            set pathsite $::HciSite
        
            set dsupdateday "ALWAYS";set dsupdateday [string toupper [tbllookup $tablename dsupdateday] ]
            set resetstat [tbllookup $tablename resetstat]
        
            #Definition des variables 
            set systemTime [clock seconds]
            set today [clock format [clock seconds]  -format %d/%m/%Y]
            set dayOfWeek [string toupper [clock format $systemTime -format %A]]
            if { [cequal $dsupdateday ""] || [cequal $dsupdateday "ALWAYS"] } {
                set doUpdate 1
            } else {
                set doUpdate 0
                switch -exact -- $dayOfWeek {
                    MONDAY      {if { [cequal $dsupdateday $dayOfWeek] ||  [cequal $dsupdateday LUNDI]    }       {echo we do it today on : $dsupdateday ; set doUpdate 1}             }
                    TUESDAY     {if { [cequal $dsupdateday $dayOfWeek] ||  [cequal $dsupdateday MARDI]    }       {echo we do it today on : $dsupdateday ; set doUpdate 1}             }
                    WEDNESDAY   {if { [cequal $dsupdateday $dayOfWeek] ||  [cequal $dsupdateday MERCREDI] }       {echo we do it today on : $dsupdateday ; set doUpdate 1}             }
                    THURSDAY    {if { [cequal $dsupdateday $dayOfWeek] ||  [cequal $dsupdateday JEUDI]    }       {echo we do it today on : $dsupdateday ; set doUpdate 1}             }
                    FRIDAY      {if { [cequal $dsupdateday $dayOfWeek] ||  [cequal $dsupdateday VENDREDI] }       {echo we do it today on : $dsupdateday ; set doUpdate 1}             }
                    SATURDAY    {if { [cequal $dsupdateday $dayOfWeek] ||  [cequal $dsupdateday SAMEDI]   }       {echo we do it today on : $dsupdateday ; set doUpdate 1}             }
                    SUNDAY      {if { [cequal $dsupdateday $dayOfWeek] ||  [cequal $dsupdateday DIMANCHE] }       {echo we do it today on : $dsupdateday ; set doUpdate 1}             }
                }
            }
            #Production des noms de fichiers et des paths
            set filenameMailContent "${idclient}_stats_[clock format [clock seconds]  -format %Y%m%d%H%M%S].html"
            set csvFilename "${idclient}_stats_[clock format [clock seconds]  -format %Y%m%d%H%M%S].csv"
            
            if {[windows_platform]} {
                set pathfilenameMail $pathintegrator\\$pathsite\\segur\\stats\\$filenameMailContent
                set pathcsvFilename $pathintegrator\\$pathsite\\segur\\csv\\$csvFilename
                set pathfilenameTemp $pathintegrator\\$pathsite\\segur\\stats\\tempBase64.b64
                set pathfilenameBody $pathintegrator\\$pathsite\\segur\\stats\\body.html
              
                set pathheader $pathintegrator\\$pathsite\\segur\\stats\\utils\\header.txt
                set pathfooter $pathintegrator\\$pathsite\\segur\\stats\\utils\\footer.txt
                set pathtblfile $pathintegrator\\$pathsite\\Tables\\$tablename.tbl
            } else {
                set pathfilenameMail $pathintegrator/$pathsite/segur/stats/$filenameMailContent
                set pathcsvFilename $pathintegrator/$pathsite/segur/csv/$csvFilename
                set pathfilenameTemp  $pathintegrator/$pathsite/segur/stats/tempBase64.b64
                set pathfilenameBody  $pathintegrator/$pathsite/segur/stats/body.html
       
                set pathheader $pathintegrator/$pathsite/segur/utils/header.txt
                set pathfooter $pathintegrator/$pathsite/segur/utils/footer.txt
                set pathtblfile $pathintegrator/$pathsite/Tables/$tablename.tbl
            }


            #csv content 
            set ffilenameCSV [open $pathcsvFilename w]
            puts  $ffilenameCSV [msgget $mh] ;  close $ffilenameCSV 
            #end csv content

 
            #HTML chargement des sources
            #fichier entete
            set fheader [open "$pathheader" r]
            set cheader [read $fheader]
            close $fheader
            #fichier pied de page
            set ffooter [open "$pathfooter" r]
            set cfooter [read $ffooter]
            close $ffooter
            
            set ffilenameMail [open $pathfilenameMail w]
            puts  $ffilenameMail " " ;  close $ffilenameMail 
        
            #Production des entetes
            set ffilenameMail [open $pathfilenameMail a]
            puts  $ffilenameMail "$cheader"
            puts  $ffilenameMail "Rapport de statistiques FINESS $idclient - SAAS Xperis du $startdateForPrint au $enddateForPrint </h1><div class=login-container>"
            close $ffilenameMail
            
            keylget args MSGID mh

            #Production du rapport
            if { $debug } {
                echo ==================== Paramètres du script =============================
                echo Date
                echo ====================
                echo systemTime : $systemTime
                echo today : $today
                echo dayOfWeek : $dayOfWeek
                echo dsupdateday : $dsupdateday
                echo doUpdate : $doUpdate
                echo lastrun : $lastrun
                echo ====================
                echo Serveur Mail
                echo ====================
                echo mailserver : $mailserver
                echo mailfrom : $mailfrom
                echo mailport : $mailport
                echo usetls : $usetls
                echo maillogin : $maillogin
                echo mailpassword : $mailpassword
                echo mailto : $mailto
                echo ====================
                echo resetstat : $resetstat
                echo ====================
                echo Fichiers
                echo ====================
                echo pathintegrator : $pathintegrator
                echo pathsite : $pathsite
                echo pathcsvFilename : $pathcsvFilename
                echo pathfilenameMail : $pathfilenameMail
                echo pathfilenameTemp : $pathfilenameTemp
                echo pathfilenameBody : $pathfilenameBody
                echo pathtblfile : $pathtblfile
                echo ====================
                echo ==================== Paramètres du script =============================
            }
            #foreach en fonction du client
            echo Production du rapport du client $idclient en cours
            xper_sendStats_segur_light $pathfilenameMail $userdata $uargs $debug           
            echo La Production du rapport est terminée      
            #Fin du foreach
            
            #Production du footer
            echo Production des footers
            set ffilenameMail [open $pathfilenameMail a]
            puts  $ffilenameMail "$cfooter"
            close $ffilenameMail

            #Production du mail
            set subject "Rapport de statistiques FINESS $idclient - SAAS Xperis du $startdateForPrint au $enddateForPrint"

            set parts [mime::initialize -canonical "text/html" -file $pathfilenameMail]

            
            #Ajouter une pièce jointe
            lappend parts [mime::initialize -canonical "application/csv; name=\"$csvFilename\"" -encoding base64\
                -header {Content-Disposition attachment} -file $pathcsvFilename]

            
            set token [::mime::initialize -canonical multipart/mixed -parts $parts]
            set command [list ::smtp::sendmessage $token -servers $mailserver -ports $mailport -username $maillogin -password $mailpassword -usetls $usetls -header [list From "$mailfrom"] -header [list To "$mailto"] -header [list Subject "$subject"] -header [list Date "[clock format [clock seconds]]"] -debug $debug]
            if {$debug} { echo "command: $command" }

            echo Emission du mail en cours
            eval $command
            echo Emission du mail terminée

            if { $deleteSource } {
                #supression des fichiers envoyé en local
                echo Debut de la supression des fichiers en local
                file delete $pathfilenameMail
                file delete $pathcsvFilename
                echo Supression des fichiers terminée
            }

            
            #Mise à jour du lastrun dans la table
            set ctblfile [open $pathtblfile r]
            set tblfile [read $ctblfile]
            close $ctblfile
            if { [catch {set ltblfile [split $tblfile "\n"] } err] } { } else {
                set newtblcontent "";
                set bell 1;
                foreach element $ltblfile {
                    #if {$debug} { echo bell : $bell }
                    if {$bell} {
                        if {![cequal $element ""]} {append newtblcontent $element "\n"} else {append newtblcontent $element }
                        } else {
                            append newtblcontent $today "\n"
                        }
                    if {[cequal $element lastrun]} {set bell 0} else { set bell 1}
                }
            }            
            set ctblfile [open $pathtblfile w]
            puts  -nonewline $ctblfile $newtblcontent ;  close $ctblfile
            echo ==================== Fin du script =============================

            lappend dispList "OVER $mh"
        }

        time { }
        shutdown {}
        default {
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}




# *************************************************************************************************
#
# $Id: xper_sendStats_segur_light, v2.0 $
#
# *************************************************************************************************
#
# xper_sendStats_segur_Light - Script qui permet de creer un fichier HMLT recapitulant les stats 
#                de la journée des threads d'un site et de l'envoyer par mail
#
# Please note: This is "employee written software", which means that you're 
# welcome to use it, but we don't guarantee that it'll actually work ;-). 
# We do however appreciate any comments you may have.
# Copyright (c) 2000-2008 E.Novation France
#
# Author : Pierre Fok, Xperis, mail : support@xperis.fr
# Date   : 2017-05-10
#
# Updated By : Idir, Hadjchaib, Xperis, mail : support@xperis.fr
# Date   : 2018-09-27
#
# Note : Ce script a ete cree dans le but de la télé-exploitation
#
######################################################################################################
# Name:        xper_sendStats_segur_light
# Purpose:  
# UPoC type:    other
# Args:     none
# Notes:    
######################################################################################################

proc xper_sendStats_segur_light { argv argb argc argd } {
    package require Sitecontrol
    package require smtp
    package require mime 
   
    global HciRootDir
    global HciSite

    set pathfilename [lindex $argv 0]
    set debug [lindex $argd 0]
    if { $debug } { echo [exec showroot] }
    
    set userdata $argb
    if { $debug } { echo "userdata : $userdata" }
    
    set documentTypeList [xper_type_document_db $argc $userdata]

    # recup des userdatas
    keylget userdata NBMESSAGES nbmessage
    keylget userdata NBSUCCESS nbsuccess
    keylget userdata NBDOUBLONS nbdoublons
    keylget userdata NBNF nbnf
    keylget userdata NBFERME nbFerme
    keylget userdata NBERR nberr
    keylget userdata NBRIS nbris
    keylget userdata NBDPI nbdpi
    keylget userdata NBLABO nblabo
    #fin recup
    
    set data [read_file $pathfilename]

    append data "<table>"
    append data "<tr>"
    append data "<th colspan=\"2\">Statistiques générales</th>"
    append data "</tr>"
    append data "<tr><td class=\"desc\">Nombre de documents soumis avec succès</td><td class=\"tbvalue\">$nbsuccess</td></tr>"
    append data "<tr><td class=\"desc\">Nombre de DMP non trouvés</td><td class=\"tbvalue\">$nbnf</td></tr>"
    append data "<tr><td class=\"desc\">Nombre de DMP fermés</td><td class=\"tbvalue\">$nbFerme</td></tr>"
    append data "<tr><td class=\"desc\">Nombre de documents en erreurs</td><td class=\"tbvalue\">$nberr</td></tr>"
    append data "<tr><td class=\"desc\">Nombre de documents en doublons</td><td class=\"tbvalue\">$nbdoublons</td></tr>"
     append data "<tr><td class=\"desc\">Total</td><td class=\"tbvalue\">$nbmessage</td></tr>"
    append data "</table>" 

    append data "<table>"
    append data "<tr>"
    append data "<th colspan=\"3\">Statistiques des envois réussis par application</th>"
    append data "</tr>"
    append data "<tr><td class=\"desc first\">RIS</td><td colspan=\"2\" class=\"tbvalue\">$nbris</td></tr>"
    append data "<tr><td class=\"desc first\">LABO</td><td colspan=\"2\" class=\"tbvalue\">$nblabo</td></tr>"
    if { $nbdpi <= 0} {
        append data "<tr><td class=\"desc first\">DPI</td><td colspan=\"2\" class=\"tbvalue\">$nbdpi</td></tr>"
    } else {
        append data "<tr>"
        append data "<td class=\"desc first\" rowspan=\"20\">DPI</td>"
        append data "<td colspan=\"2\">"
        append data $documentTypeList
        append data "<tr><td class=\"desc\">Total</td><td class=\"tbvalue\">$nbdpi</td></tr>"
        append data "</td>"
        append data "</tr>"
    }
    append data "</table>"
    
    
    #ecriture du rapport en HTML
    write_file $pathfilename $data
}


######################################################################
# Name:     xper_type_document_db
# Purpose:  <description>
# UPoC type: other
######################################################################


proc xper_type_document_db { uargs userdata  } {
    package require pgintcl

    set debug 0 ; catch {keylget uargs DEBUG debug}
    set dblogin "xperis" ; catch {keylget uargs DBLOGIN dblogin}
    set dbpassword "gofish" ; catch {keylget uargs DBPASSWORD dbpassword}
    set dbhost localhost ; catch {keylget uargs DBHOST dbhost}
    set dbport 5432 ; catch {keylget uargs DBPORT dbport}
    set dbschema "" ; catch {keylget uargs DBSCHEMA dbschema}
    set dbtable "" ; catch {keylget uargs DBTABLE dbtable}
    set docTableName ASIP-SANTE_typeCode; keylget uargs DOCTABLENAME docTableName

    if { $debug } {
        echo "*********************************************"
    }    
    keylget userdata IDCLIENT idclient
    keylget userdata STARTDATE startdate
    keylget userdata ENDDATE enddate
    if { $debug } {
        echo ID CLIENT : $idclient
        echo STARTDATE : $startdate
        echo ENDDATE : $enddate
    }
            
    if  { [ catch  { set conn [pg_connect -conninfo [list host = $dbhost user = $dblogin dbname = $dbschema password = $dbpassword port = $dbport ] ] } ] }  { 
        set resultDict {}
    } else {
        set resultDict {}
        set result [pg_exec $conn "SELECT case when document_type is NULL then 'INCONNU' else document_type end as doctype, count(*) as quant FROM $dbtable WHERE id_client='$idclient'  AND sub_criteria='DPI' AND transaction_type='dmp_submitv2' AND ack_state LIKE '%SUCCESS%' AND date_ack BETWEEN CAST(\'$startdate\' AS TIMESTAMP) AND CAST(\'$enddate\' AS TIMESTAMP) GROUP BY doctype ORDER BY doctype ASC;"]

        set docs [pg_result $result -llist]
        if { $debug } {
            echo liste des documents avec nombre: $docs
        }
        set doctypes [keylkeys docs]
        if { $debug } {
            echo liste des types de documents: $doctypes
        }

        foreach doctyp $doctypes {
            set count [keylget docs $doctyp]
            set docTitle [tbllookup $docTableName [string trim $doctyp] ]
            append resultDict "<tr><td class=\"desc\">"
            if { [string compare [string trim $docTitle] ""]==0 } {
                append resultDict "$doctyp"
            } else {
                append resultDict "$doctyp ($docTitle)"
            }
            append resultDict "</td><td class=\"tbvalue\">$count</td></tr>"
        }
        
        pg_result $result -clear
        pg_disconnect $conn   
    }

    if { $debug } {
        echo RESULTAT : $resultDict
    }

    if { $debug } {
        echo "*********************************************"
    }

    
    return $resultDict
}



######################################################################
# Name:     frequency_mail_sending
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc frequency_mail_sending { args } {
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "frequency_mail_sending/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0 ; catch {keylget uargs DEBUG debug}
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh
            set userdata [msgmetaget $mh USERDATA]

            set frequency ""
            set startDate ""
            set ldate [clock seconds]
            #set ldate "1659335336"

            if { [ catch {set frequency [keylget userdata FREQENCY] } ] } {
                echo "la fréquence est absente : Veuillez renseigner la fréquence d\'envoie des statistiques par mail dans la métadonnée FREQENCY"
                set ldispList "KILL $mh"
            }

            if { $debug } {            
                echo "frequence : $frequency"
            }

            switch $frequency {
                "JOUR" {
                    set startDate [clock add $ldate -1 days]
                    if { $debug } {            
                        echo "start Date : $startDate"
                        echo "End Date : $ldate"
                    }
                    keylset userdata STARTDATE [clock format $startDate -format "%Y-%m-%d 00:00:00"]
                    keylset userdata ENDDATE [clock format $ldate -format "%Y-%m-%d 00:00:00"]
                    msgmetaset $mh USERDATA $userdata
                    
                    set ldispList "CONTINUE $mh"
                }
                "SEMAINE" {
                    set dayWeek [clock format $ldate -format "%u"]
                    if { $dayWeek == 1 } {
                        set startDate [clock add $ldate -7 days]
                        if { $debug } {            
                            echo "start Date : $startDate"
                            echo "End Date : $ldate"
                        }
                        keylset userdata STARTDATE [clock format $startDate -format "%Y-%m-%d 00:00:00"]
                        keylset userdata ENDDATE [clock format $ldate -format "%Y-%m-%d 00:00:00"]
                        msgmetaset $mh USERDATA $userdata

                       set ldispList "CONTINUE $mh"
                    } else {
                       set ldispList "KILL $mh"
                    }
                }
                "MOIS" {
                    set dayMonth [clock format $ldate -format "%d"]
                    if { $dayMonth == 01 } {
                        set startDate [clock add $ldate -1 month]
                        if { $debug } {            
                            echo "start Date : $startDate"
                            echo "End Date : $ldate"
                        }
                        keylset userdata STARTDATE [clock format $startDate -format "%Y-%m-%d 00:00:00"]
                        keylset userdata ENDDATE [clock format $ldate -format "%Y-%m-%d 00:00:00"]
                        msgmetaset $mh USERDATA $userdata
         
                       set ldispList "CONTINUE $mh"
                    } else {
                       set ldispList "KILL $mh"
                    }
                }
                default {
                    echo "la fréquence renseignée n\'est pas prise en charge. Les différentes fréquences prisent en charge sont : JOUR, SEMAINE et MOIS"
                    set ldispList "KILL $mh"
                }
            }
                       
            lappend dispList $ldispList
        }

        time {}
        shutdown {}
        default {
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}
