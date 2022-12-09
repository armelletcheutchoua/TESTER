######################################################################
# Name:     xper_xltp_removeSpecialChars
# Purpose:  Retire tous les accents et les caractères spéciaux
# UPoC type: xltp
######################################################################

proc xper_xltp_removeSpecialChars {} {
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
    set outVal [string map {"à" "a" "â" "a" "ä" "a" "ã" "a" "é" "e" "è" "e" "ê" "e" "ë" "e" "î" "i" "ï" "i" "ô" "o" "ö" "o" "õ" "o" "ù" "u" "û" "u" "ü" "u" "ç" "c" \
    "ñ" "n" "À" "A" "Â" "A" "Ä" "A" "Ã" "A" "É" "E" "È" "E" "Ê" "E" "Ë" "E" "Î" "I" "Ï" "I" "Ô" "O" "Ö" "O" "Õ" "O" "Ù" "U" "Û" "U" "Ü" "U" "Ç" "C" "Ñ" "N" \
    "-" " " "_" " " "@" ""} $inVal]
    
    set xlateOutVals [list $outVal]
}

