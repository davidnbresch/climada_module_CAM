function cam_batch(basin_number,cam_dataset)
% batch file for CAM analysis
% NAME:
%   cam_batch
% PURPOSE:
%   call climdada routines to generate cyclone tracks and loss frequency curves
%  
% CALLING SEQUENCE:
%   cam_batch(basin_number);
% EXAMPLE:
%   cam_batch(1,['wehner'|'present_day'|'rcp45'|'rcp85']);
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   basin_number: the basin numer, see climada_tc_filter_basin
%       default=1 for North Atlantic
%       currently, only 1 (North Atl) implemetned
% OUTPUTS:
% MODIFICATION HISTORY:  NOTE: SUPERSCEEDED BY cam_batch2.m
% Andrew Gettelman
% David N. Bresch, david.bresch@gmail.com, 20150819, climada_global.centroids_dir
%-
global climada_global
if ~climada_init_vars,return;end % init/import global variables

hazard_dir=[climada_global.root_dir filesep 'data' filesep 'hazards'];
cam_data_dir=[climada_global.root_dir '_additional' filesep 'CAM'  filesep 'data' filesep 'track_data_V01' filesep cam_dataset];
cam_tc_track_dir=[climada_global.root_dir '_additional' filesep 'data' filesep 'tc_tracks' filesep cam_dataset];
cam_tc_track_file=[cam_tc_track_dir filesep 'tc_track_cam.mat'];
if ~exist(cam_tc_track_file,'file')
    % read raw CAM data and store as tc_track structure
    % Track file generation.
    tc_track=climada_tc_read_cam_database_V01(cam_data_dir);
    save(cam_tc_track_file,'tc_track','-v7.3');
else
    fprintf('reading CAM data from %s...\n',cam_tc_track_file);
    load(cam_tc_track_file);
end

% note, define basin number: only have entities for N. Atlantic right now
basin = basin_number;
hazname='TCNA';
% if basin eq 3 then hazmame='TCWP';

tc_track_prob=climada_tc_random_walk(tc_track,basin);

% need unisys tracks too 
tc_track_obs=climada_tc_read_unisys_database;  %(this works)
tc_track_prob_obs=climada_tc_random_walk(tc_track_obs,basin);

% prepare centroids
centroids=climada_centroids_read([climada_global.centroids_dir filesep 'USFL_MiamiDadeBrowardPalmBeach_centroids.xls']);

% calculate hazard event set
hazard_set_file=[hazard_dir filesep hazname '_hazard_test.mat'];

hazard_prob=climada_tc_hazard_set(tc_track_prob,hazard_set_file,centroids);
climada_hazard_stats(hazard_prob);

hazard_prob_obs=climada_tc_hazard_set(tc_track_prob_obs,hazard_set_file,centroids);
climada_hazard_stats(hazard_prob_obs);

entity=climada_entity_read;
ELS=climada_ELS_calc(entity,hazard_prob);
climada_ELS_LFC(ELS);

return
