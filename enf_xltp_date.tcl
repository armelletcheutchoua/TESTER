######################################################################
# Name:		DD/MM/YYYY_to_YYYYMMDD
# Purpose: Convertit une date DD/MM/YYYY en YYYYMMDD
# UPoC type:	xltp
# Args:		none
# Notes:	All data is presented through special variables.  The initial
#		upvar in this proc provides access to the required variables.
#
#		This proc style only works when called from a code fragment
#		within an XLT.
# History :     09/04/2015 - EnF - TLZ : Correction de l'inversion MM/DD

proc DD/MM/YYYY_to_YYYYMMDD {} {
    upvar xlateId       xlateId		\
	  xlateInList   xlateInList	\
	  xlateInTypes  xlateInTypes	\
	  xlateInVals   xlateInVals	\
	  xlateOutList  xlateOutList	\
	  xlateOutTypes xlateOutTypes	\
	  xlateOutVals  xlateOutVals

    set date [split [lindex $xlateInVals 0] /]
    set MM [lindex $date 1]
    if {[cequal [clength $MM] 1] } {
        set MM 0$MM
    }
    set DD [lindex $date 0]
    if {[cequal [clength $DD] 1] } {
        set DD 0$DD
    }
    set YYYY [csubstr [lindex $date 2] 0 4]
    set xlateOutVals $YYYY$MM$DD
}

######################################################################
# Name:		YYYYMMDD_to_YYYY-MM-DD
# Purpose:	Convertit une date YYYYMMDD en YYYY-MM-DD
# UPoC type:	xltp
# Args:		none
# Notes:	All data is presented through special variables.  The initial
#		upvar in this proc provides access to the required variables.
#
#		This proc style only works when called from a code fragment
#		within an XLT.

proc YYYYMMDD_to_YYYY-MM-DD {} {
    upvar xlateId       xlateId		\
	  xlateInList   xlateInList	\
	  xlateInTypes  xlateInTypes	\
	  xlateInVals   xlateInVals	\
	  xlateOutList  xlateOutList	\
	  xlateOutTypes xlateOutTypes	\
	  xlateOutVals  xlateOutVals

    set date [lindex $xlateInVals 0]
    set YYYY [crange $date 0 3]
    set MM [crange $date 4 5]
    set DD [crange $date 6 7]    
    set xlateOutVals $YYYY-$MM-$DD
}


######################################################################
# Name:		YYYYMMDDHHMISS_to_DD-MM-YYYY_HH:MI:SS
# Purpose:	Convertit une date YYYYMMDDHHMISS en DD-MM-YYYY_HH:MI:SS
# UPoC type:	xltp
# Args:		none
# Notes:	All data is presented through special variables.  The initial
#		upvar in this proc provides access to the required variables.
#
#		This proc style only works when called from a code fragment
#		within an XLT.

proc YYYYMMDDHHMISS_to_DD-MM-YYYY_HH:MI:SS {} {
    upvar xlateId       xlateId		\
	  xlateInList   xlateInList	\
	  xlateInTypes  xlateInTypes	\
	  xlateInVals   xlateInVals	\
	  xlateOutList  xlateOutList	\
	  xlateOutTypes xlateOutTypes	\
	  xlateOutVals  xlateOutVals

    set date [lindex $xlateInVals 0]
    set YYYY [crange $date 0 3]
    set MM [crange $date 4 5]
    set DD [crange $date 6 7]
    set HH [crange $date 7 8]
    set MI [crange $date 9 10]
    set SS [crange $date 11 12]
    set xlateOutVals $DD-$MM-$YYYY $HH:$MI:$SS
}

######################################################################
# Name:		YYYYMMDDHHMISS_to_DD-MM-YYYY_HH:MI:SS
# Purpose:	Convertit une date YYYYMMDDHHMISS en DD-MM-YYYY_HH:MI:SS
# UPoC type:	xltp
# Args:		none
# Notes:	All data is presented through special variables.  The initial
#		upvar in this proc provides access to the required variables.
#
#		This proc style only works when called from a code fragment
#		within an XLT.

proc YYYY-MM-DD_to_DD/MM/YYYY {} {
    upvar xlateId       xlateId		\
	  xlateInList   xlateInList	\
	  xlateInTypes  xlateInTypes	\
	  xlateInVals   xlateInVals	\
	  xlateOutList  xlateOutList	\
	  xlateOutTypes xlateOutTypes	\
	  xlateOutVals  xlateOutVals

    set date [lindex $xlateInVals 0]
    set YYYY [crange $date 0 3]
    set MM [crange $date 4 5]
    set DD [crange $date 6 7]
    set xlateOutVals $DD/$MM/$YYYY
}



######################################################################
# Name:		enf_xltp_setDate_YYYYMMDDHHMISS
# Purpose:	Convertit la date du jour en YYYYMMDDHHMISS
# UPoC type:	xltp
# Args:		none
# Author:		Thibaud LOPEZ - E.Novation (30/01/2014)
#

proc enf_xltp_setDate_YYYYMMDDHHMISS {} {
    upvar xlateId       xlateId		\
	  xlateInList   xlateInList	\
	  xlateInTypes  xlateInTypes	\
	  xlateInVals   xlateInVals	\
	  xlateOutList  xlateOutList	\
	  xlateOutTypes xlateOutTypes	\
	  xlateOutVals  xlateOutVals

    set xlateOutVals [clock format [clock seconds] -format "%Y%m%d%H%M%S"]

}

######################################################################
# Name:     xper_xltp_diffDate
# Purpose:  ajoute ou retranche le nombre de jour passé en  parametres à la date
#            - parametres :
#              dateRef date en entrée 
#              nbrJour nombre de jours à ajouter/retirer  format : n ajoute njour / -n retranche njours
#              formatIn : format de la date d'entrée ( exemple %d/%m/%Y)
#              formatOut : format attendu à la sortie ( exemple %d%m%Y)
#
#           - retour
#             une date au format demandé
#
# Author:		Michel LAMBERT - Xperis (03/03/2021)
# UPoC type: xltp
######################################################################

proc xper_xltp_diffDate {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName

    set dateRef [lindex $xlateInVals 0] 
    set nbrJour [lindex $xlateInVals 1]
    set formatIn [lindex $xlateInVals 2]
    set formatOut [lindex $xlateInVals 3]
    #echo "dateRef $dateRef"
    #echo "nbrJour $nbrJour"
    #echo "formatIn $formatIn"
    #echo "formatOut $formatOut"
	
    #nombre de secondes en 24 H = 86400
    set diffTimestamp [expr 86400 * $nbrJour]
     #conversion de la date d'entrée en timestamp
    set dateRefInt [clock scan $dateRef -format "$formatIn"]
    set newDateTimestamp [expr int($dateRefInt + $diffTimestamp)]
    #echo "newDateTimestamp $newDateTimestamp"
    set outVal [clock format $newDateTimestamp -format "$formatOut"]    
    
    #echo "outVal  $outVal"
    set xlateOutVals [list $outVal]
}




######################################################################
# Name:     xper_xltp_getTimestamp
# Purpose:  retourne le timestamp de la date passée en parametre
#            - parametres 
#             dateRef : date à convertir
#             formatIn : format de la date d'entrée ( exemple %d/%m/%Y)
#
#           - retour
#             une date au format timestamp
# Author:		Michel LAMBERT - Xperis (03/03/2021)
# UPoC type: xltp
######################################################################

proc xper_xltp_getTimestamp {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName

    set dateRef [lindex $xlateInVals 0]
    set formatIn [lindex $xlateInVals 1]
     #conversion de la date d'entrée en timestamp
    set outVal [clock scan $dateRef -format "$formatIn"]
    set xlateOutVals [list $outVal]
}


######################################################################
# Name:     xper_xltp_dateFromTimestamp 
# Purpose:  retourne une date au format demandée à partir d'un timestamp
#            - parametres :
#              dateRefTimestamp : date au format timlestamp
#              formatOut : format de la datede sortie ( exemple %d/%m/%Y)
#
#           - retour
#             une date au format demandé
# Author:		Michel LAMBERT - Xperis (03/03/2021)
# UPoC type: xltp
######################################################################

proc xper_xltp_dateFromTimestamp {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName

    set dateRefTimestamp [lindex $xlateInVals 0]
    set formatOut [lindex $xlateInVals 1]
    set outVal [clock format $dateRefTimestamp -format "$formatOut"]    
    set xlateOutVals [list $outVal]
}
