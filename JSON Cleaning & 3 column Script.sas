/* Deletes all datasets and resets line number in the loglist */
resetline;
proc delete data=work._all_;
run;

/*********************************************************************************************************************************************/
/* Update name and path to JSON file (MUST END WITH .JSON) */
%let JSON_File_Path=/home/u49761986/sasuser.v94/survivor-ARSA1001.json;

/* Update name and path of cleaned data (MUST END WITH .CSV) */
%let Cleaned_Data_Path=/home/u49761986/sasuser.v94/Behavioral Data - survivor-ARSA1001.csv;

/* Update name and path of additional txt files (MUST END WITH .TXT) */

/* All anticipation and outcome */
%let Anticipation_Txt=/home/u49761986/sasuser.v94/antic.run001.txt;
%let Outcome_Txt=/home/u49761986/sasuser.v94/outcome_general.run001.txt;

/* Outcome coplayer decisions */
%let Outcome_Accept_Txt=/home/u49761986/sasuser.v94/outcome_accept.run001.txt;
%let Outcome_Reject_Txt=/home/u49761986/sasuser.v94/outcome_reject.run001.txt;
%let Outcome_Neutral_Txt=/home/u49761986/sasuser.v94/outcome_neutral.run001.txt;

/* Anticipation participant decisions */
%let Anticipation_Accept_Txt=/home/u49761986/sasuser.v94/antic_accept.run001.txt;
%let Anticipation_Reject_Txt=/home/u49761986/sasuser.v94/antic_reject.run001.txt;

/* Update name and path of SAS log (MUST END WITH .LST) */
%let SAS_Log_Path=/home/u49761986/sasuser.v94/Behavioral Data - survivor-ARSA1001.lst;

/* To check for errors: search for the following strings:
	- error
	- warn
	- unin
	- overwr
	- trunc
	- convert
	- more than
/*********************************************************************************************************************************************/

/* This code tells SAS to export results to a loglist. Can comment out the proc line to print to SAS instead */
filename loglst "&SAS_Log_Path.";
/*proc printto print=loglst log=loglst new;*/

/* Loads the JSON file specified in the let statement at the top */
libname myjson json "&JSON_File_Path."; 
proc copy inlib=myjson outlib=work;
run;

/* Delete all datasets except the alldata file from the load */
proc sql noprint;
	select distinct memname into :dme separated by ' '
	from dictionary.columns
	where memname^='ALLDATA' & libname='WORK';
quit;

proc delete data=&dme.;
run;

/* Limit full data to just values of interest */
data alldata2 (where=(v /* Where there is a value */
				& ((lowcase(p1)='times' & lowcase(p3)='subject_votes') /* Vote times */
				| (lowcase(item) in:('postfeedback_waits') & lowcase(p1)='round') /* Outcome duration */
				| (lowcase(p1)='round' & lowcase(p2)='subject_votes') /* Subject vote */
				| (lowcase(p1)='coplayers' & lowcase(p3)='votes') /* Participant vote */
				| (lowcase(p4)='begin_fmri2') /* Begin FMRI time */
				| (lowcase(p1)='coplayers' & (lowcase(p3) in('name' 'female') | lowcase(p4) in('age' 'interests' 'school')))))); /* Coplayer name */
	set alldata;

	length item $200;

	/* Check that v is an indicator for the value field being populated */
	if sum(v,^missing(value)) ^in(0 2) then abort;

	/* Create a single field showing the most refined hierarchy category */
	if ^missing(p6) then item=p6;
	else if ^missing(p5) then item=p5;
	else if ^missing(p4) then item=p4;
	else if ^missing(p3) then item=p3;
	else if ^missing(p2) then item=p2;
	else if ^missing(p1) then item=p1;

	/* Upcase the new item field */
	item=upcase(item);
run;

/* Pull in just the vote times and split into the first and second time for each vote */
data sv1 (rename=(p4=coplayer_code value=onset) keep=value p4 rec round_no phase) 
	 sv2 (rename=(p4=coplayer_code value=end_time) keep=value p4 round_no phase);
		set alldata2 (where=(lowcase(p3)='subject_votes'));

	/* Create a field containing the original record count so we can always re-sort the data by the original order */
	rec=_n_;

	/* Create a field called "phase" and label as "participant vote" */
	length phase $25;
	phase='1-Vote';

	/* Retain tells SAS to populate the value with the value from the prior record */
	retain round_no reset_value;

	/* On the first record, set round number equal to 1 and determine the first value that we will use to indicate a new round */
	/* indiff is the first value and cannot be kicked off */
	if _n_=1 then do;
		round_no=1;
		reset_value=item;
	end;

	/* When we see the first item for a round, increment the round number by 1 */
	else if item=reset_value then round_no+1;

	if lowcase(reset_value)^='indiff1' then abort;

	/* Split into two datasets based on the last character in the item field */
	if substr(item,length(item))='1' then output sv1;
	else if substr(item,length(item))='2' then output sv2;
	else abort;
run;

/* Macro to apply the same code to the sv1 and sv2 dataset */
%macro a;
	%do i=1 %to 2;
		/* Create a coplayer counter */
		data sv&i. (drop=lround_no);
			set sv&i.;

			retain coplayer;

			lround_no=lag(round_no);

			if _n_=1 then coplayer=1;
			else if round_no^=lround_no then coplayer=1;
			else coplayer+1;
		run;

		/* Sort the data prior to merging by round number, coplayer number, coplayer code, and phase */
		proc sort data=sv&i.;
			by round_no coplayer coplayer_code phase;
		run;
	%end;
%mend a;
%a

/* Merge sv1 and sv2 into one dataset */
data sv;
	merge sv1 sv2;
		by round_no coplayer coplayer_code phase;
run;

/* Sort by original record order */
proc sort data=sv out=limdata1 (drop=rec);
	by rec;
run;

/* Create anticipation records by adding 7" to voting onset time for the onset; end time is 5" after anticipation onset */
data limdata2 (rename=(onset2=onset end_time2=end_time) drop=onset end_time);
	set limdata1;

	/* Convert times from string to numeric */
	onset2=input(onset,16.);
	end_time2=input(end_time,16.);

	/* Export each participant vote record */
	output;

	/* Create a copy of each record and label as anticipation */
	if 1=1 then do;
		phase='2-Anticipation';
		onset2=onset2+7;
		end_time2=onset2+5;
		output;
	end;
run;

/* Create outcome records by adding 5" to anticipation end time; end time is post-feedback waits added to the onset */
data limdata3;
	set limdata2;

	/* Export each participant vote and anticipation record */
	output;

	/* Create a copy of each record and label as anticipation */
	if phase='2-Anticipation' then do;
		phase='3-Outcome';
		onset=end_time+5;
		end_time=.;
		output;
	end;
run;

/* Match on post-feedback wait times */
data pfw (keep=round_no value item coplayer);
	set alldata2 (where=(item=:'POSTFEEDBACK_WAITS'));

	/* Remove string values from item to get coplayer number */
	coplayer=input(substr(compress(item,'','A'),2),8.);

	retain round_no reset_value;

	/* Create round number */
	if _n_=1 then do;
		round_no=1;
		reset_value=item;
	end;

	else if item=reset_value then round_no+1;

	if lowcase(reset_value)^='postfeedback_waits1' then abort;
run;

/* Match post-feedback wait times onto outcome records by coplayer and round */
proc sql;
	create table limdata4 as select a.*, sum(a.onset,input(b.value,16.)) as end_time_temp
	from limdata3 a
	left join pfw b
	on a.coplayer=b.coplayer & a.round_no=b.round_no & a.phase='3-Outcome'
	order by round_no, coplayer, phase;
quit;

/* Consolidate end times into one field */
data limdata4;
	set limdata4;

	if phase='3-Outcome' then end_time=end_time_temp;
	drop end_time_temp;
run;

/* Break program if onset or end time ever appear more than once. If this happens, then sort by another field after those below */
proc sql;
	create table ab1 as select *
	from limdata4
	group by onset
	having count(*)>1;

	create table ab2 as select *
	from limdata4
	group by end_time
	having count(*)>1;
quit;

data _null_;
	set ab1 ab2;

	if _n_ then abort;
run;

proc delete data=ab1 ab2;
run;

/* Sort by time */
proc sort data=limdata4;
	by onset end_time;
run;

/* Make duration and weight variable */
data limdata5;
	set limdata4;

	duration=end_time-onset;
	weight=1;
run;

/* Pull votes on coplayers */
data cpvotes (drop=reset_value);
	set alldata2 (where=(lowcase(p2)='subject_votes'));

	retain round_no reset_value;

	/* Create round number */
	if _n_=1 then do;
		round_no=1;
		reset_value=item;
	end;

	else if item=reset_value then round_no+1;

	if lowcase(reset_value)^='indiff' then abort;
run;

/* Match onto participate vote records */
proc sql;
	create table limdata6 as select a.*, b.value as participant_decision length=10
	from limdata5 a
	left join cpvotes b
	on a.coplayer_code=b.P3 & a.round_no=b.round_no & a.phase='1-Vote'
	order by round_no, coplayer, phase;
quit;

data limdata7;
	set limdata6;

/* Commented out since a participant could take too much time to vote and not provide an actual decision */
/*	if phase='1-Vote' & missing(decision) then abort;*/

	/* Create binary indicator for decision code */
	participant_decision=compress(transtrn(transtrn(participant_decision,'0D'x,''),'0A'x,''));
	if strip(participant_decision) ^in('' 'Keep' 'KickOut') then abort;
	if phase='1-Vote' then participant_decision_binary=(participant_decision='Keep');
run;

/* Pull votes on participants */
data pvotes (rename=(P2=coplayer_code) keep=P2 round_no coplayer_decision_value coplayer_decision);
	set alldata2 (where=(lowcase(p3)='votes'));

	/* Parse round number from p4 since these records are ordered differently than prior records */
	round_no=input(substr(P4,length(p4)),8.);

	/* Recode value field */
	value=compress(value);

	if value='-1' then coplayer_decision_value=0;
	else if value='1' then coplayer_decision_value=1;
	else if value='0' then coplayer_decision_value=2;
	else abort;

	/* Create value label */
	length coplayer_decision $10;

	if coplayer_decision_value=0 then coplayer_decision='KickOut';
	else if coplayer_decision_value=1 then coplayer_decision='Keep';
	else if coplayer_decision_value=2 then coplayer_decision='Neutral';
	else abort;
run;

/* Match onto main file */
proc sql;
	create table limdata8 as select a.*, b.coplayer_decision_value, b.coplayer_decision
	from limdata7 a
	left join pvotes b
	on a.coplayer_code=b.coplayer_code & a.round_no=b.round_no & a.phase='1-Vote'
	order by round_no, coplayer, phase;
quit;

/* Get round 1 fMRI begin time */
data fmri;
	set alldata2 (where=(lowcase(p4)='begin_fmri2'));

	value2=input(value,16.);
	lvalue2=lag(value2);

	if value2<=lvalue2 then abort;

	if _n_=1 then output;
run;

proc sql;
	select distinct value2 into :fmri_r1_begin
	from fmri;
quit;

/* Create fMRI onset */
data limdata9;
	set limdata8;

	fmri_onset=sum(onset,-1*&fmri_r1_begin.);
run;

/* Match on coplayer info */
data cpinfo (rename=(p2=coplayer_code));
	set alldata2 (where=(lowcase(p1)='coplayers' & (lowcase(p3) in('name' 'female') | lowcase(p4) in('age' 'interests' 'school')))); 
run;

proc sort data=cpinfo;
	by coplayer_code item;
run;

/* Reshape rows into columns for each characteristic of the coplayer */
proc transpose data=cpinfo out=cpinfo2 (drop=_name_);
	by coplayer_code;
	id item;
	var value;
run;

/* Match onto main file */
proc sql;
	create table limdata10 as select a.*, b.name, b.female, input(b.age,8.) as age, b.interests, b.school
	from limdata9 a
	left join cpinfo2 b
	on a.coplayer_code=b.coplayer_code & a.phase='1-Vote'
	order by onset, end_time;
quit;

/* Remove numeric prefixes from phase and recode female to binary indicator */
data limdata11 (rename=(female2=female) drop=female coplayer);
	set limdata10;

	phase=substr(phase,3);

	if female='true' then female2=1;
	else if female='false' then female2=0;
	else if ^missing(female) then abort;
run;

/* Reorder columns */
data limdata11;
	retain round_no coplayer_code phase onset end_time fmri_onset duration weight participant_decision participant_decision_binary coplayer_decision coplayer_decision_value name female age interests school;
		set limdata11;
run;

/* Export to CSV specified in let statement at the top */
proc export
	data=limdata11
	outfile="&Cleaned_Data_Path."
	dbms=csv
	replace;
run;

/* Create 7 txt files: each is a phase with the MRI onset duration and weight */
/* 1) anticipation */
/* 2) outcome */

/* Based on coplayer decision */
/* 3) outcome accept */
/* 4) outcome reject */
/* 5) outcome neutral */

/* Based on participant decision */
/* 6) anticipation accept */
/* 7) anticipation reject */

data ant_1 (drop=phase);
	set limdata11 (where=(phase='Anticipation') keep=phase fmri_onset duration weight);
run;

proc sort data=ant_1;
	by fmri_onset;
run;

proc export
	data=ant_1
	outfile="&Anticipation_Txt."
	dbms=tab
	replace;
	putnames=no;
run;

data out_2 (drop=phase);
	set limdata11 (where=(phase='Outcome') keep=phase fmri_onset duration weight);
run;

proc sort data=out_2;
	by fmri_onset;
run;

proc export
	data=out_2
	outfile="&Outcome_Txt."
	dbms=tab
	replace;
	putnames=no;
run;

proc sql;
	create table out_accept_3 (where=(phase='Outcome')) as select phase, fmri_onset, duration, weight
	from limdata11
	group by round_no, coplayer_code
	having max(phase='Vote' & coplayer_decision='Keep')
	order by fmri_onset;
quit;

proc export
	data=out_accept_3 (drop=phase)
	outfile="&Outcome_Accept_Txt."
	dbms=tab
	replace;
	putnames=no;
run;

proc sql;
	create table out_reject_4 (where=(phase='Outcome')) as select phase, fmri_onset, duration, weight
	from limdata11
	group by round_no, coplayer_code
	having max(phase='Vote' & coplayer_decision='KickOut')
	order by fmri_onset;
quit;

proc export
	data=out_reject_4 (drop=phase)
	outfile="&Outcome_Reject_Txt."
	dbms=tab
	replace;
	putnames=no;
run;

proc sql;
	create table out_neutral_5 (where=(phase='Outcome')) as select phase, fmri_onset, duration, weight
	from limdata11
	group by round_no, coplayer_code
	having max(phase='Vote' & coplayer_decision='Neutral')
	order by fmri_onset;
quit;

proc export
	data=out_neutral_5 (drop=phase)
	outfile="&Outcome_Neutral_Txt."
	dbms=tab
	replace;
	putnames=no;
run;

proc sql;
	create table ant_accept_6 (where=(phase='Anticipation')) as select phase, fmri_onset, duration, weight
	from limdata11
	group by round_no, coplayer_code
	having max(phase='Vote' & participant_decision='Keep')
	order by fmri_onset;
quit;

proc export
	data=ant_accept_6 (drop=phase)
	outfile="&Anticipation_Accept_Txt."
	dbms=tab
	replace;
	putnames=no;
run;

proc sql;
	create table ant_reject_7 (where=(phase='Anticipation')) as select phase, fmri_onset, duration, weight
	from limdata11
	group by round_no, coplayer_code
	having max(phase='Vote' & participant_decision='KickOut')
	order by fmri_onset;
quit;

proc export
	data=ant_reject_7 (drop=phase)
	outfile="&Anticipation_Reject_Txt."
	dbms=tab
	replace;
	putnames=no;
run;

proc printto;
run;
