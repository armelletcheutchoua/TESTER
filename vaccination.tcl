######################################################################
# Name:        xper_xltp_concat_Rejet_Vaccination
# Purpose:  Concattène les jets lors du chexk d'un fichier CDAR pour le DMP
# UPoC type:    xltp
# Args:     {REJET rejet} 
#           {LIBELLE libelle}
#           {VALEUR valeur}
# Notes:    All data is presented through special variables.  The initial
#       upvar in this proc provides access to the required variables.
#
#       This proc style only works when called from a code fragment
#       within an XLT.

proc xper_xltp_concat_Rejet_Vaccination {} {
    upvar xlateId       xlateId     \
      xlateInList   xlateInList \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes   \
      xlateOutVals  xlateOutVals
           
    set rejet [lindex $xlateInVals 0]
    set libelle [lindex $xlateInVals 1]
    set valeur [lindex $xlateInVals 2]
    #echo rejet $rejet
    #echo libelle $libelle
    #echo valeur $valeur
    set erreur [concat $libelle $valeur]
    set outval [concat $rejet $erreur]
    #echo erreur $erreur
    #echo outval $outval
    
    set xlateOutVals $outval
}

######################################################################
# Name:     check_uuid
# Purpose:  verifie que la valeur passée est bien un UUID
# UPoC type: xltp
######################################################################

proc check_uuid {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName

    set inVal [lindex $xlateInVals 0]
    set outVal ""
    set pattern "\[0-9a-fA-F\]{8}\-\[0-9a-fA-F\]{4}\-\[0-9a-fA-F\]{4}\-\[0-9a-fA-F\]{4}\-\[0-9a-fA-F\]{12}"
    set outVal [regexp -all ${pattern} $inVal]
   # echo uuid $inVal
   # echo outVal $outVal
    set xlateOutVals [list $outVal]
}

######################################################################
# Name:     check_date
# Purpose:  verifie que la date passée est bien au format passé en parametre
#  je converti une 1ère fois la date à checker en LONG et ensuite je repasse en date normale, si le retour <> de 1 alors c'est pas bon
# UPoC type: xltp
######################################################################

proc check_date {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName
    set outVal ""
    set dateIn [lindex $xlateInVals 0]
    set taille [string length $dateIn]
    #echo taille $taille
    if { $taille != 8 } {
        #echo dateinvalide $dateIn
        set outVal 0
    } else {
           set outVal [string equal [clock format [clock scan $dateIn  -format "%Y%m%d"] -format "%Y%m%d"] $dateIn] 
    }
    #echo dateIn $dateIn
    

    #echo outval $outVal
    set xlateOutVals [list $outVal]
}
######################################################################
# Name:     isnumeric_value
# Purpose:  verifie que la valeur passée est bien un entier
#  je converti une 1ère fois la date à checker en LONG et ensuite je repasse en date normale, si le retour <> de 1 alors c'est pas bon
# UPoC type: xltp
######################################################################

proc isnumeric_value {} {
    upvar xlateId             xlateId             \
          xlateInList         xlateInList         \
          xlateInTypes        xlateInTypes        \
          xlateInVals         xlateInVals         \
          xlateOutList        xlateOutList        \
          xlateOutTypes       xlateOutTypes       \
          xlateOutVals        xlateOutVals        \
          xlateConstType      xlateConstType      \
          xlateConfigFileName xlateConfigFileName
    set outVal 0
    set value [lindex $xlateInVals 0]
    echo value $value
    
     if {[string is integer -strict $value]} {
        set outVal 1
    }
  echo outval $outVal

    #echo outval $outVal
    set xlateOutVals [list $outVal]
}