######################################################################
# hl7Raw_ack - Generate reply to hl7 messages
###############################################################
#                                                             #
#                           NOTICE                            #
#                                                             #
#   THIS SOFTWARE IS THE PROPERTY OF AND CONTAINS             #
#   CONFIDENTIAL INFORMATION OF INFOR AND/OR ITS AFFILIATES   #
#   OR SUBSIDIARIES AND SHALL NOT BE DISCLOSED WITHOUT PRIOR  #
#   WRITTEN PERMISSION. LICENSED CUSTOMERS MAY COPY AND       #
#   ADAPT THIS SOFTWARE FOR THEIR OWN USE IN ACCORDANCE WITH  #
#   THE TERMS OF THEIR SOFTWARE LICENSE AGREEMENT.            #
#   ALL OTHER RIGHTS RESERVED.                                #
#                                                             #
#   (c) COPYRIGHT <2020> INFOR.  ALL RIGHTS RESERVED.         #
#   THE WORD AND DESIGN MARKS SET FORTH HEREIN ARE            #
#   TRADEMARKS AND/OR REGISTERED TRADEMARKS OF INFOR          #
#   AND/OR ITS AFFILIATES AND SUBSIDIARIES. ALL RIGHTS        #
#   RESERVED.  ALL OTHER TRADEMARKS LISTED HEREIN ARE         #
#   THE PROPERTY OF THEIR RESPECTIVE OWNERS.                  #
#                                                             #
###############################################################
#
# Args: tps keyedlist containing:
#   MODE    run mode ("start" or "run")
#   MSGID   message handle
#   CONTEXT Should be sms_ib_data
#
# Returns: tps keyed list containing
#   OVER        The message handle of ob reply msg
#   CONTINUE    The received message if valid
#   KILL        The received message if invalid
#
# Notes:
#
# This proc is designed for those cases when the use of a variant
# is not desired or wanted.  For example, where hl7 messages
# will be raw routed.
#
# The proc will send an hl7 ACK for each received message.
# The MSA segment will contain an AA if the message is valid
# or an AR if invalid.  If valid the incoming message is
# continued, else it is killed.
#
# Very rudimentary validation is performed.  If the MSH segment
# is completely missing or in the wrong place is about all
# the validation that is performed.
#
# If the fields exist, sending and receiving applications and
# facilities will be reversed and returned.  Also the msg
# control ID if it exists will be returned.
#
# Updated to use more modern Tcl commands: namespaces, arrays, etc.
#
# Initialize ACKMSH and ACKMSA variables so they aren't duplicated
# on proc reload
#
#####################################################################

proc hl7Raw_ack_OK { args } {
    global HciConnName

    set mode [keylget args MODE]
    set mod "$HciConnName/[lindex [info level 1] 0]"

    set context [keylget args CONTEXT]

    switch -exact -- $mode {
    start {
        return ""   ;# Nothing specific
    }

    run {
        set mh [keylget args MSGID]    ;# Message header

        # If this message was resent (as opposed to received
        # by a protocol driver), don't send an ACK.
        set flags [msgmetaget $mh FLAGS]

        if { "[lsearch -exact $flags is_resent]" ne "-1" } {
            return "{CONTINUE $mh}"
        }

        # If this message was worked as inbound, don't send an ACK.
        if { "[lsearch -exact $flags work_as_inbound]" ne "-1" } {
            echo "Work as inbound, No ACK"
            return "{CONTINUE $mh}"
        }
        set msg [msgget $mh]           ;# The message

        # Make sure we are in proper context
        if {![string equal $context sms_ib_data]} {
            echo "\n\nERROR!! $mod: wrong context $context"
            echo "CONTINUE MESSAGE -- NO ACTION TAKEN\n\n"
            return "{CONTINUE $mh}"
        }

        # Set OB reply
        set obMsg [msgcreate -type reply]
        msgset $obMsg [ackSubs::buildACKOK $msg]

        # Now continue original message and send response
        # unless there was an error, then kill original

        # For multiserver
        msgmetaset $obMsg DRIVERCTL [msgmetaget $mh DRIVERCTL]

        if {[string equal $ackSubs::ackType "AA"]} {
            return "{CONTINUE $mh} {OVER $obMsg}"
        } else {
            echo "\n\n$mod: Invalid HL7 message, sending NAK. Message is:\n"
            echo "$msg\n\n"
            return "{KILL $mh} {OVER $obMsg}"
        }

    }
    }
}

namespace eval ackSubs {

    # Define a template for an HL7 ACK message.  Define fields as lists
    # So actual field separator may be inserted. Note that Receiving
    # and Sending application and facility are reversed
    set ACKMSH ""
    set ACKMSA ""

    lappend ACKMSH {MSH} {$sepChars} {$rxAppl} {$rxFac} {$sndAppl} {$sndFac}
    lappend ACKMSH {$dttm} {} {ACK} {$ctrlID} {$procID} {$version}
    lappend ACKMSA {MSA} {$ackType} {$ctrlID} {$errMsg}

    # Set up  arrays with all the defaults
    array set VARARAY [list sepChars "^~\\&" rxAppl CLOVERLEAF rxFac {}]
    array set VARARAY [list sndAppl {} sndFac {} dttm {}  ackType AA]
    array set VARARAY [list ctrlID {} procID P version 2.3 errMsg {}]

    proc expandBackslash {str} {
        upvar $str srcStr
        set srcStr [string map {\\ \\\\} $srcStr]
        set srcStr [string map {"\{" "\\\{"} $srcStr]
        set srcStr [string map {"\}" "\\\}"} $srcStr]
    }
    proc cutBackslash {msg} {
        upvar $msg srcMsg
        set srcMsg [string map {"\\\{" "\{"} $srcMsg]
        set srcMsg [string map {"\\\}" "\}"} $srcMsg]
        set srcMsg [string map {\\\\ \\} $srcMsg]
    }

    proc buildACK {msg} {
        variable ACKMSH     ;# The MSH template for the ACK
        variable ACKMSA     ;# The MSA template for the ACK
        variable VARARAY    ;# Array with variable defaults
        variable ackType AA ;# The type of ACK AA or AR

        # Set default variables
        foreach var [array names VARARAY] {set $var $VARARAY($var)}

        # Assume field separator is bar (|)
        set fldSep |

        # Set Current date/time
        set dttm [clock format [clock seconds] -format "%Y%m%d%H%M%S"]

        # Parse the IB message.  If it looks like an HL7 message, its good
        if {[regexp -- {^MSH} $msg]} {

            # Get real field separator
            set fldSep [string index $msg 3]

            # Get the IB MSH segment fields
            set ibMSH [split [lindex [split $msg \r] 0] $fldSep]

            # Get the encoding chars and rx/send appl/fac
            lassign $ibMSH {} sepChars sndAppl sndFac rxAppl rxFac

            # Get the control ID
            set ctrlID [lindex $ibMSH 9]

            # Get the Processing ID
            set procID [lindex $ibMSH 10]

            # Get the Version
            set version [lindex $ibMSH 11]

            expandBackslash sepChars
            expandBackslash rxAppl
            expandBackslash rxFac
            expandBackslash sndAppl
            expandBackslash sndFac
            expandBackslash ctrlID
            expandBackslash procID
            expandBackslash version

        } else {

            # Invalid HL7 message
            set ackType AR
            set errMsg "Invalid HL7 message - does not start with MSH"
        }

        # Build the ACK
        # Substitute the variables and build complete message
        set obMSH [string trimright [join [subst $ACKMSH] $fldSep] $fldSep]
        set obMSA [string trimright [join [subst $ACKMSA] $fldSep] $fldSep]
        cutBackslash obMSH
        cutBackslash obMSA

        return "$obMSH\r$obMSA\r"
    }
    proc buildACKOK {msg} {
        variable ACKMSH     ;# The MSH template for the ACK
        variable ACKMSA     ;# The MSA template for the ACK
        variable VARARAY    ;# Array with variable defaults
        variable ackType AA ;# The type of ACK AA or AR

        # Set default variables
        foreach var [array names VARARAY] {set $var $VARARAY($var)}

        # Assume field separator is bar (|)
        set fldSep |

        # Set Current date/time
        set dttm [clock format [clock seconds] -format "%Y%m%d%H%M%S"]

        # Parse the IB message.  If it looks like an HL7 message, its good


        # Build the ACK
        # Substitute the variables and build complete message
        set obMSH [string trimright [join [subst $ACKMSH] $fldSep] $fldSep]
        set obMSA [string trimright [join [subst $ACKMSA] $fldSep] $fldSep]
        cutBackslash obMSH
        cutBackslash obMSA

        return "$obMSH\r$obMSA\r"
    }	
}
