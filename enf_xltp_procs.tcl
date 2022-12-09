

######################################################################
# Name:		enf_xltp_getFileName
# Purpose:	Permet d'extraire le nom du fichier d'entrée et de l'affecter à la valeur de destination
# UPoC type:	xltp
# Args:		{EXT Extension} (required, default = "", info = Si aucune 
#               valeur n'est renseignée l'extension du fichier d'entrée sera utilisée)
# Notes:	All data is presented through special variables.  The initial
#		upvar in this proc provides access to the required variables.
#
#		This proc style only works when called from a code fragment
#		within an XLT.

proc enf_xltp_getFileName {} {
    upvar xlateId       xlateId		\
	  xlateInList   xlateInList	\
	  xlateInTypes  xlateInTypes	\
	  xlateInVals   xlateInVals	\
	  xlateOutList  xlateOutList	\
	  xlateOutTypes xlateOutTypes	\
	  xlateOutVals  xlateOutVals



    set driverctl [xpmmetaget $xlateId DRIVERCTL]
    set today [clock format [clock seconds] -format "%Y%m%d"]

    # prise de l'information dans la clï¿½ MID
    set v_keydatafile [xpmmetaget $xlateId MID]
    keylget v_keydatafile NUM v_datafile

    set fileName "${today}_${v_datafile}.txt"; catch { set fileName [file tail [keylget driverctl FILENAME]] }
    catch { 
        set extension $xlateInVals
        set fileName [lindex [split $fileName .] end-1]
        append fileName .$extension
    }

    set xlateOutVals $fileName    
}


######################################################################
# Name:		enf_xltp_getMID
# Purpose:		Procédure permettant de récupérer le MID du fichier en 
#		cours
# UPoC type:	xltp
# Args:		none
# Author:	Thibaud LOPEZ - E.Novation (30/01/2014)
#

proc enf_xltp_getMID {} {
    upvar xlateId       xlateId		\
	  xlateInList   xlateInList	\
	  xlateInTypes  xlateInTypes	\
	  xlateInVals   xlateInVals	\
	  xlateOutList  xlateOutList	\
	  xlateOutTypes xlateOutTypes	\
	  xlateOutVals  xlateOutVals

    #Extraction et stockage du MID
    set mid [xpmmetaget $xlateId MID]
    keylget mid NUM xlateOutVals

}
