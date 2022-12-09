######################################################################
# Name:           getUserData_xltp
# Purpose:        Recupere la valeur du champ passÃ¯Â¿Â½ en paramÃ¯Â¿Â½tre ds USER
#                 Et le met ds le xlateOutVals.
# UPoC type:      xltp
# Args:           none
# Notes:          All data is presented through special variables.  The initial
#                 upvar in this proc provides access to the required variables.
#
#                 This proc style only works when called from a code fragment
#                 within an XLT.

 
proc getUserData_xltp {} {
    upvar xlateId       xlateId        \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals

    catch {
        set userData [xpmmetaget $xlateId USERDATA]
        set param $xlateInVals
        set valeur [keylget userData $param]
        set xlateOutVals $valeur
    }
}

######################################################################
# Name:           setUserData_xltp
# Purpose:        Recupere la valeur du champ passÃ¯Â¿Â½ en paramÃ¯Â¿Â½tre ds USER
#                 Et le met ds le xlateOutVals.
# UPoC type:      xltp
# Args:           none
# Notes:          All data is presented through special variables.  The initial
#                 upvar in this proc provides access to the required variables.
#
#                 This proc style only works when called from a code fragment
#                 within an XLT.

 
proc setUserData_xltp {} { 
    upvar xlateId       xlateId        \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals

    set metadata [xpmmetaget $xlateId USERDATA]

    set key [lindex $xlateInVals 0]
    set value [lindex $xlateInVals 1]
    keylset metadata $key $value

    xpmmetaset $xlateId USERDATA $metadata
}
 

######################################################################
# Name:        enf_tps_setUserData_fromProperties
# Purpose:    Affecte des valeurs en USERDATA
# UPoC type:    tps
# Args:     tps keyedlist containing the following keys:
#           MODE    run mode ("start", "run" or "time")
#           MSGID   message handle
#           ARGS    user-supplied arguments:
#                   <describe user-supplied args here>
#
# Returns: tps disposition list:
#          <describe dispositions used here>
#

proc enf_tps_setUserData_fromProperties { args } {
    keylget args MODE mode                  ;# Fetch mode
   global HciSiteDir
    set dispList {}                ;# Nothing to return
    
    keylget args ARGS uargs
    set dmp_path $HciSiteDir"/java_uccs/dmp_properties.yml"
    keylget uargs PATH dmp_path
    switch -exact -- $mode {
        start {
            # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
        }

        run {
        # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
     
            #set nomFichier $HciSiteDir/java_uccs/DMP&P.properties
            # LECTURE DES DONNEES DU FICHIER
            set cont_fic [read_file $dmp_path]
            set keylist ""
            set liste [split $cont_fic "\n"]

        foreach i $liste {
               if { [string length $i] > 0 && ![cequal [string first # [string trim $i]] 0] } {
             set list [split $i =]
             keylset keylist [lindex $list 0] [lindex $list 1]
               }
        } 
     
           msgmetaset $mh USERDATA $keylist     
           lappend dispList "CONTINUE $mh"
        }

        time {
            # Timer-based processing
        # N.B.: there may or may not be a MSGID key in args
        }
        
        shutdown {
        # Doing some clean-up work 
    }
    }

    return $dispList
}



######################################################################
# Name:        setUserData_fromDRIVERCTL
# Purpose:    Affecte des valeurs en USERDATA
# UPoC type:    tps
# Args:     tps keyedlist containing the following keys:
#           MODE    run mode ("start", "run" or "time")
#           MSGID   message handle
#           ARGS    user-supplied arguments:
#                   <describe user-supplied args here>
#
# Returns: tps disposition list:
#          <describe dispositions used here>
#

proc setUserData_fromDRIVERCTL { args } {
    keylget args MODE mode                  ;# Fetch mode
   global HciSiteDir
    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
        }

        run {
      # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
     
            #msgmetaget $mh type
            set orig [msgmetaget $mh ORIGSOURCECONN]
            keylset origthread ORIGSOURCECONN $orig
     
            msgmetaset $mh USERDATA $origthread
    
            lappend dispList "CONTINUE $mh"
        }

        time {
            # Timer-based processing
        # N.B.: there may or may not be a MSGID key in args
        }
        
        shutdown {
        # Doing some clean-up work 
    }
    }

    return $dispList
}

######################################################################
# Name:        setUserData_fromFILENAME
# Purpose:    Affecte le nom du fichier IB en USERDATA
# UPoC type:    tps
# Args:     tps keyedlist containing the following keys:
#           MODE    run mode ("start", "run" or "time")
#           MSGID   message handle
#           ARGS    user-supplied arguments:
#                   <describe user-supplied args here>
#
# Returns: tps disposition list:
#          <describe dispositions used here>
#

proc setUserData_fromFILENAME { args } {
    keylget args MODE mode                  ;# Fetch mode
    global HciSiteDir
    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set path [msgmetaget $mh DRIVERCTL]

            #On extrait la localisation/nom du fichier
            keylget path FILENAME filename

            ##on retire l'extension .xml
            #set filename [string range $filename 0 [expr [string length $filename] -5]]

            #On copie le nom en userdata
            keylset namefic FILENAME [file tail $filename]
            
            msgmetaset $mh USERDATA $namefic
            
            lappend dispList "CONTINUE $mh"
        }

        time {
            # Timer-based processing
        # N.B.: there may or may not be a MSGID key in args
        }
        
        shutdown {
        # Doing some clean-up work 
    }
    }

    return $dispList
}

######################################################################
# Name:        setUserData_withContent
# Purpose:    Affecte le contenu du fichier aux USERDATA
# UPoC type:    tps
# Args:     tps keyedlist containing the following keys:
#           MODE    run mode ("start", "run" or "time")
#           MSGID   message handle
#           ARGS    user-supplied arguments:
#                   <describe user-supplied args here>
#
# Returns: tps disposition list:
#          <describe dispositions used here>
#
proc setUserData_withContent { args } {
    keylget args MODE mode                  ;# Fetch mode
   global HciSiteDir
    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
        }

        run {
      # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh

            set metadata [msgmetaget $mh USERDATA]
            #msgmetaget $mh type
            keylset metadata CONTENT [msgget $mh]                 
            msgmetaset $mh USERDATA $metadata

            #msgdump $mh
            lappend dispList "CONTINUE $mh"
        }

        time {
            # Timer-based processing
        # N.B.: there may or may not be a MSGID key in args
        }
        
        shutdown {
        # Doing some clean-up work 
    }
    }

    return $dispList
}

