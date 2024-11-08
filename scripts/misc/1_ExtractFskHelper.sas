*### LAST VERSION UPDATE 4 OCT 2023 (v2.0) - CUT OUT THE ENTIRE WORK LOSS PART, SEE v1-0 IF YOU WANT IT BACK - SEE NOTES FOR DETAILS;
*### THIS SCRIPT EXTRACTS THE FSK DATA ON SICK LEAVE AND DISABILITY PENSION FOR OUR COHORT OF INDIVIDUALS
*### THIS IS A MODIFIED VERSION FROM THE SCRIPT ORIGINALLY SENT BY DANIELA, AVAILABLE IN FULL AT "K:/Reuma/RASPA 2021/03. Suggested code/";

*#! Note that this needs you to run `misc/1_ExtractCohort.R` a priori, to extract the cohort used within this script to subset the registers.;

*### 1. LOAD THE INPUT DATA FOLDERS INTO SAS;

LIBNAME FSK "K:\Reuma\RASPA 2021\01. Data Warehouse\02. Raw Data\10. FSK";
LIBNAME DATA "K:\HW\people\Anton Öberg Sysojev\MTXp_predict\data\raw";
LIBNAME OUT "HK:\HW\people\Anton Öberg Sysojev\MTXp_predict\data\raw\registers";

* --- --- --- CREATE THE COMBINED EIRA + SRQB PARTICIPANT FILE --- --- ---;

PROC IMPORT DATAFILE = 'HK:\HW\people\Anton Öberg Sysojev\MTXp_predict\data\COHORT.tsv'
	OUT = RAW_PID_CLEAN
	DBMS=DLM;
	delimiter='09'x;
run;

%LET DATASET = WORK.RAW_PID_CLEAN;    *#DEFINE A VARIABLE NAME FOR THE TARGET DATA SET CREATED ABOVE;

%let START_DATE = a.index_date - 365 AS START_DATE;		*#SET VARIABLES OF INTERVAL (HERE FROM 365 PRIOR TO INDEX DATE TO INDEX_DATE);
%let STOP_DATE = index_date - 0 AS STOP_DATE;			*#YOU PROBABLY DO NOT NEED TO SUBTRACT 0, BUT I DO IT HERE FOR FORMATING PURPOSE (UER READABILITY);

*### 2. EXTRACTING SJUKERSÄTTNING/AKTIVITETSERSÄTTNING/FÖRTIDSPENSION/DISABILITY PENSION;

DATA FTP1;    *#GET RID OF ALL THE MISSING `omfattning` IN SA_DELFALL2_3;
	SET FSK.SA_DELFALL2_3;
	WHERE omfattning ne .;
run;

PROC SORT DATA = FTP1 nodupkey dupout = DUPLICATES_FTP;    *#IDENTIFIES SOME TYPE OF DUPLICATES... UNCLEAR IN WHAT ASPECT;
			by pid del_from_datum del_tom_datum omfattning;
run;

PROC SQL;		*#SUBSETS THE FTP1 DATA TO THE INDIVIDUALS IN MY DATA SET;
	CREATE TABLE FSK_DIS_PENSION AS 
	SELECT *
	FROM FTP1
	WHERE pid IN (SELECT pid FROM &DATASET.);
quit;

DATA FSK_DIS_PENSION;		*#RENAMES A FEW VARIABLES AND FORMATS THEM APPROPRIATELY (POSSIBLY REMOVEABLE WITH UPDATES);
	SET FSK_DIS_PENSION;
	percent_dp = omfattning;
	DP_start = del_from_datum; format DP_start yymmdd10.;
	DP_stop = del_tom_datum; format DP_stop yymmdd10.;
	DROP omfattning del_from_datum del_tom_datum;
run;

PROC SORT DATA = FSK_DIS_PENSION nodupkey; by _all_; run;		*#THINK THIS FILTERS OUT DUPLICATES;
PROC SORT DATA = FSK_DIS_PENSION; BY pid DP_start DESCENDING DP_stop; run;		*#THINK THIS ARRANGE BY pid AND DP_stop;
PROC SORT DATA = FSK_DIS_PENSION nodupkey; BY pid DP_start; run;
PROC SORT DATA = FSK_DIS_PENSION; BY pid DP_start DP_stop; run;			*#NOT SURE WHAT THE LAST TWO ROWS DO... MIGHT LOOK AT DUPLICATES IN ANOTHER WAY (WE MAY NEED SORTED DATA TO ID DUPLICATES LIKE IN BASH);

DATA COUNT_DP;		*#COUNTS THE NUMBER OF OCCURENCES PER pid, IS USED LATER... 'MAX NUMBER OF DISABILITY PENSION' - THAT IS, IT CREATES A NEW VARIABLE WHICH INDEXES EACH INDIVIDUAL;
	SET FSK_DIS_PENSION;
	BY pid;
	count + 1;
	IF first.pid THEN count = 1;
run;

PROC SUMMARY DATA = COUNT_DP;		*#GETS THE MAXIMUM OF THE NEWLY CREATED `count` VARIABLE - THAT IS THE MAXIMUM NUMBER OF LINES FOR AN INDIVIDUAL;
	VAR count;
	OUTPUT OUT = count_dp_max max = ;
run;

DATA _null_;
	SET COUNT_DP_MAX;
	CALL symput('MAX_FTP',count);		*#I BELIEVE THIS MAKES IT CALL-ABLE, AND SO WE CAN SET IT AS A VARIABLE BELOW;
run;

%PUT &MAX_FTP;			*#WILD GUESS, BUT BELIEVE THIS CREATES A VARIABLE `MAX_FTP` THAT CONTAINS THE MAXIMUM VALUE RECORDED ABOVE;

*#BONKERS MACRO THAT PIVOTS THE TABLE FROM LONG TO WIDE;
/*From long to wide, only 3 variables*/
%MACRO WIDEFORM (ANTAL=, SORT=, NAMN=, VAR1=, VAR2=, VAR3=, VAR4=, VAR5=, VAR6=, VAR7=, VAR8=, VAR9=, VAR10=, VAR11=, VAR12=, VAR13=, VAR14=, VAR15=);

		%DO I=1 %TO &ANTAL;
			proc sort data = &NAMN;			%*-- Här sorteras datasetet map. den variabel som transposen ska ske över --*;
				by &SORT;
			run;
			proc transpose data=&NAMN out=wide_&&VAR&I prefix=&&VAR&I;  %*-- Transpose --*;
				by &SORT;
				var &&VAR&I;
			run;
		%if &I=1 %then %do;			%*-- Skapa ett basdataset --*;
				data &NAMN._wide;
					set wide_&&VAR&I;
					by &SORT;
					drop _name_;
				run;
			%end;
			%else %if &I>=2 %then %do;		%*-- Merga --*;
				data &NAMN._wide;
					merge &NAMN._wide wide_&&VAR&I;
					by &SORT;
					drop _name_;
				run;
			%end;
		%end;   			%*-- Avsluta loopen --*;
%MEND WIDEFORM;
%WIDEFORM(ANTAL=3, SORT=pid, NAMN=fsk_dis_pension, VAR1=DP_start, VAR2=DP_stop, VAR3=percent_dp);

*# THE ABOVE CREATES ONE SET FOR EACH OF THE INPUT VARIABLES FOR A GIVEN DATA SET, HERE THEY TARGET `DP_start`, `DP_stop` AND `percent_dp`.;
*# ONE SET PER INPUT VARIABLE IS CREATED, CONTAINING `pid`, THE NAME OF THE FORMER VARIABLE AND ONE A NUMBER OF COLUMNS EQUAL TO `MAX_FTP` TO FIT ALL THE DATA!;
*# MOST IMPORTANTLY, IT MERGES THEM ALL AS `fsk_dis_pension_wide` WHICH IS THE WORKING SET WE TAKE FORWARD; 

*### 3. EXTRACTING SJUKPENNING;

DATA SJPL;
	SET FSK.FALL4_7_SJKP;
run;

PROC SORT DATA = SJPL nodupkey dupout = DUPLICATES_SJP;		*#IDENTIFIES DUPLICATES;
			BY pid del_from_datum del_tom_datum omfattning;
run;

PROC SQL;		*#SUBSET SJPL TO MY INPUT `pid`;
	CREATE TABLE FSK_SICK_LEAVE AS
	SELECT *
	FROM SJPL
	WHERE pid IN (SELECT pid FROM &dataset.);
quit;

DATA FSK_SICK_LEAVE;		*#MUTATE VARIABLES...;
	SET FSK_SICK_LEAVE;
	percent_sl = omfattning;
	SL_start = del_from_datum; format SL_start yymmdd10.;
	SL_stop = del_tom_datum; format SL_stop yymmdd10.;
	DROP omfattning del_from_datum del_tom_datum;
run;

PROC SORT DATA = FSK_SICK_LEAVE nodupkey; by _all_; run;
PROC SORT DATA = FSK_SICK_LEAVE; by pid SL_start descending SL_stop; run;
PROC SORT DATA = FSK_SICK_LEAVE nodupkey; by pid SL_start; run;
PROC SORT DATA = FSK_SICK_LEAVE; by pid SL_start SL_stop; run;

DATA COUNT_SJP;			*#THIS DOES THE SAME THING AS IN THE PREVIOUS CHAPTER...;
	SET FSK_SICK_LEAVE;
	BY pid;
	count + 1;
	if first.pid then count = 1;
run;

PROC SUMMARY DATA = COUNT_SJP;
	VAR count;
	OUTPUT OUT = COUNT_SJP_MAX max = ;
run;

DATA _null_;
	SET COUNT_SJP_MAX;
	CALL symput('MAX_SJP', count);
run;
%PUT &MAX_SJP;

* #FOR SOME REASON, SICK LEAVE IS NEVER PIVOTED THE SAME WAY THAT DISABILITY PENSION IS, BUT I CAN NOT FOR THE LIFE OF ME FIGURE OUT WHY NOT, WHEN EVERYTHING ELSE IS IDENTICAL?;
* #I GUESS IT MIGHT BE TO AVOID ISSUES WITH MULTIPLE-TO-MULTIPLE, NOW YOU GET THE LONG-FORMAT SICK-LEAVE ON THE WIDE-FORMAT DISABILITY PENSION.;
* #THE RESULTING DATA SET BELOW SEEMS VERY MUCH FINE AND SO I DO NOT HAVE ANY ISSUES WITH THE CODE, BUT I MIGHT NOT FULLY FOLLOW...; 

*### 4. MERGING THE TWO TABLES;

DATA FSK_BOTH;			*#TAKE ONLY THE VARIABLES `pid`, `SL_start`, `SL_stop` and `percent_sl` and join onto the WIDE data from CHAPTER 2;
	MERGE FSK_SICK_LEAVE (in = a keep = pid SL_start SL_stop percent_sl)
		  FSK_DIS_PENSION_WIDE (in = b);
	BY pid;
	IF a;		*#THIS SEEMS TO BE SOME TYPE OF INNER JOIN? SKEPTICAL TO THIS... BUT LEAVING IT FOR NOW - NO IT IS OK COUNTS VERY MUCH LINE UP!;
run;

%PUT &MAX_FTP;
%PUT &MAX_SJP;

data FSK_BOTH_2;		*#LONG CHUNK OF CODE... ADDS COLUMNS `overlap`, `count_low`, `count_hih` and `count_diff` WHICH I DO NOT FULLY UNDERSTAND...;
	set FSK_BOTH;

	array DP_start		 (&MAX_FTP.) 	DP_start1 - DP_start%EVAL(&MAX_FTP.);
	array DP_stop		 (&MAX_FTP.) 	DP_stop1  - DP_stop%EVAL(&MAX_FTP.);
	array SL_DP_start (&MAX_FTP.);
	array SL_DP_stop  (&MAX_FTP.);

	overlap = 0;

	*------------------------------*;
	*--- LOOP FOR SICK LEAVE TIME ---*;
	*------------------------------*;
	do i=1 to &MAX_FTP. while (DP_start(i) ne . OR DP_stop(i) ne .);
		
		*-------------------------------------------------------------------------------------------------------------------------------*;
		*--- IF BOTH THE START AND STOP DATES FOR SICK LEAVE ARE INCLUDED IN THE DISABILITY PENSION TIME - 
				ALL SICK LEAVE DATES OVERLAP WITH DISABILITY PENSION TIME ---*;
		*-------------------------------------------------------------------------------------------------------------------------------*;
		if 	DP_start(i) <= SL_start <= SL_stop <= DP_stop(i)			
		then do;
			SL_DP_start(i) 	= 	SL_start;
			SL_DP_stop(i)	= 	SL_stop;
			overlap = 1;
		end;

		*-----------------------------------------------------------------------------------------------------------------------------*;
		*--- IF BOTH THE FTP START AND FTP STOP DATES ARE INCLUDED IN SICK LEAVE TIME - ALL FTP DATES OVERLAP WITH SICK LEAVE TIME ---*;
		*-----------------------------------------------------------------------------------------------------------------------------*;
		else if SL_start <= DP_start(i) <= DP_stop(i) <= SL_stop			
		then do;
			SL_DP_start(i) 	= 	DP_start(i);
			SL_DP_stop(i)	= 	DP_stop(i);
			overlap = 2;
		end;

		*---------------------------------------------------------------------------------------------------------------*;
		*--- IF ONLY THE START SJUKFALL IS INCLUDED IN THE FTP TIME - SICK LEAVE START DATE TO FTP END DATE OVERLAPS ---*;
		*---------------------------------------------------------------------------------------------------------------*;
		else if DP_start(i) <= SL_start <= DP_stop(i)
		then do;
			SL_DP_start(i) 		= 	SL_start;
			SL_DP_stop(i)		= 	DP_stop(i);
			overlap = 3;
		end;

		*---------------------------------------------------------------------------------------------------------------*;
		*--- IF ONLY THE STOP SJUKFALL IS INCLUDED IN THE FTP TIME - FTP START DATE TO SICK LEAVE END DATE OVERLAPS  ---*;
		*---------------------------------------------------------------------------------------------------------------*;
		else if DP_start(i) <= SL_stop <= DP_stop(i)
		then do;
			SL_DP_start(i) 	= 	DP_start(i);
			SL_DP_stop(i) 	= 	SL_stop;
			overlap = 4;
		end;
	end;

	do count_low = 1 to &MAX_FTP. until (SL_DP_start(count_low) ne .);
	end;

	do count_high = &MAX_FTP. to 1 by -1 until (SL_DP_start(count_high) ne .);
	end;

	if count_high = 0 AND count_low = (&MAX_FTP. + 1) then count_diff = 0;
	else count_diff = count_high - count_low + 1;
	
	format SL_DP_start1-SL_DP_start%EVAL(&MAX_FTP.) SL_DP_stop1-SL_DP_stop%EVAL(&MAX_FTP.) YYMMDD10.;

	drop i DP_start: DP_stop:;
run;

PROC SUMMARY DATA = FSK_BOTH_2;			*#COUNTS MAXIMUM OF `count_diff` FOR SOME REASON? ORIGINAL CODE SAYS 'Count something' WHICH IS NOT USEFUL;
	VAR count_diff;
	OUTPUT OUT = array_SL_DP_START max = ;
run;

DATA _null_;
	SET array_SL_DP_start;
	CALL symput('MAX_COUNT_DIFF',count_diff);
run;
%PUT &MAX_COUNT_DIFF;    *#MAKE THE MAXIMUM OF `count_diff` A VARIABLE THAT CAN BE CALLED;

*### 5. EXTRACTING THE RELEVANT DATA FOR A GIVEN PERIOD OF TIME;

/*Number of disability pension, sick leave or work loss days in a period of time*/
/*Let´s say I want them in the three months before start of a bDMARD, and that start is 15Jan2019*/

%let i=1;

PROC SQL;		*#JOINS THE NEWLY RETRIEVED DATA ONTO OUR INPUT;
	CREATE TABLE FSK_DIS_PENSION_SUB AS
	SELECT &START_DATE., &STOP_DATE., a.index_date, a.pid, b.*
	FROM &dataset. AS a
	LEFT JOIN FSK_DIS_PENSION AS b
	ON a.pid = b.pid;
quit;

PROC SQL;
	CREATE TABLE FSK_SICK_LEAVE_SUB AS
	SELECT &START_DATE., &STOP_DATE., a.index_date, a.pid, b.*
	FROM &dataset. AS a 
	LEFT JOIN FSK_SICK_LEAVE AS b
	ON a.pid = b.pid;
quit;

/******************************************
Period of interest    *-------------------*
A                   ___________________________
B                   __________
C                          ____________________
D                          _______
****************/

DATA DISABILITY_PENSION_CLEAN;
	SET FSK_DIS_PENSION_SUB;
	IF DP_start <= START_DATE AND DP_stop >= STOP_DATE THEN DP_days = ((STOP_DATE - START_DATE)) * percent_dp;		*#A;
	IF DP_start <= START_DATE AND DP_stop <  STOP_DATE THEN DP_days = (DP_stop - START_DATE) * percent_dp;			*#B;
	IF DP_start >  START_DATE AND DP_stop >= STOP_DATE THEN DP_days = (STOP_DATE - DP_start) * percent_dp;			*#C;
	IF DP_start >  START_DATE AND DP_stop <  STOP_DATE THEN DP_days = (DP_stop - DP_start) * percent_dp;			*#D;
	IF DP_stop < START_DATE THEN DP_days = 0;
	IF DP_start > STOP_DATE THEN DP_days = 0;
/*start_period=&start_period.; format start_period yymmdd10.;
stop_period=&stop_period.;format stop_period yymmdd10.;*/
run;

PROC SUMMARY DATA = DISABILITY_PENSION_CLEAN;		*#SUMMARIZES AND CALCULATES THE PER-INDIVIDUAL DAYS-ON-DISABILITY-PENSION;
	CLASS pid;
	VAR DP_days;
	OUTPUT OUT = DP_days_CLEAN SUM(DP_days) = DP_days_&i.;
run;

DATA DP_days_CLEAN;		*#CLEANS UP THE ABOVE DATA, REMOVES THE MISSING VARIABLE ROW AND DROPS THE FREQUENCY COLUMN;
	SET DP_days_CLEAN;
	IF pid ne .;
	/*start_period=&start_period.; format start_period yymmdd10.;
	stop_period=&stop_period.;format stop_period yymmdd10.;*/
	DROP _type_ _freq_;
run;

DATA SICK_LEAVE_CLEAN;
	SET FSK_SICK_LEAVE_SUB;
	if SL_start <= START_DATE AND SL_stop >= STOP_DATE THEN SL_days = (STOP_DATE - START_DATE) * percent_sl;	*#A;
	if SL_start <= START_DATE AND SL_stop <  STOP_DATE THEN SL_days = (SL_stop - START_DATE) * percent_sl;		*#B;
	if SL_start >  START_DATE AND SL_stop >= STOP_DATE THEN SL_days = (STOP_DATE -SL_start) * percent_sl;		*#C;
	if SL_start >  START_DATE AND SL_stop <  STOP_DATE THEN SL_days = (SL_stop - SL_start) * percent_sl;		*#D;
if SL_stop < START_DATE then SL_days = 0;
if SL_start > STOP_DATE then SL_days = 0;
run;

PROC SUMMARY DATA = SICK_LEAVE_CLEAN;
	CLASS pid;
	VAR SL_days;
	OUTPUT OUT = SL_days_CLEAN sum(SL_days) = SL_days_&i.;
run;

DATA SL_days_CLEAN;
	SET SL_days_CLEAN;
	IF pid ne .;
	/*start_period=&start_period.; format start_period yymmdd10.;
	stop_period=&stop_period.;format stop_period yymmdd10.;*/
	DROP _type_ _freq_;
run;

DATA FSK_&i.;
	MERGE Dp_days_CLEAN SL_days_CLEAN;
	BY pid;
	IF dp_days_&i.=. THEN dp_days_&i.=0;
	IF sl_days_&i.=. THEN sl_days_&i.=0;
run;

DATA OUT.FSK_SUB;
	SET FSK_1;
run;

/*
### TO DO:;
### NOTES:;
# 2.1. I decided to cut out ALL the code relating to computing the WORK LOSS. This code was complex and difficult to follow,
#		and cutting it meant that all parts of the script were clear to me. I also did not plan to use it in my project so it
#		could just as well be removed from here. Please see version v1-0 if you would like to get it back, that script is identical
#		except for the work-loss chunks.
*/
