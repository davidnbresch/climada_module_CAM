function cam_batch_multi(basin_number)
% batch file for CAM analysis
% NAME:
%   cam_batch
% PURPOSE:
%   call climdada routines to generate cyclone tracks and loss frequency curves
%  
% CALLING SEQUENCE:
%   cam_batch_multi(basin_number);
% EXAMPLE:
%   cam_batch_multi(1);
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   basin_number: the basin numer, see climada_tc_filter_basin
%       default=1 for North Atlantic
%       currently, only 1 (North Atl) implemetned
% OUTPUTS:
% MODIFICATION HISTORY:
% Andrew Gettelman  May 5, 2014
% David N. Bresch, david.bresch@gmail.com, 20150819, climada_global.centroids_dir introduced
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables


% note, define basin number: only have entities for N. Atlantic right now
basin = basin_number;
hazname='TCNA';

%%% RCP85  %%%

cam_dataset='rcp85'    

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

tc_track_prob_r85=climada_tc_random_walk(tc_track,basin);

hazard_set_file=[hazard_dir filesep hazname '_hazard_test.mat'];
centroids=[climada_global.centroids_dir filesep 'USFL_MiamiDadeBrowardPalmBeach_centroids.mat'];

hazard_prob_r85=climada_tc_hazard_set(tc_track_prob_r85,hazard_set_file,centroids);
%climada_hazard_stats(hazard_prob_r85);

entity=climada_entity_read;

ELS_r85=climada_ELS_calc(entity,hazard_prob_r85);

%%% RCP45  %%%

cam_dataset='rcp45'    

hazard_dir=[climada_global.root_dir filesep 'data' filesep 'hazards'];
cam_data_dir=[climada_global.root_dir '_additional' filesep 'CAM'  filesep 'data' filesep 'track_data_V01' filesep cam_dataset];
cam_tc_track_dir=[climada_global.root_dir '_additional' filesep 'data' filesep 'tc_tracks' filesep cam_dataset];
cam_tc_track_file=[cam_tc_track_dir filesep 'tc_track_cam.mat'];
if ~exist(cam_tc_track_file,'file')
    % read raw CAM data and store as tc_track structure
    % Track file generation.
    tc_track_r45=climada_tc_read_cam_database_V01(cam_data_dir);
    save(cam_tc_track_file,'tc_track','-v7.3');
else
    fprintf('reading CAM data from %s...\n',cam_tc_track_file);
    load(cam_tc_track_file);
end

tc_track_prob_r45=climada_tc_random_walk(tc_track,basin);

hazard_prob_r45=climada_tc_hazard_set(tc_track_prob_r45,hazard_set_file,centroids);

ELS_r45=climada_ELS_calc(entity,hazard_prob_r45);


%%% UNISYS (OBS) TRACKS %%%

%Need unisys tracks too 
tc_track_obs=climada_tc_read_unisys_database;  %(this works)
tc_track_prob_obs=climada_tc_random_walk(tc_track_obs,basin);

hazard_prob_obs=climada_tc_hazard_set(tc_track_prob_obs,hazard_set_file,centroids);
%climada_hazard_stats(hazard_prob_obs);
ELS_obs=climada_ELS_calc(entity,hazard_prob_obs);



%%% Merge all Files %%%

climada_ELS_LFC_multiple(ELS_r45,ELS_r85,1);


return
