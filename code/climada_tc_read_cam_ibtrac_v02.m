function [tc_track,tc_track_hist_file]=climada_tc_read_cam_ibtrac_v02(ibtrac_file,check_plot)
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
%   The basic quality check (climada_tc_track_quality_check) gets applied,
%   mainly to correct the dateline issue.
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
% INPUTS:
%   ibtrac_file: the filename of the ibtrac style cam cyclone file
%   see also PARAMETERS section, especially for filters
% OPTIONAL INPUT PARAMETERS:
%   check_plot: if =1, show plots, =0 not (default)
%       Note that check_plot only makes sense on first call, as 2nd time,
%       the data is restored from the .mat file, not read from netCDF again
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
%   tc_track_hist_file: the filename with path to the binary file
%       tc_track is stored in.
%
% RESTRICTIONS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150128, _prob renamed to _hist
% David N. Bresch, david.bresch@gmail.com, 20170126, climada_tc_track_quality_check
%-

% init output
tc_track=[];tc_track_hist_file='';

% init global variables
global climada_global
if ~climada_init_vars,return;end

if ~exist('ibtrac_file','var'),ibtrac_file=[];end
if ~exist('check_plot','var'),check_plot=0;end

% PARAMETERS
%
% general settings
% ----------------
%
%the unique_ID is constructed from year and even number within this year,
% a basin_number can be used to distinguish basins
% such that unique_ID=ByyyyNN with B the basin number (no
% specification B=0, yyyy the year
% and NN the number of track within the year.
basin_number=0;
%
% convert wind to knots from m/s  should check attributes and make
% appropriate conversion.
mps2kts=1.94384;

% convert wind from 60m to 10m reference height using power law with an
% exponent of .11 which is more appropriate over open water
% assuming 1st model level is about 60m high.
scale_to_10m = (10./60.)^.11;

% prompt for ibtrac_file if not given
if isempty(ibtrac_file) % ask for CAM data folder
    [filename, pathname] = uigetfile({'*.nc'},'Select netcdf tracfile:',...
        [climada_global.data_dir filesep 'tc_tracks' filesep 'test_tracfile.nc']);
    if isequal(filename,0) || isequal(pathname,0)
        return % cancel
    else
        ibtrac_file=fullfile(pathname,filename);
    end
end
if length(ibtrac_file)<2,return;end % if cancel pressed

cam_file=ibtrac_file;

% construct the binary file names
[fP,fN]=fileparts(ibtrac_file);
tc_track_hist_file=[fP filesep fN '_hist.mat'];

matlab18581117=datenum('1858-11-17 00:00:00');

if ~exist(tc_track_hist_file,'file')
    
    finfo = ncinfo(cam_file);
    dimNames = {finfo.Dimensions.Name};
    dimMatch = strncmpi(dimNames,'time',1);
    ntimes=finfo.Dimensions(dimMatch).Length;
    dimMatch = strncmpi(dimNames,'storms',1);
    nstorms=finfo.Dimensions(dimMatch).Length;
    numobs=ncread(cam_file,'numObs');
    
    source_time=ncread(cam_file,'source_time',[1,1],[1,1]);
    vec=datevec(source_time+matlab18581117);
    file_starty=vec(:,1);
    source_time=ncread(cam_file,'source_time',[1,nstorms],[1,1]);
    vec=datevec(source_time+matlab18581117);
    file_endy=vec(:,1);
    source_time=ncread(cam_file,'source_time',[1,1],[1,nstorms]);
    vec=datevec(source_time+matlab18581117);
    
    % figure out the years data is available
    
    starty=file_starty;
    endy=file_endy;
    
    display(['Allocating CAM storms for the period ' num2str(starty) ...
        ' to ' num2str(endy)])
    
    %
    % %------------------------------------------------------
    % % fill in tc structure from tracfile
    % %------------------------------------------------------
    
    t0       = clock;
    msgstr   = sprintf('Processing %i tracks ...',nstorms);
    mod_step = 10; % first time estimate after 10 events, then every 100
    if climada_global.waitbar
        fprintf('%s (updating waitbar with estimation of time remaining every 100th event)\n',msgstr);
        h        = waitbar(0,msgstr);
        set(h,'Name','reading netCDF tracks');
    else
        fprintf('%s (waitbar suppressed)\n',msgstr);
        format_str='%s';
    end
    
    resetyr = starty;
    tracksthisyr=0;
    
    for i=1:nstorms
        
        %     % check to see if storm is between start and end dates before we add
        source_time=ncread(cam_file,'source_time',[1,i],[numobs(i),1]);
        source_time=permute(source_time,[2 1]);
        vec=datevec(source_time+matlab18581117);
        vec=permute(vec,[2 1]);
        %     if (vec(1,1)<starty || vec(1,1)>endy) continue; end
        
        %Allocate storm data to structure tc_tracks
        tc_track(i).MaxSustainedWindUnit='kn';
        tc_track(i).CentralPressureUnit='mb';
        
        lon=ncread(cam_file,'source_lon',[1,1,i],[1,numobs(i),1]);
        % convert longitude (Postive East)
        lt180pos=find(lon>180);
        lon(lt180pos)=lon(lt180pos)-360;
        
        tc_track(i).lon=lon;
        tc_track(i).lat=ncread(cam_file,'source_lat',[1,1,i],[1,numobs(i),1]);
        tc_track(i).MaxSustainedWind=ncread(cam_file,'source_wind',[1,1,i],[1,numobs(i),1])*mps2kts*scale_to_10m;
        tc_track(i).CentralPressure=ncread(cam_file,'source_pres',[1,1,i],[1,numobs(i),1]);
        tc_track(i).CentralPressure(tc_track(i).CentralPressure > 1100)=NaN; % replace silly pressure data
        tc_track(i).CentralPressure(tc_track(i).CentralPressure < 800)=NaN; % replace silly pressure data
        tc_track(i).yyyy=vec(1,:);
        if (resetyr==tc_track(i).yyyy(1))
            tracksthisyr=1;
            resetyr=resetyr+1;
        else
            tracksthisyr=tracksthisyr+1;
        end
        
        tc_track(i).mm=vec(2,:);
        tc_track(i).dd=vec(3,:);
        tc_track(i).hh=vec(4,:);
        tc_track(i).ID_no=basin_number*1e6+tc_track(i).yyyy*100+tracksthisyr;
        tc_track(i).orig_event_flag=1;
        tc_track(i).datenum=source_time+matlab18581117;%datenum
        tc_track(i).TimeStep=tc_track(i).mm;
        tc_track(i).TimeStep(:)=24*(tc_track(i).datenum(2)-tc_track(i).datenum(1));
        tc_track(i).name=['CAM_storm_' num2str(i)];
        
        % the progress management
        if mod(i,mod_step)==0
            mod_step          = 100;
            t_elapsed_storm   = etime(clock,t0)/i;
            storms_remaining  = nstorms-i;
            t_projected_sec   = t_elapsed_storm*storms_remaining;
            if t_projected_sec<60
                msgstr = sprintf('est. %3.0f sec left (%i/%i storms)',t_projected_sec,   i,nstorms);
            else
                msgstr = sprintf('est. %3.1f min left (%i/%i storms)',t_projected_sec/60,i,nstorms);
            end
            if climada_global.waitbar
                waitbar(i/nstorms,h,msgstr); % update waitbar
            else
                fprintf(format_str,msgstr); % write progress to stdout
                format_str=[repmat('\b',1,length(msgstr)) '%s']; % back to begin of line
            end
        end
        
    end % i
    if climada_global.waitbar
        close(h) % dispose waitbar
    else
        fprintf(format_str,''); % move carriage to begin of line
    end
    
    % correct for dateline
    tc_track=climada_tc_track_quality_check(tc_track);
    
    if check_plot
        figure
        subplot(2,2,1);
        for i=1:length(tc_track);plot(tc_track(i).MaxSustainedWind,tc_track(i).CentralPressure,'.r');hold on;end;
        xlabel('v_{max}');ylabel('p_{min}');title('v_{max} - p_{min} relation'); % all tracks
        subplot(2,2,2);
        % plot dots, since we still have the date line issue at this stage
        for i=1:length(tc_track);plot(tc_track(i).lon,tc_track(i).lat,'.','MarkerSize',.1);hold on;end; % all tracks
        axis equal
        if exist('climada_plot_world_borders'),climada_plot_world_borders;end % plot coastline
        subplot(2,2,3);
        for i=1:length(tc_track);plot(tc_track(i).CentralPressure);hold on;end;title('CentralPressure')
        subplot(2,2,4);
        for i=1:length(tc_track);plot(tc_track(i).MaxSustainedWind);hold on;end;title('MaxSustainedWind')
    end
        
    fprintf('writing processed file %s\n',tc_track_hist_file);
    save(tc_track_hist_file,'tc_track');
    
    if check_plot
        subplot(2,2,2)
        for i=1:length(tc_track);plot(tc_track(i).lon,tc_track(i).lat,'-b');hold on;end; % all tracks
        hold on
        if exist('climada_plot_world_borders'),climada_plot_world_borders;end % plot coastline
        subplot(2,2,3)
        for i=1:length(tc_track);plot(tc_track(i).CentralPressure);hold on;end;xlabel('# of nodes per track');ylabel('(mb)');title('CentralPressure')
        subplot(2,2,4)
        for i=1:length(tc_track);plot(tc_track(i).MaxSustainedWind);hold on;end;xlabel('# of nodes per track');ylabel('(kn)');title('MaxSustainedWind')
        
        ha = axes('Position',[0 0.93 1 1],'Xlim',[0 1],'Ylim',[0  1],'Box','off', 'Visible','off', 'Units','normalized', 'clipping','off');
        titlestr = sprintf('%d - %d, %i tracks',tc_track(1).yyyy(1), tc_track(end).yyyy(end),length(tc_track));
        text(0.5, 0,titlestr,'fontsize',12,'fontweight','bold','HorizontalAlignment','center','VerticalAlignment', 'bottom')
    end
    
else
    fprintf('reading processed file %s\n',tc_track_hist_file);
    load(tc_track_hist_file);
end

return
