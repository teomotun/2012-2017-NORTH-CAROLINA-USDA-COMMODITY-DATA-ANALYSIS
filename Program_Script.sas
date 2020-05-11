options validvarname=V7;
%let path =C:\Users\teomotun\Desktop\BAE-590;
libname BAE590 "C:\Users\teomotun\Desktop\BAE-590";

/*IMPORT USDA DATA*/
PROC IMPORT DATAFILE="&path/USDA_Raw.csv" DBMS=CSV
				OUT=BAE590.USDARawData (rename=(CV____=CV)) REPLACE;
				guessingrows=MAX;
RUN;


/**Analyze the variable types for the new SAS table;*/
/*proc contents data= BAE590.USDARawData order=varnum; *list all variables in the order they appear in table;*/
/*run;*/

*Notes:
- The imported dataset has 22,181 Observations and 21 variables with all columns of CHAR type
- CV variable name had extra underscore symbols. Edited proc import
- Identified variables that should be numeric like "Value";

/*proc freq data=bae590.usdarawdata;*/
/*	tables value data_item; *tables statement determines what variable to use to get frequencies;*/
/*run;*/

*Notes:
- Value variable has non-numeric observations (D) and (Z).
- Value variable has numeric observations with a comma. 
- Value observations range widely, which might indicate that they are not all the same units.
- All entries in Data_Item variable has a (-)sign ;

/* Convert year and Value to numeric */
DATA bae590.usdaNum bae590.usdaChVal; 
	set bae590.usdarawdata(rename=(Value=New_Value));
	*Year=put(New_Year, year4.);
	Value = input(New_Value, comma18.);
	if New_Value in ("(D)","(Z)") Then output bae590.usdaChVal;
	else output bae590.usdaNum;
	drop New_Value; *New_Year;
RUN;

*Creates a freq table for year and all character variable;
proc freq data=bae590.usdaNum noprint;
	tables Year _CHARACTER_ ;
run;

*Subset the Data Item column;
data bae590.usdaNum ;
	set bae590.usdaNum;
	Length Data_Item1 Data_Item2 Data_Item3 $99 DataUnit $40; *99 is too high but we can optimize later;
	Data_Item1=scan(Data_Item,1,'-'); 
	Data_Item2=scan(Data_Item,-1,'-');
	Data_Item3=scan(Data_Item2,-1,','); *adjusting data_item2 to remove what it is already in data_item3;
	If index(Data_Item3,'MEASURED IN') > 0 Then do;
		DataUnit=scan(Data_Item3,-1);
		If DataUnit='IN' Then DataUnit ='$'; 
	end;
	Else DataUnit= "";
run;

*Creates a frequency tables to show unique DataUnits;
/*proc freq data=bae590.usdaNum noprint;*/
/*	tables DataUnit; */
/*run;*/

/*IMPORT US COUNTIES DATA*/
PROC IMPORT DATAFILE="&path\USCounties.csv" DBMS=CSV
				OUT=BAE590.US_Counties REPLACE;
				guessingrows=MAX;
RUN;
/* us_counties has 3,109 observations and 8 variables with all columns of CHAR type*/

/* Join Counties and Cities data sets */
PROC SQL;
	title 'COMBINED USDA DATA & COUNTIES DATASET';
	create table BAE590.USDAandCounties as
	select *
	from bae590.usdaNum as usda 
	inner join BAE590.US_Counties as counties
	    on lower(usda.state) = lower(counties.STATE_NAME)
	where lower(usda.county) = lower(counties.COUNTY_NAME);
	title;
QUIT;

/*/* Show content of new combined dataset */*/
/*PROC CONTENTS data=BAE590.USDAandCounties;*/
/*RUN;*/

*Notes:
- After combining USDA dataset with US Counties, the new dataset has 21,155 Observations and 33 variables

* Data Cleaning and removing redundant variables;
DATA BAE590.USDAandCountiesClean;
   SET BAE590.USDAandCounties(rename=(Centroid_Y=Latitude Centroid_X=Longitude));;
   DROP Program Region Period Watershed Week_Ending Geo_Level State_ANSI State_fips Ag_District_Code County_ANSI Centroid_X
		Centroid_Y Zip_Code watershed_code COUNTY_NAME STATE_NAME STATE_FIPS CNTY_FIPS;
Run;

/* Show content of new combined dataset */
/*PROC CONTENTS data=BAE590.USDAandCountiesClean;*/
/*RUN;*/
*Notes:
- Variables have been reduced to 18;

* Renaming missing values and $ in DataUnit Column;
data BAE590.USDAandCountiesClean(replace=yes);
  set BAE590.USDAandCountiesClean;
  if DataUnit = "" then DataUnit="Missing";
  if DataUnit = "$" then DataUnit="Dollar";
run;


* Import Population and Unemployment Data gotten from https://osbm.nc.gov/demog/county-estimates;
/*IMPORT US UNEMPLOYMENT DATA*/
PROC IMPORT DATAFILE="&path\Unemployment.csv" DBMS=CSV
				OUT=BAE590.Unemployment REPLACE;
				guessingrows=MAX;
RUN;
/* unemployment dataset has 3,274 observations and 56 variables*/


/*IMPORT US POPULATION DATA*/
PROC IMPORT DATAFILE="&path\PopulationEstimates.csv" DBMS=CSV
				OUT=BAE590.Population REPLACE;
				guessingrows=MAX;
RUN;
/* popolation dataset has 3,272 observations and 149 variables*/

/* Macros to process the population and unemployment datasets for years 2012 and 2017 */
options  nomlogic nosymbolgen mprint;
%MACRO get_nc(input=, output=, keep1=, keep2=, keep3=, keep4=, state=, rename=);
	data &output (replace=yes);
		set &input;
		where State = "&state";
		if _N_ = 1 then delete; /*first row contains total for NC which you don't want*/
		County=scan(Area_Name,1,' ');
		keep &keep1  &keep2 &keep3 &keep4;
	run;
	proc transpose data=&output out=&output(rename=(_NAME_=Years COL1=&rename));
		by FIPS County;
		var &keep3 &keep4;
	run;
	data &output (replace=yes);
		set &output;
		Year=scan(Years,3,'_');
		keep FIPS County Year &rename;
	run;
	proc sort data=&output out=&output;
		by descending Year;
	run;
%MEND get_nc;

%get_nc(input=BAE590.Population, output=BAE590.NC_Population, keep1=FIPS, keep2=County, keep3=POP_ESTIMATE_2017, keep4=POP_ESTIMATE_2012, state=NC, rename=Population_Est);

%get_nc(input=BAE590.Unemployment, output=BAE590.NC_Unemployment, keep1=FIPS, keep2=County, keep3=UNEMPLOYMENT_RATE_2017, keep4=UNEMPLOYMENT_RATE_2012, state=NC, rename=Unemployment_Est);

*Combine USDA Dataset, Population dataset and Unemployment Dataset;
PROC SQL;
	title 'COMBINED USDA DATA, Population and Unemployment demographics';
	create table BAE590.USDA_Pop_Unemp as
	select *
	from BAE590.USDAandCountiesClean as usda 
	inner join BAE590.NC_Population as population
	    on usda.Year = input(population.Year,4.)
	inner join BAE590.NC_Unemployment as unemployment
	    on usda.Year = input(unemployment.Year,4.)
	where lower(usda.County) = lower(population.County) & lower(usda.County) = lower(unemployment.County);
	title; 
QUIT;
*Combined data has 20997 observations and 20 variables;

/*IMPORT NC WEATHER DATA*/
PROC IMPORT DATAFILE="&path\weather_data.csv" DBMS=CSV
				OUT=BAE590.Weather_data REPLACE;
				guessingrows=MAX;
RUN;
* Weather dataset has 201 observations and 8 variables including CLDD, HTDD, PRCP, TAVG, TMIN & TMAX;

* Combine previous dataset with the weather dataset;
PROC SQL;
	title 'COMBINED USDA DATA, Population and Unemployment demographics and Weather';
	create table BAE590.Combined as
	select *
	from bae590.Usda_Pop_Unemp as usda 
	inner join BAE590.Weather_data as weather
	    on usda.Year = weather.year
		where usda.FIPS = weather.FIPS;
QUIT;
* Combined dataset has 21105 observations and 26 variables;

*Macros to get unique Observations for any variable in a dataset;
options  nomlogic nosymbolgen mprint;
%MACRO get_unique(data=, keep=, out=, by=);
	proc sort data=&data(keep=&keep) out=&out nodupkey;
	      by &by;
	run;
%MEND get_unique;

%get_unique(data=BAE590.Combined, keep=DataUnit, out=BAE590.Unique_Dataunits, by=DataUnit);

* Macros to get tables by each unique value in a dataset column;
options  nomlogic nosymbolgen mprint;
%macro split (data=, var=);
proc sort data=&data(keep=&var) out=values nodupkey;
      by &var;
   run;
   data _null_;
      set values end=last;
      call symputx('DataUnit_'||left(_n_),&var);
      if last then call symputx('count',_n_);
   run;
   %put _local_; /* Print local variables to log */
data
   %do i=1 %to &count;
      &&DataUnit_&i
   %end;
   ;
      set &data;
      select(&var);
   %do i=1 %to &count;
      when("&&DataUnit_&i") output &&DataUnit_&i;
   %end;
      otherwise;
      end;
   run;
%mend split;

* Tables for each unique Dataunit;
%split(data=BAE590.Combined,var=DataUnit)

*Put actual Sales Data Unit table in the BAE590 library;
DATA BAE590.USDADollar (replace=yes);
	SET WORK.Dollar;
	Pop_Density = DIVIDE(input(Population_Est,COMMA15.),SQMI); /*Normalize the population by land mass in sqmile*/
	DROP State Data_Item Data_Item2 Domain Domain_Category Data_Item3 Data_Item4 Population_Est SQMI DataUnit;
RUN;
* Analysis is done on the $ Values, the dollar dataset has 5726 observations and 18 variables;

*Sort the USDA Dollar dataset and remove duplicates;
PROC SORT DATA=BAE590.USDADollar OUT=BAE590.USDADollar NODUPKEY DUPOUT=BAE590.USDADollarDup;
	BY DESCENDING Year County Commodity;
RUN;
* Sorted USDA Dollar Value dataset has 2951 observations and 18 variables;


* get unique commodities and DataItems;
%get_unique(data=BAE590.USDADollar, keep=Commodity, out=BAE590.Unique_Commodities, by=Commodity);
%get_unique(data=BAE590.USDADollar, keep=Data_Item1, out=BAE590.Unique_DataItems, by=Data_Item1);
*There are 17 unique commodities and 23 Data Items;

* Create Custom Formats;
proc format ;
	picture roundKM(round)
		0-<1000='009' (prefix='$')
		1000-<1000000='0009.9K'(prefix='$' mult=.01)
		1000000-<1000000000='0009.9M'(prefix='$' mult=.00001)
		1000000000-<1000000000000='0009.9B'(prefix='$' mult=.00000001);

	value value_rng
		1 = '50 to 100% Decrease'
		2 = '0 to 50% Decrease'
		3 = '0 to 50% Increase'
		4 = '50 to 300% Increase'
		5 = '300 to 3000% Increase'
		6 = '> 3000% Increase';

	value unemployment_rng
		1 = '< 35% Decrease'
		2 = '35 to 40% Decrease'
		3 = '40 to 45% Decrease'
		4 = '45 to 50% Decrease'
		5 = '50 to 59% Decrease'
		6 = '> 60% Decrease';

	value pop_density_rng
		1 = '5 to 10% Decrease'
		2 = '0 to 5% Decrease'
		3 = '0 to 5% Increase'
		4 = '5 to 10% Increase'
		5 = '10 to 15% Increase'
		6 = '> 15% Increase';

	value cldd_rng
		1 = '> 15% Decrease'
		2 = '0 to 15% Decrease'
		3 = '0 to 15% Increase'
		4 = '15 to 30% Increase'
		5 = '30 to 60% Increase'
		6 = '> 60% Increase';

	value htdd_rng
		1 = '> 15% Decrease'
		2 = '0 to 15% Decrease'
		3 = '0 to 15% Increase'
		4 = '15 to 30% Increase'
		5 = '30 to 45% Increase'
		6 = '> 45% Increase';

	value prcp_rng
		1 = '> 15% Decrease'
		2 = '0 to 15% Decrease'
		3 = '0 to 10% Increase'
		4 = '10 to 20% Increase'
		5 = '20 to 30% Increase'
		6 = '> 30% Increase';

	value tavg_rng
		1 = '> 4% Decrease'
		2 = '0 to 4% Decrease'
		3 = '0 to 4% Increase'
		4 = '4 to 8% Increase'
		5 = '8 to 12% Increase'
		6 = '> 12% Increase';

	value tmin_rng
		1 = '> 8% Decrease'
		2 = '0 to 8% Decrease'
		3 = '0 to 8% Increase'
		4 = '8 to 16% Increase'
		5 = '16 to 24% Increase'
		6 = '> 24% Increase';

	value tmax_rng
		1 = '> 4% Decrease'
		2 = '0 to 4% Decrease'
		3 = '0 to 3% Increase'
		4 = '3 to 6% Increase'
		5 = '6 to 9% Increase'
		6 = '> 9% Increase';
quit;

/* Macros to group dataset by Commodities and sort according to highest summary statistics */
%MACRO get_state_commodity_data(input=, out=, year=, rename=);
	%get_year_data(input=&input, out=temp, year=&year);

	title "&year North Carolina USDA Data Grouped by Commodities Created on %left(%qsysfunc(today(),weekdate.))";
	proc means data=temp mean sum MAXDEC=2; 
	    var Value;
	    class Commodity;
	    output out=temp (drop=_type_ _freq_) sum=&rename / autoname;
	run;

	DATA temp;
		SET temp;
		if _N_ = 1 then delete;
	RUN;

	/* Sort according to highest summary statistics */
	proc sort data=temp out=&out;
		by DESCENDING &rename;
	run;
	DATA &out;
		SET &out;
		formatted = &rename;
		format formatted roundKM.;
	RUN;
%MEND get_state_commodity_data;

ods pdf file="&path/PDF_Report.pdf";
* Get commodity distribution for years 2012 and 2017;
%get_state_commodity_data(input=BAE590.USDADollar, out=BAE590.Commodity2012, year=2012, rename=Value_2012_Dollar);
* There are 16 commodities in 2012 dataset;

* Get Bar Chart of Commodities distribution for 2012 in NC;
%_eg_conditional_dropds(WORK.SORTTempTableSorted);
PROC SQL;
	CREATE VIEW WORK.SORTTempTableSorted AS
		SELECT T.Commodity, T.formatted
		FROM BAE590.COMMODITY2012(FIRSTOBS=1 ) as T;
QUIT;
Axis1	STYLE=1 WIDTH=1	MINOR=  (NUMBER=1)
	LABEL=( FONT='Arial' HEIGHT=14pt COLOR=BLUE   "MEASURED VALUE IN $");
Axis2 STYLE=1 WIDTH=1 LABEL=( FONT='Arial' HEIGHT=14pt COLOR=BLUE   "COMMODITIES");
TITLE; TITLE1 "COMMODITIES DISTRIBUTION IN NORTH CAROLINA FOR 2012"; FOOTNOTE;
FOOTNOTE1 "Created on %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) at %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";
PROC GCHART DATA=WORK.SORTTempTableSorted; VBAR 
	 Commodity/ SUMVAR=formatted CLIPREF FRAME	CFRAME=WHITE TYPE=SUM
	OUTSIDE=SUM LEGEND=LEGEND1 DESCENDING COUTLINE=BLACK RAXIS=AXIS1 MAXIS=AXIS2
	PATTERNID=MIDPOINT LREF=4 CREF=CX969696 AUTOREF; LABEL formatted="Value";
RUN; 
QUIT;
%_eg_conditional_dropds(WORK.SORTTempTableSorted);
TITLE; FOOTNOTE;

* Get commodity distribution for years 2012 and 2017;
%get_state_commodity_data(input=BAE590.USDADollar, out=BAE590.Commodity2017, year=2017, rename=Value_2017_Dollar);
* There are 17 unique commodities in 2017 datasets;

* Get Bar Chart of Commodities distribution for 2017 in NC;
%_eg_conditional_dropds(WORK.SORTTempTableSorted);
PROC SQL;
	CREATE VIEW WORK.SORTTempTableSorted AS
		SELECT T.Commodity, T.formatted
	FROM BAE590.COMMODITY2017(FIRSTOBS=1 ) as T;
QUIT;
Axis1 STYLE=1	WIDTH=1	MINOR= 	(NUMBER=1)	
LABEL=( FONT='Arial' HEIGHT=14pt COLOR=BLUE   "MEASURED VALUE IN $");
Axis2 STYLE=1 WIDTH=1	LABEL=( FONT='Arial' HEIGHT=14pt COLOR=BLUE   "COMMODITIES");
TITLE; TITLE1 "COMMODITIES DISTRIBUTION FOR NORTH CAROLINA IN 2017";
FOOTNOTE; FOOTNOTE1 "Created on %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) at %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";
PROC GCHART DATA=WORK.SORTTempTableSorted;
	VBAR  Commodity/ SUMVAR=formatted CLIPREF FRAME	TYPE=SUM
	OUTSIDE=SUM	LEGEND=LEGEND1	DESCENDING	COUTLINE=BLACK
	RAXIS=AXIS1 MAXIS=AXIS2 PATTERNID=MIDPOINT	LREF=4	CREF=BLACKAUTOREF;
RUN;
QUIT;
%_eg_conditional_dropds(WORK.SORTTempTableSorted);
TITLE; FOOTNOTE;


* Merge 2012 and 2017 commodity distribution datasets for years 2012 and 2017 and also calculate percentage change;
PROC SQL;
	create table BAE590.Commmodities as
	select *, (n.Value_2017_Dollar- i.Value_2012_Dollar)/i.Value_2012_Dollar*100 AS PERCENT_CHANGE
	from BAE590.Commodity2012 as i 
	inner join BAE590.Commodity2017 as n
	    on i.Commodity = n.Commodity;
QUIT;

* Get Bar Chart of Percentage Change in Commodities Between 2012 & 2017
%_eg_conditional_dropds(WORK.SORTTempTableSorted);PROC SQL;
	CREATE VIEW WORK.SORTTempTableSorted AS
		SELECT T.Commodity, T.PERCENT_CHANGE
	FROM BAE590.COMMMODITIES(FIRSTOBS=1 ) as T;
QUIT;
Axis1 STYLE=1WIDTH=1MINOR= (NUMBER=1)	LABEL=( FONT='Arial' HEIGHT=14pt COLOR=BLUE   "% CHANGE");
Axis2 STYLE=1 WIDTH=1 LABEL=( FONT='Arial' HEIGHT=14pt COLOR=BLUE   "COMMODITY");
TITLE; TITLE1 "PERCENTAGE CHANGE IN COMMODITY VALUES BETWEEN 2012 & 2017";
FOOTNOTE; FOOTNOTE1 "Created on %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) at %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";
PROC GCHART DATA=WORK.SORTTempTableSorted;	
	VBAR Commodity/ SUMVAR=PERCENT_CHANGE CLIPREF FRAME 
	TYPE=SUM LEGEND=LEGEND1 DESCENDING COUTLINE=BLACK RAXIS=AXIS1	
	MAXIS=AXIS2 PATTERNID=MIDPOINT LREF=4 CREF=BLACK AUTOREF;
RUN; QUIT;
%_eg_conditional_dropds(WORK.SORTTempTableSorted);
TITLE; FOOTNOTE;
ods pdf close;

* Macros to extract unique year from any dataset;
%MACRO get_year_data(input=, out=, year=);
	DATA &out (REPLACE=YES);
		SET &input;
		WHERE Year = &year;
	RUN;
%MEND get_year_data;

* Get 2012 and 2017 data from USDADollar dataset;
%get_year_data(input=BAE590.USDADollar, out=BAE590.USDA2017_data, year=2017);
%get_year_data(input=BAE590.USDADollar, out=BAE590.USDA2012_data, year=2012);

* Macros to rename columns in the 2012 and 2017 data gotten previously;
%MACRO rename_year_data(input=, out=, year=);
	DATA &out (rename=(Value=Value_&year 
								   Unemployment_Est=Unemployment_rate_&year
								   CLDD = CLDD_&year
								   HTDD = HTDD_&year
								   PRCP = PRCP_&year
								   TAVG = TAVG_&year
								   TMAX = TMAX_&year
								   TMIN = TMIN_&year
								   Pop_Density = Pop_Density_&year) replace=Yes);
		SET &input;
		DROP YEAR;
	RUN;
%MEND rename_year_data;

* Rename the specified variables in both dataset;
%rename_year_data(input=BAE590.USDA2017_data, out=BAE590.USDA2017_data, year=2017);
%rename_year_data(input=BAE590.USDA2012_data, out=BAE590.USDA2012_data, year=2012);

*PROC GPROJECT converts the spherical coordinates to a flat Cartesian format in maps.counties;
proc gproject data=maps.counties
	out=NC_Counties;
	where state eq 37;
	id state county;
run;

* Get change in variables from 2012 to 2017;
PROC SQL;
	create table BAE590.All_Change_data as
	select i.Ag_District, i.County, i.FIPS, i.Latitude, i.Longitude, i.Commodity, i.Data_Item1,
		   round((n.Value_2017- i.Value_2012)/i.Value_2012*100,0.2) AS Value_Change,
		   round((n.Unemployment_rate_2017- i.Unemployment_rate_2012)/i.Unemployment_rate_2012*100,0.2) AS Unemployment_Change,
		   round((n.Pop_Density_2017- i.Pop_Density_2012)/i.Pop_Density_2012*100,0.2) AS Pop_Density_Change,
		   round((n.CLDD_2017- i.CLDD_2012)/i.CLDD_2012*100,0.2) AS CLDD_Change,
		   round((n.HTDD_2017- i.HTDD_2012)/i.HTDD_2012*100,0.2) AS HTDD_Change,
		   round((n.PRCP_2017- i.PRCP_2012)/i.PRCP_2012*100,0.2) AS PRCP_Change,
		   round((n.TAVG_2017- i.TAVG_2012)/i.TAVG_2012*100,0.2) AS TAVG_Change,
		   round((n.TMAX_2017- i.TMAX_2012)/i.TMAX_2012*100,0.2) AS TMAX_Change,
		   round((n.TMIN_2017- i.TMIN_2012)/i.TMIN_2012*100,0.2) AS TMIN_Change
	from BAE590.USDA2017_data as n 
	inner join BAE590.USDA2012_data as i
	    on i.County = n.County
		where i.Commodity=n.Commodity;
QUIT;

* Macros to get Summary Staitistics of each commodity and make linear regression with strongest predictors;
%macro get_commodity_statistics(commodity=);
	DATA temp (replace=yes);
		SET BAE590.All_Change_Data;
		DROP FIPS Latitude Longitude;
		WHERE Commodity = "&commodity";
	RUN;

	/* Scatter plot for all variables based on correlation*/
	%let interval=Unemployment_Change Pop_Density_Change 
				  CLDD_Change HTDD_Change PRCP_Change TAVG_Change TMIN_Change TMAX_Change;
	ods graphics / reset=all imagemap;  /*imagemap shows html like object*/
	proc corr data=temp nocorr
	          plots(only)=scatter(nvar=all  ellipse=none); /* rank by descending for all variables */
	   var &interval;
	   with Value_Change;
	   title "CORRELATION AND SCATTER PLOTS FOR &commodity";
	run;
	title;

	/*Correlation matrix to show multicolinearity and show no descriptive statistics*/
	ods graphics off;
	proc corr data=temp rank outp=temp2
	          nosimple best=3;
	   var Value_Change &interval;
	   title "CORRELATION MATRIX TO GET TOP PREDICTORS FOR &commodity";
	run;
	title;

	data temp2 (replace=yes);
		set temp2;
		if _N_ = 1 or _N_ = 2 OR _N_ = 3 then delete;
		drop _TYPE_;
	run;

	proc sql noprint;
		Create table temp_var as
		select name
		into :vars separated by ' '
		from dictionary.columns
		where libname="WORK" and /*must be upper case*/
		memname="TEMP2" and /*must be upper case*/
		varnum between 3 and 4;
	quit;

	proc sql noprint;
		select distinct name into: temp_var_list seperated by ' ' from temp_var;
	quit;

	/* multiple regression */
	ods graphics on;
	proc glm data=temp 
	         plots(only)=(contourfit);
	    model Value_Change=&temp_var_list;
	    store out=multiple;
	    title "LINEAR REGRESSION MODEL WITH USING TOP PREDICTIVE VARIABLES FOR &commodity";
	run;
	quit;
%mend get_commodity_statistics;

* The next two macros show maps for each commodity. Also shows map of demographics and weather information;
%MACRO get_map(data=, commodity=, variable=);
	DATA temp (replace=yes);
		SET &data (rename=(County=County_nm));
		if _n_ = 1 then County = 1;
		else County = _n_*2 - 1;
		WHERE Commodity = "&commodity";
		*Keep County_nm Value County;
	RUN;

	data temp2;
		length xtext $30.;
		merge NC_Counties temp;
		by County;
		array NumVar _numeric_;
		do over NumVar;
			if NumVar=. then NumVar=0.1;
		end;

		if -100 =< Value_Change <= -50 then value_rng= 1;
		else if -49.99 <= Value_Change <= 0 then value_rng=2;
		else if 0.001 <= Value_Change <= 50 then value_rng=3;
		else if 50.001 <= Value_Change <= 300 then value_rng=4;
		else if 300.01 <= Value_Change <= 3000 then value_rng=5;
		else if 3000.01 <= Value_Change then value_rng=6;

		if -10 =< Pop_Density_Change <= -5 then pop_density_rng= 1;
		else if -4.99 <= Pop_Density_Change <= 0 then pop_density_rng=2;
		else if 0.001 <= Pop_Density_Change <= 5 then pop_density_rng=3;
		else if 5.001 <= Pop_Density_Change <= 10 then pop_density_rng=4;
		else if 10.01 <= Pop_Density_Change <= 15 then pop_density_rng=5;
		else if 15.01 <= Pop_Density_Change then pop_density_rng=6;

		if -34.99 =< Unemployment_Change then unemployment_rng= 1;
		else if -39.99 <= Unemployment_Change <= -35 then unemployment_rng=2;
		else if -44.99 <= Unemployment_Change <= -40 then unemployment_rng=3;
		else if -49.99 <= Unemployment_Change <= -45 then unemployment_rng=4;
		else if -59.99 <= Unemployment_Change <= -50 then unemployment_rng=5;
		else if -60.001 >= Unemployment_Change then unemployment_rng=6;

		if TAVG_Change <= -4 then tavg_rng= 1;
		else if -3.99 <= TAVG_Change <= 0 then tavg_rng=2;
		else if 0.001 <= TAVG_Change <= 4 then tavg_rng=3;
		else if 4.001 <= TAVG_Change <= 8 then tavg_rng=4;
		else if 8.01 <= TAVG_Change <= 12 then tavg_rng=5;
		else if 12.01 <= TAVG_Change then tavg_rng=6;

		if TMIN_Change <= -8 then tmin_rng= 1;
		else if -7.99 <= TMIN_Change <= 0 then tmin_rng=2;
		else if 0.001 <= TMIN_Change <= 8 then tmin_rng=3;
		else if 8.001 <= TMIN_Change <= 16 then tmin_rng=4;
		else if 16.01 <= TMIN_Change <= 24 then tmin_rng=5;
		else if 24.01 <= TMIN_Change then tmin_rng=6;

		if TMAX_Change <= -4 then tmax_rng= 1;
		else if -3.99 <= TMAX_Change <= 0 then tmax_rng=2;
		else if 0.001 <= TMAX_Change <= 3 then tmax_rng=3;
		else if 3.001 <= TMAX_Change <= 6 then tmax_rng=4;
		else if 6.01 <= TMAX_Change <= 9 then tmax_rng=5;
		else if 9.01 <= TMAX_Change then tmax_rng=6;

		if PRCP_Change <= -15 then prcp_rng= 1;
		else if -14.99 <= PRCP_Change <= 0 then prcp_rng=2;
		else if 0.001 <= PRCP_Change <= 10 then prcp_rng=3;
		else if 10.001 <= PRCP_Change <= 20 then prcp_rng=4;
		else if 20.01 <= PRCP_Change <= 30 then prcp_rng=5;
		else if 30.01 <= PRCP_Change then prcp_rng=6;

		if CLDD_Change <= -15 then cldd_rng= 1;
		else if -14.99 <= CLDD_Change <= 0 then cldd_rng=2;
		else if 0.001 <= CLDD_Change <= 15 then cldd_rng=3;
		else if 15.001 <= CLDD_Change <= 30 then cldd_rng=4;
		else if 30.01 <= CLDD_Change <= 60 then cldd_rng=5;
		else if 60.01 <= CLDD_Change then cldd_rng=6;

		if HTDD_Change <= -15 then htdd_rng= 1;
		else if -14.99 <= HTDD_Change <= 0 then htdd_rng=2;
		else if 0.001 <= HTDD_Change <= 15 then htdd_rng=3;
		else if 15.001 <= HTDD_Change <= 30 then htdd_rng=4;
		else if 30.01 <= HTDD_Change <= 45 then htdd_rng=5;
		else if 45.01 <= HTDD_Change then htdd_rng=6;

		*xtext = cats(County_nm)||' ('||cats(Value_Change)||')';
		*if nmiss(of _numeric_)>0 then delete;
		format value_rng value_rng.;
		format unemployment_rng unemployment_rng.;
		format pop_density_rng pop_density_rng.;
		format cldd_rng cldd_rng.;
		format htdd_rng htdd_rng.;
		format prcp_rng prcp_rng.;
		format tavg_rng tavg_rng.;
		format tmin_rng tmin_rng.;
		format tmax_rng tmax_rng.;
	run;


	%annomac; *%ANNOMAC macro which tells SAS to have the annotate macros ready to be used;

	/*Calling the %MAPLABEL macro which will create the annotate dataset to be called in PROC GMAP*/
	%maplabel(NC_Counties, temp2, NCAnnotate, County_nm, County, font='Tahoma/bo', color=black, size=1.25);

	LEGEND1 LABEL=(HEIGHT=1 POSITION=TOP JUSTIFY=CENTER
	%if &variable = value_rng %then %do;
	 	"PERCENTAGE CHANGE IN VALUE OF &commodity")
	%end;
	%if &variable = pop_density_rng %then %do;
	 	"PERCENTAGE CHANGE IN POPULATION DENSITY")
	%end;
	%if &variable = unemployment_rng %then %do;
	 	"PERCENTAGE CHANGE IN UNEMPLOYMENT RATE")
	%end;
	%if &variable = cldd_rng %then %do;
	 	"PERCENTAGE CHANGE IN COOLING DEGREE DAYS")
	%end;
	%if &variable = htdd_rng %then %do;
	 	"PERCENTAGE CHANGE IN HEATING DEGREE DAYS")
	%end;
	%if &variable = prcp_rng %then %do;
	 	"PERCENTAGE CHANGE IN ANNUAL PRECIPITATION")
	%end;
	%if &variable = tavg_rng %then %do;
	 	"PERCENTAGE CHANGE IN ANNUAL TEMPERATURE")
	%end;
	%if &variable = tmin_rng %then %do;
	 	"PERCENTAGE CHANGE IN ANNUAL MINIMUM TEMPERATURE")
	%end;
	%if &variable = tmax_rng %then %do;
	 	"PERCENTAGE CHANGE IN ANNUAL MAXIMUM TEMPERATURE")
	%end;

	ACROSS=1 DOWN=5 POSITION = (bottom outside left)FRAME MODE=PROTECT

	%if &variable = value_rng %then %do;
	 	VALUE=(HEIGHT=1 '50 to 100 % Decrease' '0 to 49 % Decrease' '0 to 50 % Increase' '50 to 300 % Decrease' '300 to 3000 % Increase'
			'>3000 % Decrease');
		title1 "MAP SHOWING PERCENTAGE CHANGE IN VALUE OF &commodity BETWEEN 2012 AND 2017 ACROSS NORTH CAROLINA";
	%end;
	%if &variable = pop_density_rng %then %do;
	 	VALUE=(HEIGHT=1 '5 to 10% Decrease' '0 to 5% Decrease' '0 to 5% Increase' '5 to 10% Increase' '10 to 15% Increase'
		    '> 15% Increase');
		title1 "MAP SHOWING PERCENTAGE CHANGE IN POPULATION DENSITY BETWEEN 2012 AND 2017 ACROSS NORTH CAROLINA";
	%end;
	%if &variable = unemployment_rng %then %do;
	 	VALUE=(HEIGHT=1 '< 35% Decrease' '35 to 40% Decrease' '40 to 45% Decrease' '45 to 50% Decrease' '50 to 59% Decrease'
			'> 60% Decrease');
		title1 "MAP SHOWING PERCENTAGE CHANGE IN UNEMPLOYMENT RATE BETWEEN 2012 AND 2017 ACROSS NORTH CAROLINA";
	%end;
	%if &variable = cldd_rng %then %do;
	 	VALUE=(HEIGHT=1 '> 15% Decrease' '0 to 15% Decrease' '0 to 15% Increase' '15 to 30% Increase' '30 to 60% Increase'
			'> 60% Increase');
		title1 "MAP SHOWING PERCENTAGE CHANGE IN COOLING DEGREE DAYS BETWEEN 2012 AND 2017 ACROSS NORTH CAROLINA";
	%end;
	%if &variable = htdd_rng %then %do;
	 	VALUE=(HEIGHT=1 '> 15% Decrease' '0 to 15% Decrease' '0 to 15% Increase' '15 to 30% Increase' '30 to 45% Increase'
			'> 45% Increase');
		title1 "MAP SHOWING PERCENTAGE CHANGE IN HEATING DEGREE DAYS BETWEEN 2012 AND 2017 ACROSS NORTH CAROLINA";
	%end;
	%if &variable = prcp_rng %then %do;
	 	VALUE=(HEIGHT=1 '> 15% Decrease' '0 to 15% Decrease' '0 to 10% Increase' '10 to 20% Increase' '20 to 30% Increase'
			'> 30% Increase');
		title1 "MAP SHOWING PERCENTAGE CHANGE IN ANNUAL PRECIPITATION BETWEEN 2012 AND 2017 ACROSS NORTH CAROLINA";
	%end;
	%if &variable = tavg_rng %then %do;
	 	VALUE=(HEIGHT=1 '> 4% Decrease' '0 to 4% Decrease' '0 to 4% Increase' '4 to 8% Increase' '8 to 12% Increase'
			'> 12% Increase');
		title1 "MAP SHOWING PERCENTAGE CHANGE IN ANNUAL TEMPERATURE BETWEEN 2012 AND 2017 ACROSS NORTH CAROLINA";
	%end;
	%if &variable = tmin_rng %then %do;
	 	VALUE=(HEIGHT=1 '> 8% Decrease' '0 to 8% Decrease' '0 to 8% Increase' '8 to 16% Increase' '16 to 24% Increase'
			'> 24% Increase');
		title1 "MAP SHOWING PERCENTAGE CHANGE IN ANNUAL MINIMUM TEMPERATURE BETWEEN 2012 AND 2017 ACROSS NORTH CAROLINA";
	%end;
	%if &variable = tmax_rng %then %do;
	 	VALUE=(HEIGHT=1 '> 4% Decrease' '0 to 4% Decrease' '0 to 3% Increase' '3 to 6% Increase' '6 to 9% Increase'
			6 = '> 9% Increase');
		title1 "MAP SHOWING PERCENTAGE CHANGE IN ANNUAL MAXIMUM TEMPERATURE BETWEEN 2012 AND 2017 ACROSS NORTH CAROLINA";
	%end;

	footnote j=r "Created:%sysfunc(today(),weekdate.)";
	proc gmap data=temp2 map=temp2;
		id County;
		choro &variable / anno=ncannotate legend=LEGEND1;
		pattern1 v=ms c=red;
		pattern2 v=ms c=darkorange;
		pattern3 v=ms c=yellow;
		pattern4 v=ms c=palegreen;
		pattern5 v=ms c=mediumgreen;
		pattern6 v=ms c=darkgreen;
	run;
	quit;
%MEND get_map;


%MACRO get_maps_and_statistics();
	%local i next_commodity next_factor;
	%let factors_list = unemployment_rng pop_density_rng cldd_rng htdd_rng prcp_rng tavg_rng tmin_rng tmax_rng;
	%let x1 = FEED; %let x2 = DEPRECIATION; %let x3 = FUELS;%let x4 = LABOR; %let x5 = RENT;
	%let x6 = INTEREST; %let x7 = TAXES;%let x8 = MILK;
	%let list =&x1 &x2 &x3 &x4 &x5 &x6 &x7 &x8;
	%do i=1 %to %sysfunc(countw(&factors_list));
		%let next_factor = %scan(&factors_list, &i);
		%get_map(data=BAE590.All_Change_data, commodity=FEED, variable=&next_factor);
		%let i = %eval(&i+1);
	%end;

	%do i=1 %to %sysfunc(countw(&list));
		%let next_commodity = %scan(&list, &i);
		%get_map(data=BAE590.All_Change_data, commodity=&next_commodity, variable=value_rng);
		%get_commodity_statistics(commodity=&next_commodity);
		%let i = %eval(&i+1);
	%end;
	%get_map(data=BAE590.All_Change_data, commodity=EXPENSE TOTALS, variable=value_rng);
	%get_commodity_statistics(commodity=EXPENSE TOTALS);
	%get_map(data=BAE590.All_Change_data, commodity=ANIMAL TOTALS, variable=value_rng);
	%get_commodity_statistics(commodity=ANIMAL TOTALS);
	%get_map(data=BAE590.All_Change_data, commodity=CROP TOTALS, variable=value_rng);
	%get_commodity_statistics(commodity=CROP TOTALS);
	%get_map(data=BAE590.All_Change_data, commodity=FERTILIZER TOTALS, variable=value_rng);
	%get_commodity_statistics(commodity=FERTILIZER TOTALS);
	%get_map(data=BAE590.All_Change_data, commodity=SEEDS & PLANTS TOTALS, variable=value_rng);
	%get_commodity_statistics(commodity=SEEDS & PLANTS TOTALS);
	%get_map(data=BAE590.All_Change_data, commodity=SUPPLIES & REPAIRS, variable=value_rng);
	%get_commodity_statistics(commodity=SUPPLIES & REPAIRS);
	%get_map(data=BAE590.All_Change_data, commodity=CHEMICAL TOTALS, variable=value_rng);
	%get_commodity_statistics(commodity=CHEMICAL TOTALS);
	%get_map(data=BAE590.All_Change_data, commodity=AG SERVICES, variable=value_rng);
	%get_commodity_statistics(commodity=AG SERVICES);
%MEND get_maps_and_statistics;

%get_maps_and_statistics();
ods pdf close;