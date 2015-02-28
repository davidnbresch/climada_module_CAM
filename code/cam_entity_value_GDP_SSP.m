function entity=cam_entity_value_GDP_SSP(entity_file_regexp,target_year,SSP_version)
% scale up asset values
% MODULE:
%   CAM
% NAME:
%   cam_entity_value_GDP_SSP
% PURPOSE:
%   A copy of the original climada_entity_value_GDP_adjust for the CAM
%   module. Calls cam_entity_value_GDP_SSP_one, see there for details
%
%   Scale up asset values based on a country's estimated total asset value.
%
%   We first normalize the asset values, then multiply by GDP_value and a
%   scale_up_factor based on income group. GDP_value comes from the SSP
%   data file (see SSP_data_file in PARAMETER section in code), the
%   scale_up_factor from economic_data_file (see PARAMETER section in code)
%
%   Prior calls: e.g. climada_nightlight_entity, country_risk_calc
%   Next calls: e.g. country_risk_calc
% CALLING SEQUENCE:
%   entity=cam_entity_value_GDP_SSP(entity_file_regexp,target_year,SSP_version)
% EXAMPLE:
%   cam_entity_value_GDP_SSP('*_future.mat',2035) % all future for 2035
%   cam_entity_value_GDP_SSP('*_*_entity.mat',2015); % all today for 2015
% INPUT:
%   entity_file_regexp: the full filename of the entity to be scaled up
%       or a regexp expression, e.g. for all entities:
%       entity_file_regexp=[climada_global.data_dir filesep 'entities' filesep '*.mat']
%       or just a regexp to be evaluated within ../data/entities, such as
%       e.g. entity_file_regexp='*future.mat';
% OPTIONAL INPUT PARAMETERS:
%   target_year: the year we would like to get the GDP estimates for
%       Default=2035, see SSP data file for possible years
%   SSP_version: the SSP 3 or 5, hence either 'Ssp3Db' or 'Ssp5Db'. In fact
%       this is the name of the tab within the Excel file we read, hence the
%       user could also define a new one. Default 'Ssp3Db'
% OUTPUTS:
%   entity: entity with adjusted asset values, also stored as .mat file 
%   (only last entity if entity_file_regexp covers more than one)
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150227, initial
% David N. Bresch, david.bresch@gmail.com, 20150228, finished
%-

% initialize output
entity = [];

% set global variables and directories
global climada_global
if ~climada_init_vars,return;end % init/import global variables

% check input
if ~exist('entity_file_regexp','var'), entity_file_regexp='';end
if ~exist('target_year','var'),target_year=2035;end
if ~exist('SSP_version','var'),SSP_version='Ssp3Db';end


% PARAMETERS
%

% prompt for entity_file_regexp if not given
if isempty(entity_file_regexp) % local GUI
    entity_file_regexp=[climada_global.data_dir filesep 'entities' filesep '*.mat'];
    [filename, pathname] = uigetfile(entity_file_regexp, 'Select entity:');
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        entity_file_regexp=fullfile(pathname,filename);
    end
end

if isempty(strfind(entity_file_regexp,filesep))
    % in case only a filename regexp without path has been specified
    entity_file_regexp=[climada_global.data_dir filesep 'entities' filesep entity_file_regexp];
end

% find the desired entity / entities
fP = fileparts(entity_file_regexp);
D_entity_mat = dir(entity_file_regexp);

% loop over entity files and adjust asset values
for file_i=1:length(D_entity_mat)
    
    entity_file_i = [fP filesep D_entity_mat(file_i).name];
    try
        fprintf('%s:\n',D_entity_mat(file_i).name)
        load(entity_file_i)
        checksum_before=sum(entity.assets.Value);
        [entity,ok]=cam_entity_value_GDP_SSP_one(entity,target_year,SSP_version);
        if ok
            checksum_after=sum(entity.assets.Value);
            fprintf(' total asset value before %g, after %g\n',checksum_before,checksum_after)
            fprintf(' saving %s in %s (by %s)\n',D_entity_mat(file_i).name,fP,mfilename)
            save(entity_file_i,'entity')
        end
    catch
        fprintf('skipped (invalid entity): %s\n',entity_file_i);
        entity.assets=[]; % dummy, to indicate failure
    end
    
end % file_i

end % cam_entity_value_GDP_SSP