######################################################################
# Name:        xper_trxId_file_extension
# Purpose:    Retourne l'extension du fichier IB pour l'utiliser comme trxId
# UPoC type:    trxid
# Args:    none
# Returns:    The message's transaction ID
# Notes:
#    The message is both modify- and destroy-locked -- attempts to modify
#    or destroy it will error out.

proc xper_trxId_file_extension { mh } {
    global HciConnName                          ;# Name of thread
    set module "xper_trxId_file_extension/$HciConnName"   ;# Use this before every echo/puts
    set msgSrcThd [msgmetaget $mh SOURCECONN]   ;# Name of source thread where message came from
                                                ;# Use this before necessary echo/puts

    set trxId trxid              ;# determine the trxid

    set driver [msgmetaget $mh DRIVERCTL]
    if { [catch {set filename [file tail [keylget driver FILENAME]]} err] } {
        if { [catch {set filename [file tail [keylget driver FILESET.OBFILE]]} err] } {
            error "Impossible de retrouver le nom d'origine du message"
        }
    }
    set ext [lindex [split $filename "."] 1]
    set trxId [string toupper $ext]
      
    return $trxId                ;# return it
}
