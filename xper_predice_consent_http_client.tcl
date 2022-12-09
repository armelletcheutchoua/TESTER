######################################################################
# Name:     pred_construct_consent_request_HTTP_CLIENT
# Purpose:  Permet de construire la requête d'interrogation de prédice pour le consentement via le DRIVERCTL
# UPoC type: tps
######################################################################

proc pred_construct_consent_request_HTTP_CLIENT { args } {
    package require base64
    package require Sitecontrol
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "pred_construct_consent_request_HTTP_CLIENT/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0
    catch {keylget uargs DEBUG debug}
    set dispList {}
    echo "****   pred_construct_consent_request_HTTP_CLIENT ****"
    switch -exact -- $mode {
        start {}

        run {
            keylget args MSGID mh

            set userdata [msgmetaget $mh USERDATA]
            
            set ipp NULL
            catch {keylget userdata CONS_IPP ipp}

            if {[cequal $ipp NULL]} {
                error "Le consentement a besoin de la variable CONS_IPP dans les USERDATA"
            }

            set domainId NULL
            catch {keylget userdata CONS_DOMID domainId}

            if {[cequal $domainId NULL]} {
                error "Le consentement a besoin de la variable CONS_DOMID dans les USERDATA"
            }

            set domainType NULL
            catch {keylget userdata CONS_DOMTYPE domainType}

            if {[cequal $domainType NULL]} {
                error "Le consentement a besoin de la variable CONS_DOMTYPE dans les USERDATA"
            }
 
            #info
            #echo "********** info passées ***************"
            #echo "ipp $IPP"
            #echo "domainId $domainId"
            #echo "domainType $domainType"
            #echo "userdata  $userdata"
            #echo "********** ***************"
            #Recupération de l'URL dans le NetConfig
            if { [catch {set success [::Sitecontrol::loadNetConfig]} err] || $success == -1} {
                echo "Impossible d'ouvrir le fichier netconfig $err"
                return
            }
            set threadconfig [::Sitecontrol::getThreadData $HciConnName]
            keylget threadconfig PROTOCOL.URL url

            #Pilotage de l'URL pour le protocole HTTP CLIENT 
            set driverctl [msgmetaget $mh DRIVERCTL]
            keylset driverctl HTTP-CLIENT.URL ${url}?patientId=$ipp&domainId=$domainId&domainIdType=$domainType

            #On stocke le message en base64
            set base64 [::base64::encode -maxlen 0 [msgget $mh]]
            keylset userdata MSG $base64
          
            
            
            #Suppression du contenu (inutile pour la requête de consentement)
            msgset $mh ""
            
            msgmetaset $mh USERDATA $userdata
            msgmetaset $mh DRIVERCTL $driverctl
            echo "**** -----------------------  ****"
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
# Name:         xper_httpQuery
# Purpose:   Reprise de la proc Basic Message-driven HTTP query
# UPoC type:  tps
# Args:      tps keyedlist containing the following keys:
#            MODE    uses time-mode for time-driven queries
#                    uses run-mode for message-driven queries
#                    start mode always used for storing NetConfig vals
#            MSGID   message handle
#            ARGS    user-supplied arguments: 
#                    MSGUSE - used in Run mode only
#                        URL  (default) content of message will be used as URL
#                        DATA content of message wil be used as DATA
#                               when using POST or PUT option
#                        CGI  content of message will be used as 
#                               paramlist for CGI script, URL of CGI script
#                               to be defined in GUI.
#                        DRIVERCTL - used in Run mode only
#                              0 Ignore DRIVERCTL.HTTP-CLIENT metadata
#                              1 (default) Use DRIVERCTL.HTTP-CLIENT metadata values
#                                (if present) to override default setttings.
#
######################################################################

proc xper_httpQuery { args   } {
    global cfgs

    keylget args MODE mode       
    keylget args ARGS uargs
    set dispList {}
echo "******* xper_httpQuery ****************"
    switch -exact -- $mode {
        start {
            # grab and store CFGS values for run/time mode -- 
            # CFGS are only available in start mode.
            keylget args CFGS cfgs
            keylget cfgs WAIT wait
            switch -exact -- $wait {
                0 {
                    keylset cfgs TIMEOUT -1
                }
            }
            return ""
        }

        time {
            # fetch the URL using the specified method
            # the URL used will be taken from NetConfig
            keylget cfgs METHOD method
            switch -exact -- $method {
                PUT { set res [httpput $cfgs] }
                POST { set res [httppost $cfgs] }
                default { set res [httpget $cfgs] }
            }

            # parse out the response
            set status [keylget res "STATUS"]
            set statCode [lindex $status 1]
            set body [keylget res "BODY"]
            set headers [keylget res "HEADERS"]  
            keylget cfgs URL url

            # check for success (status code 100-299)
            if {($statCode >= 100) && ($statCode <= 299)} {
                # if OK, place msg into IB queue
                # This UPoC is outbound, so use OVER to generate IB msg
                set outMsg [msgcreate -recover -type data $body]
                # attach URL to response message
                keylset usrdata URL $url
                #Specifique : ajout des headers de reponse et du status code dans les userdatas
                keylset usrdata STATUS $status
                keylset usrdata HEADERS $headers
                msgmetaset $outMsg USERDATA $usrdata
                lappend dispList "OVER $outMsg"
            } else {
                # otherwise, report the error and send a blank msg to error DB
                set msg "(httpQuery/Time [crange [fmtclock [getclock]] 0 18]) Error fetching URL $url: $status"
                echo "$msg \r\n"
                set outMsg [msgcreate -recover -type data ""]
                msgmetaset $outMsg USERDATA $msg
                lappend dispList "ERROR $outMsg"
            }
        }

        run {
            # extract URL from inbound message
            keylget args MSGID inMsg

            # fail gracefully if user args are not a keyed list
            set msguse URL
            if [catch {keylget uargs MSGUSE msguse} err] {
                                puts stdout "httpQuery error: $err"
                                lappend dispList "ERROR $inMsg"
                                return $dispList
                        }
                
            set driverctl 1
            keylget uargs DRIVERCTL driverctl

            # update local var 'val' using user params and msg content
            set val ${cfgs}
            switch $msguse {
                DATA {
                    keylset val DATA [msgget $inMsg]
                }
                CGI {
                    keylget val URL url
                    append url "?[msgget $inMsg]"
                    keylset val URL $url
                }
                default {
                    set url [string trim [msgget $inMsg]]
                    regsub -all " " $url %20 url
                    keylset val URL $url                
                }
            }

            if $driverctl {
                # override any http-client driver settings (except DATA)
                # with msg specific DRIVERCTL metadata
                set drvrctl [msgmetaget $inMsg DRIVERCTL]
                if [clength $drvrctl] {
                    set httpCtl "" ;keylget drvrctl HTTP-CLIENT httpCtl
                    set newurl "" ; keylget httpCtl URL newurl
                    regsub -all " " [string trim $newurl] %20 newurl
                    if [clength $newurl] { keylset val URL $newurl }
                    set newMethod ""; keylget httpCtl METHOD newMethod
                    if [clength $newMethod] { keylset val METHOD $newMethod }
                    set newHeaders ""; keylget httpCtl HEADERS newHeaders
                    if [clength $newHeaders] { keylset val HEADERS $newHeaders }                
                }
            }

            # fetch the URL using the specified method
            keylget cfgs METHOD method
            switch -exact -- $method {
                PUT 
                { 
                                if [catch {keylget val DATA}] {
                                        puts stdout "httpQuery error: httpput requires a 'DATA' key"
                                        lappend dispList "ERROR $inMsg"
                                        return $dispList
                                }
                    #echo "Executing: httpput $val\r\n"
                    set res [httpput $val] 
                }
                POST 
                { 
                                if [catch {keylget val DATA}] {
                                        puts stdout "httpQuery error: httppost requires a 'DATA' key"
                                        lappend dispList "ERROR $inMsg"
                                        return $dispList
                                }
                    #echo "Executing: httppost $val\r\n"
                    set res [httppost $val] 
                }
                default 
                { 
                    #echo "Executing: httpget $val\r\n"
                    set res [httpget $val] 
                }
            }

            # parse out the response
            set status [keylget res "STATUS"]
            set statCode [lindex $status 1]
            set body [keylget res "BODY"]
            set headers [keylget res "HEADERS"]  
            keylget val URL url

            # check for success (status code 100-299)
            if {($statCode >= 100) && ($statCode <= 299)} {
                keylget cfgs WAIT wait
                switch -exact -- $wait {
                    1
                    {
                        # if OK, place msg into IB queue
                        set outMsg [msgcreate -recover -type reply $body]
                        msgmetaset $outMsg DESTCONN [msgmetaget $inMsg ORIGSOURCECONN]
                        msgmetaset $outMsg SOURCECONN [msgmetaget $inMsg DESTCONN]
                        msgmetaset $outMsg DRIVERCTL [msgmetaget $inMsg DRIVERCTL]
                    }
                    0
                    {
                        # if OK, place msg into IB queue
                        set outMsg [msgcreate -recover -type data $body]
                    }
                }
                      
                lappend dispList "KILL $inMsg"
                # Copy user metadata from query message. Attach URL to userdata if
                # it is compatible with a keyed list
                set usrdata [msgmetaget $inMsg USERDATA]
                catch {keylset  usrdata URL $url}
                #Specifique : ajout des headers de reponse et du status code dans les userdatas
                catch {keylset usrdata STATUS $status}
                catch {keylset usrdata HEADERS $headers}
                msgmetaset $outMsg USERDATA $usrdata
                lappend dispList "OVER $outMsg"
            } else {
                # otherwise, report the error and send orig msg to error DB
                set msg "(httpQuery/Run) Error fetching URL $url: $status"
                echo $msg
                msgmetaset $inMsg USERDATA $msg
                lappend dispList "ERROR $inMsg"
            }
        }

        shutdown {
            # the following code will be called if the thread is shut down
        }

        default {
             error "Procedure httpClientQuery used in undefined mode $mode."
        }
    }
      echo "**** -----------------------  ****"
    return $dispList
}

######################################################################
# Name:         pred_consent_req_HTTP_CLIENT
# Purpose:   Validation des acquittements
######################################################################

proc pred_consent_req_HTTP_CLIENT { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args
   
    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "pred_consent_req/$HciConnName/$ctx" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return
echo "********   pred_consent_req_HTTP_CLIENT   *****"
    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            
            if { $debug } {
                puts stdout "$module: Starting in debug mode..."
            }

            # load json packages
            package require json
            package require json::write

            package require base64 
            
            # init the token global var
            set ::token ""
        }

        run {
            
            # 'run' mode always has a MSGID; fetch and process it
             keylget args MSGID mh
            keylget args OBMSGID obmh

            set obudata [msgmetaget $obmh USERDATA]
            set obtype ""
            keylget obudata MSGTYPE obtype
            
             #nombre de relance
            set nbResend 1
            catch {keylget obudata RESEND nbResend}
            echo "nbResend obudata   $nbResend"
            
            #echo "obudata $obudata"
            set msg [msgget $mh]
            
            set obmh_userdata [msgmetaget $obmh USERDATA]
            set obmsg [::base64::decode [keylget obmh_userdata MSG]]
            #recup du message pour etre envoyé à doca
            #echo "  obmsg $obmsg"  
            keylset uData MSGDOCA $obmsg
          
            lappend dispList "CONTINUE $obmsg"    
    
            # reply validation logic here
            set udata [msgmetaget $mh USERDATA]
            # get http response code of reply msg
            keylget udata STATUS statusList
            set statusCode [lindex $statusList 1]  
            # invalid http code
            if {$statusCode != 200} {
                echo "received invalid response "
                set data [lindex [split $msg \[] 1]
                set msg [lindex [split $data \]] 0]
            #    msgmetaset $obmh USERDATA $msg
            #    return "{ERROR $obmh} {KILLREPLY $mh}"                   
            }
            #echo "msg avant $msg"
            
            #ATTENTION A DECOMMENTER UNIQUEMENT POUR TEST
            #je force la reponse.      
            #set msg TEMPORARY
            #set msg DESACTIVATED
            #set msg PRE_EHR
            
            keylset uData RESEND $nbResend

            # convert to data type message
            set datamh [msgcreate -recover ""]
            msgset $datamh $obmsg
            echo "Retour interrogation :  $msg"
            switch $msg {
                "ACTIVATED_TEST" {
                  echo "en attente test $nbResend"
                  keylset uData TRXID "RESEND_$nbResend"
               }
               "ACTIVATED" {
                echo "active envoi a Predice"
                  keylset uData TRXID $msg 
               }
               "PRE_EHR" {
                   echo "en attente $msg $nbResend"
                  keylset uData TRXID "RESEND_$nbResend"
               }
               "OPENING_REQUEST" {
                   echo "en attente $msg $nbResend"
                  keylset uData TRXID "RESEND_$nbResend"
               }
               "TEMPORARY" { 
                 echo "en attente $msg $nbResend"
                  keylset uData TRXID "RESEND_$nbResend"               
               }
               "DESACTIVATED" {
                echo "desactive $msg on supprime"
                  keylset uData TRXID $msg 
               }
               "CLOSED" {
                echo "ferme $msg on supprime"
                  keylset uData TRXID $msg 
               }
            }

            msgmetaset $datamh USERDATA $uData
            #echo trxid : [keylget uData TRXID]
            #echo exp udata : "RESEND_$nbResend"
            #echo uData : $uData
            
            #renommage du fichier de sortie avec le nom d'origine
            set driver [msgmetaget $mh DRIVERCTL]
            if { [catch {set filename [file tail [keylget driver FILENAME]]} err] } {                
                error "Impossible de retrouver le nom d'origine du message"
            }
            echo " filename $filename"  
            echo " ************ ------------------------------ ******************"         
            # Affectation du nom du fichier
            set driverctl "{FILESET {{OBFILE {$filename}}}}"
            msgmetaset $datamh DRIVERCTL $driverctl
            lappend dispList "CONTINUE $datamh" 
            lappend dispList "KILL $obmh" 
            lappend dispList "KILLREPLY $mh"
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
  echo "**** -----------------------  ****"
    return $dispList
}


######################################################################
# Name:     xper_send_to_doca
# Purpose:  renvoie le message original a DOCA
# UPoC type: tps
######################################################################

proc xper_send_to_doca { args } {
    package require base64
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_send_to_doca/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0
    catch {keylget uargs DEBUG debug}
    set nbResend 0 
    set dispList {}
    set datList [datlist]
    
    switch -exact -- $mode {
        start {}

        run {
            echo "******  xper_send_to_doca  ****"
            keylget args MSGID mh   
                  
            set userdata [msgmetaget $mh USERDATA]
            catch {keylget userdata RESEND nbResend}
            echo "nbresend  $nbResend"   
             if { [cequal $nbResend 0] } {
                echo "premier envoi"
                lappend dispList "CONTINUE $mh" 
             } else {
                echo "second envoi"            
                      
        # GRM DU FICHIER xdsb            
            set package "schema/IHE"
            set ocmfile "XDS.b_DocumentRepository"           
            set rootxml "nm1:ProvideAndRegisterDocumentSetRequest"            
            set msg_doca_original ""
            set gh ""            
            if { [catch { set gh [grmcreate -msg $mh -warn warn xml $package $ocmfile $rootxml] } err] } {
                   echo "probleme grm $err"
                   hcidatlistreset $datList
                   #grmdestroy $gh
            } else {
                   echo "recupere le message en base 64"
                                                  #nm1:ProvideAndRegisterDocumentSetRequest.0(0).nm1:Document(0).#text
                   set dh_idMessage [grmfetch $gh nm1:ProvideAndRegisterDocumentSetRequest.0(0).nm1:Document(0).#text]    
                   set msg_doca_original [datget $dh_idMessage VALUE]
                   set msg_doca_original [::base64::decode $msg_doca_original]
                   #echo "msg_doca_original $msg_doca_original"                   
                   hcidatlistreset $datList
                   grmdestroy $gh
            }
            
                keylset userdata MSGDOCA_ORIGINAL $msg_doca_original 
                msgmetaset $mh USERDATA $userdata 
                #creation d'un nouveau message avec le CDA
                set mhCDA [msgcopy $mh]
                msgset $mhCDA ""
                msgset $mhCDA $msg_doca_original 
                lappend dispList "CONTINUE $mhCDA"           
                lappend dispList "KILL $mh"  
            }

            
        }

        time {}
        shutdown {}
        default {
            error "Unknown mode '$mode' in $module"
        }
    }
  echo "**** -----------------------  ****"
    return $dispList
}


######################################################################
# Name:     xper_send_to_doca_V2
# Purpose:  renvoie le message original a DOCA
# UPoC type: tps
######################################################################

proc xper_send_to_doca_V2 { args } {
    package require base64
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_send_to_doca_V2/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0
    catch {keylget uargs DEBUG debug}
    set nbResend 0 
    set dispList {}
    set datList [datlist]
    
    switch -exact -- $mode {
        start {}

        run {
            echo "******  xper_send_to_doca_V2  ****"
            keylget args MSGID mh   
                  
            set userdata [msgmetaget $mh USERDATA]
            catch {keylget userdata RESEND nbResend}
            echo "nbresend  $nbResend"   
             if { [cequal $nbResend 0] } {
                echo "premier envoi"
                lappend dispList "CONTINUE $mh" 
             } else {
                echo "second envoi "
                #creation d'un nouveau message avec le CDA
                set mhCDA [msgcopy $mh]
                lappend dispList "CONTINUE $mhCDA"           
                lappend dispList "KILL $mh"  
            }

            
        }

        time {}
        shutdown {}
        default {
            error "Unknown mode '$mode' in $module"
        }
    }
  echo "**** -----------------------  ****"
    return $dispList
}
######################################################################
# Name:     xper_set_resend
# Purpose:  ajoute le nombre de tentavive de relance dans les userData
# UPoC type: tps
######################################################################

proc xper_set_resend { args } {
    package require base64
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_set_resend/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set debug 0
    catch {keylget uargs DEBUG debug}
    set nbResend 1 ; keylget uargs RESEND nbResend  
    #echo "nbResend  $nbResend "
    set dispList {}
    set datList [datlist]
    
    switch -exact -- $mode {
        start {}

        run {
            echo "******  xper_set_resend ****"
            #echo "nbResend  $nbResend "
            keylget args MSGID mh           
            set userdata [msgmetaget $mh USERDATA]            
            keylset userdata RESEND $nbResend 
            msgmetaset $mh USERDATA $userdata 
            lappend dispList "CONTINUE $mh"  
            #echo "userdata $userdata"
        }

        time {}
        shutdown {}
        default {
            error "Unknown mode '$mode' in $module"
        }
    }
  echo "**** -----------------------  ****"
    return $dispList
}

