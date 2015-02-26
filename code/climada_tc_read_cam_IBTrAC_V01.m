function tc_track=climada_tc_read_cam_ibtrac_v01(ibtrac_file,starty,endy)
% TC tracks from a CAM high resolution simulation.
% NAME:
%   climada_tc_read_cam_ibtrac_v01
% PURPOSE:
%   read storm track data from an IBTrAC style netcdf file stored in
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
%   developed by Julio Bachmeister.
%
%   NOTE: THIS IS THE FIRST VERSION (V01)
%
%   next step: see climada_tc_filter_basin and then climada_tc_random_walk
% CALLING SEQUENCE:
%   tc_track=climada_tc_read_cam_ibtrac_v01(ibtrac_file,starty,endy);
% EXAMPLE:
%   tc_track=climada_tc_read_cam_ibtrac_v01(ibtrac_file,1980,2000);
% INPUTS:
%   netcdf IBTrAC style file 
%       ..climada_additional/data/tc_track/cam
% OPTIONAL INPUT PARAMETERS:
%   ibtrac_file: the directory where the CAM data resides (sub-folders with
%       year), inside each one file traj_out.txt
%       -> prompted for if not given or passed empty
%   starty: the first year (yyyy) of the data to be processed, default
%       first sub-folder in ibtrac_file
%   endy: the last year (yyyy) of the data to be processed, default
%       last sub-folder in ibtrac_file
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
% if ~climada_init_vars,return;end

if ~exist('ibtrac_file','var'),ibtrac_file=[];end
if ~exist('starty','var'),starty=[];end
if ~exist('endy','var'),endy=[];end
%ibtrac_file='cam5_1_amip_run2_tracfile.nc'
%>> source_wind_data=ncread('/project/20141031_jet/cam5_1_amip_run2_tracfile.nc','source_wind',[1,1,1],[1,numobs(1),1]);
%>> feather(source_wind_data);figure(gcf);
%>> plot(source_wind_data,'DisplayName','source_wind_data','YDataSource','source_wind_data');figure(gcf)


% PARAMETERS
%
% general settings
% ----------------
min_nodes=3;    % minimal nodes a track must have to be selected
%
check_plot=1; % whether we show a check plot (=1) or not (=0)
%
% 
%the unique_ID is constructed from year and even number within this year,
% a basin_number can be used to distinguish basins
% such that unique_ID=ByyyyNN with B the basin number (no
% specification B=0, yyyy the year
% and NN the number of track within the year.
basin_number=0;
cam_file='/traj_out.txt';
n_tracks=0; %Total storm number

% convert wind to knots from m/s  should check attributes and make
% appropriate conversion.
mps2kts=1.94384;

% convert wind from 60m to 10m reference height using power law with an
% exponent of .11 which is more appropriate over open water
% assuming 1st model level is about 60m high.
scale_to_10m = (10./60.)^.11;

%
% for TEST
% ibtrac_file='cam5_1_amip_run2_tracfile.nc';

if isempty(ibtrac_file) % ask for CAM data folder
    % look for in climada_additional
    ibtrac_file=[climada_global.root_dir 'climada_additional' filesep 'CAM' filesep 'data'];
    ibtrac_file = uigetdir(ibtrac_file,'Select CAM track data:');
end
if length(ibtrac_file)<2,return;end % if cancel pressed

cam_file=[climada_global.root_dir '/climada_additional/CAM/data/' ibtrac_file];

matlab18581117=datenum('1858-11-17 00:00:00')

finfo = ncinfo(cam_file);
dimNames = {finfo.Dimensions.Name};
dimMatch = strncmpi(dimNames,'time',1);
ntimes=finfo.Dimensions(dimMatch).Length;
dimMatch = strncmpi(dimNames,'storms',1);
nstorms=finfo.Dimensions(dimMatch).Length;
numobs=ncread(cam_file,'numObs');
% source_time=ncread(cam_file,'source_time',[1,1],[numobs(1),1]);
% time=ncread(cam_file,'time',[1,1],[numobs(1),1]);
% source_pres=ncread(cam_file,'source_pres',[1,1,1],[1,numobs(1),1]);
% source_wind=ncread(cam_file,'source_wind',[1,1,1],[1,numobs(1),1]);
% %read wind attribute and make sure in knots 10m
% source_lat=ncread(cam_file,'source_lat',[1,1,1],[1,numobs(1),1]);
% source_lon=ncread(cam_file,'source_lon',[1,1,1],[1,numobs(1),1]);
% file_starty=fix(ncread(cam_file,'time',[1,1],[1,1]))/10000;
% file_endy=fix(ncread(cam_file,'time',[1,nstorms],[1,1]))/10000;
% % fracday=time(1)-yearst;

source_time=ncread(cam_file,'source_time',[1,1],[1,1]);
vec=datevec(source_time+matlab18581117)
file_starty=vec(:,1);
source_time=ncread(cam_file,'source_time',[1,nstorms],[1,1]);
vec=datevec(source_time+matlab18581117)
file_endy=vec(:,1);

% figure out the years data is available

if isempty(starty),starty=file_starty;end
if isempty(endy),endy=file_endy;end
% and some sanity checks
if starty<file_starty,starty=file_starty;end
if endy>file_endy,endy=file_endy;end

display(['Allocating CAM storms for the period ' num2str(starty) ...
    ' to ' num2str(endy)])

% 
% %------------------------------------------------------
% % fill in tc structure from tracfile
% %------------------------------------------------------
msgstr=sprintf('Processing %i tracks ...',nstorms);
fprintf('%s\n',msgstr);
h = waitbar(0,msgstr);
resetyr = starty;

for i=1:nstorms
    waitbar(i/nstorms,h);
    %Allocate storm data to structure tc_tracks
    tc_track(i).MaxSustainedWindUnit='kn';
    tc_track(i).CentralPressureUnit='mb';
    tc_track(i).TimeStep=0;

    lon=ncread(cam_file,'source_lon',[1,1,1],[1,numobs(i),1]);
    % convert longitude (Postive East)
    lt180pos=find(lon>180);
    lon(lt180pos)=lon(lt180pos)-360;    
    
    tc_track(i).lon=ncread(cam_file,'source_lon',[1,1,1],[1,numobs(i),1]);
    tc_track(i).lat=ncread(cam_file,'source_lat',[1,1,1],[1,numobs(i),1]);

    tc_track(i).MaxSustainedWind=ncread(cam_file,'source_wind',[1,1,1],[1,numobs(i),1])*mps2kts*scale_to_10m;

    tc_track(i).CentralPressure=ncread(cam_file,'source_pres',[1,1,1],[1,numobs(i),1]);
    tc_track(i).CentralPressure(tc_track(i).CentralPressure > 1100)=NaN; % replace silly pressure data
    tc_track(i).CentralPressure(tc_track(i).CentralPressure < 800)=NaN; % replace silly pressure data

    
    source_time=ncread(cam_file,'source_time',[1,1],[numobs(1),1]);
    vec=datevec(source_time+matlab18581117)
    tc_track(i).yyyy=vec(:,1);
    if (resetyr==tc_track(i).yyyy)
        tracksthisyr=1;
        resetyr=resetyr+1;           
    else
        tracksthisyear=tracksthisyear+1;
    end
    
    tc_track(i).mm=vec(:,2);
    tc_track(i).dd=vec(:,3);
    tc_track(i).hh=vec(:,4);
    tc_track(i).ID_no=basin_number*1e6+tc_track(i).yyyy*100+tracksthisyr;
    tc_track(i).orig_event_flag=1;
    tc_track(i).datenum=source_time+matlab18581117;%datenum
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
