// This file spatially joins xy data to shapefiles

* set up
clear
set type double
cd "C:\Users\perez_g\Desktop\Data_vis_wa\data_vis_wa\Dollar store\Stata\Programs"

gl root "C:\Users\perez_g\Desktop\Data_vis_wa\data_vis_wa\Dollar store"
gl GIS "$root/GIS"
gl Stata "$root/Stata"
gl Data "$Stata/Data"
gl Dollar_data "$root/Dollar store data"
gl Electoral_data "$root/Electoral data"
gl Citylab_data "$root/City lab data"

*Create a Dta from a shape file
capture shp2dta using "$GIS/tl_2017_us_county.shp", genid(_ID) data("$Data\county_data.dta") coor("$Data\county_coor.dta") replace

import excel "$Data\County-Type-Share.xlsx", sheet("Sheet1") firstrow clear allstring
replace FIPS = "0"+FIPS if length(FIPS) == 4
drop if FIPS == ""
tempfile county_classify
save `county_classify'

import delimited "$Data\co-est2018-alldata.csv", varnames(1) clear
tostring state county, replace
replace state = "0"+ state if length(state) == 1
replace county = "0" + county if length(county) == 2
replace county = "00" + county if length(county) == 1
gen FIPS = state+county
tempfile county_pop
save `county_pop'

import delimited "$Electoral_data\indivisible_events.csv", varnames(1) clear
tostring zipcode, replace
replace zipcode = "0"*(5-length(zipcode))+zipcode if zipcode != "."
save "$Data\events2", replace

* import zipless groups
import delimited "$Data\zipless_indivisble_groups.csv", varnames(1) stringcols(3 4) clear
drop if zipcode == ""
drop count
tempfile zipless_fixed
save `zipless_fixed'

* import zip xy
import delimited "$GIS\Shapefiles\zipxy.txt", varnames(1) clear
ren ïzip zipcode
tostring zipcode, replace
replace zipcode = "0"*(5-length(zipcode))+zipcode
save "$Data\zipxy", replace

* append all groups and match-in zip XY
use "$Data\events2", clear
drop if length(zipcode) != 5
append using "$Data/indivisible_geocoded"
append using `zipless_fixed'
replace ïevent = event if missing(ïevent)
drop event
ren ïevent event
duplicates drop event location zipcode, force
replace zipcode = strtrim(zipcode)
merge m:1 zipcode using "$Data/zipxy"
drop if _m == 2

* fix x y for geoinpoly
destring x y, replace
replace x = lat if x ==.
replace y = lng if y ==.
drop lat lng _merge
gen flag = 1 if x==.
drop if flag == 1
sort location zipcode
gen _Y = x
gen _X = y

* Spatial join using geoinpoly points to polygons
geoinpoly _Y _X using "$Data\county_coor.dta"

* merge the matched polygons with the database and get attributes
merge m:1 _ID using "$Data\county_data.dta", keep(master match) 
keep if _m == 3
drop _m
gen FIPS = STATEFP + COUNTYFP
merge m:1 FIPS using `county_classify', keepus(TypeNumber)
drop _m

gen counter = 1 if event != ""
collapse (sum) counter, by(FIPS Type)

merge m:1 FIPS using `county_pop', keepus(pop)
keep if _m == 3
drop _m

collapse (sum) pop counter, by(Type)

/*
* events per district
gen counter = 1
collapse (sum) counter, by(_ID STATEFP)
ren counter indivisible_groups
save "$Data\Events_in_dist", replace

// drop if STATEFP == "02" | STATEFP == "15"
// * Make PA map
// spmap counter using "$Data\Districts_coor.dta" , id(_ID) fcolor(Reds) ///
// legend(symy(*2) symx(*2) size(*2) position (4)) 



use "$Data/dollar_master_clean", clear
merge m:1 _ID using "$Data\Events_in_dist"
keep if _m == 3

// graph of
keep if dis == "TX-04" | dis == "TX-05" | dis == "TX-08" | dis == "TX-11" ///
| dis == "TX-13" | dis == "TX-19" | dis == "TX-36" | dis == "GA-01" ///
| dis == "GA-09" | dis == "GA-10" | dis == "GA-14" | dis == "OK-01" ///
| dis == "AL-01" | dis == "AL-04" | dis == "AZ-08" | dis == "IL-15" ///
| dis == "IL-16" | dis == "KY-02" | dis == "KY-05" | dis == "KS-01"

sort Nu
graph bar Nu, over(dis)

TX-4, TX-5, TX-8, TX-11, TX-13, TX-19, TX-36, GA-1, GA-9, GA-10, GA-14, OK-1, AL-1, AL-4, AZ-8, IL-15, IL-16, KY-2, KY-5 & KS-1
twoway scatter indivi Num, ///
msize(vsmall) ///
mcolor(lavender%50) ///
mstyle(o) ///
graphregion(color(white)) ///
ylab(,nogrid) ///
ytitle("Indivisible Groups")

collapse (median) indivi, by(bin)
graph dot indi, over(bin) vertical





