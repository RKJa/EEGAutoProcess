% This script will take data after PreProcessEEG is run. It Fourier Filters, then Epochs the data
% Any issues - Rajat_Jain@IEEE.org

% Open workers for parallel processing
if matlabpool('size')<feature('numcores')
    if matlabpool('size')
        matlabpool('close');
    end
    matlabpool('open','local',feature('numcores'));
end

run(['../bcilab']);
pop_editoptions( 'option_single', false);

%%
origfilepath='F:\NoBCIpilot\cleaned'; %Folder where all the data is stored
replacefilepath='F:\NoBCIpilot\processed\';
filetype='_cleaned.set'; %This is based on whatever is added to the end of the PreProcessEEG script default: _cleaned.set

filter=true; %If you want to filter, set to true
low_cutoff=[]; %Low frequency cut-off- the data should be de-trended by pre processing so typically should be set to []
high_cutoff=40; %High cutoff (normally ~40Hz for ERPs)

epoch=true; %If you want to epoch, set to true (otherwise false), then change settings below
PhotoDiodeEventCheck=0; %Convert and check each point with photodiode points

% Cell array of cell arrays to store photodiodes based on the event list

exptypes={'_'}; %This should be the same length as allevents
allevents={{'Cue'}};  %change _AD and _ID events back to '96' and '48'
lim=[-1 2]; %Set the epoch size, about stimulus, pre and post stimulus


%% Now let's filter!

fileList = getAllFiles(origfilepath);
Fileidx=strfind(fileList,filetype); Fileidx=find(~cellfun(@isempty,Fileidx)); %Find the cleaned set Files
fileList=fileList(Fileidx); %Extract just these files

for fn=1:length(fileList)%randperm(length(fileList))%
    fail=0;
    
    pathsep=strfind(fileList{fn},filesep);pathsep=pathsep(end); %find where the directory ends and filename starts
    filename=fileList{fn}(pathsep+1:end-length(filetype));
    
    %IDENTIFY WHICH EXPERIMENT TYPE THIS FILE IS
    vin=zeros(length(exptypes),1);
    for v=1:length(vin)
        vin(v)=~isempty(strfind(lower(filename),lower(exptypes{v})));
    end
    
    filepath=fileList{fn}(1:pathsep);
    
    newfilepath=strrep(filepath, origfilepath, replacefilepath);
    
    if ~exist([newfilepath filename '_processed.set'],'file')
        if ~exist(newfilepath,'dir');
            mkdir(newfilepath);
        end
        
        EEG=pop_loadset([filename filetype],filepath);
        if filter
            tic
            [~,EEG]=evalc('pop_eegfilt(EEG,low_cutoff,high_cutoff)');
            toc
        end
        
        if isempty(find(vin))
            disp(['Experiment type not found! Cannot Epoch ' filename])
            fileID = fopen([replacefilepath 'FilterEpochfailures' date '.txt'],'a');
            fprintf(fileID,'\n%s\n',[filepath filename filetype]);
            fprintf(fileID,'\t%s\n',['Experiment type not found! Cannot Epoch']);
            fclose(fileID);
            
        else
            
            
            
            if epoch
                try
                    idx=find(vin);
                    events=allevents{idx(1)};
                    if PhotoDiodeEventCheck %We can check event types into list of photodiodes which are switched on
                        neweventlist={};
                        for evno=1:length(EEG.event)
                            currentevent=str2double(EEG.event(evno).type);
                            if ~isnan(currentevent)
                                currentevent=dec2bin(currentevent,16); %Take event and convert to binary input list
                                newevent=[0,0,0,0];
                                for pdcount=1:length(newevent)
                                    if strcmp(currentevent(pdcount),'1')
                                        newevent(pdcount)=1; %newevent is a list which inputs are on
                                    end
                                end
                                for evref=1:length(events)
                                    validevent=1; %Assume its a valid event and reject if not
                                    for eventelement=1:length(events{evref})
                                        if events{evref}(eventelement)~=-1 && events{evref}(eventelement)~=newevent(eventelement)
                                            validevent=0;
                                        end
                                    end
                                    if validevent==1
                                        neweventlist{end+1}=EEG.event(evno).type; %If it compares to anything in the list, convert event type to true
                                    end
                                end
                            end
                        end
                        neweventlist=unique(neweventlist);
                        [EEG,idx]=pop_epoch(EEG,neweventlist,lim);
                        
                    else
                        EEG=pop_epoch(EEG,events,lim);
                    end
                catch Error
                    disp(['Cannot Epoch ' fileList{fn}]);
                    fileID = fopen([replacefilepath 'FilterEpochfailures ' date '.txt'],'a');
                    fprintf(fileID,'\n%s\n',[filepath filename filetype]);
                    fprintf(fileID,'\t%s\n',[Error.message]);
                    fprintf(fileID,'\t%s\n',['Line ' num2str(Error.stack(end).line) ' ' Error.stack(end).file]);
                    fclose(fileID);
                    fail=1;
                end
                
            end
            if fail==0
                pop_saveset(EEG,'filename',[filename '_processed'],'filepath',newfilepath);
                fileID = fopen([replacefilepath 'FilterEpochsaves ' date '.txt'],'a');
                fprintf(fileID,'\n%s\n',[filepath filename filetype ' saved with size ' num2str(size(EEG.data))]);
                fclose(fileID);
            end
        end
    end
end
