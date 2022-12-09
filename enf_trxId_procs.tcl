




######################################################################
# Name:        enf_trxid_tbllookup
# Purpose:     <description>
# UPoC type:   trxid
# Args:     msgId = message handle
#           args  = (optional) user arguments 
# Returns:  The message's transaction ID
#
# Notes:
#    The message is both modify- and destroy-locked -- attempts to modify
#    or destroy it will error out.
#

proc enf_trxid_tbllookup { mh {args {}} } {
    global HciConnName                          ;# Name of thread
    set module "enf_trxid_tbllookup/$HciConnName"   ;# Use this before every echo/puts
    set msgSrcThd [msgmetaget $mh SOURCECONN]   ;# Name of source thread where message came from
    
    set debug 0; keylget args DEBUG debug
    set tblname ""; keylget args TABLE tblname
    set fieldLocation ""; keylget args FIELDLOCATION fieldLocation
    set fieldLocationSeg ""
    set fieldLocationField ""
    set fieldLocationSubField ""
    set fieldLocationSubSubField ""
    set trxId "trxId"
    if { ![cequal $fieldLocation ""] } {
        set fieldLocationSeg [lindex [split $fieldLocation .] 0]
        set fieldLocationField [lindex [split $fieldLocation .] 1]
        set fieldLocationSubField [lindex [split $fieldLocation .] 2]
        set fieldLocationSubSubField [lindex [split $fieldLocation .] 3]
        if {$debug} {
            echo fieldLocationSeg : $fieldLocationSeg
            echo fieldLocationField : $fieldLocationField
            echo fieldLocationSubField : $fieldLocationSubField
            echo fieldLocationSubSubField : $fieldLocationSubSubField
        }
        set fileContent [msgget $mh]

        if {$debug} {
            echo fileContent : $fileContent
        }

        # Get MSH.1 OR H.1 (Separator Characters)
        # Get MSH 1.1 OR H.1.1 (Subflied Separator Character)
        set sep_char [lindex [split $fileContent |] 1]
        set f_sep_char |
        set sf_sep_char [crange $sep_char 0 0]
        set ssf_sep_char [crange $sep_char 1 1]

        if {$debug} {
            echo sep_char : $sep_char
            echo f_sep_char : $f_sep_char
            echo sf_sep_char : $sf_sep_char
            echo ssf_sep_char : $ssf_sep_char
        }

        # Get Line Separator Characters
        if {[string first \r $fileContent] > -1} {
            if {[string first \n $fileContent] > -1} {
                set line_sep_char "\r\n"
                echo line_sep_char "\\r\\n"
            } else {
                set line_sep_char "\r"
                echo line_sep_char "\\r"
            }
        } elseif {[string first \n $fileContent] > -1} {
            set line_sep_char "\n"
            echo line_sep_char "\\n"
        }


        if {$debug} {
            set split [split $fileContent $line_sep_char]
            echo split : ${split}
            echo llength : [llength $split]
        }

        foreach ligne [split $fileContent $line_sep_char] {

            if {$debug} {
                echo ligne : $ligne
                echo isThere : [string first $fieldLocationSeg $ligne]
            }

            set fieldContent "KO"
            if {[string first $fieldLocationSeg $ligne] > -1} {

                if {$debug} {
                    echo clength fieldLocationSubSubField : [clength $fieldLocationSubSubField]
                    echo clength fieldLocationSubField : [clength $fieldLocationSubField]
                    echo clength fieldLocationField : [clength $fieldLocationField]
                }

                if {[clength $fieldLocationSubSubField] > 0} {
                        set fieldContent [lindex [split [lindex [split [lindex [split $ligne $f_sep_char] $fieldLocationField] $sf_sep_char] $fieldLocationSubField] $ssf_sep_char] $fieldLocationSubSubField]
                } elseif {[clength $fieldLocationSubField] > 0} {
                    set fieldContent [lindex [split [lindex [split $ligne $f_sep_char] $fieldLocationField] $sf_sep_char] $fieldLocationSubField]
                } elseif {[clength $fieldLocationField] > 0} {
                    set fieldContent [lindex [split $ligne $f_sep_char] $fieldLocationField]
                } else {
                    set fieldContent "KO"
                }
                
                if {$debug} {
                    echo fieldContent : $fieldContent
                }

                break
            }
        }
                
        set trxId [tbllookup ${tblname} ${fieldContent}]

        if {$debug} {
            echo TRXID: $trxId
        }
    }
    return $trxId                ;# return it
}

######################################################################
# Name:        enf_trxid_getfilename
# Purpose:    <Procédure qui retourne comme élément de routage le nom du fichier transporté>
# UPoC type:    trxid
# Args:        msgId    = message handle
# Returns:    The message's transaction ID
#
# Notes:
#    The message is both modify- and destroy-locked -- attempts to modify
#    or destroy it will error out.
#

proc enf_trxid_getfilename { mh } {
    global HciConnName                          ;# Name of thread
    set module "enf_trxid_getfilename/$HciConnName"   ;# Use this before every echo/puts
    set msgSrcThd [msgmetaget $mh SOURCECONN]   ;# Name of source thread where message came from
                                                ;# Use this before necessary echo/puts
    
    set driver [msgmetaget $mh DRIVERCTL]
    set fileName [file tail [keylget driver FILENAME]]
    set trxId $fileName              ;# determine the trxid
    return $trxId                ;# return it
}
