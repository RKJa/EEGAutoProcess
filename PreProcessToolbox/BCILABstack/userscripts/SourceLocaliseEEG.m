                                                                                                                                                                                 run(['../../SIFT/StartSIFT.m']); %Start SIFT
run(['../bcilab']);
pop_editoptions( 'option_single', false);
env_clear_memcaches;

%% Define what we're searching for
origfilepath='F:\TrainingDataTest\cleaned';
replacefilepath='F:\TrainingDataTest\SourceLocd';
filetype='_cleaned.set'; %File type. typically raw BioSemi ie .bdf
fileList = getAllFiles(origfilepath);
Fileidx=strfind(fileList,filetype); Fileidx=find(~cellfun(@isempty,Fileidx)); %Find the BioSemi Files
fileList=fileList(Fileidx); %Extract just these files

%% Headmodel index
sublist=cellstr(num2str([1:999]','%03i'))';
%sublist=cellstr(num2str([509]','%03i'))';
Headmodels={'F:\cBCI\headmodels\' ,sublist,'_BioSemi.mat'};

resample=256; % Set to zero to not resample, else set to resample rate
standardise=true;

% Regions
RegionsofInterest=[];%{'causibfa','grg'}; % Regions in the headmodel you wish to keep (make [] if all)
MergedRegionsofInterest=[];%{'visual L',{'nkng', 'ieongod'}}; % Regions to merge (make [] if none)
%% Now Process
for fn=1:length(fileList)
    
    pathsep=strfind(fileList{fn},filesep);pathsep=pathsep(end); %find where the directory ends and filename starts
    filename=fileList{fn}(pathsep+1:end-length(filetype));
    filepath=fileList{fn}(1:pathsep);
    
    newfilepath=strrep(filepath, origfilepath, replacefilepath);
    if ~exist(newfilepath,'dir');
        mkdir(newfilepath);
    end
    if ~exist([newfilepath filename '_SourceLocalised.set'],'file')
        try
            
            % Find the correct headmodel
            ind=[];
            for hmc=1:length(Headmodels{2})
                if ~isempty(strfind(filename,Headmodels{2}{hmc}))
                    ind(end+1)=hmc;
                end
            end
            
            % And process
            
            if length(ind)==0
                disp(['No headmodel found for ' filepath filename]);
            elseif length(ind)>1
                disp(['Too many headmodels found for ' filepath filename]);
            else
                
                HM=[Headmodels{1} Headmodels{2}{ind} Headmodels{3}];
                hmObj=load(HM);
                model_channels=hmObj.metadata.label;
                
                EEG=exp_eval(io_loadset([filepath filename filetype],'markerchannel',{'remove_eventchns',false}));
                
                data_channels={EEG.chanlocs.labels};
                req_channels=data_channels(ismember(data_channels,model_channels)); % Required channels
                EEG=flt_selchans('signal',EEG,'Channels',req_channels,'OrderPreservation','dataset-order');
                if resample
                    EEG=flt_resample('signal',EEG,'SamplingRate',resample,'FilterLength',10,'StopbandWeight',1);
                end
                EEG=flt_sourceLocalize('signal',EEG,'HeadModelObject',HM, ...
                    'InverseMethod',{'LORETA',{'LoretaOptions',{'MaxTolerance',0.001,'MaxIterations',100,'GridSize',100,'TrackHistory',false,'VerboseOutput',true,'InitalNoiseFactor',0.001,'BlockSize',32,'SkipFactor',2,'MaxBlocks',Inf,'Standardize','all'}}}, ...
                    'SourceAtlasLabels',hmObj.metadata.atlas.label, ...
                    'CollapseRoiCsd','median', ...
                    'KeepFullCsd',false, ...
                    'ROIAtlasLabels',RegionsOfInterest, ...
                    'CombineROI',MergedRegionsofInterest, ...
                    'appendROI','false', ...
                    'MakeDipfitStruct',false, ...
                    'TransformData',true, ...
                    'Verbosity',false);
                if standardise
                    EEG=flt_standardize('signal',EEG,'WindowLength',5,'Sphere',false,'StepSize',0.333,'UseGPU',false,'CovarianceRegularization',0.001);
                end
                
                EEG=exp_eval(EEG);
                vertlocs=hmObj.metadata.surfaces(end).vertices; % 3-d coordinates of the vertices
                for el=1:length(EEG.chanlocs)
                    EEG.chanlocs(el).labels=EEG.roiLabels{el}; % Add correct channel name
                    vert=hmObj.metadata.atlas.color==el; % Relevent 3d coordinates
                    coords=median(vertlocs(vert,:)); % select all 3D coordinates and find center
                    EEG.chanlocs(el).X=coords(1);
                    EEG.chanlocs(el).Y=coords(2);
                    EEG.chanlocs(el).Z=coords(3);
                end
                EEG.srcpot=[];
                pop_saveset(EEG,'filename',[filename '_SourceLocalised'],'filepath',newfilepath);
                env_clear_memcaches;
            end
        catch Error
            
            disp(['File failed: ' filepath filename filetype]);
        fileID = fopen([replacefilepath 'SourceLocalisationfailures' date '.txt'],'a');
fprintf(fileID,'\n%s\n',[filepath filename filetype]);
fprintf(fileID,'\t%s\n',[Error.message]);
fprintf(fileID,'\t%s\n',['Line ' num2str(Error.stack(end).line) ' ' Error.stack(end).file]);
fclose(fileID);
        end
    end
end