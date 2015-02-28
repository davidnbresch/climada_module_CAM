% selected_countries_CAM
% climada batch code
% MODULE:
%   CAM
% NAME:
%   selected_countries_CAM
% PURPOSE:
%   Run all CAM project countries, all calculations
%
%   run this code (see PARAMETERS)
%   - first with  check_country_names=1;
%     > checks for country list being ok
%   - second check_country_names=0
%     > generates all entities (the assets) and hazard event sets and
%     calculates damages
%   - subsequent calls just repeat the damage calculations (unless you set
%     country_risk_calc_force_recalc=1). Thus if you repeat the second step,
%     since all hazard sets are stored, it will be fast and easy to play with
%     parameters (e.g. damage functions). 
%
%   SPECIAL: in order to process CAM files only, the global variable
%   climada_global.tc.default_raw_data_ext is set to '.nc' to avoid
%   processing the UNISYS ('.txt') files in tc_track, see also code
%   centroids_generate_hazard_sets
%
%   run as a batch code, such that all is available on command line, all
%   PARAMETERS are set in this file, see section below
%
% CALLING SEQUENCE:
%   selected_countries_CAM % a batch code
% EXAMPLE:
%   selected_countries_CAM % a batch code
% INPUTS:
%   see PARAMETERS in this batch code
% OPTIONAL INPUT PARAMETERS:
% OUTPUTS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150203, initial (on ICE to Paris)
% David N. Bresch, david.bresch@gmail.com, 20150206, tested, ok
% David N. Bresch, david.bresch@gmail.com, 20150228, tested including asset scaling, ok
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% PARAMETERS
%
% switches to run only parts of the code:
% ---------------------------------------
%
% define the peril to treat. If ='', run TC, TS and TR (and also EQ and WS,
% but this does not take much time, see PARAMETERS section in
% centroids_generate_hazard_sets)
peril_ID='TC'; % default='TC'
%
%climada_global.tc.default_raw_data_ext='.nc'; % to restrict to netCDF TC track files
climada_global.tc.default_raw_data_ext='.txt'; % to restrict to UNISYS TC track files
%
% to check for climada-conformity of country names
check_country_names=0; % default=0, if=1, stops after check
%
% parameters for country_risk_calc
% method=-3: default, using GDP_entity and probabilistic sets, see country_risk_calc
% method=3: FAST for checks, using GDP_entity and historic sets, see country_risk_calc
% method=-7: skip entity and hazard generation, probabilistic sets, see country_risk_calc
country_risk_calc_method=3; % default=-3, using GDP_entity and probabilistic sets, see country_risk_calc
country_risk_calc_force_recalc=0; % default=0, see country_risk_calc
%
% whether we calculate admin1 level (you might not set this =1 for the full
% country list, i.e. first run all requested countries with
% calculate_admin1=0, then restrict the list and only run with
% calculate_admin1=1 for these (e.g. USA, CHN...)
calculate_admin1=0; % default=0
%
% where we store the .mat file with key results, set='' to omit
country_risk_results_mat_file=[climada_global.data_dir filesep 'results' filesep 'CAM_country_risk.mat'];
%
% where we store the results table, set='' to omit writing the report
damage_report_filename=[climada_global.data_dir filesep 'results' filesep 'CAM_country_risk_report.xls'];
%
% whether we plot all the global damage frequency curves
plot_global_DFC=1; % WARNING: needs a X-windows server or the like
plot_max_RP=500; % the maxium RP we show (to zoom in a bit)
%
% the explicit list of countires we'd like to process
% see climada_country_name('ALL'); to obtain it. The ones either not TC
% exposed or otherwise not needed are just commented out 
country_list={
    %'Afghanistan'
    %'Akrotiri'
    %'Aland'
    %'Albania'
    %'Algeria'
    %'American Samoa'
    %'Andorra'
    %'Angola'
    'Anguilla'
    %'Antarctica'
    'Antigua and Barbuda'
    %'Argentina'
    %'Armenia'
    'Aruba'
    %'Ashmore and Cartier Islands'
    'Australia'
    %'Austria'
    %'Azerbaijan'
    'Bahamas'
    %'Bahrain'
    %'Baikonur'
    %'Bajo Nuevo Bank (Petrel Islands)'
    'Bangladesh'
    'Barbados'
    %'Belarus'
    %'Belgium'
    'Belize'
    %'Benin'
    'Bermuda'
    %'Bhutan'
    %'Bolivia'
    %'Bosnia and Herzegovina'
    %'Botswana'
    %'Brazil'
    %'British Indian Ocean Territory'
    'British Virgin Islands'
    %'Brunei'
    %'Bulgaria'
    %'Burkina Faso'
    %'Burundi'
    'Cambodia'
    %'Cameroon'
    %'Canada'
    %'Cape Verde'
    'Cayman Islands'
    %'Central African Republic'
    %'Chad'
    %'Chile'
    'China'
    %'Clipperton Island'
    'Colombia'
    'Comoros'
    %'Congo'
    %'Cook Islands'
    %'Coral Sea Islands'
    'Costa Rica'
    %'Cote dIvoire'
    %'Croatia'
    'Cuba'
    %'Curacao' % NOT supported in climada_create_GDP_entity
    %'Cyprus'
    %'Cyprus UN Buffer Zone'
    %'Czech Republic'
    %'Democratic Republic of the Congo'
    %'Denmark'
    %'Dhekelia'
    %'Djibouti'
    'Dominica'
    'Dominican Republic'
    %'Ecuador'
    %'Egypt'
    'El Salvador'
    %'Equatorial Guinea'
    %'Eritrea'
    %'Estonia'
    %'Ethiopia'
    %'Faeroe Islands'
    %'Falkland Islands'
    'Fiji'
    %'Finland'
    %'France'
    %'French Polynesia'
    %'French Southern and Antarctic Lands '
    %'Gabon'
    %'Gambia'
    %'Georgia'
    %'Germany'
    %'Ghana'
    %'Gibraltar'
    %'Greece'
    %'Greenland'
    'Grenada'
    'Guam'
    'Guatemala'
    %'Guernsey'
    %'Guinea'
    %'Guinea-Bissau'
    'Guyana'
    'Haiti'
    %'Heard Island and McDonald Islands '
    'Honduras'
    'Hong Kong'
    %'Hungary'
    %'Iceland'
    'India'
    %'Indian Ocean Territory' % NOT supported in climada_create_GDP_entity
    'Indonesia'
    %'Iran'
    %'Iraq'
    %'Ireland'
    %'Isle of Man'
    %'Israel'
    %'Italy'
    'Jamaica'
    'Japan'
    %'Jersey'
    %'Jordan'
    %'Kazakhstan'
    %'Kenya'
    'Kiribati'
    'Korea'
    %'Kosovo'
    %'Kuwait'
    %'Kyrgyzstan'
    'Laos'
    %'Latvia'
    %'Lebanon'
    %'Lesotho'
    %'Liberia'
    %'Libya'
    %'Liechtenstein'
    %'Lithuania'
    %'Luxembourg'
    %'Macao' % NOT supported in climada_create_GDP_entity
    %'Macedonia'
    'Madagascar'
    %'Malawi'
    'Malaysia'
    %'Maldives' % NOT supported in climada_create_GDP_entity
    %'Mali'
    %'Malta'
    'Marshall Islands'
    %'Mauritania'
    'Mauritius'
    'Mexico'
    'Micronesia'
    %'Moldova'
    %'Monaco'
    %'Mongolia'
    %'Montenegro' % NOT supported in climada_create_GDP_entity
    'Montserrat'
    %'Morocco'
    'Mozambique'
    'Myanmar'
    %'Namibia'
    'Nauru'
    %'Nepal'
    %'Netherlands'
    'New Caledonia'
    'New Zealand'
    'Nicaragua'
    %'Niger'
    %'Nigeria'
    %'Niue'
    %'Norfolk Island'
    %'North Cyprus'
    %'North Korea'
    'Northern Mariana Islands'
    %'Norway'
    %'Oman'
    'Pakistan'
    'Palau'
    %'Palestine'
    'Panama'
    'Papua New Guinea'
    %'Paraguay'
    %'Peru'
    'Philippines'
    'Pitcairn Islands'
    %'Poland'
    %'Portugal'
    'Puerto Rico'
    %'Qatar'
    %'Romania'
    %'Russia'
    %'Rwanda'
    'Saint Helena'
    'Saint Kitts and Nevis'
    'Saint Lucia'
    %'Saint Martin' % NOT supported in climada_create_GDP_entity
    'Saint Pierre and Miquelon'
    'Saint Vincent and the Grenadines'
    'Samoa'
    %'San Marino'
    'Sao Tome and Principe'
    %'Saudi Arabia'
    %'Scarborough Reef'
    %'Senegal'
    %'Serbia'
    %'Serranilla Bank'
    'Seychelles'
    %'Siachen Glacier'
    %'Sierra Leone'
    'Singapore'
    %'Sint Maarten' % NOT supported in climada_create_GDP_entity
    %'Slovakia'
    %'Slovenia'
    'Solomon Islands'
    %'Somalia'
    %'Somaliland'
    %'South Africa'
    'South Georgia and South Sandwich Islands'
    %'South Sudan'
    %'Spain'
    %'Spratly Islands' % NOT supported in climada_create_GDP_entity
    'Sri Lanka'
    %'St-Barthelemy' % NOT supported in climada_create_GDP_entity
    %'Sudan'
    'Suriname'
    %'Swaziland'
    %'Sweden'
    %'Switzerland'
    %'Syria'
    'Taiwan'
    %'Tajikistan'
    %'Tanzania'
    'Thailand'
    %'Timor-Leste'
    %'Togo'
    'Tonga'
    'Trinidad and Tobago'
    %'Tunisia'
    %'Turkey'
    %'Turkmenistan'
    'Turks and Caicos Islands'
    'Tuvalu'
    %'US Minor Outlying Islands' % NOT supported in climada_create_GDP_entity (even an error)
    'US Virgin Islands'
    %'USNB Guantanamo Bay'
    %'Uganda'
    %'Ukraine'
    %'United Arab Emirates'
    %'United Kingdom'
    'United States'
    %'Uruguay'
    %'Uzbekistan'
    'Vanuatu'
    %'Vatican'
    'Venezuela'
    'Vietnam'
    %'Wallis and Futuna Islands'
    %'Western Sahara'
    %'Yemen'
    %'Zambia'
    %'Zimbabwe'
    };
%
% % only wpa (West Pacific Ocean) - to show how one can define a region
% country_list={
%     'Cambodia'
%     'China'
%     'Hong Kong'
%     'Indonesia'
%     'Japan'
%     'Korea'
%     'Laos'
%     'Malaysia'
%     'Micronesia'
%     'Myanmar'
%     'Philippines'
%     'Singapore'
%     'Taiwan'
%     'Thailand'
%     'Vietnam'
%     };
%
% % TEST list (only a few)
% % ----
% country_list={
%     'Bangladesh'
%     'Barbados'
%     'El Salvador'
%     'Vietnam'
%     };
%
% more technical parameters
climada_global.waitbar=0; % switch waitbar off (especially without Xwindows)


% check names
if check_country_names
    for country_i=1:length(country_list)
        [country_name,country_ISO3,shape_index] = climada_country_name(country_list{country_i});
        fprintf('%s: %s %s\n',country_list{country_i},country_name,country_ISO3);
    end % country_i
    climada_plot_world_borders(1,country_list) % plot and show selected in yellow
    fprintf('STOP after check country names, now set check_country_names=0\n')
    return
end

% next lines is called twice (see further below) as on first call, we
% create all entities and hazard event sets, then scale asset valuea, then
% repeat damage calculation (just to illustrate, the experienced user will
% only run what he/she needs ;-)
% create entities, hazard sets and calculate damage on admin0 (country) level
country_risk=country_risk_calc(country_list,country_risk_calc_method,country_risk_calc_force_recalc,0,peril_ID);

% country_risk now contains the results based on climada's GDP-based asset
% estimates, now adjust for CAM:

% adjust asset value of today's assets
cam_entity_value_GDP_SSP('*_*_entity.mat',2015); % all today for 2015

% adjust asset value of all future assets
cam_entity_value_GDP_SSP('*_future.mat',2035) % all future for 2035

% calculate damage on admin0 (country) level
country_risk=country_risk_calc(country_list,country_risk_calc_method,country_risk_calc_force_recalc,0,peril_ID);

% next line allows to combine sub-perils, such as wind (TC) and surge (TS)
% EDC is the maximally combined EDS, i.e. only one fully combined EDS per
% hazard and region, i.e. one EDS for all TC Atlantic damages summed up
% (per event), one for TC Pacific etc.
[country_risk,EDC]=country_risk_EDS_combine(country_risk); % combine TC and TS and calculate EDC

if ~isempty(country_risk_results_mat_file)
    fprintf('storing country_risk and EDC in %s\n',country_risk_results_mat_file);
    save(country_risk_results_mat_file,'country_risk','EDC')
end % country_risk_results_mat_file

% next few lines would allow results by state/province (e.g. for US states)
if calculate_admin1
    % calculate damage on admin1 (state/province) level
    probabilistic=0;if country_risk_calc_method<0,probabilistic=1;end
    country_risk1=country_admin1_risk_calc(country_list,probabilistic,0);
    country_risk1=country_risk_EDS_combine(country_risk1); % combine TC and TS
end % calculate_admin1

% next line allows to calculate annual aggregate where appropriate
% see also below in plot_global_DFC
%country_risk=country_risk_EDS2YDS(country_risk);

% write a short report to stdout
fprintf('\n\n');
country_risk_report_raw(country_risk);
fprintf('\n\n');

if ~isempty(damage_report_filename)
    if calculate_admin1
        country_risk_report([country_risk country_risk1],1,damage_report_filename);
    else
        country_risk_report(country_risk,1,damage_report_filename);
    end
end % generate_damage_report

if plot_global_DFC
   
   % cr_DFC_plot(country_risk); each single country
   cr_DFC_plot_aggregate(country_risk,[],[],0); % save image, do NOT plot
    
end % plot_global_DFC
