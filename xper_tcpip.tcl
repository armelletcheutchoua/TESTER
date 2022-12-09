######################################################################
# Name:    xper_cl_check_ack
# Purpose:    Validate an inbound reply, resend msg if necessary.
# UPoC type:    tps
# Args:     tps keyedlist containing the following keys:
#           MODE    run mode ("start" or "run")
#           MSGID   message handle
#   Choisir le nombre de tentative de représentation N d'un message en AR ou CR.
#       {REPLY_COUNT N} par defaut 3 tentative.
#   Pour une représentation a l'infinie {REPLY_COUNT -1}
#   Choisir de transmettre l'acquittement sur la route {BYPASS ROUTE}ou sur la route reply {BYPASS REPLY} par default none, l'acquittement est supprimé après traitement
#   {REPLY_COUNT 3} {BYPASS NONE} {DEBUG 0}
#   {REPLY_COUNT 0} {BYPASS ROUTE} {DEBUG 0} 
#   {REPLY_COUNT -1} {BYPASS REPLY} {DEBUG 1}
#   {IGNORAR 1} {IGNOREAE 1}
#   {IGNORAR 1}
#
# Returns: tps disposition list:
#        KILLREPLY = Always kill reply message
#        PROTO      = reply not OK, count not exceeded, resend 
#                    original message
#        ERROR      = reply not OK, count is exceeded, send 
#                    original message to Error Database
#
# Notes:
#        Needs the following procs to run correctly:
#            cl_sendOK_save (OB DATA TPS)
#            cl_resend_ob_msg (REPLY GEN TPS)
#
# Check the HL7 acknowledgement received and take action as below:
#
# If AA or CA, Kill saved message and kill reply
#
# If AE or CE, non-recoverable error.  Kill reply and place original
# (saved) message in database (Notify user)
#
# If AR or CR, Possible recoverable error.  Attempt to resend original
# (saved) message up to three times.  If receive more than 3 AR/CR
# replies, treat as AE/CE above.
#  
# History : IHB 08/04/2022 Developpement initial
proc xper_cl_check_ack { args } {
    keylget args MODE mode                  ;# Fetch mode
    keylget args CONTEXT ctx
    keylget args ARGS uargs
    
    # OBMSGID argument contains handle of outbound message
    # send_cnt is a count of how many resends

    global HciConnName send_cnt
    set debug 0     ; keylget uargs DEBUG debug
    set reply_count "3"; keylget uargs REPLY_COUNT reply_count
    set bypass "NONE"; keylget uargs BYPASS bypass
    set ignorar "0"; keylget uargs IGNORAR ignorar
    set ignorae "0"; keylget uargs IGNORAE ignorae
    if {$debug} { 
        echo bypass : $bypass
        echo reply_count : $reply_count
    }
    set module "$HciConnName/[lindex [info level 1] 0]"

    switch -exact -- $mode {
    
        start {
            set send_cnt 0    ;# Init resend counter
    
            return ""
        }
    
        run {
            keylget args MSGID mh
            
            # Modify to work with CL 5.6
            set my_mh {}
            keylget args OBMSGID my_mh    ;# Get handle of outbound message
    
            # Get a copy of the reply message
            set msg [msgget $mh]
            
            # Get a copy of the orig message
            set msgOrig [msgget $my_mh]
            
            
            # Split it into HL7 segments and fields
            # Field separator normally "|"
            set fldsep [string index $msg 3]
            set fldsepOrig [string index $msgOrig 3]
            # Get segments
            set segments [split $msg \r]
            set segmentsOrig [split $msgOrig \r]
            # Get fields from reply MSH segment
            set mshflds [split [lindex $segments 0] $fldsep]
            set mshfldsOrig [split [lindex $segmentsOrig 0] $fldsepOrig]
            # Get ACK type from reply MSA segment and message, if one
            set idmsg [lindex $mshflds 9]
            set idmsgOrig [lindex $mshfldsOrig 9]
            # Get fields from MSA segment
            set msaflds [split [lindex $segments 1] $fldsep]
            # Get ACK type from MSA segment and message, if one
            set acktype [lindex $msaflds 1]
            set ackmsg [lindex $msaflds 3]
    
            if {[lempty $ackmsg]} { set ackmsg "NO MESSAGE" }
    
            # Look for all possible hl-7 ack types, 
            # take appropriate action
            if {![cequal $bypass NONE]} {
                set acktype BYPASS
            }
            
            if {![cequal $idmsg $idmsgOrig]} {
                echo l'ID de l'acquittement ne correspond pas au message transmis
                set acktype IDKO
            }
    
    
            
            switch -exact -- $acktype {
                IDKO {
                    set send_cnt 0         ;# Init counter
                    return "{KILLREPLY $mh} {PROTO $my_mh}"
                    
                }
                
                BYPASS {
                    # Good ACK - Clean up
                    set send_cnt 0         ;# Init counter
                    switch -exact -- $bypass {
                        ROUTE {
                            return "{OVER $mh} {KILL $my_mh}"
                            if {$debug} { Etat BYPASS - ROUTE }
                        }
                        REPLY {
                            return "{CONTINUE $mh} {KILL $my_mh}"
                            if {$debug} { Etat BYPASS - REPLY }
                        }
                    }
                    
                }
                
                AA - CA {
                    # Good ACK - Clean up
                    set send_cnt 0         ;# Init counter
                    return "{KILLREPLY $mh} {KILL $my_mh}"
                    
                }
        
                AR - CR {
                    if {$ignorar} {
                        echo "\n$module : Received AR response"
                        echo "Message KILLED"
                        echo "Reply is:"
                        echo $msg\n\n
                        echo "Message is:"
                        echo [msgget $my_mh]\n
                        return "{KILLREPLY $mh} {KILL $my_mh}"
                    } else {
                        
                        # AR - resend up to 3 times0
            
                        # Have we sent more than 3 times?
                        if {$send_cnt > $reply_count && $reply_count != -1} {
                
                            # Init counter
                            set send_cnt 0
                
                            # Tell em bout it and put reason in metadata
                            echo "\n$module: Three consecutive AR\
                                responses - $ackmsg"
                            echo "Message to Error Database"
                            echo "Reply is:"
                            echo $msg\n\n
                            echo "Message is:"
                            echo [msgget $my_mh]\n
                
                            # Put reason in metadata and send message to
                            # Error database
                
                            msgmetaset $my_mh USERDATA "Exceeded\
                                Application Reject (AR) retrys - $ackmsg"
                
                            return "{KILLREPLY $mh} {ERROR $my_mh}"
                            
                        } else {
                
                            # We haven't resent enough - do it again
                            # First, increment counter
                
                            incr send_cnt
                            return "{KILLREPLY $mh} {PROTO $my_mh}"
                        }
                    }
                }
    
                AE - CE {
                    if {$ignorae} {
                        echo "\n$module : Received AE response"
                        echo "Message KILLED"
                        echo "Reply is:"
                        echo $msg\n\n
                        echo "Message is:"
                        echo [msgget $my_mh]\n
                        return "{KILLREPLY $mh} {KILL $my_mh}"
                    } else {
                        # AE in non-recoverable - just send to ERROR database
            
                        # Init Counter
                        set send_cnt 0
            
                        # Tell em bout it and put reason in metadata
            
                        echo "\n$module : Received AE response"
                        echo "Message to Error Database"
                        echo "Reply is:"
                        echo $msg\n\n
                        echo "Message is:"
                        echo [msgget $my_mh]\n
            
                        # Put message in metadata and message in Error DB
            
                        msgmetaset $my_mh USERDATA "Application Error\
                            (AE) - $ackmsg"
            
                        return "{KILLREPLY $mh} {ERROR $my_mh}"
                    }
                }
        
                default {
                    # If we get invalid ACK, trea it as an 
                    # AE - non recoverable
        
                    # Init Counter
                    set send_cnt 0
        
                    # Tell em bout it and put reason in metadata
        
                    echo "\n$module : Received Invalid response"
                    echo "Message to Error Database"
                    echo "Reply is:"
                    echo $msg\n\n
                    echo "Message is:"
                    echo [msgget $my_mh]\n
        
                    # Put message in metadata and message in Error DB
                    msgmetaset $my_mh USERDATA "Invalid response -\
                        [msgget $mh]"
        
                    return "{KILLREPLY $mh} {ERROR $my_mh}"
                }
            }
        }
    }
}
