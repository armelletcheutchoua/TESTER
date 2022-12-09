######################################################################
# Name:      batch_carto_netconfig
# Purpose:   <description>
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

proc batch_carto_netconfig { args } {

    package require base64

            netconfig load
            # Chargement des process
            set processes [netconfig get process list]
            #echo $processes
             file mkdir $::env(HCIROOT)/CARTO
            set filename $::env(HCIROOT)/CARTO/
            append filename rapport[clock format [clock seconds] -format %Y%m%d%H%M].csv
            set CSV ""
            if {![file exist $filename]} {
                append CSV "Protocole D;Parametres D\r\n" 
            }
            foreach process $processes {
                echo "Process : $process"
                set threads [netconfig get process connections $process]
                #echo $threads
                foreach thread $threads {
                    echo "    Thread : $thread"
                    set destList ""
                    set server ""
                    set directory ""
                    set dest ""
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
                            keylget threadconfig PROTOCOL.FTPPORT port
                            if { [cequal $port "ftp"] } {
                                set port "21"
                            }
                            #keylget threadconfig PROTOCOL.FTPPASSWD password
                            keylget threadconfig PROTOCOL.FTPIBDIR directory
                            if { [cequal $directory ""] } {
                                keylget threadconfig PROTOCOL.FTPOBDIR directory
                            } 
                            # specificite 6.2
                            # bug hcicrypt à revoir 
                            #catch {exec hcicrypt decrypt $password} password
                            #set password  [::base64::decode $password]
                            set server ftp://${login}:@${host}:${port}
                            echo "        Adresse : $server"
                        }
                        "fileset/local-tps" {
                            keylget threadconfig PROTOCOL.IBDIR directory
                            if { [cequal $directory ""] } {
                                keylget threadconfig PROTOCOL.OBDIR directory
                            }
                            echo "        Adresse : $directory"
                        }
                        "fileset/local-oldest" {
                            keylget threadconfig PROTOCOL.IBDIR directory
                            if { [cequal $directory ""] } {
                                keylget threadconfig PROTOCOL.OBDIR directory
                            }
                            echo "        Adresse : $directory"
                        }
                        "file" {
                            keylget threadconfig PROTOCOL.INFILE directory
                            if { [cequal $directory ""] } {
                                keylget threadconfig PROTOCOL.OUTFILE directory
                            }
                            echo "        Adresse : $directory"
                        }
                        "database-inbound" {
                            keylget threadconfig PROTOCOL.IB_ACTION.CONTENT directory
                            echo "        Requete : $directory"
                        }
                        "database-outbound" {
                            keylget threadconfig PROTOCOL.OB_ACTION.CONTENT directory
                            echo "        Requete : $directory"
                        }
                        "tcpip" {
                            keylget threadconfig PROTOCOL.HOST host
                            keylget threadconfig PROTOCOL.PORT port
                            if { [cequal $host ""] } {
                                set server "listening localhost:${port}"
                            } else {
                                set server ${host}:${port}
                            }
                            echo "        Adresse : $server"
                        }
                        "pdl-tcpip" {
                            keylget threadconfig PROTOCOL.HOST host
                            keylget threadconfig PROTOCOL.PORT port
                            if { [cequal $host ""] } {
                                set server "listening localhost:${port}"
                            } else {
                                set server ${host}:${port}
                            }
                            echo "        Adresse : $server"
                        }
                        default {
                            echo "        Erreur : Protocole non repertorie"
                        }
                    }
                    keylget threadconfig DATAXLATE xlate

                    # Gestion du routage
                    foreach dest $xlate {
                        keylget dest ROUTE_DETAILS dest
                        set dest [lindex $dest 0]
                        keylget dest TYPE routeType
                        switch $routeType {
                            "generate" {set dest "procedure"}
                            "raw" {
                                keylget dest DEST dest
                                echo "        Transport vers: $dest"
                            }
                            default {
                                keylget dest DEST dest
                                echo "        Transformation vers : $dest"
                            }
                        }
                        append destList $dest ,
                    }
                    if {$protocol eq {tcpip}} { 
                        set protocol TCP/IP
                        }
                    if {$protocol eq {upoc}} { 
                        set protocol "Base de donnees"
                        }
                    if {$protocol eq {fileset/local-tps}} { 
                        set protocol "Repertoire partage"
                        }
                    if {$protocol eq {fileset/local-oldest}} { 
                        set protocol "Repertoire partage"
                        }
                    if {$protocol eq {fileset/ftp}} { 
                        set protocol FTP
                        }
                    if {$protocol eq {fileset/sftp}} { 
                        set protocol SFTP
                        }
                    if {$protocol eq {fileset/ftps}} { 
                        set protocol FTPS
                        }
                    if {$protocol eq {database-inbound}} { 
                        set protocol "Base de donnees"
                        }
                    if {$protocol eq {fdatabase-outbound}} { 
                        set protocol "Base de donnees"
                        }
                    if {$protocol eq {pdl-tcpip}} { 
                        set protocol TCP/IP
                        }    
                    set dir "\nURL : ${directory}"
                    if {${directory} eq ""} {
                    set dir ""
                    }
                    if {${directory} eq "nul:"} {
                    set dir ""
                    }
                    set serv "\nServeur: ${server}"
                    if {${server} eq ""} {
                    set serv ""
                    }
                    #echo "        Export CSV : ${process};${thread};${protocol};${server};${directory};${destList}"
                    #append CSV "${protocol};\"test\ntest\ntest\ntest\"\r\n"
                    append CSV "${protocol};\"Process Cloverleaf: ${process}\nThread Cloverleaf: ${thread}${serv}${dir}\"\r\n"
                    
                }
                echo ""
            }
            #echo $CSV
           echo test
            # open the filename for writing
            set fileId [open $filename "a+"]
            # send the data to the file -
            #  omitting '-nonewline' will result in an extra newline
            # at the end of the file
            fconfigure $fileId -translation lf
            puts $fileId $CSV
            # close the file, ensuring the data is written out before you continue
            #  with processing.
            close $fileId
}

#batch_carto_netconfig
