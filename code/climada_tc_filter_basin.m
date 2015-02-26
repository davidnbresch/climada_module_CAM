function tc_track_basin=climada_tc_filter_basin(tc_track,basin_number)
% This function determines the ocean basin of storm tracks in
% structure tc_track.
%
% NAME:
%   climada_tc_filter_basin
% PURPOSE:
%   Catagorize storms in 5 different ocean basins
%   (North Atlantic, South Atlantic, North Pacific, South Pacific,
%   Indian Ocean). Only necessary if global data used as allocated
%   in climada_tc_read_gfdl_database.m. The function reduces the
%   structure to the specified basin and modifies the ID_no.
%
%   previous call: climada_tc_read_cam_database
% CALLING SEQUENCE:
%   tc_track_out=climada_tc_filter_basin(tc_track,basin);
% EXAMPLE:
%   tc_track_natl=climada_tc_read_gfdl_database(tc_track,1);
%-

if ~exist('basin_number','var');basin_number=1;display(['No basin specified, default North Atlantic']);end


% Criteria for basin on starting point and end point of track.
% [Start Range West; Start Range East: End Range West; End Range East]

crit(1,:,:)=[-80 0; 0 20; -140 0; 0 0; 1 1]; %North Atlantic
crit(2,:,:)=[-80 0; 0 30;  -80 0; 0 10; -1 -1]; %South Atlantic
crit(3,:,:)=[-180 -75; 120 180; -180 -85; 100 180; 1 1]; %North Pacific
crit(4,:,:)=[-180 -75; 150 180; -180 -85; 130 180; -1 -1]; %South Pacific
crit(5,:,:)=[0 0; 40 130; 0 0;20 115; -1 1]; %Indian Ocean

basin_name={'North Atlantic','South Atlantic','North Pacific',...
    'South Pacific','Indian Ocean'};
n_tracks=length(tc_track);
next_track=0;

msgstr=['Classification for ' char(basin_name(basin_number)) ' of ' num2str(n_tracks)  ' storm tracks'];

h = waitbar(0,msgstr);

for i=1:n_tracks
    waitbar(i/n_tracks,h);
    
    if (tc_track(i).lon(1) > crit(basin_number,1,1) & tc_track(i).lon(1) < crit(basin_number,1,2) || ... %Test startin position
            tc_track(i).lon(1) > crit(basin_number,2,1) & tc_track(i).lon(1) < crit(basin_number,2,2)) & ...
            (tc_track(i).lon(end) > crit(basin_number,3,1) & tc_track(i).lon(end) < crit(basin_number,3,2) || ... %Test end position
            tc_track(i).lon(end) > crit(basin_number,4,1) & tc_track(i).lon(end) < crit(basin_number,4,2)) & ...
            (sign(tc_track(i).lat(1))==crit(basin_number,5,1) || sign(tc_track(i).lat(1))==crit(basin_number,5,2)) %Test for latitude
        
        next_track=next_track+1;
        tc_track_basin(next_track)=tc_track(i);
        % Change basin number in ID_no
        tc_track_basin(next_track).ID_no=basin_number*1e6+rem(tc_track(i).ID_no,1e6);
    end
end

if next_track>0
    display([num2str(next_track) ' storms identified in ' char(basin_name(basin_number))])
elseif next_track==0
    display([num2str(next_track) ' storms identified in ' char(basin_name(basin_number))])
    tc_track_basin=[];
end
close(h)

%
if basin_number==3
    % treat negative longitudes (simple, just add 360 to negative
    % longitudes, does result in dots being connected nicely on map)
    for track_i=1:length(tc_track_basin)
        tc_track_basin(track_i).lon(tc_track_basin(track_i).lon<0)=...
            tc_track_basin(track_i).lon(tc_track_basin(track_i).lon<0)+360;
    end % track_i
end

return

