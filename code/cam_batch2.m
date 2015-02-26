function cam_batch2(basin_number,cam_dataset)
% batch file for CAM analysis
% NAME:
%   cam_batch2
% PURPOSE:
%   call climdada routines to generate cyclone tracks and loss frequency curves
%  
% CALLING SEQUENCE:
%   cam_batch(basin_number,cam_dataset);
% EXAMPLE:
%   cam_batch(1,['wehner'|'present_day'|'rcp45'|'rcp85']);
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   basin_number: the basin numer, see climada_tc_filter_basin
%       default=1 for North Atlantic
%       currently, only 1 (North Atl) implemetned
%   cam_dataset: ['wehner'|'present_day'|'rcp45'|'rcp85']
% OUTPUTS:
% MODIFICATION HISTORY:
% Andrew Gettelman May 5 2014: based on cam_batch.m  code for original (2012) climada
%-
global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%%% TEST 
basin_number=1;
cam_dataset='present_day';

%%%% SET UP PATHS %%%

hazard_dir=[climada_global.root_dir filesep 'data' filesep 'hazards'];
results_dir=[climada_global.root_dir filesep 'data' filesep 'results'];
entity_dir=[climada_global.root_dir filesep 'data' filesep 'entities'];
system_dir=[climada_global.root_dir filesep 'data' filesep 'system'];
cam_data_dir=[climada_global.modules_dir filesep 'CAM'  filesep 'data' filesep 'track_data_ibtrac' filesep cam_dataset];
%cam_data_dir=[climada_global.modules_dir filesep 'CAM'  filesep 'data' filesep 'track_data_V01' filesep cam_dataset];
cam_tc_track_dir=[climada_global.modules_dir filesep 'CAM' filesep 'data' filesep 'tc_tracks' filesep cam_dataset];
cam_tc_track_file=[climada_global.modules_dir filesep 'CAM' filesep 'data' filesep 'tc_tracks' filesep cam_dataset filesep 'tc_track_cam.mat'];

%%% CAM TC TRACKS (calculate or read) %%%

if ~exist(cam_tc_track_file,'file')
    % read raw CAM data and store as tc_track structure
    % Track file generation.
    tc_track=climada_tc_read_cam_ibtrac_v01([cam_data_dir filesep 'cam_tracfile.nc'])%
%    tc_track=climada_tc_read_cam_database_V01(cam_data_dir);
    save(cam_tc_track_file,'tc_track','-v7.3');
else
    fprintf('reading CAM data from %s...\n',cam_tc_track_file);
    load(cam_tc_track_file);
end

% note, define basin number: only have entities for N. Atlantic right now
basin = basin_number;
hazname='TCNA';
% if basin eq 3 then hazmame='TCWP';

%%% Probabilistic Tracks %%%

tc_track_prob=climada_tc_random_walk(tc_track,basin);

%%% Generate Hazard Set and Statistics %%%

hazard_set_file=[hazard_dir filesep hazname '_hazard_' cam_dataset '.mat'];
centroids=[system_dir filesep 'USFL_MiamiDadeBrowardPalmBeach_centroids.mat'];

hazard_prob=climada_tc_hazard_set(tc_track_prob,hazard_set_file,centroids);
climada_hazard_stats(hazard_prob);  % Makes a plot

%New Entity files... 

entity_file_today=[entity_dir filesep 'USFL_MiamiDadeBrowardPalmBeach_today.xls'];
entity_today=climada_entity_read(entity_file_today,hazard_set_file);   


%new: climada-master generate Damage Frequency curve...
EDS_today=climada_EDS_calc(entity_today,hazard_prob);
EDS_today_file= ['EDS_today_' cam_dataset '.mat'];
climada_EDS_save(EDS_today,EDS_today_file);

climada_EDS_DFC(EDS_today);

%%% Add Observations... %%%

%Need unisys tracks too 

tc_track_obs=climada_tc_read_unisys_database;  
tc_track_prob_obs=climada_tc_random_walk(tc_track_obs,basin);

hazard_set_file_obs=[hazard_dir filesep hazname '_hazard_obs.mat'];

hazard_prob_obs=climada_tc_hazard_set(tc_track_prob_obs,hazard_set_file_obs,centroids);
climada_hazard_stats(hazard_prob_obs);
EDS_obs=climada_EDS_calc(entity_today,hazard_prob_obs);
EDS_obs_file= ['EDS_today_obs.mat'];
climada_EDS_save(EDS_obs,EDS_obs_file);


%If EDS files exist, they can be compared...
file1=[results_dir filesep 'EDS_today_obs.mat'];
file2=[results_dir filesep 'EDS_today_' cam_dataset '.mat'];
climada_EDS_DFC(file1,file2,1);

return
