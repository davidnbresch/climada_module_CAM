function climada_tc_analyze_cam(basin_number,cam_dataset)
% climada
% NAME:
%   climada_tc_analyze_cam
% PURPOSE:
%   analyze CAM tracks for one basin
%
%   present code reads all UNISYS and CAM data automatically, 
%   but please see climada_tc_read_cam_database for details
% CALLING SEQUENCE:
%   climada_tc_analyze_cam(basin_number,cam_dataset);
% EXAMPLE:
%   climada_tc_analyze_cam(1,['wehner'|'present_day'|'rcp45'|'rcp85']);
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   basin_number: the basin numer, see climada_tc_filter_basin
%       default=1 for North Atlantic
%       currently, only 1 (North Atl) and 3 (West Pacific) are implemented
% OUTPUTS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20120406, 20120407, 20120416
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
if ~exist('basin_number','var'),basin_number=1;end
if ~exist('cam_dataset','var'),cam_dataset='wehner';end

% PARAMETERS
%
% to run faster in TEST (to debug), one might suppress the (time-consuming)
% plots (=1). Default=0 to show plots
suppress_plots=0; % default=0
%
% set UNISYS data source and track file, only North Atl is part of climada,
% other basins are in climada_additional (to keep zip-file of climada lean)
if basin_number==1 % North Atl
    basin_txt='NorAtl';
    basin_coord_rectangle=[-120 0 0 50]; % lonmin lonmax latmin latmax -> XLim YLim
    unisys_data_file=[climada_global.root_dir filesep 'data' filesep 'tc_tracks' filesep 'tracks.atl.txt'];
    unisys_tc_track_file=[climada_global.root_dir filesep 'data' filesep 'tc_tracks' filesep 'tc_track_atl.mat'];
elseif basin_number==3 % North West Pacific
    basin_txt='WesPac';
    basin_coord_rectangle=[100 190 0 50]; % lonmin lonmax latmin latmax -> XLim YLim
    unisys_data_file=[climada_global.root_dir '_additional' filesep 'data' filesep 'tc_tracks' filesep 'tracks.bwp.txt'];
    unisys_tc_track_file=[climada_global.root_dir '_additional' filesep 'data' filesep 'tc_tracks' filesep 'tc_track_bwp.mat'];
else
    fprintf('WARNING: other basins not implemented yet, stopped\n');
    return
end
%
% set CAM data source and track file
%jt cam_data_dir=[climada_global.root_dir '_additional' filesep 'data' filesep 'tc_tracks' filesep 'cam'];
cam_data_dir=[climada_global.root_dir '_additional' filesep 'CAM'  filesep 'data' filesep 'track_data_V01' filesep cam_dataset];
cam_tc_track_dir=[climada_global.root_dir '_additional' filesep 'data' filesep 'tc_tracks' filesep cam_dataset];
cam_tc_track_file=[climada_global.root_dir '_additional' filesep 'data' filesep 'tc_tracks' filesep cam_dataset filesep 'tc_track_cam.mat'];
%
% set the figure filenames etc
cam_results_dir=[climada_global.root_dir '_additional' filesep 'data' filesep 'results' filesep 'cam_results' filesep cam_dataset];
if ~exist(cam_results_dir,'dir')
    [fP,fN]=fileparts(cam_results_dir);
    fprintf('creating folder %s\n',cam_results_dir);
    mkdir(fP,fN);
end
if ~exist(cam_tc_track_dir,'dir')
    [fP,fN]=fileparts(cam_tc_track_dir);
    fprintf('creating folder %s\n',cam_tc_track_dir);
    mkdir(fP,fN);
end
fig1_filename= [cam_results_dir filesep 'analyze_cam_fig1_' basin_txt '.jpg'];
fig2a_filename=[cam_results_dir filesep 'analyze_cam_fig2a_UNISYS_' basin_txt '.jpg'];
fig2b_filename=[cam_results_dir filesep 'analyze_cam_fig2b_CAM_' basin_txt '.jpg'];
fig3a_filename=[cam_results_dir filesep 'analyze_cam_fig3a_UNISYS_' basin_txt '.jpg'];
fig3b_filename=[cam_results_dir filesep 'analyze_cam_fig3b_CAM_' basin_txt '.jpg'];
fig4_filename= [cam_results_dir filesep 'analyze_cam_fig4_' basin_txt '.jpg'];


if ~exist(unisys_tc_track_file,'file')
    % read raw UNISYS data file and store as tc_track structure
    tc_track=climada_tc_read_unisys_database(unisys_data_file);
    save(unisys_tc_track_file,'tc_track','-v7.3');
else
    fprintf('reading UNISYS data from %s...\n',unisys_tc_track_file);
    load(unisys_tc_track_file);
end
tc_track_unisys=tc_track; tc_track=[];

if ~exist(cam_tc_track_file,'file')
    % read raw CAM data and store as tc_track structure

%    tc_track=climada_tc_read_cam_ibtrac_v01('cam5_1_amip_run2_tracfile.nc')
    tc_track=climada_tc_read_cam_database_V01(cam_data_dir);
    save(cam_tc_track_file,'tc_track','-v7.3');
else
    fprintf('reading CAM data from %s...\n',cam_tc_track_file);
    load(cam_tc_track_file);
end
tc_track=climada_tc_filter_basin(tc_track,basin_number);

% data preparation (make UNISYS and CAM datasets comparable)
% ----------------------------------------------------------

% figure out years of cam data
cam_year.min=9999;
cam_year.max=0000;
for track_i=1:length(tc_track)
    if tc_track(track_i).yyyy(1)<cam_year.min,cam_year.min=tc_track(track_i).yyyy(1);end
    if tc_track(track_i).yyyy(1)>cam_year.max,cam_year.max=tc_track(track_i).yyyy(1);end
end % track_i

% figure out years of unisys data
unisys_year.min=9999;
unisys_year.max=0000;
unisys_year.trackyear=zeros(length(tc_track_unisys)); % allocate
for track_i=1:length(tc_track_unisys)
    unisys_year.trackyear(track_i)=tc_track_unisys(track_i).yyyy(1);
    if tc_track_unisys(track_i).yyyy(1)<unisys_year.min,unisys_year.min=tc_track_unisys(track_i).yyyy(1);end
    if tc_track_unisys(track_i).yyyy(1)>unisys_year.max,unisys_year.max=tc_track_unisys(track_i).yyyy(1);end
end % track_i

fprintf('cam years %i..%i (%i tracks), unisys years %i..%i (%i tracks)\n',...
    cam_year.min,cam_year.max,length(tc_track),unisys_year.min,unisys_year.max,length(tc_track_unisys));

% reduce unisys to cam (keep it simple, assuming cam is less than unisys)
%cam_year_pos= unisys_year.trackyear>=cam_year.min & unisys_year.trackyear<=cam_year.max;
% using logical indexing (faster than find, previous line left in for
% readability, as on ewould then use tc_track_unisys=tc_track_unisys(cam_year_pos)
%tc_track_unisys=tc_track_unisys(unisys_year.trackyear>=cam_year.min & unisys_year.trackyear<=cam_year.max);

if (sum(unisys_year.trackyear>=cam_year.min & unisys_year.trackyear<=cam_year.max) == 0)
    fprintf('WARNING: UNISYS and CAM do not cover the same period\n');
    cam_year.maxoffset=unisys_year.max;
    cam_year.minoffset=cam_year.maxoffset-(cam_year.max-cam_year.min);
    tc_track_unisys=tc_track_unisys(unisys_year.trackyear>=cam_year.minoffset & unisys_year.trackyear<=cam_year.maxoffset);
    unisys_year.min=9999;
    unisys_year.max=0000;
    for track_i=1:length(tc_track_unisys)
        unisys_year.trackyear(track_i)=tc_track_unisys(track_i).yyyy(1);
        if tc_track_unisys(track_i).yyyy(1)<unisys_year.min,unisys_year.min=tc_track_unisys(track_i).yyyy(1);end
        if tc_track_unisys(track_i).yyyy(1)>unisys_year.max,unisys_year.max=tc_track_unisys(track_i).yyyy(1);end
    end % track_i
    fprintf('we will be comparing the following time periods: cam years %i..%i (%i tracks), unisys years %i..%i (%i tracks)\n',...
    cam_year.min,cam_year.max,length(tc_track),unisys_year.min,unisys_year.max,length(tc_track_unisys));
else
    tc_track_unisys=tc_track_unisys(unisys_year.trackyear>=cam_year.min & unisys_year.trackyear<=cam_year.max);
% figure out remaining years of unisys data (kind of check)
    unisys_year.min=9999;
    unisys_year.max=0000;
    for track_i=1:length(tc_track_unisys)
        unisys_year.trackyear=tc_track_unisys(track_i).yyyy(1);
        if tc_track_unisys(track_i).yyyy(1)<unisys_year.min,unisys_year.min=tc_track_unisys(track_i).yyyy(1);end
        if tc_track_unisys(track_i).yyyy(1)>unisys_year.max,unisys_year.max=tc_track_unisys(track_i).yyyy(1);end
    end % track_i
    fprintf('same time period: cam years %i..%i (%i tracks), unisys years %i..%i (%i tracks)\n',...
    cam_year.min,cam_year.max,length(tc_track),unisys_year.min,unisys_year.max,length(tc_track_unisys));
end

%
%if sum(abs(unisys_year.min-cam_year.min)+abs(unisys_year.max-cam_year.max))>0,...
%        fprintf('WARNING: UNISYS and CAM do not cover the same period\n');end
%
%fprintf('same time period: cam years %i..%i (%i tracks), unisys years %i..%i (%i tracks)\n',...
%    cam_year.min,cam_year.max,length(tc_track),unisys_year.min,unisys_year.max,length(tc_track_unisys));

if ~suppress_plots
    
    % plot the tracks (colored by Saffir-Simpson class)
    % ---------------
    
    fprintf('plotting tracks...\n');
    fig1_handle=figure('Name','track comparison','Position',[427 91 655 599],'Color',[1 1 1]);
    subplot(2,1,1)
    hold on;
    title(sprintf('%i UNISYS tracks %i..%i',length(tc_track_unisys),unisys_year.min,unisys_year.max));
    climada_plot_tc_track_stormcategory(tc_track_unisys,[],1);
    % for track_i=1:length(tc_track_unisys) % would be tracks only, no coloring
    %     plot(tc_track_unisys(track_i).lon,tc_track_unisys(track_i).lat);
    % end
    climada_plot_world_borders
    set(gca,'XLim',basin_coord_rectangle(1:2));set(gca,'YLim',basin_coord_rectangle(3:4));
    axis off
    hold off
    
    subplot(2,1,2)
    hold on;
    title(sprintf('%i CAM tracks %i..%i',length(tc_track),cam_year.min,cam_year.max));
    climada_plot_tc_track_stormcategory(tc_track,[],1);
    climada_plot_world_borders
    set(gca,'XLim',basin_coord_rectangle(1:2));set(gca,'YLim',basin_coord_rectangle(3:4));
    axis off
    hold off
    %
    fprintf('saving figure as %s\n',fig1_filename);
    saveas(fig1_handle,fig1_filename);
    
end % ~suppress_plots

if ~suppress_plots
    
    % ACE (accumulated cinetic energy) and intensity statistics
    % ---------------------------------------------------------
    
    fprintf('plotting ACE statistics...\n');
    
    tc_track_unisys = climada_add_tc_track_season(tc_track_unisys);
    climada_plot_ACE(tc_track_unisys,'',0);
    fig2a_handle=gcf;
    set(fig2a_handle,'Name','ACE statistics for UNISYS');
    set(fig2a_handle,'Position',[427 91 655 599]);
    set(fig2a_handle,'Color',[1 1 1]);
    title(sprintf('%i UNISYS tracks %i..%i',length(tc_track_unisys),unisys_year.min,unisys_year.max));
    fprintf('saving figure as %s\n',fig2a_filename);
    saveas(fig2a_handle,fig2a_filename);
    
    tc_track = climada_add_tc_track_season(tc_track);
    climada_plot_ACE(tc_track,'',0);
    fig2b_handle=gcf;
    set(fig2b_handle,'Name','ACE statistics for CAM');
    set(fig2b_handle,'Position',[427 91 655 599]);
    set(fig2b_handle,'Color',[1 1 1]);
    title(sprintf('%i CAM tracks %i..%i',length(tc_track),cam_year.min,cam_year.max));
    fprintf('saving figure as %s\n',fig2b_filename);
    saveas(fig2b_handle,fig2b_filename);
    
end % ~suppress_plots

if ~suppress_plots
    
    % initial and delta-windspeed distribution
    % ----------------------------------------
    
    [mu,sigma,A] = climada_distribution_v0_vi(tc_track_unisys,'m/s', 1, 0);
    fig3a_handle=gcf;
    set(fig3a_handle,'Name','v-ditsribution statistics for UNISYS');
    set(fig3a_handle,'Position',[427 91 655 599]);
    set(fig3a_handle,'Color',[1 1 1]);
    title(sprintf('%i UNISYS tracks %i..%i',length(tc_track_unisys),unisys_year.min,unisys_year.max));
    fprintf('saving figure as %s\n',fig3a_filename);
    saveas(fig3a_handle,fig3a_filename);
    
    [mu,sigma,A] = climada_distribution_v0_vi(tc_track,'m/s', 1, 0);
    fig3b_handle=gcf;
    set(fig3b_handle,'Name','v-ditsribution statistics for CAM');
    set(fig3b_handle,'Position',[427 91 655 599]);
    set(fig3b_handle,'Color',[1 1 1]);
    title(sprintf('%i CAM tracks %i..%i',length(tc_track),cam_year.min,cam_year.max));
    fprintf('saving figure as %s\n',fig3b_filename);
    saveas(fig3b_handle,fig3b_filename);
    
end % ~suppress_plots

if ~suppress_plots
    
    % plot starting points of tracks
    % ------------------------------
    
    fprintf('plotting starting points...\n');
    
     fig4_handle=figure('Name','start point comparison','Position',[427 91 655 599],'Color',[1 1 1]);
    subplot(2,1,1)
    
    start_lon=zeros(length(tc_track_unisys)); % init
    start_lat=start_lon;
    for track_i=1:length(tc_track_unisys)
        start_lon(track_i)=tc_track_unisys(track_i).lon(1);
        start_lat(track_i)=tc_track_unisys(track_i).lat(1);
    end
    climada_plot_world_borders
    hold on;
    plot(start_lon,start_lat,'.r')    
    title(sprintf('%i UNISYS tracks %i..%i',length(tc_track_unisys),unisys_year.min,unisys_year.max));
    set(gca,'XLim',basin_coord_rectangle(1:2));set(gca,'YLim',basin_coord_rectangle(3:4));
    axis off
    hold off
    
      subplot(2,1,2)
    
    start_lon=zeros(length(tc_track)); % init
    start_lat=start_lon;
    for track_i=1:length(tc_track)
        start_lon(track_i)=tc_track(track_i).lon(1);
        start_lat(track_i)=tc_track(track_i).lat(1);
    end
    climada_plot_world_borders
    hold on;
    plot(start_lon,start_lat,'.r')    
    title(sprintf('%i CAM tracks %i..%i',length(tc_track),cam_year.min,cam_year.max));
    set(gca,'XLim',basin_coord_rectangle(1:2));set(gca,'YLim',basin_coord_rectangle(3:4));
    axis off
    hold off
   
    fprintf('saving figure as %s\n',fig4_filename);
    saveas(fig4_handle,fig4_filename);
    

end % ~suppress_plots


return
