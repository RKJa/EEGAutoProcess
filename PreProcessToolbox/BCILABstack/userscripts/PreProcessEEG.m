% This should be run first. It searches for raw data and removes artifacts
% and de-trends (ie generally cleans it). Can be followed by FilterEpochEEG
% and MergeEEG
% 
% Any Issues - Rajat_Jain@ieee.org 

%% Load in BCILAB
run(['../../SIFT/StartSIFT.m']); %Start SIFT
run(['../bcilab']); %Start BCIlab
pop_editoptions( 'option_single', false);

%% User Options
convertphotodiodes=false;% Recommendation: Set to true for experiments which use Photodiodes for markers
standardize=true;
resample=0; % Set to zero to not resample, else set to resample rate

origfilepath='F:\NoBCIpilot\converted';
replacefilepath='F:\NoBCIpilot\cleaned';
filetype='.set'; %File type. typically raw BioSemi ie .bdf
%% Setup files etc
fileList = getAllFiles(origfilepath);
Fileidx=strfind(fileList,filetype); Fileidx=find(~cellfun(@isempty,Fileidx)); %Find the BioSemi Files
fileList=fileList(Fileidx); %Extract just these files

opts.datapath         = 'data:/';
hmObj=load(env_translatepath(['data:/','HeadModels',filesep,'Colin27_BioSemi_10_10_MobilabHeadModel_5003V_iso2mesh.mat']),'metadata');

%% Now Process
for fn=1:length(fileList)

    pathsep=strfind(fileList{fn},filesep);pathsep=pathsep(end); %find where the directory ends and filename starts
    filename=fileList{fn}(pathsep+1:end-4);
    filepath=fileList{fn}(1:pathsep);
    
     newfilepath=strrep(filepath, origfilepath, replacefilepath);
     if ~exist(newfilepath,'dir');
         mkdir(newfilepath);
     end
if ~exist([newfilepath filename '_cleaned.set'],'file')
    try
EEG=exp_eval(io_loadset([filepath filename filetype],'markerchannel',{'remove_eventchns',false}));
if convertphotodiodes
EEG=exp_eval(flt_PD_to_numeric(EEG));
end
% Swap out busted electrodes
if exist([filepath filename '_badelectrodes.txt'],'file')
    EEG=exp_eval(EEG);
    Eidx=[];
    BadElectrodes=textread([filepath filename '_badelectrodes.txt'],'%s');
    for k=1:length(BadElectrodes)
        try
        currentelectrode=find(strcmp(lower(BadElectrodes{k}),lower({EEG.chanlocs.labels})));
        Eidx(k)=currentelectrode;
        catch
            disp([num2str(length(currentelectrode)) ' instances of electrode ' BadElectrodes{k} ' found']);
        end
    end
    
    for k=1:2:length(Eidx)
        EEG.chanlocs(Eidx(k+1)).labels=BadElectrodes{k};
        EEG.chanlocs(Eidx(k)).labels=['BUSTED' num2str(k)];
    end
end

EEG=exp_eval(flt_selchans('signal',EEG,'Channels',hmObj.metadata.label,'OrderPreservation','query-order'));

% Store event and channel data for reference
originalevents={EEG.event.type};originalchannels={EEG.chanlocs.labels};
 if resample && resample<EEG.srate
EEG=flt_resample('signal',EEG,'SamplingRate',resample,'FilterLength',10,'StopbandWeight',1);
 end
EEG=exp_eval(flt_clean_settings('signal',EEG,'DataSetting','Rajat_Oct_2015','RetainPhases',true,'PreferFIR',true,'CausalFiltering',true));

%Store event and channel data for changes
postevents={EEG.event.type};postchannels={EEG.chanlocs.labels};

EEG=flt_reref('signal',EEG);
EEG=flt_interpchs('signal',EEG,'TemplateHeadModel',env_translatepath([opts.datapath 'HeadModels' filesep 'Colin27_BioSemi_10_10_MobilabHeadModel_5003V_iso2mesh.mat']));
if standardize
EEG=flt_standardize('signal',EEG,'WindowLength',5,'Sphere',false,'StepSize',0.333,'UseGPU',false,'CovarianceRegularization',0.001);
end
EEG=exp_eval(EEG);

for evno=1:length(EEG.event)
    EEG.event(evno).latency=EEG.event(evno).latency+(EEG.etc.filter_delay*EEG.srate);
end
pop_saveset(EEG,'filename',[filename '_cleaned'],'filepath',newfilepath);

% Now Find changes - ie electrodes and events removed by BCI lab and add to a file
brokenelectrodes = setdiff(originalchannels,postchannels);
boundaryindex=strcmp('boundary',postevents); postevents=postevents(~boundaryindex); %Remove BCIlabs "boundary" events
PreProcessingInfo=brokenelectrodes;
PreProcessingInfo{end+1}=['Original Events ' num2str(length(originalevents))];
PreProcessingInfo{end+1}=['Post Events ' num2str(length(postevents))];
PreProcessingInfo{end+1}=['Lost Events ' num2str(length(originalevents)-length(postevents))];
PreProcessingInfo{end+1}=['Maintained Events ' num2str(round(100*length(postevents)/length(originalevents))) '%'];
fileID = fopen([newfilepath filename '_PreProcesschanges.txt'],'w');
fprintf(fileID,'%s\r\n', PreProcessingInfo{:});
fclose(fileID);
    catch Error
        disp(['File failed: ' filepath filename filetype]);
        fileID = fopen([replacefilepath 'PreProcessfailures' date '.txt'],'a');
fprintf(fileID,'\n%s\n',[filepath filename filetype]);
fprintf(fileID,'\t%s\n',[Error.message]);
fprintf(fileID,'\t%s\n',['Line ' num2str(Error.stack(end).line) ' ' Error.stack(end).file]);
fclose(fileID);
    end
end
end

disp('Pre Processing (PreProcessEEG.m script) is finished');
