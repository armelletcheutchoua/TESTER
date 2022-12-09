######################################################################
# Name:     xper_inovelan_sendMail
# Purpose:  <description>
# UPoC type: tps
######################################################################

proc xper_inovelan_sendMail { args } {
    global HciConnName
    keylget args MODE mode
    set ctx ""   ; keylget args CONTEXT ctx
    set module "xper_inovelan_sendMail/$HciConnName/$ctx"
    set uargs {} ; keylget args ARGS uargs
    set from "cloverleaf@xperis.fr"  ; catch {keylget uargs FROM from}
    set login ""  ; catch {keylget uargs LOGIN login}
    set pass ""  ; catch {keylget uargs PASSWORD pass}
    set server "localhost"  ; catch {keylget uargs SERVER server}
    set port 25  ; catch {keylget uargs PORT port}
    set usetls 0  ; catch {keylget uargs USETLS usetls}
    set dirTemp "inovelan" ; catch {keylget uargs DIRTEMP dirTemp}
    set debug 0
    catch {keylget uargs DEBUG debug}
    set dispList {}

    switch -exact -- $mode {
        start {}

        run {
            set pathintegrator $::HciRoot
            set pathsite $::HciSite
            keylget args MSGID mh
            
            set userdata [msgmetaget $mh USERDATA]
            if { $debug } {
                echo "userdata du message : $userdata"
            }
            if { [ catch {set to [keylget userdata TO] } ] } {
                echo "le destinataire est absent : Veuillez renseigner les destinataires séparés d'une virgule dans la métadonnée TO"
            }
            if { [ catch {set pdfContent [keylget userdata PDFCONTENT] } ] } {
                echo "le pdf est absent : Veuillez renseigner le PDF en BASE64 dans la métadonnée PDFCONTENT"
            }
            if { [ catch {set subj [keylget userdata SUBJECT] } ] } {
                echo "le sujet du mail est absent : Veuillez renseigner le sujet dans la métadonnée SUBJECT"
            }
            if { [ catch {set body [keylget userdata BODY] } ] } {
                echo "le contenu du mail est absent : Veuillez renseigner le contenu dans la métadonnée BODY"
            }

            set keyMID [msgmetaget $mh MID]
            keylget keyMID NUM mid
            set xdmFilename "$mid.zip"
            set pdfFilename "$mid.pdf"
            if {[windows_platform]} {
                set xdmPath "$pathintegrator\\$pathsite\\$dirTemp\\$xdmFilename"
                set pdfPath "$pathintegrator\\$pathsite\\$dirTemp\\$pdfFilename"
            } else {
                set xdmPath  "$pathintegrator/$pathsite/$dirTemp/$xdmFilename"
                set pdfPath  "$pathintegrator/$pathsite/$dirTemp/$pdfFilename"
            }

              if { $debug } {
                echo ==================== Paramètres du script =============================
                echo Date
                echo ====================
                echo systemTime : [clock seconds]
                echo ====================
                echo Serveur Mail
                echo ====================
                echo mailserver : $server
                echo mailfrom : $from
                echo mailport : $port
                echo usetls : $usetls
                echo maillogin : $login
                echo mailto : $to
                echo ====================
                echo Fichiers
                echo ====================
                echo pathintegrator : $pathintegrator
                echo pathsite : $pathsite
                echo XDM path : $xdmPath
                echo PDF path : $pdfPath
                echo ====================
                echo ==================== Paramètres du script =============================
            }
            
            #ihe xdm content 
            set ffilenameXDM [open $xdmPath w]
            puts  $ffilenameXDM [msgget $mh] ;  close $ffilenameXDM 
            #pdf content 
            set ffilenamePDF [open $pdfPath w]
            puts  $ffilenamePDF $pdfContent ;  close $ffilenamePDF
            
            
            set parts [mime::initialize -canonical text/html -string $body]

            #Add IHEXDM and PDF
            lappend parts [mime::initialize -canonical "application/zip; name=\"$xdmFilename\"" -encoding base64\
                -header {Content-Disposition attachment} -file $xdmPath]
            lappend parts [mime::initialize -canonical "application/pdf; name=\"$pdfFilename\"" -encoding base64\
                -header {Content-Disposition attachment} -file $pdfPath]

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

        time {}
        shutdown {}
        default {
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}
