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

* import county population
import delimited "$Data\co-est2018-alldata.csv", varnames(1) clear
tostring state county, replace
replace state = "0"+ state if length(state) == 1
replace county = "0" + county if length(county) == 2
replace county = "00" + county if length(county) == 1
gen FIPS = state+county
tempfile county_pop
save `county_pop'

* import 2016 results by county
import delimited "$Data\countypres_2000-2016.csv", clear stringcols(5)
keep if year == 2016
keep if office == "President"
replace fips = "0"*(5-length(fips))+fips
ren fips FIPS
destring candidatevotes, replace force
keep candidatevote FIPS state state_po county party
reshape wide candidatevote, i(FIPS state state_po county) j(party) string
ren candidatevotesdemocrat votes_dem
ren candidatevotesrep votes_gop
gen total_votes = candidatevotesNA + votes_dem + votes_gop
drop candidatevotesNA
drop if FIPS == "000NA"
tempfile county_2016
save `county_2016'

* import indivisible events
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

* Export events
export delimited using "$Data\events_xy_output.csv", replace

* merge the matched polygons with the database and get attributes
merge m:1 _ID using "$Data\county_data.dta", keep(master match) 
keep if _m == 3
drop _m
gen FIPS = STATEFP + COUNTYFP
merge m:1 FIPS using `county_classify', keepus(TypeNumber)
drop _m

gen counter = 1 if event != ""
collapse (sum) counter, by(FIPS Type)
destring Type, replace

merge m:1 FIPS using `county_pop', keepus(pop)
keep if _m == 3
drop _m

merge m:1 FIPS using `county_2016', keepus(*votes* state county)
replace votes_dem = 0 if _n < 96 & _n > 68
replace votes_gop = 0 if _n < 96 & _n > 68
replace total_votes = 0 if _n < 96 & _n > 68
keep if _m == 3
drop _m

* mark who won
gen w2016 = "D" if votes_dem > votes_gop
replace w2016 = "R" if votes_dem < votes_gop
save "$Data\indivisible_in_counties", replace

* christmas tree plot
gen per_100k = 100000*counter/pop
sort TypeNumber per_100k
replace TypeNumber = TypeNumber - .13 if w2016 == "D"
replace TypeNumber = TypeNumber + .13 if w2016 == "R"
twoway ///
(scatter per_100k TypeNumber if w2016 == "R", ///
msize(med) mcolor(cranberry%10)) ///
(scatter per_100k TypeNumber if w2016 == "D", ///
msize(med) mcolor(blue%10))


collapse (sum) pop counter *vote*, by(Type)
gen pct_trump = votes_gop/total_votes
// drop *votes*




