#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.02		// version number of Migrate()
#include <Waves Average>

// LoadMigration contains 3 procedures to analyse cell migration in IgorPro
// Use ImageJ to track the cells. Outputs from tracking are saved in sheets in an Excel Workbook, 1 per condition
// Execute Migrate().
// This function will trigger the load and the analysis of cell migration via two functions
// LoadMigration() - will load all sheets of migration data from a specified excel file
// MakeTracks() - does the analysis
// NOTE no headers in Excel file. Keep data to columns A-H, max of 1000 rows
// columns are
// A - 0 - ImageJ row
// B - 1 - Track No
// C - 2 - Slice No
// D - 3 - x (in px)
// E - 4 - y (in px)
// F - 5 - distance
// G - 6 - velocity
// H - 7 - pixel value

// Menu item for easy execution
Menu "Macros"
	"Cell Migration...",  Migrate()
End

// Colours are taken from Paul Tol SRON stylesheet
// Define colours
StrConstant SRON_1 = "0x4477aa;"
StrConstant SRON_2 = "0x4477aa; 0xcc6677;"
StrConstant SRON_3 = "0x4477aa; 0xddcc77; 0xcc6677;"
StrConstant SRON_4 = "0x4477aa; 0x117733; 0xddcc77; 0xcc6677;"
StrConstant SRON_5 = "0x332288; 0x88ccee; 0x117733; 0xddcc77; 0xcc6677;"
StrConstant SRON_6 = "0x332288; 0x88ccee; 0x117733; 0xddcc77; 0xcc6677; 0xaa4499;"
StrConstant SRON_7 = "0x332288; 0x88ccee; 0x44aa99; 0x117733; 0xddcc77; 0xcc6677; 0xaa4499;"
StrConstant SRON_8 = "0x332288; 0x88ccee; 0x44aa99; 0x117733; 0x999933; 0xddcc77; 0xcc6677; 0xaa4499;"
StrConstant SRON_9 = "0x332288; 0x88ccee; 0x44aa99; 0x117733; 0x999933; 0xddcc77; 0xcc6677; 0x882255; 0xaa4499;"
StrConstant SRON_10 = "0x332288; 0x88ccee; 0x44aa99; 0x117733; 0x999933; 0xddcc77; 0x661100; 0xcc6677; 0x882255; 0xaa4499;"
StrConstant SRON_11 = "0x332288; 0x6699cc; 0x88ccee; 0x44aa99; 0x117733; 0x999933; 0xddcc77; 0x661100; 0xcc6677; 0x882255; 0xaa4499;"
StrConstant SRON_12 = "0x332288; 0x6699cc; 0x88ccee; 0x44aa99; 0x117733; 0x999933; 0xddcc77; 0x661100; 0xcc6677; 0xaa4466; 0x882255; 0xaa4499;"

//// @param hex		variable in hexadecimal
Function hexcolor_red(hex)
	Variable hex
	return byte_value(hex, 2) * 2^8
End

//// @param hex		variable in hexadecimal
Function hexcolor_green(hex)
	Variable hex
	return byte_value(hex, 1) * 2^8
End

//// @param hex		variable in hexadecimal
Function hexcolor_blue(hex)
	Variable hex
	return byte_value(hex, 0) * 2^8
End

//// @param data	variable in hexadecimal
//// @param byte	variable to determine R, G or B value
Static Function byte_value(data, byte)
	Variable data
	Variable byte
	return (data & (0xFF * (2^(8*byte)))) / (2^(8*byte))
End

// Loads the data and performs migration analysis
Function Migrate()
	
	Variable cond = 2
	Variable tStep = 20
	Variable pxSize = 0.32
	
	Prompt cond, "How many conditions?"
	Prompt tStep, "Time interval (min)"
	Prompt  pxSize, "Pixel size (�m)"
	DoPrompt "Specify", cond, tStep, pxSize
	
	// kill all windows and waves before we start
	String fullList = WinList("*", ";","WIN:3")
	String name
	Variable i
 
	for(i = 0; i < ItemsInList(fullList); i += 1)
		name = StringFromList(i, fullList)
		DoWindow/K $name		
	endfor
	
	KillWaves/A/Z
	
	// Pick colours from SRON palettes
	String pal
	if(cond == 1)
		pal = SRON_1
	elseif(cond == 2)
		pal = SRON_2
	elseif(cond == 3)
		pal = SRON_3
	elseif(cond == 4)
		pal = SRON_4
	elseif(cond == 5)
		pal = SRON_5
	elseif(cond == 6)
		pal = SRON_6
	elseif(cond == 7)
		pal = SRON_7
	elseif(cond == 8)
		pal = SRON_8
	elseif(cond == 9)
		pal = SRON_9
	elseif(cond == 10)
		pal = SRON_10
	elseif(cond == 11)
		pal = SRON_11
	else
		pal = SRON_12
	endif

	Make/O/N=(cond,3) colorwave
	Make/O/T/N=(cond) sum_Label
	Make/O/N=(cond) sum_MeanSpeed, sum_SemSpeed, sum_NSpeed
	Make/O/N=(cond) sum_MeanIV, sum_SemIV
	
	String pref, lab
	Variable color
	Variable /G gR, gG, gB
	
	fullList = "cdPlot;ivPlot;ivHPlot;dDPlot;MSDPlot;DAPlot;"
	
	for(i = 0; i < 6; i += 1)
		name = StringFromList(i, fullList)
		DoWindow/K $name
		Display /N=$name		
	endfor
	
	for(i = 1; i < cond+1; i += 1)
		Prompt pref, "Experimental condition e.g. \"Ctrl_\", \"Test_\". Quotes + underscore required"
		DoPrompt "Describe conditions", pref
		
		if(V_Flag)
      			Abort "The user pressed Cancel"
		endif
		
		lab = ReplaceString("_",pref,"")
		sum_Label[i-1] = lab
		
		// specify colours
		if(cond < 13)
			color = str2num(StringFromList(i-1,pal))
			gR = hexcolor_red(color)
			gG = hexcolor_green(color)
			gB = hexcolor_blue(color)
		else
			color = str2num(StringFromList(round((i-1)/12),pal))
			gR = hexcolor_red(color)
			gG = hexcolor_green(color)
			gB = hexcolor_blue(color)
		endif
		colorwave[i-1][0] = gR // offset by one because cond is 1-based
		colorwave[i-1][1] = gG
		colorwave[i-1][2] = gB
		// run other procedures
		LoadMigration(pref)
		MakeTracks(pref,tStep,pxSize)
	endfor
	
	DoWindow /K summaryLayout
	NewLayout /N=summaryLayout
	
	// Tidy up summary windows
	DoWindow /F cdPlot
	SetAxis/A/N=1 left
	Label left "Cumulative distance (�m)"
	Label bottom "Time (min)"
		AppendLayoutObject /W=summaryLayout graph cdPlot
	DoWindow /F ivPlot
	SetAxis/A/N=1 left
	Label left "Instantaneous velocity (�m/min)"
	Label bottom "Time (min)"
		AppendLayoutObject /W=summaryLayout graph ivPlot
	DoWindow /F ivHPlot
	SetAxis/A/N=1 left
	SetAxis bottom 0,2
	Label left "Frequency"
	Label bottom "Instantaneous velocity (�m/min)"
	ModifyGraph mode=6
		AppendLayoutObject /W=summaryLayout graph ivHPlot
	DoWindow /F dDPlot
	Label left "Directionality ratio (d/D)"
	Label bottom "Time (min)"
		AppendLayoutObject /W=summaryLayout graph dDPlot
	DoWindow /F MSDPlot
	ModifyGraph log=1
	SetAxis/A/N=1 left
	String wName = StringFromList(0,WaveList("W_Ave*",";","WIN:"))
	SetAxis bottom tStep,((numpnts($wName)*tStep)/2)
	Label left "MSD"
	Label bottom "Time (min)"
		AppendLayoutObject /W=summaryLayout graph MSDPlot
	DoWindow /F DAPlot
	SetAxis left 0,1
	SetAxis bottom 0,((numpnts($wName)*tStep)/2)
	Label left "Direction autocorrelation"
	Label bottom "Time (min)"
		AppendLayoutObject /W=summaryLayout graph DAPlot
	
	// average the speed data from all conditions	
	String wList, newName
	Variable nTracks, last, j
	
	for(i = 0; i < cond; i += 1) // loop through conditions, 0-based
		pref = sum_Label[i] + "_"
		wList = WaveList("cd_" + pref + "*", ";","")
		nTracks = ItemsInList(wList)
		newName = "Sum_Speed_" + ReplaceString("_",pref,"")
		Make/O/N=(nTracks) $newName
		WAVE w0 = $newName
		for(j = 0; j < nTracks; j += 1)
			wName = StringFromList(j,wList)
			Wave w1 = $wName
			last = numpnts(w1)	// finds last point (max cumulative distance)
			w0[j]=w1[last-1]/((last-1)*tStep)	// calculates speed
		endfor
		WaveStats/Q w0
		sum_MeanSpeed[i] = V_avg
		sum_SemSpeed[i] = V_sem
		sum_NSpeed[i] = V_npnts
	endfor
	DoWindow /K SpeedTable
	Edit /N=SpeedTable sum_Label,sum_MeanSpeed,sum_MeanSpeed,sum_SemSpeed,sum_NSpeed
	DoWindow /K SpeedPlot
	Display /N=SpeedPlot sum_MeanSpeed vs sum_Label
	Label left "Speed (�m/min)"
	SetAxis/A/N=1/E=1 left
	ErrorBars sum_MeanSpeed Y,wave=(sum_SemSpeed,sum_SemSpeed)
	ModifyGraph zColor(sum_MeanSpeed)={colorwave,*,*,directRGB,0}
	ModifyGraph hbFill=2
	AppendToGraph/R sum_MeanSpeed vs sum_Label
	SetAxis/A/N=1/E=1 right
	ModifyGraph hbFill(sum_MeanSpeed#1)=0,rgb(sum_MeanSpeed#1)=(0,0,0)
	ModifyGraph noLabel(right)=2,axThick(right)=0,standoff(right)=0
	ErrorBars sum_MeanSpeed#1 Y,wave=(sum_SemSpeed,sum_SemSpeed)
		AppendLayoutObject /W=summaryLayout graph SpeedPlot
	
	// average instantaneous velocity variances
	for(i = 0; i < cond; i += 1) // loop through conditions, 0-based
		pref = sum_Label[i] + "_"
		wList = WaveList("iv_" + pref + "*", ";","")
		nTracks = ItemsInList(wList)
		newName = "Sum_ivVar_" + ReplaceString("_",pref,"")
		Make/O/N=(nTracks) $newName
		WAVE w0 = $newName
		for(j = 0; j < nTracks; j += 1)
			wName = StringFromList(j,wList)
			Wave w1 = $wName
			w0[j] = variance(w1)	// calculate varance for each cell
		endfor
		WaveStats/Q w0
		sum_MeanIV[i] = V_avg
		sum_SemIV[i] = V_sem
	endfor
	AppendToTable /W=SpeedTable sum_MeanIV,sum_SemIV
	DoWindow /K IVCatPlot
	Display /N=IVCatPlot sum_MeanIV vs sum_Label
	Label left "Variance (�m/min)"
	SetAxis/A/N=1/E=1 left
	ErrorBars sum_MeanIV Y,wave=(sum_SemIV,sum_SemIV)
	ModifyGraph zColor(sum_MeanIV)={colorwave,*,*,directRGB,0}
	ModifyGraph hbFill=2
	AppendToGraph/R sum_MeanIV vs sum_Label
	SetAxis/A/N=1/E=1 right
	ModifyGraph hbFill(sum_MeanIV#1)=0,rgb(sum_MeanIV#1)=(0,0,0)
	ModifyGraph noLabel(right)=2,axThick(right)=0,standoff(right)=0
	ErrorBars sum_MeanIV#1 Y,wave=(sum_SemIV,sum_SemIV)
		AppendLayoutObject /W=summaryLayout graph IVCatPlot
	
	// Tidy summary layout
	DoWindow /F summaryLayout
	// in case these are not captured as prefs
#if igorversion()>=7
		LayoutPageAction size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
#endif
	ModifyLayout units=0
	ModifyLayout frame=0,trans=1
	Execute /Q "Tile"
	
	OrderGraphs()
	Execute "TileWindows/O=1/C"
	// when we get to the end, print (pragma) version number
	Print "***"
	Print "Executed Migrate v", GetProcedureVersion("LoadMigration.ipf")
	Print "***"
End

// This function will load the tracking data from an Excel Workbook
//// @param pref	prefix for excel workbook e.g. "ctrl_"
Function LoadMigration(pref)
	String pref
	
	String sheet, prefix, wList
	Variable i
	
	XLLoadWave/J=1
	Variable moviemax = ItemsInList(S_value)
	NewPath/O/Q path1, S_path
	
	for(i = 0; i < moviemax; i += 1)
		sheet = StringFromList(i,S_Value)
		prefix = pref + num2str(i)
		XLLoadWave/S=sheet/R=(A1,H1000)/O/K=0/N=$prefix/P=path1 S_fileName
		wList = wavelist(prefix + "*",";","")	// make matrices
		Concatenate/O/KILL wList, $prefix
	endfor
	
	Print "***\r  Condition", pref, "was loaded from", S_path,"\r  ***"
	
End

// This function will make cumulative distance waves for each cell. They are called cd_*
//// @param pref	prefix for excel workbook e.g. "ctrl_"
//// @param tStep	timestep. Interval/frame rate of movie.
//// @param pxSize	pixel size. xy scaling.
Function MakeTracks(pref,tStep,pxSize)
	String pref
	Variable tStep, pxSize
	
	NVAR cR = gR
	NVAR cG = gG
	NVAR cB = gB
	
	String wList0 = WaveList(pref + "*",";","") // find all matrices

	Variable nWaves = ItemsInList(wList0)
	
	Variable nTrack
	String mName0, newName, plotName, avList, avName, errName
	Variable i, j
	
	String layoutName = pref + "layout"
	DoWindow /K $layoutName
	NewLayout /N=$layoutName		// Igor 7 has multipage layouts, using separate layouts for now.

	// cumulative distance and plot over time	
	plotName=pref + "cdplot"
	DoWindow /K $plotName	// set up plot
	Display /N=$plotName

	for(i = 0; i < nWaves; i += 1)
		mName0 = StringFromList(i,wList0)
		WAVE m0 = $mName0
		Duplicate/O/R=[][5] m0, w0	// distance
		Duplicate/O/R=[][1] m0, w1	// cell number
		Redimension/N=-1 w0, w1
		nTrack = WaveMax(w1)	// find maximum track number
		for(j = 1; j < (nTrack+2); j += 1)	// index is 1-based, plus 2 was needed.
			newName = "cd_" + mName0 + "_" + num2str(j)
			Duplicate/O w0 $newName
			WAVE w2 = $newName
			w2 = (w1==j) ? w0 : NaN
			WaveTransform zapnans w2
			if(numpnts(w2)==0)
				Killwaves w2
			else
				w2[0] = 0	// first point in distance trace is -1 so correct this
				Integrate/METH=0 w2	// make cumulative distance
				SetScale/P x 0,tStep,"min", w2
				AppendtoGraph /W=$plotName $newName
			endif
		endfor
		DoWindow /F $plotName
	endfor
	ModifyGraph /W=$plotName rgb=(cR,cG,cB)
	avList = Wavelist("cd*",";","WIN:"+ plotName)
	avName = "W_Ave_cd_" + ReplaceString("_",pref,"")
	errName = ReplaceString("Ave", avName, "Err")
	fWaveAverage(avList, "", 3, 1, AvName, ErrName)
	AppendToGraph /W=$plotName $avName
	DoWindow /F $plotName
	Label left "Cumulative distance (�m)"
	ErrorBars $avName Y,wave=($ErrName,$ErrName)
	ModifyGraph lsize($avName)=2,rgb($avName)=(0,0,0)
	
	AppendLayoutObject /W=$layoutName graph $plotName
	
	// instantaneous velocity over time	
	plotName=pref + "ivplot"
	DoWindow /K $plotName	// set up plot
	Display /N=$plotName

	for(i = 0; i < nWaves; i += 1)
		mName0 = StringFromList(i,wList0)
		WAVE m0 = $mName0
		Duplicate/O/R=[][5] m0, w0	// distance
		Duplicate/O/R=[][1] m0, w1	// cell number
		Redimension/N=-1 w0, w1
		nTrack = WaveMax(w1)	// find maximum track number
		for(j = 1; j < (nTrack+2); j += 1)	// index is 1-based, plus 2 was needed.
			newName = "iv_" + mName0 + "_" + num2str(j)
			Duplicate/O w0 $newName
			WAVE w2=$newName
			w2 = (w1==j) ? w0 : NaN
			WaveTransform zapnans w2
			if(numpnts(w2)==0)
				Killwaves w2
			else
			w2[0] = 0	// first point in distance trace is -1, so correct this
			w2 /= tStep	// make instantaneous velocity (units are �m/min)
			SetScale/P x 0,tStep,"min", w2
			AppendtoGraph /W=$plotName $newName
			endif
		endfor
		DoWindow /F $plotName
	endfor
	ModifyGraph /W=$plotName rgb=(cR,cG,cB)
	avList = Wavelist("iv*",";","WIN:"+ plotName)
	avName = "W_Ave_iv_" + ReplaceString("_",pref,"")
	errName = ReplaceString("Ave", avName, "Err")
	fWaveAverage(avList, "", 3, 1, AvName, ErrName)
	AppendToGraph /W=$plotName $avName
	DoWindow /F $plotName
	Label left "Instantaneous velocity (�m/min)"
	ErrorBars $avName Y,wave=($ErrName,$ErrName)
	ModifyGraph lsize($avName)=2,rgb($avName)=(0,0,0)
	
	AppendLayoutObject /W=$layoutName graph $plotName
	
	plotName = pref + "ivHist"
	DoWindow /K $plotName	//set up plot
	Display /N=$plotName
	
	Concatenate/O/NP avList, tempwave
	newName = pref + "_ivHist"
	Variable bval=ceil(wavemax(tempwave)/(sqrt((3*pxsize)^2)/tStep))
	Make/O/N=(bval) $newName
	Histogram/P/B={0,(sqrt((3*pxsize)^2)/tStep),bVal} tempwave,$newName
	AppendToGraph /W=$plotName $newName
	ModifyGraph /W=$plotName rgb=(cR,cG,cB)
	ModifyGraph mode=5,hbFill=4
	SetAxis/A/N=1/E=1 left
	SetAxis bottom 0,2
	Label left "Frequency"
	Label bottom "Instantaneous velocity (�m/min)"
	Killwaves tempwave
	
	AppendLayoutObject /W=$layoutName graph $plotName
	
	// plot out tracks
	plotName=pref + "tkplot"
	DoWindow /K $plotName	//set up plot
	Display /N=$plotName
	
	Variable off
	
	for(i = 0; i < nWaves; i += 1)
		mName0 = StringFromList(i,wList0)
		WAVE m0 = $mName0
		Duplicate/O/R=[][3] m0, w0	//x pos
		Duplicate/O/R=[][4] m0, w1	//y pos
		Duplicate/O/R=[][1] m0, w2	//track number
		Redimension/N=-1 w0, w1,w2		
		nTrack=WaveMax(w2)	//find maximum track no.
		for(j = 1; j < (nTrack+1); j += 1)	//index is 1-based
			newName = "tk_" + mName0 + "_" + num2str(j)
			Duplicate/O w0 w3
			w3 = (w2==j) ? w3 : NaN
			WaveTransform zapnans w3
			if(numpnts(w3)==0)
				Killwaves w3
			else
			off = w3[0]
			w3 -= off	//set to origin
			w3 *= pxSize
			// do the y wave
			Duplicate/O w1 w4
			w4 = (w2==j) ? w4 : NaN
			WaveTransform zapnans w4
			off=w4[0]
			w4 -=off
			w4 *=pxSize
			Concatenate/O/KILL {w3,w4}, $newName
			WAVE w5 = $newName
			AppendtoGraph /W=$plotName w5[][1] vs w5[][0]
			endif
		endfor
		Killwaves w0, w1, w2 //tidy up
	endfor
	DoWindow /F $plotName
	ModifyGraph /W=$plotName rgb=(cR,cG,cB)
	SetAxis left -250,250;DelayUpdate
	SetAxis bottom -250,250;DelayUpdate
	ModifyGraph width={Plan,1,bottom,left};DelayUpdate
	ModifyGraph mirror=1;DelayUpdate
	ModifyGraph grid=1
	
	AppendLayoutObject /W=$layoutName graph $plotName
	
	// calculate d/D directionality ratio
	plotName = pref + "dDplot"
	DoWindow /K $plotName	// setup plot
	Display /N=$plotName
	
	String wName0, wName1
	Variable len
	wList0 = WaveList("tk_" + pref + "*", ";","")
	nWaves = ItemsInList(wList0)
	
	for(i = 0; i < nWaves; i += 1)
		wName0 = StringFromList(i,wList0)			// tk wave
		wName1 = ReplaceString("tk",wName0,"cd")	// cd wave
		WAVE w0=$wName0
		WAVE w1=$wName1
		newName = ReplaceString("tk",wName0,"dD")
		Duplicate/O w1 $newName
		WAVE w2=$newName
		len = numpnts(w2)
		w2 = 1
		for(j = 1; j < len; j += 1)
			w2[j]= sqrt(w0[j][0]^2 + w0[j][1]^2) / w1[j]
		endfor
		AppendtoGraph /W=$plotName w2
	Endfor
	ModifyGraph /W=$plotName rgb=(cR,cG,cB)
	avList=Wavelist("dD*",";","WIN:"+ plotName)
	avName="W_Ave_dD_" + ReplaceString("_",pref,"")
	errName=ReplaceString("Ave", avName, "Err")
	fWaveAverage(avList, "", 3, 1, AvName, ErrName)
	AppendToGraph /W=$plotName $avName
	DoWindow /F $plotName
	Label left "Directionality ratio (d/D)"
	Label bottom "Time (min)"
	ErrorBars $avName Y,wave=($ErrName,$ErrName)
	ModifyGraph lsize($avName)=2,rgb($avName)=(0,0,0)
	
	AppendLayoutObject /W=$layoutName graph $plotName
	
	// calculate MSD (overlapping method)
	plotName = pref + "MSDplot"
	DoWindow /K $plotName	//setup plot
	Display /N=$plotName
	
	wList0 = WaveList("tk_" + pref + "*", ";","")
	nWaves = ItemsInList(wList0)
	Variable k
	
	for(i = 0; i < nWaves; i += 1)
		wName0=StringFromList(i,wList0)	// tk wave
		WAVE w0 = $wName0
		len = DimSize(w0,0)
		mName0 = ReplaceString("tk",wName0,"MSDtemp")
		newName = ReplaceString("tk",wName0,"MSD")	// for results of MSD per cell
		Make/O/N=(len,len-1) $mName0=NaN // this calculates all, probably only need first half
		WAVE m0 = $mName0
		for(k = 0; k < len-1; k += 1)	// by col, this is delta T
			for(j = 1; j < len; j += 1)	// by row, this is the starting frame
				if(j > k)
					m0[j][k]= ((w0[j][0] - w0[j-(k+1)][0])^2)+((w0[j][1] - w0[j-(k+1)][1])^2)
				endif
			endfor
		endfor
		Make/O/N=(len+1) $newName=NaN
		WAVE w2 = $newName
		// extract cell MSDs per time point
		for(k = 0;k < len; k += 1)
			Duplicate/FREE/O/R=[][k] m0, w1 //no need to redimension or zapnans
			Wavestats/Q w1			
			w2[k+1] = v_avg
		endfor
		KillWaves m0
		SetScale/P x 0,tStep,"min", w2
		AppendtoGraph /W=$plotName w2
	endfor
	ModifyGraph /W=$plotName rgb=(cR,cG,cB)
	avList=Wavelist("MSD*",";","WIN:"+ plotName)
	avName="W_Ave_MSD_" + ReplaceString("_",pref,"")
	errName=ReplaceString("Ave", avName, "Err")
	fWaveAverage(avList, "", 3, 1, avName, errName)
	AppendToGraph /W=$plotName $avName
	DoWindow /F $plotName
	ModifyGraph log=1
	SetAxis/A/N=1 left
	len = numpnts($avName)*tStep
	SetAxis bottom tStep,(len/2)
	Label left "MSD"
	Label bottom "Time (min)"
	ErrorBars $avName Y,wave=($errName,$errName)
	ModifyGraph lsize($avName)=2,rgb($avName)=(0,0,0)
	
	AppendLayoutObject /W=$layoutName graph $plotName
	
	// calculate direction autocorrelation
	plotName = pref + "DAplot"
	DoWindow /K $plotName	// setup plot
	Display /N=$plotName
	
	for(i = 0; i < nWaves; i += 1)
		wName0 = StringFromList(i,wList0)			// tk wave
		WAVE w0 = $wName0
		len=DimSize(w0,0)	// len is number of frames
		Make/O/N=(len-1,2) vwave	// make vector wave. nVectors is len-1
		vwave = w0[p+1][q] - w0[p][q]
		Make/O/D/N=(len-1) magwave	// make magnitude wave. nMagnitudes is len-1
		magwave = sqrt((vwave[p][0]^2) + (vwave[p][1]^2))
		vwave /= magwave[p]	// normalise the vectors
		mName0 = ReplaceString("tk",wName0,"DAtemp")
		newName = ReplaceString("tk",wName0,"DA")	// for results of DA per cell
		Make/O/N=(len-1,len-2) $mName0 = NaN	// matrix for results (nVectors,n�t)
		WAVE m0 = $mName0
		for(k = 0; k < len-1; k += 1)	// by col, this is �t 0-based
			for(j = 0; j < len; j += 1)	// by row, this is the starting vector 0-based
				if((j+(k+1)) < len-1)
					m0[j][k]= (vwave[j][0] * vwave[j+(k+1)][0]) + (vwave[j][1] * vwave[j+(k+1)][1])
				endif
			endfor
		endfor
		Make/O/N=(len-1) $newName = NaN // npnts is len-1 not len-2 because of 1st point = 0
		Wave w2 = $newName
		w2[0] = 1
		// extract cell average cos(theta) per time interval
		for(k = 0; k < len-2; k += 1)
			Duplicate/FREE/O/R=[][k] m0, w1 //no need to redimension or zapnans
			Wavestats/Q w1	//mean function requires zapnans	
			w2[k+1] = v_avg
		endfor
		KillWaves m0
		SetScale/P x 0,tStep,"min", w2
		AppendtoGraph /W=$plotName w2
	endfor
	Killwaves vwave,magwave
	ModifyGraph /W=$plotName rgb=(cR,cG,cB)
	avList = Wavelist("DA*",";","WIN:"+ plotName)
	avName="W_Ave_DA_" + ReplaceString("_",pref,"")
	errName=ReplaceString("Ave", avName, "Err")
	fWaveAverage(avList, "", 3, 1, avName, errName)
	AppendToGraph /W=$plotName $avName
	DoWindow /F $plotName
	SetAxis left -1,1
	Label left "Direction autocorrelation"
	Label bottom "Time (min)"
	ErrorBars $avName Y,wave=($errName,$errName)
	ModifyGraph lsize($avName)=2,rgb($avName)=(0,0,0)
	
	AppendLayoutObject /W=$layoutName graph $plotName
	
	// Plot these summary windows at the end
	avName = "W_Ave_cd_" + ReplaceString("_",pref,"")
	errName = ReplaceString("Ave", avName, "Err")
	AppendToGraph /W=cdPlot $avName
	DoWindow /F cdPlot
	ErrorBars $avName Y,wave=($errName,$errName)
	ModifyGraph lsize($avName)=2,rgb($avName)=(cR,cG,cB)
	
	avName = "W_Ave_iv_" + ReplaceString("_",pref,"")
	errName = ReplaceString("Ave", avName, "Err")
	AppendToGraph /W=ivPlot $avName
	DoWindow /F ivPlot
	ErrorBars $avName Y,wave=($errName,$errName)
	ModifyGraph lsize($avName)=2,rgb($avName)=(cR,cG,cB)
	
	newName = pref + "_ivHist"
	AppendToGraph /W=ivHPlot $newName
	DoWindow /F ivHPlot
	ModifyGraph rgb($newName)=(cR,cG,cB)
	
	avName = "W_Ave_dD_" + ReplaceString("_",pref,"")
	errName = ReplaceString("Ave", avName, "Err")
	AppendToGraph /W=dDPlot $avName
	DoWindow /F dDPlot
	ErrorBars $avName Y,wave=($errName,$errName)
	ModifyGraph lsize($avName)=2,rgb($avName)=(cR,cG,cB)
			
	avName = "W_Ave_MSD_" + ReplaceString("_",pref,"")
	errName = ReplaceString("Ave", avName, "Err")
	AppendToGraph /W=MSDPlot $avName
	DoWindow /F MSDPlot
	ErrorBars $avName Y,wave=($errName,$errName)
	ModifyGraph lsize($avName)=2,rgb($avName)=(cR,cG,cB)
	
	avName = "W_Ave_DA_" + ReplaceString("_",pref,"")
	errName = ReplaceString("Ave", avName, "Err")
	AppendToGraph /W=DAPlot $avName
	DoWindow /F DAPlot
	ErrorBars $avName Y,wave=($errName,$errName)
	ModifyGraph lsize($avName)=2,rgb($avName)=(cR,cG,cB)
	
	// Tidy report
	DoWindow /F $layoutName
	// in case these are not captured as prefs
#if igorversion()>=7
		LayoutPageAction size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
#endif
	ModifyLayout units=0
	ModifyLayout frame=0,trans=1
	Execute /Q "Tile"
	TextBox/C/N=text0/F=0/A=RB/X=0.00/Y=0.00 ReplaceString("_",pref,"")
End

// This function reshuffles the plots so that they will be tiled (LR, TB) in the order that they were created
Function OrderGraphs()
	String list = WinList("*", ";", "WIN:1")		// List of all graph windows
	Variable numWindows = ItemsInList(list)
	
	Variable i
	
	for(i=0; i<numWindows; i+=1)
		String name = StringFromList(i, list)
		DoWindow /F $name
	endfor
End

// Function from aclight to retrieve #pragma version number
//// @param procedureWinTitleStr	This is the procedure window "LoadMigration.ipf"
Function GetProcedureVersion(procedureWinTitleStr)
	String procedureWinTitleStr
 
	// By default, all procedures are version 1.00 unless
	// otherwise specified.
	Variable version = 1.00
	Variable versionIfError = NaN
 
	String procText = ProcedureText("", 0, procedureWinTitleStr)
	if (strlen(procText) <= 0)
		return versionIfError		// Procedure window doesn't exist.
	endif
 
	String regExp = "(?i)(?:^#pragma|\\r#pragma)(?:[ \\t]+)version(?:[\ \t]*)=(?:[\ \t]*)([\\d.]*)"
 
	String versionFoundStr
	SplitString/E=regExp procText, versionFoundStr
	if (V_flag == 1)
		version = str2num(versionFoundStr)
	endif
	return version	
End