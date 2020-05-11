/* MATERIAL LEARNED IN PROGRAMMING 1: LESSONS 1-3 */
ods graphics on;
ods noproctitle; *turn off all procedure titles;
*ensure that valid SAS names are created when importing files & turn on graphics;
options validvarname=v7;
*ods trace on/off => Writes to the SAS log a record of each output object that is
 created, or suppresses the writing of this record.;
*ods select extremeobs =>writes 5 extreme observations; 

*declare a variable named path;
%let path=/home/dsjones51/sasuser.v94/EPG194/data;
%let outpath=/home/dsjones51/sasuser.v94/EPG194/output;

*Create a library that points at path;
libname PG1 "&path";
libname xlout xlsx "&outpath/southpacific.xlsx";

data work.sales;
	set sashelp.shoes;
	format netsales dollar15.;
	label NetSales = "Difference between Sales and Returns"; */permanent label assigned;
/* 	drop subsidiary; *if we wanted to drop this column; */
	NetSales = Sales - Returns; *created a new column named NetSales;
*Note that there is no run statement. The beginning of the title global statement
  signals the end of the data step;
 
title "Complete Shoe Sales Table";
*prints the first 5 observations;
proc print data=work.sales (obs=5);
run;

*Print proc is the only proc that needs an explicit request to show labels in the first statement;
proc print data=work.sales label;
	where 30000<sales<100000;
	where also Inventory>100000;
	where also product like "% Dress"; *% is a wild card for any number of characters; 
	label Inventory="the amount of products in stock";
	*the above label statement changes the display of the column name to label;
run;

title "Complete statistics of Shoe Sales Table";
proc means data=work.sales; 
run;

title "Print only Mean of Shoe Sales Table with 2 decimal places";
proc means data=work.sales mean MAXDEC=2; 
run;

title "MEANS: Var=NetSales Class= Region";
proc means data=work.sales mean sum MAXDEC=2; 
    var NetSales; *analyze the values in column NetSales;
    class region; *grouped by or classified by region; 
    *Class does not require we sort data ahead of time;
run;

title "MEANS: Var=NetSales Class= Region";
proc means data=work.sales mean sum MAXDEC=2; 
    var NetSales; *analyze the values in column NetSales;
    class region; *grouped by or classified by region; 
    *Class does not require we sort data ahead of time;
    ways 1; 
    *ways ->allows us to control how the values of the classification
    variables are used to segment the data. 
    If ways=0, we use zero classifications to segment data, or we get statistics for all data. 
    If ways=1, we have 2 separate tables.
    If ways=2, we use the combination of the 2 columns to calculate summary stats;
run;

title "MEANS: Var=NetSales Where Region= 'Canada' or 'United States'";
proc means data=work.sales mean sum MAXDEC=2; 
*mean sum ->specifies to only show those statistics.
 maxdec=2 -> maximum decimal places =2;
    var NetSales; /*analyze the values in column NetSales*/
    where region in ("Canada", "United States"); /*summary statistics where region = Canada or US*/
run;

title "PRINT: Var=Region Product Subsidiary Stores Where Stores>20";
*Prints the observations where stores>20 for the different classifications 
  in the variables/columns listed;
proc print data=work.sales; 
    var  Region Product Subsidiary stores; 
    where Stores >20; 
run;

title "MEANS: Var=Stores Class=Region Subsidiary Where Stores=>20";
proc means data=work.sales mean sum MAXDEC=2; 
    var Stores ; /*analyze the values in column Stores*/
    class Region Subsidiary; /*grouped by or classified by region and subsidiary*/
	where Stores >20; /*analyze only values in column Stores>20*/
run;

proc contents data=work.sales;
run;
title; *turn title off;
*************************;



proc contents data="&path/storm_summary.sas7bdat"; 
run;

* the following does not work as it needs to point to a specific worksheet; 
/* proc contents data="&path/storm.xlsx";  */
/* run; */


proc contents data=pg1.storm_summary; 
run;

*creating a library that points at an excel file;
libname PG2 xlsx "&path/storm.xlsx";
*To use the PG2 library, you would write pg2.Worksheet1, where 
Worksheet1 is the name of the worksheet you are accessing. 

*Display contents of worksheet storm_summary;
proc contents data= pg2.storm_summary;
run;

libname pg2 clear;

*importing an xlsx file;
proc import datafile="&path/storm.xlsx" 
			dbms=xlsx out=work.storm_damage replace;
	sheet="Storm_Damage"; *as default it reads the 1st sheet if not specified;
run;

*importing a csv file;
proc import datafile="&path/storm_damage.csv" 
			dbms=csv out=work.storm_damage_import replace;
run;

*importing an tab-delimited file. ;
proc import datafile="&path/storm_damage.tab"
            dbms=tab out=storm_damage_tab replace;
/* 			guessingrows=max; *This examines all rows to provide columns type or lenght; */
run; 

*importing a file with a specific delimiter;
proc import datafile="&path/np_traffic.tab"
            dbms=tab out=storm_damage_tab2 replace;
            delimiter="|";
run; 

proc print data= work.storm_damage;
	Where Date >= "01Jan2010"d;
	format Date date9.;
run;

proc freq data=work.sales;
	tables region product; *creates two frequency tables;
run;

proc freq data=work.sales;
	tables _ALL_; *creates frequency tables for all columns;
run;

proc sort data=work.sales;
	by region;
run;

*order=freq sorts frequencies in descending order;
*nlevels tells you the number of levels/bins;
proc freq data=work.sales order=freq nlevels;
	by region; 
	tables product /nocum plots=freqplot(orient=horizontal scale=percent); *creates one product table for each region and a plot;
run;

proc sort data=work.sales out=sortedsales;
	format netsales dollar15.;
	where Region = "United States";
	by NetSales descending Inventory;
run; 

proc sort data=work.sales out=sortsales noduprecs Dupout=sortsalesdups;
	where Region = "United States";
	by _ALL_; *sorts all columns by descending order;
	*Noduprecs removes duplicates and stores them in dupout file;
run;

proc sort data=sortsales out=sortsalesuniq nodupkey Dupout=sortsalesnonuniq;
	by Subsidiary;
	*Nodupkey keeps only the first occurence of each unique value.
	The column name after by statement determines the key/unique value;
run;

**************************;
data storm_windavg;
    set pg1.storm_range;
    WindAvg=mean(wind1, wind2, wind3, wind4);
    WindRange=range(of wind1-wind4);
run; 

data storm_new;
	set pg1.storm_damage;
	drop Summary;
	*Add assignment and FORMAT statements;
	YearsPassed=yrdif(Date,Today(),"age");
	Anniversary=mdy(month(date), day(Date),year(today()));
	format YearsPassed 4.1 Date Anniversary mmddyy10;
run;

data cars2;
	set sashelp.cars;
	if MSRP<30000 then Cost_Group=1;
	if MSRP>=30000 then Cost_Group=2;
	keep Make Model Type MSRP Cost_Group;
run;

data under40 over40;
    set sashelp.cars;
	keep Make Model MSRP Cost_Group;
    if MSRP<20000 then do;
       Cost_Group=1;
       output under40;
    end;
    else if MSRP<40000 then do;
       Cost_Group=2;
       output under40;
    end;
    else do;
       Cost_Group=3;
       output over40;
    end;
run;

data cars2;
    set sashelp.cars;
    length CarType $ 6; *definning the character column with a lenght of 6;
    if MSRP<60000 then CarType="Basic";
    else CarType="Luxury";
    keep Make Model MSRP CarType;
run;

data indian atlantic pacific;
	set pg1.storm_summary;
	length Ocean $ 8;
	keep Basin Season Name MaxWindMPH Ocean;
	Basin=upcase(Basin);
	OceanCode=substr(Basin,2,1);
	*Modify the program to use IF-THEN-DO syntax;
	if OceanCode="I" then do;
		Ocean="Indian";
		output indian;
	end;
	else if OceanCode="A" then do;
		Ocean="Atlantic";
		output atlantic;
	end;
	else do; 
		Ocean="Pacific";
		output pacific;
	end;
run;

data parks monuments;
    set pg1.np_summary;
    where type in ('NM', 'NP');
    Campers=sum(OtherCamping, TentCampers, RVCampers,
                BackcountryCampers);
    format Campers comma17.;
    length ParkType $ 8;
    select (type);
        when ('NP') do;
            ParkType='Park';
            output parks;
		end;
		otherwise do;
            ParkType='Monument';
            output monuments;
		end;
    end;
    keep Reg ParkName DayVisits OtherLodging Campers ParkType;
run;

%let DateOfToday= date();
footnote "Footnote: Report Generated for Parks created &DateOfToday";
proc print data=parks;
run;
footnote; *turn footnote off;

proc freq data=pg1.storm_final order= freq nlevels; *order=freq ->ascending order/ nlevels->table of number of levels per column;
	tables BasinName StartDate; 
	format StartDate monname.; *format how startdate is printed;
run;

proc freq data=pg1.storm_final;
	tables BasinName*StartDate / norow nocol nopercent; *cross-tabulation frequency tables. Only include frequency;
	format StartDate monname.;
run;

*cross-tabulation frequency tables presented differently;
proc freq data=pg1.storm_final;
	tables BasinName*StartDate / crosslist;
	format StartDate monname.;
run;

*cross-tabulation frequency tables presented differently;
proc freq data=pg1.storm_final noprint; *suppress the printing report;
	tables BasinName*StartDate / list out=pg1.storm_count; *the frequency table becomes an output SAS table;;
	format StartDate monname.;
run;

proc sgplot data=pg1.np_codelookup;
    where Type in ('National Historic Site', 'National Monument',
                   'National Park');
    hbar region / group=type seglabel
                  fillattrs=(transparency=0.5) dataskin=crisp;
    keylegend / opaque across=1 position=bottomright
                location=inside;
    xaxis grid;
run;

proc means data=sashelp.heart noprint;
	var Weight;
	class Chol_Status;
	ways 1;
	*output statistics to a SAS table;
	output out=heart_stats mean=AvgWeight;
run;

**************EPG194 Activity p105a08*************;
*  Activity 5.08                                 *;
*    Run the program and examine the results to  *;
*    see examples of other procedures that       *;
*    analyze and report on the data.             *;
**************************************************;

%let Year=2016;
%let basin=NA;

**************************************************;
*  Creating a Map with PROC SGMAP                *;
*   Requires SAS 9.4M5 or later                  *;
**************************************************;

*Preparing the data for map labels;
data map;
	set pg1.storm_final;
	length maplabel $ 20;
	where season=&year and basin="&basin";
	if maxwindmph<100 then MapLabel=" ";
	else maplabel=cats(name,"-",maxwindmph,"mph");
	keep lat lon maplabel maxwindmph;
run;

*Creating the map;
title1 "Tropical Storms in &year Season";
title2 "Basin=&basin";
footnote1 "Storms with MaxWind>100mph are labeled";

proc sgmap plotdata=map;
    *openstreetmap;
    esrimap url='http://services.arcgisonline.com/arcgis/rest/services/World_Physical_Map';
            bubble x=lon y=lat size=maxwindmph / datalabel=maplabel datalabelattrs=(color=red size=8);
run;
title;footnote;

**************************************************;
*  Creating a Bar Chart with PROC SGPLOT         *;
**************************************************;
title "Number of Storms in &year";
proc sgplot data=pg1.storm_final;
	where season=&year;
	vbar BasinName / datalabel dataskin=matte categoryorder=respdesc;
	xaxis label="Basin";
	yaxis label="Number of Storms";
run;

**************************************************;
*  Creating a Line PLOT with PROC SGPLOT         *;
**************************************************;
title "Number of Storms By Season Since 2010";
proc sgplot data=pg1.storm_final;
	where Season>=2010;
	vline Season / group=BasinName lineattrs=(thickness=2);
	yaxis label="Number of Storms";
	xaxis label="Basin";
run;

**************************************************;
*  Creating a Report with PROC TABULATE          *;
**************************************************;

proc format;
    value count 25-high="lightsalmon";
    value maxwind 90-high="lightblue";
run;

title "Storm Summary since 2000";
footnote1 "Storm Counts 25+ Highlighted";
footnote2 "Max Wind 90+ Highlighted";

proc tabulate data=pg1.storm_final format=comma5.;
	where Season>=2000;
	var MaxWindMPH;
	class BasinName;
	class Season;
	table Season={label=""} all={label="Total"}*{style={background=white}},
		BasinName={LABEL="Basin"}*(MaxWindMPH={label=" "}*N={label="Number of Storms"}*{style={background=count.}} 
		MaxWindMPH={label=" "}*Mean={label="Average Max Wind"}*{style={background=maxwind.}}) 
		ALL={label="Total"  style={vjust=b}}*(MaxWindMPH={label=" "}*N={label="Number of Storms"} 
		MaxWindMPH={label=" "}*Mean={label="Average Max Wind"})/style_precedence=row;
run;
title;
footnote;

******************************************;

*export to excel;
data xlout.South_Pacific;
	set pg1.storm_final;
	where Basin="SP";
run;

*export to excel;
proc means data=pg1.storm_final noprint maxdec=1;
	where Basin="SP";
	var MaxWindKM;
	class Season;
	ways 1;
	output out=xlout.Season_Stats n=Count mean=AvgMaxWindKM max=StrongestWindKM;
run;

************export to csv;
ods csvall file= "&outpath/cars.csv";
proc print data = sashelp.cars noobs;
	var Make Model Type MSRP MPG_City MPG_Highway;
	format MSRP dollar8;
run;
ods csvall close;

*********export to PDF;
ods pdf file="&outpath/wind.pdf";
ods noproctitle;
title "Wind Statistics by Basin";
proc means data=pg1.storm_final min mean median max maxdec=0;
    class BasinName;
    var MaxWindMPH;
run;
title "Distribution of Maximum Wind";
proc sgplot data=pg1.storm_final;
    histogram MaxWindMPH;
    density MaxWindMPH;
run; 
title;  
ods pdf close;

proc sql;
select Name, Age, Height*2.54 as HeightCM format 5.1,
       Birthdate format=date9.
    from pg1.class_birthdate
    where age > 14 
    order by Height desc;
quit; 

proc sql;
*asterisct after select, selects all columns;
create table work.storm_table as
 select * 
 	from pg1.storm_final (drop=Lat);
quit;

proc sql;
create table top_damage as
select Event, 
       Date format=monyy7.,
       Cost format=dollar16.
       from pg1.storm_damage
       order by Cost desc;
title "Top 10 Storms by Damage Cost";
    select *
        from top_damage(obs=10);
quit;

proc sql;
select Season, Name, s.Basin, BasinName, MaxWindMPH 
    from pg1.storm_summary as s 
        inner join pg1.storm_basincodes as b 
        on upcase(s.basin)=b.basin 
    order by Season desc, Name;
quit; 


libname pg1 clear; *not necessary as it does it when you close SAS;
libname xlout clear; *lets people edit the excel file;
title;
ods proctitle;

*The code below only outputs data for year 3 given the implicit output;
*implicit output occurs after the run statement for each row; 
data forecast;
	set sashelp.shoes;
	keep Region Product Subsidiary Year ProjectedSales;
	format ProjectedSales dollar10.;
    Year=1;
	ProjectedSales=Sales*1.05;
	Year=2;
	ProjectedSales=ProjectedSales*1.05;
	Year=3;
	ProjectedSales=ProjectedSales*1.05;
run;
	

*The code below only outputs data for all years and implicit output is ommitted;
data forecast;
    set sashelp.shoes;
    keep Region Product Subsidiary Year ProjectedSales;
    format ProjectedSales dollar10.;
    Year=1;
    ProjectedSales=Sales*1.05;
    output;
    Year=2;
    ProjectedSales=ProjectedSales*1.05;
    output;
    Year=3;
    ProjectedSales=ProjectedSales*1.05;
    output;
run;


data indian (drop=MaxWindMPH)atlantic (drop=MaxWindKM) pacific; *column drop for each table;
*column drop below doesn't create column in the PDV, hence cannot use for calculations;
	set pg2.storm_summary (drop=MinPressure); 
	length Ocean $ 8;
	Basin=upcase(Basin);
	StormLength=EndDate-StartDate;
	MaxWindKM=MaxWindMPH*1.60934;
	if substr(Basin,2,1)="I" then do;
		Ocean="Indian";
		output indian;
	end;
	else if substr(Basin,2,1)="A" then do;
		Ocean="Atlantic";
		output atlantic;
	end;
	else do;
		Ocean="Pacific";
		output pacific;
	end;
	drop Season; *column drop for all tables but kept in PDV;
run;

data monument(drop=ParkType) park(drop=ParkType) other;
    set pg2.np_yearlytraffic;
    select (ParkType);
        when ('National Monument') output monument;
        when ('National Park') output park;
        otherwise output other;
    end;
    drop Region;
run;
*same as code in AA;
data houston_rain;
	set pg2.weather_houston;
	*initializing column to zero and retaining value for each iteration;
	keep Date DailyRain YTDRain;
	retain YTDRain 0;
	YTDRain=sum(YTDRain,DailyRain);
	DayNum+1;
/*	YTDRain=YTDRain+DailyRain; *this statement fails if DailyRain is missing;*/
run;
*AA;
data houston_rain;
	set pg2.weather_houston;
	*initializing column to zero and retaining value for each iteration;
	keep Date DailyRain YTDRain;
	YTDRain+DailyRain;
	DayNum+1; *adds column with iteration number;
run;

*The RETAIN statement can be used for purposes other than accumulating columns. 
Create new columns that sequentially store the maximum value to date for Count, 
as well as the corresponding values for Month and Location.;
data cuyahoga_maxtraffic;
    set pg2.np_monthlyTraffic;
    where ParkName = 'Cuyahoga Valley NP';
    retain TrafficMax 0 MonthMax LocationMax;
    if Count>TrafficMax then do;
        TrafficMax=Count;
        MonthMax=Month;
        LocationMax=Location;
    end;
    format Count TrafficMax comma15.;
    keep Location Month Count TrafficMax MonthMax LocationMax;
run;

proc sort data=pg2.storm_2017 out=storm2017_sort(keep=_ALL_);
	by Basin;
run;

*data step below has to be ran after the proc sort step above;
data storm2017_max;
	set storm2017_sort;
	by Basin; 
	*the by statement creates the first.basin & last.basin columns in the PDV. 
	But, it is not an output to the table, unless we explicitly create 
	new columns like below;
	First_Basin=first.basin; 
	Last_Basin=last.basin;
run;
data storm2017_max;
	set storm2017_sort;
	by Basin;
	*where does not work as last.column are assinged in the execution phase;
/*	where last.basin=1;*/
	If last.basin=1; *if false, following code is 
	skipped including implicit output and moves onto next iteration;
	StormLength=EndDate-StartDate;
	MaxWindKM=MaxWindMPH*1.60934;
run;
data houston_monthly;
	set pg2.weather_houston;
	keep Date Month DailyRain MTDRain YTDRain;
	by Month;
	if first.Month = 1 then MTDRain=0;
	MTDRain+DailyRain;
	YTDRain+DailyRain;
run;

data houston_monthly;
	set pg2.weather_houston;
	keep Date Month DailyRain MTDRain;
	by Month;
	if first.Month=1 then MTDRain=0;
	MTDRain+DailyRain;
	*AA, AB and AC are equivalent statements; 
	if last.Month=1; *Only outputs last month. AA;
/*	if last.Month; *AB;*/
/*	if last.Month then output;*AC;*/
run;

proc sort data=pg2.np_acres 
          out=sortedAcres(keep=Region ParkName State GrossAcres);
    by Region ParkName;
run;
*needs sorting code above first;
data multiState singleState;
    set sortedAcres;
    by Region ParkName;
    if First.ParkName=1 and Last.ParkName=1 
        then output singleState;
    else output multiState;
    format GrossAcres comma15.;
run;

data quiz_summary;
	set pg2.class_quiz;
	Name=upcase(Name);
	Mean1=mean(Quiz1, Quiz2, Quiz3, Quiz4, Quiz5);
	/* Numbered Range: col1-coln where n is a sequential number */ 
	Mean2=mean(of Quiz1-Quiz5);
	/* Name Prefix: all columns that begin with the specified character string */ 
	AvgQuiz=mean(of Q:);
	format Quiz1--AvgQuiz 3.1; *formating columns from Quiz1 to AvgQuiz;
	*another way to format all numeric columns;
	format _numeric_ 3.1; 
	*Keywords _all_ and _character_ are also available;
run;

data quiz_summary;
	set pg2.class_quiz;
	*sortn routine re-orders values in columns from low to high;
	call sortn (of Quiz1-Quiz5);
	*function below is averaging the highest 3 quizes. Data is already sorted with sortn;
	QuizAvg=mean(of Quiz3-Quiz5);
run;

/* Step: long missing values*/
data quiz_report;
    set pg2.class_quiz;
	if Name in("Barbara", "James") then do;
		Quiz1=.;
		Quiz2=.;
		Quiz3=.;
		Quiz4=.;
		Quiz5=.;
	end;
run;

/* Same as step: long missing values above*/
data quiz_report;
    set pg2.class_quiz;
	if Name in("Barbara", "James") then call missing(of Q:);
run;


/* SAS macro that duplicates the Excel RANDBETWEEN function */
%macro RandBetween(min, max);
   (&min + floor((1+&max-&min)*rand("uniform")))
%mend;

data quiz_analysis;
	studentID=%RandBetween(1000,9999);
	set pg2.class_quiz;
	drop Quiz1-Quiz5 name;
    Quiz1st=largest(1, of Quiz1-Quiz5); *function gets the largest of q1-5;
	Quiz2nd=largest(2, of Quiz1-Quiz5);
	Quiz3rd=largest(3, of Quiz1-Quiz5);
	Top3Avg=round(mean(Quiz1st,Quiz2nd,Quiz3rd));
run;
data wind_avg;
	set pg2.storm_top4_wide;
	WindAvg1=round(mean(of Wind1-Wind4), .1);
	WindAvg2=mean(of Wind1-Wind4); 
	format WindAvg2 5.1; 
run;

data storm_detail2;
	set pg2.storm_detail;
	WindDate=datepart(ISO_Time);
	WindTime=timepart(ISO_Time);
	format WindDate date9. WindTime time.;
run;
data storm_length;
	set pg2.storm_final(obs=10);
	keep Season Name StartDate Enddate StormLength Weeks;
	Weeks=intck('week', StartDate, EndDate,'c'); *discrete count of weeks;
	Weeks=intck('week', StartDate, EndDate,'c'); *continuous count of weeks;
run;


data storm_damage2;
	set pg2.storm_damage;
	keep Event Date AssessmentDate1 AssessmentDate2 AssessmentDate3 Anniversary;
	AssessmentDate1=intnx('month', Date, 0);*shifts dates by 0 months and to the 1st day;
	AssessmentDate2=intnx('month', Date, 2);*shifts dates forward by 2 months and to the 1st day;;
	AssessmentDate3=intnx('month', Date, -1);*backwards 1 month, day 1;
	Anniversary=intnx("year", Date, -1, "end");*backwards 1 year, day 30/31;
    format Date AssessmentDate1 AssessmentDate2 AssessmentDate3 Anniversary date9.;
run;
proc sort data=pg2.np_weather(keep=Name Code Date Snow)
          out=winter2015_2016;
    where date between '01Oct15'd and '01Jun16'd and Snow > 0;
    by Code Date;
run;

data snowforecast;
    set winter2015_2016;
    retain FirstSnow;
    by Code;
    if first.Code then FirstSnow=Date;
    if last.Code then do;
        LastSnow=Date;
        WinterLengthWeeks=intck('week', FirstSnow, LastSnow, 'c');
		*projectedfirst snow is the same day next year;
        ProjectedFirstSnow=intnx('year', FirstSnow, 1, 'same');
        output;
    end;
    format FirstSnow LastSnow ProjectedFirstSnow date7.;
    drop Snow Date;	
run;

data weather_japan_clean;
    set pg2.weather_japan;
	*convert each occurrence of two or more consecutive blanks into a single blank;
    NewLocation=compbl(Location);
	*removes blank characters;
	NewStation=compress(Station);
	*removes spaces and '-' characters;
	NewStation=compress(Station,"- ");
run;

data weather_japan_clean;
	set pg2.weather_japan;
	Location=compbl(Location); *removing extra blanks;
	City=propcase(scan(Location, 1,','),"");*only the space should be treated as a limiter between words;
	Prefecture=scan(Location, 2,',');*specifies what are the delimiters;
	Country=scan(Location,-1);
run;

data weather_japan_clean;
	set pg2.weather_japan;
	Location=compbl(Location);
	City=propcase(scan(Location, 1, ','), ' ');
	*Adding a space as a delimiter works if there are no spaces 
	embedded in City or Prefecture.
	The STRIP function removes leading and training blanks.;
	Prefecture=strip(scan(Location, 2, ','));
	if Prefecture="Tokyo";
run;
data storm_damage2;
    set pg2.storm_damage;
    drop Date Cost Deaths;
    CategoryLoc=find(Summary, 'Category', 'i');
    if CategoryLoc > 0 then 
       Category=substr(Summary, CategoryLoc, 10);
	*The SUBSTR function starts at the number stored in CategoryLoc 
	   and reads 10 characters, and returns the string to Category.;
run;

data storm_id;
	set pg2.storm_final;
	keep StormID: ;
	Day=StartDate-intnx('year', StartDate, 0);
	StormID1=cat(Name, Season, Day);
	StormID2=cats(Name, Season, Day);
	StormID3=catx("-", Name, Season, Day);
	StormID2=cats(Name, '-', Season, Day);
run;
*LENGTH:figuring out what is a good lenght for a column;
data parklookup;
    set pg2.np_unstructured_codes end=lastrow;
    length ParkCode $ 4;
    ParkCode=scan(Column1, 2, '{}:,"()-');
    ParkName=scan(Column1, 4, '{}:,"()');
	*code below is to figure out what is a good lenght for column ParkName;
    retain MaxLength 0;
    NameLength=length(ParkName);
    MaxLength=max(NameLength,MaxLength);
    if lastrow=1 then putlog MaxLength=;
run;

proc print data=parklookup(obs=10);
run;

proc contents data=parklookup;
run;
*Same as LENGTH code, but this time we know what is a good lenght.;
data parklookup;
    set pg2.np_unstructured_codes end=lastrow;
    length ParkCode $ 4 ParkName $ 83;
    ParkCode=scan(Column1, 2, '{}:,"()-');
    ParkName=scan(Column1, 4, '{}:,"()');
/*     retain MaxLength 0; */
/*     NameLength=length(ParkName); */
/*     MaxLength=max(NameLength,MaxLength); */
/*     if lastrow=1 then putlog MaxLength=; */
run;

proc print data=parklookup(obs=10);
run;

proc contents data=parklookup;
run;

data work.stocks2;
    set pg2.stocks2;
    Date2=input(Date,date9.);
    Volume2=input(Volume,comma12.);
run;

data work.stocks2;
	set pg2.stocks2 (rename=(Volume=CharVolume));
	Date2=input (Date,date9);
	Volume=input (CharVolume,comma12.);
	drop CharVolume;
run;
/* INPUT Function */
data atl_precip;
	set pg2.weather_atlanta;
	where AirportCode='ATL';
	drop AirportCode City Temp: ZipCode;
	if precip ne "T" then PrecipNum=input(Precip, 6.);
	else PrecipNum=0;
	TotalPrecip+PrecipNum;
run;

data atl_precip;
	set pg2.weather_atlanta(rename= (date=CharDate));
	where AirportCode='ATL';
	drop AirportCode City Temp: ZipCode CharDate;
	if precip ne "T" then PrecipNum=input(Precip, 6.);
	else PrecipNum=0;
	TotalPrecip+PrecipNum;
	Date=input(CharDate,mmddyy10.);
	Format Date date9.;
run;

/* PUT Function */
data atl_precip;
	set pg2.weather_atlanta;
	*catx takes numbers and strings;
	CityStateZip=catx(' ' ,city,'GA',ZipCode);
	ZipCodeLast2=substr(put(ZipCode,z5.), 4, 2);
run;

data work.stocks2;
    set pg2.stocks2(rename=(Volume=CharVolume Date=CharDate));
    Volume=input(CharVolume,comma12.);
    Date=input(CharDate,date9.);
    drop Char:;
run;

/*Create format called genfmt and HRANGE ( low-lowest value, high is highest value)*/
proc format;
    value $genfmt 'F'='Female'
                  'M'='Male';
    *modify the following VALUE statement;
    value HRANGE low-<58 = "Below Average"
                 58-60 = "Average"
                 60<-high = "Above Average"
                 other = 'Miscoded';
run;

proc format;
    value $region 'NA'='Atlantic'
                  'WP','EP','SP'='Pacific'
                  'NI','SI'='Indian'
                  ' '='Missing'
                  other='Unknown';
run;

data storm_summary;
    set pg2.storm_summary;
    Basin=upcase(Basin);
    BasinGroup=put(Basin, $region.);
run;

/* Building a custom format */
data sbdata;
    retain FmtName '$sbfmt';
    set pg2.storm_subbasincodes(rename=(Sub_Basin=Start 
                                        SubBasin_Name=Label));
    keep Start Label FmtName;
run;

proc format cntlin=sbdata;
run;


/*Create the CATFMT format for storm categories*/
data catdata;
    retain FmtName "catfmt";
    set pg2.storm_categories(rename=(Low=Start 
                                     High=End
                                     Category=Label));
    keep FmtName Start End Label;
run;


/* The CNTLIN= option specifies a table from which formats are built */
proc format cntlin=catdata;
run;

proc format fmtlib library=work;
select $sbfmt catfmt;
run;


/* Specify where to save the format. can save in pg2 catalog or pg2.formats catalog */
/* proc format library=pg2 OR */
proc format library=pg2.formats;
    value $gender 'F'='Female'
                  'M'='Male'
                  other='Miscoded';
    value hght low-<58  = 'Below Average'
                58-60   = 'Average'
               60<-high = 'Above Average';
run;

/*options fmtsearch=(pg2);
or */
options fmtsearch=(pg2.formats);

proc print data=pg2.class_birthdate noobs;
    where Age=12;
    var Name Gender Height;
    format Gender $gender. Height hght.;
run;

/* Create custom formats for table without missing labels */
data np_lookup;
    retain FmtName '$RegLbl';
    set pg2.np_codeLookup(rename=(ParkCode=Start));
    if Region ne ' ' then Label=Region;
    else Label='Unknown';
    keep Start Label FmtName;
run;


/* Concatenating Tables with matching columns */
data class_current;
    set sashelp.class 
	pg2.class_new2(rename=(Student=Name));
run;

data work.np_combine;
    LENGTH 8$
    set pg2.np_2014(rename=(Park=ParkCode Type=ParkType))
        pg2.np_2015 
        pg2.np_2016;
    CampTotal=sum(of Camping:);
    where Month in(6, 7, 8) and ParkType="National Park";
    format CampTotal comma15.;
    drop Camping:;
run;


/* Merging tables */
proc sort data=pg2.class_teachers out=teachers_sort;
	by Name;
run;

proc sort data=pg2.class_test2 out=test2_sort;
	by Name;
run;

data class2;
    merge teachers_sort test2_sort;
    by Name;
run;


/*%let statements define macro variables containing lists of */
/*dataset variables*/
%let categorical=House_Style Overall_Qual Overall_Cond Year_Built 
ods graphics;
proc freq data=STAT1.ameshousing3;
    tables &categorical / plots=freqplot ;
    format House_Style $House_Style.
           Overall_Qual Overall.
           Overall_Cond Overall.
           ;
    title "Categorical Variable Frequency Analysis";
run; 

/*st101d01.sas*/  /*Part C*/
/*PROC UNIVARIATE provides summary statistics and plots for */
/*interval variables.  The ODS statement specifies that only */
/*the histogram be displayed.  The INSET statement requests */
/*summary statistics without having to print out tables.*/
ods select histogram;
ods select histogram;
proc univariate data=STAT1.ameshousing3 noprint;
    var &interval;
    histogram &interval / normal kernel;
    inset n mean std / position=ne;
    title "Interval Variable Distribution Analysis";
run;

/* Ttest H0 is null value, interval shows confidence interval*/
ods graphics;
proc ttest data=STAT1.ameshousing3 
           plots(shownull)=interval
           H0=135000;
    var SalePrice;
    title "One-Sample t-test testing whether mean SalePrice=$135,000";
run;
title;

/*Two-Sample t-test*/
ods graphics;
proc ttest data=STAT1.ameshousing3 plots(shownull)=interval;
    class Masonry_Veneer;
    var SalePrice;
    format Masonry_Veneer $NoYes.;
    title "Two-Sample t-test Comparing Masonry Veneer, No vs. Yes";
run;
title;

/*SalesPrice=>y and Liv_Area=>x, reg means show regression line*/
proc sgscatter data=STAT1.ameshousing3;
    plot SalePrice*Gr_Liv_Area / reg;
    title "Associations of Above Grade Living Area with Sale Price";
run;

%let interval=Gr_Liv_Area Basement_Area Garage_Area Deck_Porch_Area 
         Lot_Area Age_Sold Bedroom_AbvGr Total_Bathroom;

/*You can make several plots in one statement and tell it not to use labels*/
options nolabel;
proc sgscatter data=STAT1.ameshousing3;
    plot SalePrice*(&interval) / reg;
    title "Associations of Interval Variables with Sale Price";
run;

/*sGLM, diagnostic produce panel display of diagnostics plot*/
/* Levene's test for homogeneity is used to test the assumption of equal variances */
ods graphics;
proc glm data=STAT1.ameshousing3 plots=diagnostics;
    class Heating_QC;
    model SalePrice=Heating_QC;
	means Heating_QC / hovtest=levene;  /* compute undjusted means/ arithmetic means and perform levenes test of homogeneity for anova*/
    format Heating_QC $Heating_QC.;
    title "One-Way ANOVA with Heating Quality as Predictor";
run;
quit;
title;

/*Anova with with GLM to determine which pairs are significant diff*/
/* Also made pairwise comparisons and applied tukey's asseement as well as comparison to a control using Dunnett's adjustment */
ods graphics;
ods select lsmeans diff diffplot controlplot;
proc glm data=STAT1.ameshousing3 
         plots(only)=(diffplot(center) controlplot); /* diffplot modifies diffogram produced by lsmeans with pdiff=all */
    class Heating_QC; /* classification variable */
    model SalePrice=Heating_QC; /* response variable */
    lsmeans Heating_QC / pdiff=all 
                         adjust=tukey; /* spec predictor variable pdiff requests pdiff for differences, pdiff = all compares all means and produces diffogram automatically */
    lsmeans Heating_QC / pdiff=control('Average/Typical') 
                         adjust=dunnett; /* adjustment method for multiple comparisons, default is tukey, pdiff=control requests that each level be compared to control*/
    format Heating_QC $Heating_QC.;
    title "Post-Hoc Analysis of ANOVA - Heating Quality as Predictor";
run;
quit;
title;

/* Scatter plot for all variables based on correlation*/
%let interval=Gr_Liv_Area Basement_Area Garage_Area Deck_Porch_Area 
         Lot_Area Age_Sold Bedroom_AbvGr Total_Bathroom;
ods graphics / reset=all imagemap;  /*imagemap shows html like object*/
proc corr data=STAT1.AmesHousing3 rank
          plots(only)=scatter(nvar=all ellipse=none); /* rank by descending for all variables */
   var &interval;
   with SalePrice;
   id PID;
   title "Correlations and Scatter Plots with SalePrice";
run;
title;

proc corr data=stat1.bodyfat2 nosimple
             plots(only)=scatter(nvar=all);
             var Age Weight Height;   
          run;

/*Correlation matrix to show multicolinearity and show no descriptive statistics*/
ods graphics off;
proc corr data=STAT1.AmesHousing3 
          nosimple 
          best=3;
   var &interval;
   title "Correlations and Scatter Plot Matrix of Predictors";
run;
title;

/* Simple linear regression*/
ods graphics;
proc reg data=STAT1.ameshousing3;
    model SalePrice=Lot_Area;
    title "Simple Regression with Lot Area as Regressor";
run;
quit;
title;

/* Group categorical predictive variables and display descriptive statistics */
ods graphics off;
proc means data=STAT1.ameshousing3
           mean var std nway;
    class Season_Sold Heating_QC;
    var SalePrice;
    format Season_Sold Season.;
    title 'Selected Descriptive Statistics';
run;

/* Interaction plot with season in x_axis and heating_qc as vertical line */
proc sgplot data=STAT1.ameshousing3;
    vline Season_Sold / group=Heating_QC 
                        stat=mean 
                        response=SalePrice 
                        markers;
    format Season_Sold season.;
run; 

/* 2 way Anova, internal means keep internally defined encoding like 1,2,3,4 */
ods graphics on;
proc glm data=STAT1.ameshousing3 order=internal;
    class Season_Sold Heating_QC;
    model SalePrice = Heating_QC Season_Sold;
    lsmeans Season_Sold / diff adjust=tukey;
    format Season_Sold season.;
    title "Model with Heating Quality and Season as Predictors";
run;
quit;
title;

ods graphics on;
proc glm data=STAT1.ameshousing3 
         order=internal 
         plots(only)=intplot; /* interaction plot */
    class Season_Sold Heating_QC;
    model SalePrice = Heating_QC Season_Sold Heating_QC*Season_Sold; /* included interraction effect */
    lsmeans Heating_QC*Season_Sold / diff slice=Heating_QC; /* compute lsmeans of all groups in the cross factors, slice interraction effect by the different levels of heating_qc*/
    format Season_Sold Season.;
    store out=interact; /* save to item store */
    title "Model with Heating Quality and Season as Interacting Predictors";
run;
quit;

/* access item store and make adjustments without refitting model, adjust=tukey adjests p-value for multiple comparison test */
proc plm restore=interact plots=all; /* produces plots for all the statement included in the step */
    slice Heating_QC*Season_Sold / sliceby=Heating_QC adjust=tukey;
    effectplot interaction(sliceby=Heating_QC) / clm; /* show interraction plot sliceby heating_qc, clm requests confidence intervals for the mean */
run; 
title;

/* multiple regression */
ods graphics on;
proc reg data=STAT1.ameshousing3 ;
    model SalePrice=Basement_Area Lot_Area;
    title "Model with Basement Area and Lot Area";
run;
quit;

proc glm data=STAT1.ameshousing3 
         plots(only)=(contourfit);
    model SalePrice=Basement_Area Lot_Area;
    store out=multiple;
    title "Model with Basement Area and Gross Living Area";
run;
quit;

proc plm restore=multiple plots=all;
    effectplot contour (y=Basement_Area x=Lot_Area);
    effectplot slicefit(x=Lot_Area sliceby=Basement_Area=250 to 1000 by 250);
run; 

title;

/* Macros */
proc print data=orion.customer_dim;  
   footnote "Report Created on &sysdate";
run;

%symdel level ordertype;     /* deleting macros */

%let location=DE;
title "Customers in &location";
proc print data=orion.customer;
   var Customer_ID Customer_Name Gender; 
   where Country="&location";
run;

/* Display macros using symbolgen or put */
options nosymbolgen;
%let type=Internet;
proc print data=orion.customer_dim;
   var Customer_Name Customer_Gender Customer_Age;
   where Customer_Group contains "&type";
   title "&type Customers";
run;
%put The value of macro variable Type is &type;
title;

/* Macro delimiters for library*/
set &year..sales

/* Macro delimiters for words*/
work.&season.rate

%let month=JUL;
%let year=2003;
proc print data=orion.organization_dim;
   where Employee_Hire_Date="01&month&year"d;
   id Employee_ID;
   var Employee_Name Employee_Country Employee_Hire_Date;
   title "Personal Information for Employees Hired in &month &year";
run;

/* Macros function */
%let secondwd=%substr("Four score and seven",6,5);
%let area2=%scan(&location,2,*); /* '*' is a delimiter */
%upcase(&month)
%eval(&firstyr+&numyears-1);   /* only integers*/
%let b=%sysevalf(10.5+20.8, param);  /* floating point arithmetic. Param can be boolean, ceil or floor*/
%let current=%sysfunc(time(),time.); /* %sysfunc allows you to use SAS functions and specify formats */
%let d=%sysfunc(mdy(01,01,2000),weekdate.);
%substr(&text,7,8) /* extract 8 characters from position 7 */
%str(code)  /* Helps to wrap special characters, it's not good for  & or %*/
%let list=%str(one;two;); /* Need to add %() to any self closing tag */
%let company=%nrstr(AT&T);  /* Not resolved str is used to mask it now */

/* Creating Macro Variables at Execution Time */
call symputx('interest','varies');    /* As arguments for the SYMPUTX routine, you specify the macro variable name interest and the value varies, and you enclose both arguments in quotation marks.  */
call symputx('cost', price);  /* Can also pass in data step values */
call symputx('daily_fee',put(fee/days,dollar6.)); /* Can also pass in functions */

%let idnum=121044;
data _null_;
   set orion.employee_addresses;
   where employee_ID=&idnum;
   call symputx ('name',employee_name); /*name is macro-variable, employee name is the value*/
run;
proc print data=orion.orders noobs;
   var order_ID order_type order_date delivery_date;
   where employee_ID=&idnum;
title "Orders Taken by Employee &idnum: &name";
run;

%let id=1020;
data _null_; /* Execute without writing observations to a dataset*/
   set orion.customer_type;
   call symputx('type'||left(customer_type_id),customer_type);  /* Left concatenates it */
   /*Alternative solution using the CATS function*/
   /*call symputx(cats('type',customer_type_id),customer_type);*/
run;
proc print data=orion.customer;
   var Customer_Name Customer_ID Gender;
   where customer_type_id=&id;
title "A list of &&type&id"; /* Delay resolution of reference until second scan i.e id assignment. Known as forward rescan rule. 2&& resolves to 1 */
run;

/* PROC SQL */
proc sql;
	select n(distinct city_state)
		into :numlocs
	from students;
	%let numlocs=&numlocs; /* Remove blanks */
	select distinct city_state
		into :place1-:place&numlocs 
	from students;
quit;

/* You can filter by averages i.e you compute avgs, assign to macros and filter it */
title; 
footnote; 
%let start=01Jan2011;
%let stop=31Jan2011;
proc means data=orion.order_fact noprint;
   where order_date between "&start"d and "&stop"d;
   var Quantity Total_Retail_Price;
   output out=stats_q_p mean=Avg_Quant Avg_Price;
run;
data _null_;
   set stats_q_p;
   call symputx('Quant',put(Avg_Quant,4.2));
   call symputx('Price',put(Avg_Price,dollar7.2));
run;
proc print data=orion.order_fact noobs n;
   where order_date between "&start"d and "&stop"d;
   var Order_ID Order_Date Quantity Total_Retail_Price;
   sum Quantity Total_Retail_Price;
   format Total_Retail_Price dollar6.;
   title1 "Report from &start to &stop";
   title3 "Average Quantity: &quant";
   title4 "Average Price: &price";
run;
/* Delete the macro variables Quant and Price from the Global Symbol Table */
%symdel quant price;

/* Replace the PROC MEANS step and the DATA step with a PROC SQL step */
%let start=01Jan2011;
%let stop=31Jan2011;
proc sql noprint;
   select mean(quantity) format=4.2,
          mean(total_retail_price)format=dollar7.2
      into :quant, :price
      from orion.order_fact
      where order_date between "&start"d and "&stop"d;
quit;
proc print data=orion.order_fact noobs n; /* displays no of observations */
   where order_date between "&start"d and "&stop"d;
   var Order_ID Order_Date Quantity Total_Retail_Price;
   sum Quantity Total_Retail_Price;
   format Total_Retail_Price dollar6.;
   title1 "Report from &start to &stop";
   title3 "Average Quantity: &quant";
   title4 "Average Price: &price";
run;
title;

/* You can make initial code shorter using PROC SQL */
%let year=2011;
proc sql noprint;
   select avg(Quantity), avg(Total_Retail_Price)
      into:qty, :price
      from orion.order_fact
      where year(Order_Date)=&year;
run;
%let qty=&qty;
%let price=&price;
title "Orders Exceeding Average in &year";
footnote "Average Quantity: &qty";
footnote2 "Average Price: &price";
proc print data=orion.order_fact noobs;
   where year(Order_Date)=&year and Quantity>&qty
         and Total_Retail_Price>&price;
   var Customer_ID order_id Order_Date Quantity Total_Retail_Price;
run;
title;
footnote;

/* Creating a macro of unique values in a column */
proc sql noprint;
	select distinct Country
		into :countries
		seperated by ', '
		from orion.customer;
quit;

%put &countries /* Write value of countries to the log */

/* Define Macro, Compile Macro(submit) and Call the Macro */
options mcompilenote=all; /* Show compile note in log */
%macro puttime;
   %put The current time is %sysfunc(time(),timeampm.).;
%mend puttime;

/* Check if macro was stored in catalog */
proc catalog cat=work.sasmacr;
   contents;
   title "My Temporary Macros";
quit;
title;
%puttime  /* Calling defined macro*/

/* Syslast stores name of most recently created dataset */
options mcompilenote=all;
%macro prtlast;
   proc print data=&syslast (obs=10);
      title "Listing of &syslast";
   run;
   title;
%mend;

/* Use it to print last sata or proc step */
data work.customers;
   set orion.customer;
   keep Customer_ID Country Customer_Name;
run;
options mprint;    /* MPRINT displays SAS statements generated by macros execution */
%prtlast
proc sort data=work.customers out=work.sort_customers;
   by Country;
run;
options mprint;    /* MPRINT displays SAS statements generated by macros execution */
%prtlast

/* Using positional parameters in macro definitions */
options mcompilenote=all;
%macro count(opts, start, stop);
   proc freq data=orion.orders;
      where Order_Date between "&start"d and "&stop"d;
      table Order_Type / &opts;  /* Opts is options for statistics */
      title1 "Orders from &start to &stop";
   run;  
   title;
%mend count;
options mprint;
%count(nocum,01jan11,31dec11)
%count(,01jul11,31dec11)  /* comma is used as placeholder to have a null value */

/* Use keyword parameters, you specify key = value */
%macro count(opts=,start=01jan11,stop=31dec11); /* Opt has null default value */
   proc freq data=orion.orders;
      where Order_Date between "&start"d and "&stop"d;
      table Order_Type / &opts;
      title1 "Orders from &start to &stop";
   run;       
   title;
%mend count;
options mprint;
%count()
%count(opts=nocum)
%count(stop=01jul11,opts=nocum nopercent)

/* Parameters can also me mixed i.e positional and keywords. You list the positional first */
%macro count(opts,start=01jan11,stop=31dec11);
   proc freq data=orion.orders;
      where Order_Date between "&start"d and "&stop"d;
      table Order_Type / &opts;
      title1 "Orders from &start to &stop";
   run;   
   title;
%mend count;
options mprint;
%count()
%count(nocum)
%count(stop=30jun11,start=01apr11) /* assigned null to opts*/
%count(nocum nopercent,stop=30jun11)

/* MACROS CONDITIONAL PROCESSING */
%macro count(type=,start=01jan2011,stop=31dec2011);
   proc freq data=orion.order_fact;
      where Order_Date between "&start"d and "&stop"d;
      table quantity;
      title1 "orders from &start to &stop";
      %if &type=  %then %do;
         title2 "For All Order types";
      %end;
      %else %do;
         title2 "For Order type &type Only";
         where same and Order_Type=&type;
      %end;
   run;   
   title;
%mend count;
options mprint mlogic;

%count()
%count(type=3)

%macro cust(place);
   %let place=%upcase(&place);
   data customers;
      set orion.customer;
   %if &place=US %then %do;
      where Country='US';
      keep Customer_Name Customer_Address Country;
   %end;
   %else %do;
      where Country ne 'US';
      keep Customer_Name Customer_Address Country Location;
      length location $ 12;
      if      country="AU" then location='Australia';
      else if country="CA" then location='Canada';
      else if country="DE" then location='Germany';
      else if country="IL" then location='Israel';
      else if country="TR" then location='Turkey';
      else if country="ZA" then location='South Africa';
   %end;
   run;
   title;
%mend cust;

options mprint mlogic; /* mlogic is used to monitor SAS execution */
%cust(us)
%cust(international)

/* Can use %INCLUDE */
%macro reports;
    %include 'daily.sas';
	  %if &sysday=Friday %then %do;
	     %include 'weekly.sas';
    %end;
%mend;

/* Processing partial macros statements */
%macro counts(rows);
   title 'Customer Counts by Gender';
   proc freq data=orion.customer_dim;
   tables
   %if &rows ne  %then &rows *;
      Customer_Gender;  /* If you specify rows it's tables rows*customer_gender (2-way freq table) else it's just tables customer_gender (1-way freq table) */
   run;
   title;
%mend counts;
options mprint mlogic;
%counts()
%counts(customer_age_group)

/* Validating macros conditionals */
options mprint mlogic symbolgen;
%macro customers(place) / minoperator; /* Or "options MINOPERATOR" to be able to use in the macros globally*/
   %let place=%upcase(&place);
   proc sql noprint;
      select distinct Country into :list separated by ' '
         from orion.customer;
   quit;
   %if &place in &list %then %do;  /* %if not (&var in AU CA DE US); */
      proc print data=orion.customer;
         var Customer_Name Customer_Address Country;
         where upcase(country)="&place";
         title "Customers from &place";
      run;
      title;
   %end;
   %else %do;
      %put Sorry, no customers from &place..;
      %put Valid countries are: &list..;
   %end;  
%mend customers;
%customers(de)
%customers(dk)

/* Macros iterative processes */
options mlogic mprint;
%macro read(first=2007,last=2011);
   %do year=&first %to &last;
      data orders&year;
         infile "my-file-path\orders&year..dat"; 
         /* infile "my-file-path\ord&year..dat"; * z/OS */
         input Order_ID Order_Type Order_Date : date9.;
      run;
  %end;
%mend read;

%read(first=2008,last=2010)

options  nomlogic nosymbolgen mprint;
%macro split (data=, var=);
   proc sort data=&data(keep=&var) out=values nodupkey;
      by &var;
   run;
   data _null_;
      set values end=last;
      call symputx('site'||left(_n_),&var);
      if last then call symputx('count',_n_);
   run;
   %put _local_; /* Print local variables to log */
data
   %do i=1 %to &count;
      &&site&i
   %end;
   ;
      set &data;
      select(&var);
   %do i=1 %to &count;
      when("&&site&i") output &&site&i;
   %end;
      otherwise;
      end;
   run;
%mend split;

/* Displaying all the datasets in a library with an option of specifying no of obs */
options nosymbolgen nomlogic mprint;
options MSTORED SASMSTORE=printlib; /* Storing the macro */
%macro printlib(lib=WORK,obs=5) /store;
   %let lib=%upcase(&lib);
      data _null_;
      set sashelp.vstabvw end=final;
      where libname="&lib";
      call symputx('ds'||left(_n_),memname, 'L'); /* 'L' is scope i.e Local, 'G' is Global */
      if final then call symputx('totaldsn',_n_);
   run;
   %do i=1 %to &totaldsn;
      proc print data=&lib..&&ds&i(obs=&obs);
      title "&lib..&&ds&i Data Set";
      run;
   %end;  
   title;
%mend printlib;

%printlib(lib=orion)

/* Storing the macros */
options mstored sasmstore=orion;
%macro autocust /STORE;
   proc print data=orion.customer_dim;
      var customer_name customer_gender customer_age;
      title "Customers Listing as of &systime";      
   run;
%mend autocust;
proc catalog cat=orion.sasmacr;
   contents;
quit;
%autocust

/* %* is comment in macros*/