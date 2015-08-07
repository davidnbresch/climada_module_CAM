function cam_USA_hazard_check(hazard_set_file,show_plot)
% batch file for CAM analysis
% NAME:
%   cam_USA_hazard_check
% PURPOSE:
%   check hazard set as generated in the CAM project
%
%   restrict hazard set to 
%  
% CALLING SEQUENCE:
%   cam_USA_hazard_check(hazard_set_file,show_plot)
% EXAMPLE:
%   cam_USA_hazard_check('USA_UnitedStates_Allstorms.ibtracs_all.v03r04_tracfile_TC.mat',0)
%   cam_USA_hazard_check('USA_UnitedStates_f.e12.FAMIPC5.ne120_g16.rcp4.5.001_10m_tracfile_TC.mat',0)
%   cam_USA_hazard_check('USA_UnitedStates_f.e13.FAMIPC5.ne120_ne120.1979_2012.001_tracfile_TC.mat',0)
%   cam_USA_hazard_check('USA_UnitedStates_f.e13.FAMIPC5.ne120_ne120.1979_2012.002_tracfile_TC.mat',0)
%   cam_USA_hazard_check('USA_UnitedStates_f.e13.FAMIPC5.ne120_ne120.1979_2012.003_tracfile_TC.mat',0)
%   cam_USA_hazard_check('USA_UnitedStates_f.e13.FAMIPC5.ne120_ne120.RCP85_2070_2099_sst3.001_tracfile_TC.mat',0)
%   cam_USA_hazard_check('USA_UnitedStates_f.e13.FAMIPC5.ne120_ne120.RCP85_2070_2099.001_tracfile_TC.mat',0)
%   cam_USA_hazard_check('USA_UnitedStates_f.e13.FAMIPC5.ne120_ne120.RCP85_2070_2099.002_tracfile_TC.mat',0)
%   cam_USA_hazard_check('USA_UnitedStates_f.e13.FAMIPC5.ne120_ne120.RCP85_2070_2099.003_tracfile_TC.mat',0)
%   cam_USA_hazard_check('USA_UnitedStates_FAMIPC5_ne120_79to05_03_omp2_10m_tracfile_TC.mat',0)
%   cam_USA_hazard_check('USA_UnitedStates_FAMIPC5_ne120_2070to2100_03_omp2_10m_tracfile_TC.mat',0)
% INPUTS:
%   hazard_set_file: hazard set filename
% OPTIONAL INPUT PARAMETERS:
%   show_plot: if=0, only store as jpg file without showing the plot
%       =1: show plot and save as jpg (default)
% OUTPUTS:
%   saves jpg files, named accordingly
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 201500806, initial
% David N. Bresch, david.bresch@gmail.com, 201500807, update
%-
global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('hazard_set_file','var'),hazard_set_file='';end
if ~exist('show_plot','var'),show_plot=1;end

if show_plot,fig_visible='on';else fig_visible='off';end

% use a local data dir (for david only)
module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];
module_data_dir=strrep(module_data_dir,'CAM','_CAM'); % local version
% otherwise, use standard climada
if ~exist(module_data_dir,'file'),module_data_dir=climada_global.data_dir;end % default

% prompt for entity_filename if not given
if isempty(hazard_set_file) % local GUI
    hazard_set_file      = [module_data_dir filesep 'hazards' filesep '*.mat'];
    [filename, pathname] = uigetfile(hazard_set_file, 'Select hazard set file:');
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        hazard_set_file = fullfile(pathname,filename);
    end
end

[fP,fN,fE] = fileparts(hazard_set_file);
if ~strcmp(fE,'.mat'),fE='.mat';end % force .mat

if isempty(fP) % complete path, if missing
    hazard_set_file=[module_data_dir filesep 'hazards' filesep fN fE];
end

fprintf('loading %s\n',fN);
load(hazard_set_file); % loads hazard

n_centroids=length(hazard.lon);
% restrict to contiguous US:
fprintf('restricting hazards to contiguous US ...');
pos=find(hazard.lon>-126 & hazard.lat<50);
hazard.lon=hazard.lon(pos);
hazard.lat=hazard.lat(pos);
hazard.centroid_ID=hazard.centroid_ID(pos);
hazard.intensity=hazard.intensity(:,pos);
hazard.distance2coast_km=hazard.distance2coast_km(pos);
hazard.country_name=hazard.country_name(pos);
fprintf(' (remain %2.0f%% of all centroids)\n',length(hazard.lon)/n_centroids*100);

fprintf('restricting to coastal ...');
pos=find(hazard.distance2coast_km<100);
hazard.lon=hazard.lon(pos);
hazard.lat=hazard.lat(pos);
hazard.centroid_ID=hazard.centroid_ID(pos);
hazard.intensity=hazard.intensity(:,pos);
hazard.distance2coast_km=hazard.distance2coast_km(pos);
hazard.country_name=hazard.country_name(pos);
fprintf(' (remain %2.0f%% of all centroids)\n',length(hazard.lon)/n_centroids*100);

[fP,fN,fE] = fileparts(hazard_set_file);
fN=strrep(fN,'.','_'); % avoid too many dots in filename (problems with extension)
fN=strrep(fN,'UnitedStates_','cont_'); % shorten the filename and indicate we restricted
hazard_set_file=[fP filesep fN fE];
hazard.comment2=sprintf('domain restricted to coast of contiguous US, %s by %s (in %s)',datestr(now),getenv('USER'),mfilename);
fprintf('saving as %s\n',hazard_set_file);
save(hazard_set_file,'hazard');

fprintf('showing largest event\n');
CAM_plot = figure('Name','CAM hazard','visible',fig_visible,'Color',[1 1 1]);

% ---------- the only line which really 
% does something, i.e. plot the largest 
% event windfield:
climada_hazard_plot(hazard,-1,'',[],0);
% -------------------------------------

xlabel(strrep(fN,'_','\_')) % we do not need to label 'lon', hence can use this

CAM_plot_name=[module_data_dir filesep 'results' filesep fN '_largest.jpg'];
while exist(CAM_plot_name,'file'),CAM_plot_name=strrep(CAM_plot_name,'.jpg','_.jpg');end % avoid overwriting
if ~isempty(CAM_plot_name)
    saveas(CAM_plot,CAM_plot_name,'png');
    fprintf('saved as %s\n',CAM_plot_name);
end
if ~show_plot,delete(CAM_plot);end

% % to check expected damage, too:
% entity=climada_entity_load('USA_UnitedStates_entity');
% % re-encode, since my local entity might not exist a tyour centroids
% entity=climada_assets_encode(entity,hazard);
% EDS=climada_EDS_calc(entity,hazard);
% fprintf('ED: %g\n',EDS.ED)

end % cam_USA_hazard_check