function [entity,ok]=cam_entity_value_GDP_SSP_one(entity,target_year,SSP_version)
% scale up asset values GDP
% MODULE:
%   CAM
% NAME:
%   cam_entity_value_GDP_SSP_one
% PURPOSE:
%   A copy of the original climada_entity_value_GDP_adjust_one for the CAM
%   module. Usually called from cam_entity_value_GDP_SSP (which treats a
%   series of entities)
%
%   Scale up asset values based on a country's estimated total asset value,
%   based on an SSP scenario (SSP_version) and for a target year.
%
%   We first normalize the asset values, then multiply by GDP*PPP*SCL, where
%   - GDP comes from the SSP data file, either the Ssp3Db or Ssp5Db tab as
%     specified by SSP_version and the column as specified by target_year
%     (see SSP_data_file in PARAMETER section in code)
%   - PPP, the purchase power parity conversion comes from tab "conversion
%     rate" in SSP_data_file (in PARAMETER section in code)
%   - SCL, the scale_up_factor based on income group comes from the core
%     climada economic_data_file (see PARAMETER section in code)
%
%   Caution: as soon as the entity has a field entity.assets.admin0_ISO3
%
%   Note: to avoid any troubles, entity.assets.Cover is set equal to entity.assets.Value
%
%   Prior calls: e.g. climada_nightlight_entity, country_risk_calc
%   Next calls: e.g. country_risk_calc
% CALLING SEQUENCE:
%   entity=cam_entity_value_GDP_SSP_one(entity,target_year,SSP_version)
% EXAMPLE:
%   entity=cam_entity_value_GDP_SSP_one(entity,2035,'Ssp3Db')
% INPUT:
%   entity: an entity structure, see e.g. climada_entity_load and
%       climada_entity_read
% OPTIONAL INPUT PARAMETERS:
%   target_year: the year we would like to get the GDP estimates for
%       Default=2035, see SSP data file for possible years
%   SSP_version: the SSP 3 or 5, hence either 'Ssp3Db' or 'Ssp5Db'. In fact
%       this is the name of the tab within the Excel file we read, hence the
%       user could also define a new one. Default 'Ssp3Db'
% OUTPUTS:
%   entity: on output the entity as on inpit, with adjusted asset values,
%       i.e. the sum(entity.assets.Value) now equals GDP*PPP*SCL
%       The print statement to stdout does list the factors and states the
%       matching ISO3 code for security checks, i.e. would they not all be
%       the same (the requested country), there might either be double
%       entries in tables or problems elsewhere.
%   ok: =1, if successfully scaled, =0 if not
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150227, initial
%-

ok=0;

% set global variables and directories
global climada_global
if ~climada_init_vars,return;end % init/import global variables

% check input
if ~exist('entity','var'),return;end
if ~exist('target_year','var'),target_year=2035;end
if ~exist('SSP_version','var'),SSP_version='Ssp3Db';end

module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% the table with SSP data (per country)
% NOTE that GDP data in this file is in billion USD, hence we multiply by 1e9
SSP_data_file=[module_data_dir filesep 'SSP_country_data_2013-06-12_OECDonly.xls'];
%
% the table with global GDP and income group info (per country)
% here, we only need income group from this file, as we use GDP from SSP_data_file
economic_data_file=[climada_global.data_dir filesep 'system' filesep 'economic_indicators_mastertable.xls'];
%
% missing data indicator (any missing in Excel has this entry)
misdat_value=-999;
%
% income group depending scale-up factors
% we take the income group number (1..4) from the
% economic_indicators_mastertable and use it as index to the
% income_group_factors:
income_group_factors = [2 3 4 5];

% Check if economic data file is available
if ~exist(SSP_data_file,'file')
    fprintf('Error: SSP information is missing.\n')
    fprintf('Please download it from the <a href="https://github.com/davidnbresch/climada_module_CAM">CAM repository on GitHub\n</a>');
    return;
end

if ~exist(economic_data_file,'file')
    fprintf('Error: income group information is missing.\n')
    fprintf('Please download it from the <a href="https://github.com/davidnbresch/climada">core climada repository on GitHub\n</a>');
    return;
end

% Read SSP data
[fP,fN]=fileparts(SSP_data_file);
SSP_data_file_mat=[fP filesep fN '.mat'];
if ~climada_check_matfile(SSP_data_file,SSP_data_file_mat)
    SSP_data.Ssp3Db = climada_xlsread('no',SSP_data_file,'Ssp3Db',1,misdat_value);
    SSP_data.Ssp5Db = climada_xlsread('no',SSP_data_file,'Ssp5Db',1,misdat_value);
    SSP_data.conversion_rates = climada_xlsread('no',SSP_data_file,'conversion_rates',1,misdat_value);
    fprintf('saving SSP data as %s\n',SSP_data_file_mat);
    save(SSP_data_file_mat,'SSP_data');
else
    load(SSP_data_file_mat);
end

% get the GDP for the target year (since column headers contain year)
fieldname=sprintf('VAL%i',target_year);
if isfield(SSP_data.(SSP_version),fieldname)
    SSP_data_GDP=SSP_data.(SSP_version).(fieldname)*1e9;
else
    fprintf(' skipped (no SSP data for year %i): %s\n',target_year,entity.assets.filename);
    return
end

% Read economic data
[fP,fN]=fileparts(economic_data_file);
economic_data_file_mat=[fP filesep fN '.mat'];
if ~climada_check_matfile(economic_data_file,economic_data_file_mat)
    econ_master_data = climada_xlsread('no',economic_data_file,[],1,misdat_value);
    fprintf('saving economic master data as %s\n',economic_data_file_mat);
    save(economic_data_file_mat,'econ_master_data');
else
    load(economic_data_file_mat);
end

if isfield(entity.assets,'admin0_ISO3')
    admin0_ISO3=char(entity.assets.admin0_ISO3);
    gdp_country_index = find(strcmp(SSP_data.(SSP_version).REGION,admin0_ISO3));
    if isempty(gdp_country_index)
        fprintf(' skipped (no admin0_ISO3/GDP match): %s, %s\n',admin0_ISO3,entity.assets.filename);
        return
    else
        GDP_value=SSP_data_GDP(gdp_country_index);
    end
    cnv_country_index = find(strcmp(SSP_data.conversion_rates.REGION,admin0_ISO3));
    if isempty(cnv_country_index)
        fprintf(' skipped (no admin0_ISO3/conversion rate match): %s, %s\n',admin0_ISO3,entity.assets.filename);
        return
    else
        conversion_rate=SSP_data.conversion_rates.conversion_rate(cnv_country_index);
    end
    scl_country_index = find(strcmp(econ_master_data.ISO3,admin0_ISO3));
    if isempty(scl_country_index)
        fprintf(' skipped (no admin0_ISO3/scale up match): %s, %s\n',admin0_ISO3,entity.assets.filename);
        return
    else
        scale_up_factor = income_group_factors(econ_master_data.income_group(scl_country_index));
    end
else
    fprintf(' skipped (no admin0_ISO3): %s\n',entity.assets.filename);
    return
end

% double check (to really avpid messing numbers up)
test_str=char(SSP_data.(SSP_version).REGION{gdp_country_index});
if ~strcmp(test_str,admin0_ISO3)
    fprintf(' WARNING: GDP REGION mismatch (%s <> %s)\n',test_str,admin0_ISO3)
end
test_str=char(SSP_data.conversion_rates.REGION{cnv_country_index});
if ~strcmp(test_str,admin0_ISO3)
    fprintf(' WARNING: conversion REGION mismatch (%s <> %s)\n',test_str,admin0_ISO3)
end
test_str=char(econ_master_data.ISO3{scl_country_index});
if ~strcmp(test_str,admin0_ISO3)
    fprintf(' WARNING: scale up ISO3 mismatch (%s <> %s)\n',test_str,admin0_ISO3)
end

if (~isnan(scale_up_factor) && ~isnan(GDP_value)) && ~isnan(conversion_rate)
    
    % normalize assets
    entity.assets.Value = entity.assets.Value/sum(entity.assets.Value);
    
    % scale up
    entity.assets.Value = entity.assets.Value*GDP_value*conversion_rate*scale_up_factor;
    
    % for consistency, update Cover
    if isfield(entity.assets,'Cover'),entity.assets.Cover=entity.assets.Value;end
    
    msg_str=' ';ok=1;
else
    msg_str='WARNING - not scaled ';
end
    
fprintf('%s%s: GDP %g, conversion %f, scale_up_factor %2.2f, year %i, (%s)\n',...
    msg_str,admin0_ISO3,GDP_value,conversion_rate,scale_up_factor,target_year,entity.assets.filename);

end % cam_entity_value_GDP_SSP_one