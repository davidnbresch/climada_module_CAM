function cam_calibrate(method,entity_file,hazard)
% climada CAM calibrate damagefunction
% MODULE:
%   CAM
% NAME:
%   cam_calibrate
% PURPOSE:
%   Calibrate damagefunctions for CAM project
%
%   In essence, calc EDS and compare with EM-DAT for the country as in the
%   entity. At the moment, only TC (wind) is implemented, only the
%   damagefunction definition is peril-dependent, see code below (search
%   for PERIL EDIT).
%
%   Standard use: run once with method=0 (checks USA) then run with method=2
%   By providing any other 3-digit country ISO code, you can check any
%   country by comparison with EM-DAT (see also emdat_read)
%   You can check any entitie's damage function(s) with climada_damagefunctions_plot
%
%   Previous call: country_risk_calc('USA',-3) % as for method=0 USA entity
%       and TC hazard event set need to exist
% CALLING SEQUENCE:
%   cam_calibrate(method,entity_file,hazard)
% EXAMPLE:
%   country_risk_calc('USA',-3) % only in case you do not have an entity and hazard set already
%   cam_calibrate(0,'USA') % check USA
%   cam_calibrate(1,'JPN') % check and save Japan
%   cam_calibrate(2,'USA') % calibrate all entities
% INPUTS:
%   method: =0 (default), run the calibration for the country as in the entity,
%       show results, but do NOT update the damagefunction in the entity
%       set =-1 to also show the plot (if=0, the plot is only saved)
%       =1: DO update the damagefunction in the entity (i.e. save the
%       calibrated damagefunction to the entity) - but do NOT check again
%       (use method=0 for this)
%       =2: update the damagefunctions in ALL entities. BE CAREFUL, this
%       truly OVERWRITES the damagefunctions in ALL entities.
% OPTIONAL INPUT PARAMETERS:
%   entity_file: the entity file with assets (today) to be used for calibration
%       OR just the 3-digit country code, such as 'USA' - in this case, the
%       code also tries to get the hazard filename from entity
%       If a filename is given, it needs to be an entity file (with path) NOT entity structure
%       > prompts for file if not given
%   hazard: the hzard event set
%       Either a hazard set file (with path) or a hazard structure
%       > prompts for file if not given
% OUTPUTS:
%   plot, as figure stored to .../results/cam_calibrate_{ISO3}_{peril_ID}.png
%       (just saved, not shown, unless method=-1)
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150307, initial
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

if ~exist('method','var'),method=0;end
if ~exist('entity_file','var'),entity_file=[];end
if ~exist('hazard','var'),hazard=[];end

%module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% the maxium return period (RP) we show (to zoom in a bit)
plot_max_RP=250;


if method==-1,fig_visible='on';else fig_visible='off';end

if isempty(entity_file) % prompt for entity if not given
    entity_file=[climada_global.data_dir filesep 'entities' filesep '*.mat'];
    [filename, pathname] = uigetfile(entity_file, 'Select entity:');
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        entity_file=fullfile(pathname,filename);
    end
end
if isstruct(entity_file)
    fprintf('Error: please pass an entity file, NOT a structure, aborted\n');
    return
else
    
    if length(entity_file)==3 % an ISO3 country code passed
        [country_name,country_ISO3]=climada_country_name(entity_file);
        entity_file=[climada_global.data_dir filesep 'entities' ...
            filesep country_ISO3 '_' strrep(country_name,' ','') '_entity.mat'];
    end
    
    % load the entity, if a filename has been passed
    load(entity_file); % contains entity
    
    if isempty(hazard) % infer hazard event set from entity
        if exist(entity.assets.hazard.filename,'file')
            hazard=entity.assets.hazard.filename;
        end
    end

end


if isempty(hazard) % prompt for hazard if not given
    hazard=[climada_global.data_dir filesep 'hazards' filesep '*.mat'];
    [filename, pathname] = uigetfile(hazard, 'Select hazard event set:');
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        hazard=fullfile(pathname,filename);
    end
end

if ~isstruct(hazard) % load the hazard, if a filename has been passed
    hazard_file=hazard;hazard=[];
    load(hazard_file); % contains hazard
end

country_name=entity.assets.admin0_name;
country_ISO3=entity.assets.admin0_ISO3;
peril_ID=hazard.peril_ID;



% ********* edit damagefunctions here in section PERIL EDIT ************

if ~strcmp(peril_ID,'TC')
    fprintf('Error: peril_ID of hazards set does not match the one we''re editing, aborted\n');
    return
end

[damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,25,1,0.375,'s-shape','TC',0);
fprintf('TC atl: %s\n',dmf_info_str);
% next line is the proper way, as we never delete a damagefunctions, just add
%entity=climada_damagefunctions_replace(entity,damagefunctions);
% next line is the fast way, really replacing with the ONLY ONE:
entity.damagefunctions=damagefunctions;

% ********* end edit damagefunctions here in section PERIL EDIT ********


% from now on, entity contains the adjusted damagefunction, which is also
% stored in damagefunctions (used in method==2 below)

if method<1
    
    % figure peril region
    [~,fN]=fileparts(hazard.filename);
    fN=strrep(fN,country_ISO3,'');
    fN=strrep(fN,strrep(country_name,' ',''),'');
    fN=strrep(fN,peril_ID,'');
    fN=strrep(fN,'_','');
    peril_region=strrep(fN,'_','');
    
    fprintf('\n*** %s %s %s %s ***\n',...
        char(country_ISO3),char(country_name),char(peril_ID),char(peril_region));
    
    EDS=climada_EDS_calc(entity,hazard);
    DFC=climada_EDS2DFC(EDS);
    
    DFC_plot = figure('Name',['DFC ' char(country_ISO3) ' ' char(country_name) ' ' peril_ID ' ' peril_region],'visible',fig_visible,'Color',[1 1 1],'Position',[430 20 920 650]);
    legend_str={};max_RP_damage=0; % init
    
    plot(DFC.return_period,DFC.damage,'-b','LineWidth',2);hold on
    max_damage   =interp1(DFC.return_period,DFC.damage,plot_max_RP); % interp to plot_max_RP
    max_RP_damage=max(max_RP_damage,max_damage);
    legend_str{end+1}=country_name;
    
    % add EM-DAT
    em_data=emdat_read('',country_name,peril_ID,1,1); % last parameter =1 for verbose
    if ~isempty(em_data)
        [adj_EDS,climada2emdat_factor_weighted] = cr_EDS_emdat_adjust(EDS);
        if abs(climada2emdat_factor_weighted-1)>10*eps
            adj_DFC=climada_EDS2DFC(adj_EDS);
            plot(adj_DFC.return_period,adj_DFC.damage,':b','LineWidth',1);
            legend_str{end+1}='EM-DAT adjusted';
        end
        
        plot(em_data.DFC.return_period,em_data.DFC.damage,'dg');
        legend_str{end+1} = em_data.DFC.annotation_name;
        plot(em_data.DFC.return_period,em_data.DFC_orig.damage,'og');
        legend_str{end+1} = em_data.DFC_orig.annotation_name;
        max_RP_damage=max(max_RP_damage,max(em_data.DFC.damage));
    end % em_data
    
    % zoom to 0..plot_max_RP years return period
    if max_RP_damage==0,max_RP_damage=1;end
    axis([0 plot_max_RP 0 max_RP_damage]);
    
    legend(legend_str,'Location','NorthWest'); % show legend
    title([peril_ID ' ' peril_region ' ' country_ISO3 ' ' country_name]);
    
    DFC_plot_name=[climada_global.data_dir filesep 'results' filesep 'cam_calibrate_' country_ISO3 '_' peril_ID '.png'];
    while exist(DFC_plot_name,'file'),DFC_plot_name=strrep(DFC_plot_name,'.png','_.png');end % avoid overwriting
    if ~isempty(DFC_plot_name)
        saveas(DFC_plot,DFC_plot_name,'png');
        fprintf('saved as %s\n',DFC_plot_name);
    end
    if method>=0,delete(DFC_plot);end
    
elseif method==1
    if ~exist(entity.assets.hazard.filename,'file')
        entity.assets.hazard.filename=hazard.filename;
    end
    fprintf('entity saved as %s\n',entity_file);
    save(entity_file,'entity')
    
elseif method==2
    fprintf('updating all entities\n');
    
    folder_name=[climada_global.data_dir filesep 'entities'];
    D=dir([folder_name filesep '*.mat']);
    
    for D_i=1:length(D)
        if ~D(D_i).isdir && ~(strcmp(D(D_i).name,'entity_template.mat') || strcmp(D(D_i).name,'demo_today.mat'))
                        
            entity_file=[folder_name filesep D(D_i).name];
            
            try
                load(entity_file)
                
                if isfield(entity,'damagefunctions')
                    
                    % next line is the proper way, as we never delete a damagefunctions, just add
                    %entity=climada_damagefunctions_replace(entity,damagefunctions);
                    % next line is the fast way, really replacing with the ONLY ONE:
                    entity.damagefunctions=damagefunctions;
                    
                    fprintf('%s updated\n',D(D_i).name);
                    save(entity_file,'entity')
                    
                end
            catch
                fprintf('%s skipped (catch)\n',D(D_i).name);
            end
            
        end % ~D(D_i).isdir
        
    end % D_i
end % method

end % cam_calibrate