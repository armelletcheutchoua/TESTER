######################################################################
# Name:     xper_xltp_diffDate
# Purpose:  ajoute ou retrnache le nombre de jopur passé en  parametres à la date
#            - parametres :
#             dateRef date en entrée 
#             nbrJour nombre de jours à ajouter/retirer  format : n ajoute njour/ -n retranche njours
#             formatIn : format de la date d'entrée ( exemple %d/%m/%Y)
#             formatOut : format attendu à la sortie ( exemple %d%m%Y)
#
#           - retour
#             une date au format demandé
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
    echo "dateRef $dateRef"
    echo "nbrJour $nbrJour"
    echo "formatIn $formatIn"
    echo "formatOut $formatOut"
    #nombre de secondes en 24 H = 86400
    set diffTimestamp [expr 86400 * $nbrJour]
     #conversion de la date d'entrée en timestamp
    set dateRefInt [clock scan $dateRef -format "$formatIn"]
    set newDateTimestamp [expr int($dateRefInt + $diffTimestamp)]
    echo "newDateTimestamp $newDateTimestamp"
    set outVal [clock format $newDateTimestamp -format "$formatOut"]    
    
    echo "outVal  $outVal"
    set xlateOutVals [list $outVal]
}
