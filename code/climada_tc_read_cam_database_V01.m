function tc_track=climada_tc_read_cam_database_V01(cam_data_dir,starty,endy)
% TC tracks from a CAM high resolution simulation.
% NAME:
%   climada_tc_read_cam_database
% PURPOSE:
%   read storm track data from annual text files stored in
%   ...climada_additional/CAM/data/track_data_V01
%   Data provided by A.Gettleman (andrew.gettelman@env.ethz.ch)
%
%   Note the V01, since there is a newer data format, you might also
%   consider using climada_tc_read_cam_database instead
%
%   filter the raw data, namely:
%   - a VALID record (=node) is required to have lat, lon and either pressure
%     or windspeed (so recrods with only geographical information are skipped)
%   - pressure [mb] needs to be in the range 800..1100, otherwise set to
%     NaN, windspeeds of zero are also set to NaN
%   - longitudes are converted such that east is positive.
%
%   Tracks were  derived with a CAM cyclone tracking algorithm
%   http://vis.lbl.gov/~romano/climate/tropicalstorms.html
%
%   NOTE: THIS IS THE FIRST VERSION (V01), there is a newer code, see
%   climada_tc_read_cam_database.m
%
%   next step: see climada_tc_filter_basin and then climada_tc_random_walk
% CALLING SEQUENCE:
%   tc_track=climada_tc_read_cam_database_V01(cam_data_dir,starty,endy);
% EXAMPLE:
%   tc_track=climada_tc_read_cam_database_V01(cam_data_dir,1980,2000);
% INPUTS:
%   Text files must be stored in sub-folders (one for each year) in
%       ..climada_additional/data/tc_track/cam
% OPTIONAL INPUT PARAMETERS:
%   cam_data_dir: the directory where the CAM data resides (sub-folders with
%       year), inside each one file traj_out.txt
%       -> prompted for if not given or passed empty
%   starty: the first year (yyyy) of the data to be processed, default
%       first sub-folder in cam_data_dir
%   endy: the last year (yyyy) of the data to be processed, default
%       last sub-folder in cam_data_dir
% OUTPUTS:
%   tc_track: a structure with the track information for each cyclone i and
%           data for each node j (times are at 00Z, 06Z, 12Z, 18Z):
%       tc_track(i).lat(j): latitude at node j of cyclone i
%       tc_track(i).lon(j): longitude at node j of cyclone i
%       tc_track(i).MaxSustainedWind(j): Maximum sustained (1 minute)
%           surface (10m) windspeed in knots (in general, these are to the nearest 5 knots).
%       tc_track(i).MaxSustainedWindUnis, almost always 'kn'
%           (others allowed: 'mph', 'm/s' or 'km/h')
%       tc_track(i).CentralPressure(j): optional
%       tc_track(i).CentralPressureUnit: 'mb'
%       tc_track(i).yyyy: 4-digit year, optional
%       tc_track(i).mm: month, optional
%       tc_track(i).dd: day, optional
%       tc_track(i).hh: hours
%       tc_track(i).datenum:  matlab notation for dat: yyyy,mm,dd,hh
%       tc_track(i).TimeStep(j)=time step [h] from this to next node
%       tc_track(i).ID_no: unique ID, optional
%       tc_track(i).name: name, optional
%       tc_track(i).orig_event_flag: whether it is an mother(=1) or daugther(=0) storm
%
%   Save the output tc_track manually (using save) if needed. 
%
% RESTRICTIONS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20120329
% David N. Bresch, david.bresch@gmail.com, 20121024, moved into a module: CAM
% David N. Bresch, david.bresch@gmail.com, 20121026, checked V01
%-

% init output
tc_track=[];

% init global variables
global climada_global
if ~climada_init_vars,return;end

if ~exist('cam_data_dir','var'),cam_data_dir=[];end
if ~exist('starty','var'),starty=[];end
if ~exist('endy','var'),endy=[];end

% PARAMETERS
%
% general settings
% ----------------
min_nodes=3;    % minimal nodes a track must have to be selected
%
check_plot=1; % whether we show a check plot (=1) or not (=0)
%
% the unique_ID is constructed from year and even number within this year,
% a basin_number can be used to distinguish basins
% such that unique_ID=ByyyyNN with B the basin number (no
% specification B=0, yyyy the year
% and NN the number of track within the year.
basin_number=0;
cam_file='/traj_out.txt';
n_tracks=0; %Total storm number
%
% for TEST
%%cam_data_dir=[climada_global.root_dir '_additional/CAM/data/track_data'];

if isempty(cam_data_dir) % ask for CAM data folder
    % look for in climada_additional
    cam_data_dir=[climada_global.root_dir '_additional' filesep 'CAM' filesep 'data' filesep 'track_data_V01'];
    cam_data_dir = uigetdir(cam_data_dir,'Select folder which contains CAM track data:');
end

if length(cam_data_dir)<2,return;end % if cancel pressed

[fP,fN]=fileparts(cam_data_dir);
if ~findstr(fN,'_V01') % check for version
    fprintf('NOTE: if you encounter troubles, consider using climada_tc_read_cam_database instead\n');
end

% figure out the years data is available
D=dir(cam_data_dir);file_starty=[];
for file_i=1:length(D)
    if length(D(file_i).name)==4
        if isempty(file_starty),file_starty=str2double(D(file_i).name);end
        file_endy=str2double(D(file_i).name);
    end
end
if isempty(starty),starty=file_starty;end
if isempty(endy),endy=file_endy;end
% and some sanity checks
if starty<file_starty,starty=file_starty;end
if endy>file_endy,endy=file_endy;end

display(['Allocating CAM storms for the period ' num2str(starty) ...
    ' to ' num2str(endy)])

raw_data=NaN(1,8); % Create first line to access
% raw_data, will be deleted afterwards
for i=starty:endy
    % open the database for reading
    raw_track_file=[cam_data_dir filesep num2str(i) cam_file];
    fid=fopen(raw_track_file,'r');
    % read raw data
    while not(feof(fid))
        % read header of storm, need to begin with 'start'
        str=fscanf(fid,'%s',1);
        if strcmp(str,'start')==1
            n_tracks=n_tracks+1;
            
            %Number of the storm in current year
            storm_yr(n_tracks)=i;
            
            % header: Timesteps,Year,Month,Day,Hour,Fraction that passed thickness
            %         criteria, Fraction that passed warm core criteria
            header(n_tracks,:)=fscanf(fid,'%f',7);
            nsteps=header(n_tracks,1);
            
            %Add continously storm data into matrix raw_data for preprocessing
            % raw_data: Lon,Lat,Wind,Pressure,YYYY,MM,DD,HH
            raw_data(end+1:end+nsteps,:) = fscanf(fid,'%f',[8   nsteps])';
        else
        end
    end
end
fclose('all');
%Remove first line of raw data again
raw_data(1,:)=[];

%------------------------------------------------------
% Pre-process raw_data
%------------------------------------------------------

%------------------------------------------------------
raw_data(raw_data(:,4) > 1100,4)=NaN; % replace silly pressure data
raw_data(raw_data(:,4) <  800,4)=NaN; % replace silly pressure

% convert longitude (Postive East)
%------------------
% second convert to range [-180 ...180]
lt180pos=find(raw_data(:,1)>180);
raw_data(lt180pos,1)=raw_data(lt180pos,1)-360;
% transform from m/s to kn
raw_data(:,3)=raw_data(:,3)./0.5144;

%------------------------------------------------------
% Allocate raw_data to output variable tc_track
%------------------------------------------------------
msgstr=sprintf('Processing %i tracks ...',n_tracks);
fprintf('%s\n',msgstr);
h = waitbar(0,msgstr);

for i=1:n_tracks
    waitbar(i/n_tracks,h);
    %Allocate storm data to structure tc_tracks
    ind=[1+sum(header(1:i-1,1)):sum(header(1:i,1))];
    tc_track(i).MaxSustainedWindUnit='kn';
    tc_track(i).CentralPressureUnit='mb';
    tc_track(i).TimeStep=6*ones(length(ind),1);
    tc_track(i).lon=raw_data(ind,1)';
    tc_track(i).lat=raw_data(ind,2)';
    tc_track(i).MaxSustainedWind=raw_data(ind,3);
    tc_track(i).CentralPressure=raw_data(ind,4);
    tc_track(i).yyyy=raw_data(ind,5);
    tc_track(i).mm=raw_data(ind,6);
    tc_track(i).dd=raw_data(ind,7);
    tc_track(i).hh=raw_data(ind,8);
    tc_track(i).ID_no=basin_number*1e6+raw_data(ind(1),1)*100+storm_yr(i);
    tc_track(i).orig_event_flag=1;
    tc_track(i).datenum=datenum(raw_data(ind,5),raw_data(ind,6),raw_data(ind,7),raw_data(ind,8),0,0);
    tc_track(i).name=['CAM_storm_' num2str(i)];
end


if check_plot
    figure
    subplot(2,2,1);
    for i=1:length(tc_track);plot(tc_track(i).MaxSustainedWind,tc_track(i).CentralPressure,'.r');hold on;end;;xlabel('v_{max}');ylabel('p_{min}');title('v_{max} - p_{min} relation'); % all tracks
    subplot(2,2,2);
    % plot dots, since we still have the date line issue at this stage
    for i=1:length(tc_track);plot(tc_track(i).lon,tc_track(i).lat,'.','MarkerSize',.1);hold on;end; % all tracks
    if exist('climada_plot_world_borders'),climada_plot_world_borders;end % plot coastline
    subplot(2,2,3);
    for i=1:length(tc_track);plot(tc_track(i).CentralPressure);hold on;end;title('CentralPressure')
    subplot(2,2,4);
    for i=1:length(tc_track);plot(tc_track(i).MaxSustainedWind);hold on;end;title('MaxSustainedWind')
end

close(h); % dispose waitbar

return