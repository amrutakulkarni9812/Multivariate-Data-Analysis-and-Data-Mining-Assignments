/*Code to import the data set*/
proc import out = multi
	datafile = "C:\Users\Nishaat\Desktop\Multivariate\Project\multi.csv"
	dbms = csv 
	replace;   
	getnames = Yes;
	Datarow = 2;
run;

/*Rename the columns with more intuitive names*/
data multi;
set multi;
rename SeriousDlqin2yrs = Sdl2
		RevolvingUtilizationOfUnsecuredL = RUL
		age = AgeY
		NumberOfTime30_59DaysPastDueNotW = Due3059
		DebtRatio = Debt
		MonthlyIncome = Incom
		NumberOfOpenCreditLinesAndLoans = OCLL
		NumberOfTimes90DaysLate = Due90
		NumberRealEstateLoansOrLines = RELL
		NumberOfTime60_89DaysPastDueNotW = Due6089
		NumberOfDependents = Depen;
run;
ods graphics on;

/*Remove the outliers and missing values*/
data Cleaned_Multi;
set multi;
		if Incom = "NA" then delete;
	    if Depen = "NA" then delete;
		if RUL > 5 then delete;
		if 18 > AgeY > 90 then delete;
		if Debt > 7 then delete;
		if OCLL > 24 then delete;
		if RELL > 30 then delete;
		if Incom > 100000 then delete;
		if Depen > 10 then delete;
	
run;

/*Convert the data type of Income and NoOfDependents columns from character to numeric so as to perform further operations*/
data Cleaned_Multi;
	set Cleaned_Multi;
	Income = Incom * 1;
	Depend = Depen * 1;
	drop incom depen;
	run;

/*Normalize the data so as to bring all variables to the same range*/
proc standard data=Cleaned_Multi mean=0 std=1 out=zCrRisk;
var RUL AgeY Due3059 Debt Income OCLL Due90 RELL Due6089 Depend;
run;

/*Find correlations among all the independent variables*/
proc corr data=zCrRisk ;
var RUL AgeY Due3059 Debt Income OCLL Due90 RELL Due6089 Depend;
run;

/*Perform Principal Component Analysis on independent variables to get rid of correlations*/
proc princomp data=zCrRisk out=princout;
var RUL AgeY Due3059 Debt Income OCLL Due90 RELL Due6089 Depend;
run;

/*Perform Factor Analysis on independent variables to group them and get less number of factors than independent variables*/
proc factor data = zCrRisk method = principal rotate = varimax score 
mineigen=1 nfactors=4  residuals eigenvectors out=factout outstat=fact;
	var RUL AgeY Due3059 Debt Income OCLL Due90 RELL Due6089 Depend;
run;
/*Get the output of factors in factout data set*/

/*Divide the factor data into 70% training and 30% test data*/
proc surveyselect data=factout samprate=0.70 seed=49201 out=jk outall 
method=srs noprint;
run;

data training testing;
set jk;
if selected = 1 then output training;
else output testing;
drop selected;
run;

/*Perform cluster analysis on the factor data set and plot the output clusters*/
ods graphics on;
proc fastclus data=Factout maxc=2 maxiter=10 out=clus;
   var Factor1 Factor2 Factor3 Factor4;
run;

proc freq;
   tables cluster*Sdl2;
run;

proc candisc ncan = 2 out=can;
   class cluster;
   var Factor1 Factor2 Factor3 Factor4;
   title3 'Canonical Discriminant Analysis of Clusters';
run;

proc sgplot data= can;
   scatter y=Can2 x=Can1 / group=cluster;
   title3 'Plot of clusters';
run;

dm "odsresults; clear";

/* Perform K Nearest Neighbor Analysis on the factor data set*/

title;
proc discrim data = training method = npar k = 20
	testdata = testing
	testout = Test_Out;
	class Sdl2;
	var Factor1 Factor2 Factor3 Factor4;
run;

dm "odsresults; clear";

/*Perform Linear Discriminant Analysis on the factor data set*/

/*Check statistics of both groups (group 0 = People who won't face credit default, group 1 = People who will face credit default)*/

title;
proc discrim data=Training anova all distance outstat = dis method = normal pool=yes testdata = Testing TESTout = LDA_Out 
crossvalidate outcross = cross1 mahalanobis posterr;
	priors equal ;
	class Sdl2;
	var Factor1 Factor2 Factor3 Factor4;
run;

/*proc print data = Validate_Out;*/

/*Perform Logistic Regression on the factor data set*/
ods graphics on;
   proc logistic data=training outest=betas covout plots(only)=(roc(id=obs) effect);
      model Sdl2(event = '1') = RUL AgeY Due3059 Debt Income OCLL Due90 RELL Due6089 Depend
					/ selection=stepwise
                     slentry=0.3
                     slstay=0.35
                     details
                     lackfit;
      output out=pred p=phat lower=lcl upper=ucl
             predprob=(individual crossvalidate);
   run;
   ods graphics off;
